`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/14 14:27:17
// Design Name: 
// Module Name: serial_cfar_2048
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module serial_cfar_2048
#(
    parameter DW                =   16  , // DATA WIDTH
    parameter PN                =   1  , // PARALLEL NUMBER
    parameter PROT_UNIT_LENGTH  =   3   , //protect unit length
    parameter REF_UNIT_LENGTH   =   16   , //reference unit length
    parameter FRAME_LEN         =   1024 , //input frame length
    parameter BASE_CHAN_IDX     =   0   ,  //基础通道编号
    parameter K_WIDTH           =   5   
)
(
    input                  s_axis_aclk     ,
    input                  s_axis_aresetn  , 

    input [DW*PN-1:0]      s_axis_tdata    , // 并行输入数据
    input                  s_axis_tvalid   , 
    input                  s_axis_tstart   ,
    input                  s_axis_tlast    ,
    input  [K_WIDTH-1:0]   s_axis_user_k   , //input multiply coefficient

    output                 s_axis_tready   ,
    
    output reg             m_axis_tdata    , // CFAR 检测二值数据 
    output reg[DW-1 : 0]   m_axis_tuser    , // CFAR 检测实际幅度值
    output reg[17:0]       m_axis_user_dpl_idx , // 多普勒通道编号  这里 将多普勒通道信号的位宽扩展，适应现有项目的需要
    output reg[17:0]       m_axis_user_dst_idx , // 距离通道编号
    output reg             m_axis_tvalid   ,
    output reg             m_axis_tlast 
);


// 恒虚警窗口长度，为(保护单元长度+参考单元长度)*2+1
localparam WL = ( PROT_UNIT_LENGTH + REF_UNIT_LENGTH )*2+1 ;    

/*
    REG & WIRE DECLARATION
*/

// 镜像寄存器组输出并行数据
wire [ WL*DW-1 : 0 ] scr_m_axis_tdata ; //serial cfar register parallel output data
wire                 scr_m_axis_tvalid; 
// 流水线cfar模块信号
wire            scp_m_axis_tdata       ; // serial cfar pipeline 
wire            scp_m_axis_tvalid      ;
wire [DW-1:0]   scp_m_axis_user_value  ;
    
// 输入的并行数据进入镜像寄存器组
serial_cfar_register 
#(
    .DW (DW             ),// Data Width
    .PN (PN             ),// Parallel Number
    .WL (WL             ) // Window Length
)serial_cfar_register_inst0
(
    .s_axis_aclk    (s_axis_aclk        ),
    .s_axis_aresetn (s_axis_aresetn     ),
    .s_axis_tdata   (s_axis_tdata       ),
    .s_axis_tvalid  (s_axis_tvalid      ),

    .s_axis_tready  (s_axis_tready      ),
    .m_axis_tdata   (scr_m_axis_tdata   ),
    .m_axis_tvalid  (scr_m_axis_tvalid  ) 
);

// 并行的cfar处理模块
serial_cfar_pipeline
#(
    .DATA_WIDTH         (DW                 ),    //input data width
    .REF_UNIT_LENGTH    (REF_UNIT_LENGTH    ),    //reference unit length
    .PROT_UNIT_LENGTH   (PROT_UNIT_LENGTH   ),    //protect unit length
    .K_WIDTH            (8                  )    //multiply coefficient width
)serial_cfar_pipeline_inst0
(
    .s_axis_aclk         (s_axis_aclk           ),
    .s_axis_aresetn      (s_axis_aresetn        ),
    .s_axis_tdata        (scr_m_axis_tdata      ),
    .s_axis_tvalid       (scr_m_axis_tvalid     ),
    .s_axis_user_k       (s_axis_user_k         ),
    
    .m_axis_tdata        (scp_m_axis_tdata      ),
    .m_axis_tvalid       (scp_m_axis_tvalid     ),
    .m_axis_user_value   (scp_m_axis_user_value )   // 输出幅度值
);

// 内部产生开始信号与终止信号
reg [17:0]  dst_cnt         ; // 距离单元计数器
reg [17:0]   dpl_cnt         ; // 多普勒单元计数器  2023/5/23 修改为 8位位宽支持更大的多普勒单元个数
wire        cfar_tlast     = ( dpl_cnt ==  FRAME_LEN ) ;// dst_cnt内部计数器从1开始所以此处不是与FRAME_LEN-1比较
//或者将此处修改为时序逻辑输出，此时可以将逻辑修改为dst_cnt == FRAME_LEN - 1 



// 产生距离单元编号

always @ ( posedge s_axis_aclk )
   if ( ~s_axis_aresetn )
       dst_cnt <= 0 ; 
   else if ( (dpl_cnt == ( PN-1 ) ) & scp_m_axis_tvalid ) // dst_cnt内部计数器从1开始
       dst_cnt <= dst_cnt + 1 ;
   else
       dst_cnt <= dst_cnt ;

   
       
// 产生多普勒单元编号
always @ ( posedge s_axis_aclk)
    if ( ~s_axis_aresetn | cfar_tlast ) 
        dpl_cnt <= 0 ;
    else if (scp_m_axis_tvalid )
        dpl_cnt <= dpl_cnt + 1;
    else
        dpl_cnt <= dpl_cnt ;


// 将输出数据使用寄存器寄存输出
always @ ( posedge s_axis_aclk )
    if ( ~s_axis_aresetn )
        begin
            m_axis_tdata        <= 0 ;
            m_axis_tvalid       <= 0 ;
            m_axis_tuser        <= 0 ;
            m_axis_user_dpl_idx <= 0 ;
            m_axis_user_dst_idx <= 0 ;
            //m_axis_tlast        <= 0 ;
        end
    else if ( scp_m_axis_tvalid )
        begin
            m_axis_tdata        <= scp_m_axis_tdata         ;
            m_axis_tvalid       <= scp_m_axis_tvalid        ;
            m_axis_tuser        <= scp_m_axis_user_value    ;
            m_axis_user_dpl_idx <= dpl_cnt + BASE_CHAN_IDX  ;
            m_axis_user_dst_idx <= dst_cnt                  ;
            //m_axis_tlast        <= cfar_tlast               ;
        end
    else
        begin
            m_axis_tdata        <= 0    ;
            m_axis_tvalid       <= 0    ;
            m_axis_tuser        <= 0    ;
            m_axis_user_dpl_idx <= 0    ;
            m_axis_user_dst_idx <= 0    ;
            //m_axis_tlast        <= 0    ;
        end
        
    // 处理完成生成逻辑 2019/5/7
    always @ ( posedge s_axis_aclk )
        if ( ~s_axis_aresetn )
            m_axis_tlast <= 0 ;
        else 
            m_axis_tlast <= cfar_tlast ; 

/*
    数据输出验证部分，将CFAR处理结果输出为文本格式
*/
/*
integer fid;
initial
    begin
        case(BASE_CHAN_IDX)
            0     : fid = $fopen("serial_cfar_dout_0.txt","w");   
            64    : fid = $fopen("serial_cfar_dout_64.txt","w");   
            128   : fid = $fopen("serial_cfar_dout_128.txt","w");   
            192   : fid = $fopen("serial_cfar_dout_192.txt","w");   
            256   : fid = $fopen("serial_cfar_dout_256.txt","w");   
            320   : fid = $fopen("serial_cfar_dout_320.txt","w");
            384   : fid = $fopen("serial_cfar_dout_384.txt","w"); 
            448   : fid = $fopen("serial_cfar_dout_448.txt","w");			
        endcase
    end

always @ ( posedge s_axis_aclk )
    if ( m_axis_tdata ) // 如果输出数据过门限值,将过门限的多普勒信息，距离信息与幅度信息打印出来
        $fdisplay(fid,"%d,%d,%d",m_axis_user_dpl_idx,m_axis_user_dst_idx,m_axis_tuser);
*/
endmodule
    
    

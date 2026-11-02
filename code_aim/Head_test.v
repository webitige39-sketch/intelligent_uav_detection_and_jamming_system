`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
/*
    作者：张子宁
    
    日期：2023/9/4
    
    模块功能：时域信号进行门限检测，找到start和last。


    日志：  2023/9/4：完成模块功能

            2023/11/6：完善计数逻辑

*/
//////////////////////////////////////////////////////////////////////////////////


module Thr_detection#(
    parameter DATA_WIDTH          = 32 ,        // Input & Output Data Width
    parameter FRAME_LENGTH        = 512         // Input & Output FRAME 512
)(  
    input [31:0]                     Thred             ,
    input                            s_axis_aclk       ,
    input                            s_axis_aresetn    ,
    input [DATA_WIDTH-1 : 0]         s_axis_tdata      ,
    input                            s_axis_tvalid     ,
    input                            Freq_Thr_over     ,//频域门限检测结束，开始发射
    input                            FIND_EN           ,

    output reg                       m_axis_tstart     ,
    output reg                       m_axis_tlast      ,
	output reg                       FIND              ,
	output reg [20:0]                CNT               ,
	output     [31:0]                data_sum          
    ); 

    
parameter DW = DATA_WIDTH;


//求和后的结果
wire                      data_sum_valid  ;
reg  [ 5  : 0   ]         cnt = 0         ;

wire [DATA_WIDTH-1:0]corr_out;
wire corr_out_vld;


    corr #( 
        .DATA_WIDTH(16        ),
        .WINDOW_LEN(128       )
    ) u_dut (
        .clk        (s_axis_aclk               ),
        .rst_n      (s_axis_aresetn            ),
        .valid_in   (s_axis_tvalid             ),
        .din_i      (s_axis_tdata[DW/2-1-:DW/2]),   
        .din_q      (s_axis_tdata[  DW-1-:DW/2]),   

        .valid_out  (corr_out_vld              ),
        .dout_pwr_sq(corr_out                  )
    );



reg                                     CNT_rst                    ;

assign data_sum = corr_out_vld?corr_out:32'b0;




//FIND_EN：用于重新拉高门限检测模块中的FIND信号，继续检测门限
//FIND为1时寻找tstart为0时停止寻找,表示找到
always@ (posedge s_axis_aclk)
    if( ~s_axis_aresetn | FIND_EN)
        begin 
            FIND  <= 1   ;
        end
    else if( data_sum > Thred )
        begin
            FIND <= 0 ;
        end
    else
            FIND <= FIND ;




//取FIND的下降沿,用于CNT清0
reg      FIND_LATE;
always @( posedge s_axis_aclk ) 
    if( ~s_axis_aresetn )
        FIND_LATE <= 1 ;
    else
        FIND_LATE <= FIND ;


always @( posedge s_axis_aclk )
    if( ~s_axis_aresetn )
        CNT_rst <= 0 ;
    else
        CNT_rst <= ~FIND & FIND_LATE ;



//CNT计数器，用于标志tstart和tlast
always @( posedge s_axis_aclk ) 

    if(~s_axis_aresetn | CNT_rst )
        CNT <= 0 ;

    else if( (~FIND_LATE) | (CNT < 100000) ) //或改成与
        CNT <= CNT + 1;

    else
        CNT <= CNT ;


always @ ( posedge s_axis_aclk )
        if ( ~ s_axis_aresetn )
            begin
                m_axis_tlast  <= 0 ;
                m_axis_tstart <= 0 ;
            end
        else if ( ~FIND )
            begin
                m_axis_tstart <= ( CNT == 100 )  ;
                m_axis_tlast  <= ( CNT == ( FRAME_LENGTH + 100 ) ) ;//100
            end
        else
            begin
                m_axis_tstart<= 0 ;
                m_axis_tlast <= 0 ;
            end


			
			
endmodule
`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////////////////////////
/*    
   -------------------------------------------------------------------------------------------------
    作者： 张子宁
	
    时间： 2023/10/16日
    
    说明： 瞄频干扰

    版本：	
           
    日志:  
    2023/11/1   窄带瞄频分两部分：分频白噪声和dds产生的频偏
                    白噪声：根据时钟频率和分频值生成窄带信号
                    dds：   根据检测模块传来的user信号产生需要的频偏值

    2023/11/7  修改了分频器输出信号的宽度，可以实现更窄的干扰


    2023/12/6  用于拉高find的信号要在发射结束一定时间后产生

    zsh 2025/1/20 aim_noise_valid为发射时间
                  EN_GANRAO为有效噪声 两者相差3000点保护时间 

                  修改1:     81行        en_cnt <= en ; ----->   en_cnt <= en_cnt ; 
                  修改2：    299行       dout_tvalid && EN_GANRAO; -----> dout_tvalid && en_cnt;


    zsh 2025/3/23 添加宽带干扰、扫频干扰、切片转发干扰、梳状谱干扰，可以通过sel_jam选择所需要的干扰
                  sel_jam = 0  为窄带瞄频干扰 
                  sel_jam = 1  为扫频干扰，核心思路为通过更改dds频率控制字产生不同频率的单音信号，在与经过二相编码之后的噪声混频得到，扫频周期约为0.2ms，扫频带宽为30.72Mhz
                  sel_jam = 2  为宽带干扰，直接将高斯白噪声生成模块生成的白噪声输出 噪声带宽与高斯白噪声生成模块时钟频率相同，现为30.72Mhz
                  sel_jam = 3  为切片转发干扰，通过检测模块rom储存的数据获得接收信号，之后累加地址，并不断循环，产生切片转发干扰
                  sel_jam = 4  为梳状谱干扰，把切片转发干扰使用五个单音信号调制到不同频点产生 delta f 大约0.5Mhz
                  已全部仿真测试完成
    ------------------------------------------------------------------------------------------------

    zsh 2026/1/5 修改为窄带干扰模式，方便测试
                  sel_jam = 0  为窄带瞄频干扰 
                  sel_jam = 1  为宽带干扰，直接将高斯白噪声生成模块生成的白噪声输出 噪声带宽与高斯白噪声生成模块时钟频率相同，现为45Mhz

*/
/////////////////////////////////////////////////////////////////////////////////////////////////////



module aim_noise
/*#(  
    parameter	PRINT_LOG	   =	1	,
	parameter	LOG_NAME_wb_re	 =	"wb_noise_re.txt",
    parameter   LOG_NAME_wb_im   =	"wb_noise_im.txt",
    parameter   LOG_NAME_aim_re   =	"aim_noise_re.txt",
    parameter   LOG_NAME_aim_im   =	"aim_noise_im.txt",
    parameter   LOG_NAME_mix_re   =	"mix_noise_re.txt",
    parameter   LOG_NAME_mix_im   =	"mix_noise_im.txt"
)*/
(
    input                               s_axis_aclk                ,
    input                               s_axis_aresetn             ,
    input              [  15:0]         F_user                     ,
    input              [  15:0]         DIV_CNT                    ,
    input                               Freq_Thr_over              ,
    input              [  31:0]         AIM_TIME                   ,
    input                               FIND                       ,
    input                               NO_UAV                     ,

    input              [   9:0]         ADDRB                      ,
    input                               REA                        ,
    input              [  31:0]         m_axis_tdata_ram           ,
    input              [  31:0]         sel_jam	                   ,
    input                               F_user_valid               ,         


    output             [ 127:0]         fctr_bus                   ,
    output             [  31:0]         aim_noise                  ,
    output                              aim_noise_valid            ,
    output reg                          FIND_EN_AIM                ,
    output                              EN_GANRAO                  ,
    output             [  31:0]         data_2ph                   ,
    output             [  31:0]         sincos                     ,
    output             [  31:0]         data                       

);


//使能逻辑
reg  [ 31:0 ] CNT_EN = 0;
reg  en = 0 ;
reg  en_cnt = 0 ;


always@ ( posedge s_axis_aclk )
//    if( ~s_axis_aresetn | CNT_EN == (AIM_TIME-1)| NO_UAV )
    if( ~s_axis_aresetn | CNT_EN == (AIM_TIME-1))
        begin
            en_cnt <= 0 ;
        end
    else if( Freq_Thr_over )
        begin
            en_cnt <= 1 ;
        end
    else
        begin
            en_cnt <= en_cnt ; 
        end


//CNT_EN使能en的计数器，用于控制使能时间
//当计数到100M(1s)时,归零
always @(posedge s_axis_aclk) 
    if( ~s_axis_aresetn | CNT_EN ==( AIM_TIME-1 ) )
        begin 
            CNT_EN  <= 0   ;
        end
    else if( en_cnt )
        begin
            CNT_EN <= CNT_EN + 1 ;
        end
    else 
        begin
            CNT_EN <= CNT_EN ;//？0吗
        end


//FIND_EN：用于重新拉高门限检测模块中的FIND信号
//当使能计数到（干扰发射结束）时，让门限检测模块继续检测门限
always @(posedge s_axis_aclk) 
    if( ~s_axis_aresetn  )
        begin 
            FIND_EN_AIM <= 0 ; 
        end
    else if( CNT_EN ==( AIM_TIME-1) )
        begin
            FIND_EN_AIM <= 1 ; 
        end
    else 
        FIND_EN_AIM <= 0 ;

//en使能模块，用于产生干扰
//当检测到Freq_Thr_over时，开始给干扰产生模块使能
//当CNT_EN计数到1s时，关闭给干扰产生模块的使能
always@ ( posedge s_axis_aclk )
    if( ~s_axis_aresetn | CNT_EN == (AIM_TIME-1-3000) )
        begin
            en <= 0 ;
        end
    else if( Freq_Thr_over )
        begin
            en <= 1 ;
        end
    else
        begin
            en <= en ; 
        end

//assign EN_GANRAO = en && ~FIND;
assign EN_GANRAO = en ;


//白噪声
//    wire[31:0] data;
    wire       data_vld;


    noise_source noise_source_inst0(
        .clk(s_axis_aclk      ),
        .rstn(s_axis_aresetn  ),
        .noise_en(EN_GANRAO   ),
        .noise_out(data       ),
        .noise_vld(data_vld   )
    );



/********************白噪声产生分频信号(目标带宽)并将其二相编码******************/
    reg [31:0]    data_div     ;
    reg           data_div_vld ;
    reg [15:0]    cnt_div_clk  ;//计数器
    

//根据带宽BAND_WIDTH产生分频值div_fs  
//如何计算？？？？？


//1.分频
    always@(posedge s_axis_aclk)begin   
        if(~s_axis_aresetn)
        begin
            cnt_div_clk<=16'b0;
            data_div<=32'b0;
            data_div_vld<=0;
        end
        //计数器达到分频值，将data给data_div,实现分频
        else if(cnt_div_clk==DIV_CNT)
        begin
            data_div<=data;
            data_div_vld<=data_vld;
            cnt_div_clk<=0;
        end
        else
        begin
            cnt_div_clk<=cnt_div_clk+1;
            data_div<=data_div;
            data_div_vld<=data_div_vld;
        end
    end

//2.二相编码
//  wire  [31:0]    data_2ph;
    wire            data_2ph_vld;

    assign data_2ph[31-:16]=(data_div[31])?16'd32769:16'd32767;
    assign data_2ph[  15:0]=(data_div[15])?16'd32769:16'd32767;
    assign data_2ph_vld    = data_div_vld;//?


    wire [ 15:0 ]  fctr_comb1;
    wire [ 15:0 ]  fctr_comb2;
    wire [ 15:0 ]  fctr_comb3;
    wire [ 15:0 ]  fctr_comb4;
    reg  [ 15:0 ]  fctr_sweep;


       reg [ 15:0 ]  fctr [7:0];

    
integer m;
always @(posedge s_axis_aclk) begin
    if (~s_axis_aresetn | FIND_EN_AIM) begin
        for (m = 0; m < 8; m = m + 1) begin
            fctr[m] <= 16'd0;
        end
    end
    else if (F_user_valid && (F_user[13:10] < 4'd8) && (F_user[9:0] != 10'd0)) begin
        // For a 1024-point FFT and 16-bit DDS phase increment:
        // fctr = bin * 2^16 / 1024 = bin << 6.
        fctr[F_user[13:10]] <= {6'd0, F_user[9:0]} << 6;
    end
    else begin
        // No valid new F_user: hold all DDS frequency words.
        for (m = 0; m < 8; m = m + 1) begin
            fctr[m] <= fctr[m];
        end
    end
end
        
    wire        [15:0]  lo_95m_real1    [7:0]         ;
    wire        [15:0]  lo_95m_imag1    [7:0]         ;


        
    wire        [15:0]  lo_95m_real    [7:0]         ;
    wire        [15:0]  lo_95m_imag    [7:0]         ;


genvar i;
generate 
    for(i=0;i<8;i=i+1)begin:dds_fctr
            dds_fctr_0 u_dds_fctr  (
                .aclk                              (s_axis_aclk               ),// input wire aclk
                .aresetn                           (s_axis_aresetn            ),// input wire aresetn
                .s_axis_config_tvalid              (1                         ),// input wire s_axis_config_tvalid
                .s_axis_config_tdata               (fctr[i]                    ),// input wire [15 : 0] s_axis_config_tdata
                .m_axis_data_tvalid                (                          ),// output wire m_axis_data_tvalid
                .m_axis_data_tdata                 ({lo_95m_imag1[i],lo_95m_real1[i]}),// output wire [31 : 0] m_axis_data_tdata
                .m_axis_phase_tvalid               (                          ),// output wire m_axis_phase_tvalid
                .m_axis_phase_tdata                (                          ) // output wire [15 : 0] m_axis_phase_tdata
            );
    end
endgenerate


genvar l;
generate
    for (l = 0; l < 8; l = l + 1) begin : dds_output_gate
        assign lo_95m_real[l] = (fctr[l] == 16'd0) ? 16'd0 : lo_95m_real1[l];
        assign lo_95m_imag[l] = (fctr[l] == 16'd0) ? 16'd0 : lo_95m_imag1[l];
    end
endgenerate

// 4) Recommended debug bus, if your current aim_noise has fctr_bus output:
assign fctr_bus = {fctr[7], fctr[6], fctr[5], fctr[4], fctr[3], fctr[2], fctr[1], fctr[0]};

// 5) Recommended sincos debug. Your F_user=532 has target_id=0, so probe lane 0 first.
assign sincos = {lo_95m_imag[0], lo_95m_real[0]};

/************************混频器：将dds产生的信号和二相编码信号混频************************/
    wire [ 7:0]   cmpy_0_m_axis_dout_tvalid ;
    wire [63:0]   cmpy_0_m_axis_dout_tdata  [7:0] ;
    wire [15:0]   cmpy_0_im [7:0];
    wire [15:0]   cmpy_0_re [7:0];
    reg  [31:0]   din_reg             ;
    reg           din_vld = 1         ;
    reg           s_axis_tvalid_reg   ;

genvar j;
generate
    for(j=0;j<8;j=j+1)begin:mult
    cmpy_0 complex_multiplier (
    .aclk                              (s_axis_aclk               ),// input wire aclk
    .aresetn                           (s_axis_aresetn            ),// input wire aresetn
    .s_axis_a_tvalid                   (1                         ),// input wire s_axis_a_tvalid
    .s_axis_a_tdata                    (din_reg                   ),// input wire [31 : 0] s_axis_a_tdata
    .s_axis_b_tvalid                   (1                         ),// input wire s_axis_b_tvalid
    .s_axis_b_tdata                    ({lo_95m_imag[j],lo_95m_real[j]}),// input wire [31 : 0] s_axis_b_tdata
    .m_axis_dout_tvalid                (cmpy_0_m_axis_dout_tvalid[j]),// output wire m_axis_dout_tvalid
    .m_axis_dout_tdata                 (cmpy_0_m_axis_dout_tdata[j]) // output wire [63 : 0] m_axis_dout_tdata
    );
    end
endgenerate


wire [16*8 - 1:0]data_parallel_i;
wire [16*8 - 1:0]data_parallel_q;
genvar k;

for (k = 0;k<8;k = k+1)begin
    assign cmpy_0_re[k] = cmpy_0_m_axis_dout_tdata[k][30-:16];
    assign cmpy_0_im[k] = cmpy_0_m_axis_dout_tdata[k][62-:16];
end

assign data_parallel_i = {cmpy_0_re[0],cmpy_0_re[1],cmpy_0_re[2],cmpy_0_re[3],cmpy_0_re[4],cmpy_0_re[5],cmpy_0_re[6],cmpy_0_re[7]};
assign data_parallel_q = {cmpy_0_im[0],cmpy_0_im[1],cmpy_0_im[2],cmpy_0_im[3],cmpy_0_im[4],cmpy_0_im[5],cmpy_0_im[6],cmpy_0_im[7]};

wire [18:0] data_sum_i;
wire [18:0] data_sum_q;
wire data_sum_valid_i;
wire data_sum_valid_q;

//求和模块加法树
add_tree#(
    .IS_BUFFERED                       (1                         ),
    .DATA_WIDTH                        (16                        ),
    .ADD_NUM                           (8                         ) 
    )add_tree_inst_i(
    .clk                               (s_axis_aclk               ),
    .rst                               (~s_axis_aresetn           ),
    .din                               (data_parallel_i           ),
    .din_vld                           ('b1                       ),
    .dout                              (data_sum_i                ),
    .dout_vld                          (data_sum_valid_i          ) 
    );

    //求和模块加法树
add_tree#(
    .IS_BUFFERED                       (1                         ),
    .DATA_WIDTH                        (16                        ),
    .ADD_NUM                           (8                         ) 
    )add_tree_inst_q(
    .clk                               (s_axis_aclk               ),
    .rst                               (~s_axis_aresetn           ),
    .din                               (data_parallel_q           ),
    .din_vld                           ('b1                       ),
    .dout                              (data_sum_q                ),
    .dout_vld                          (data_sum_valid_q          ) 
    );

//    assign data_sum_noise = {data_sum_q,data_sum_i};


// 延时一个时钟用作使能信号
always @ ( posedge s_axis_aclk ) if (!s_axis_aresetn) din_reg <= 0 ; else din_reg <= data_2ph ;
always @ ( posedge s_axis_aclk ) if (!s_axis_aresetn) s_axis_tvalid_reg <= 0 ; else s_axis_tvalid_reg <= din_vld ;



    reg [15:0] dout_im_reg;
    reg [15:0] dout_re_reg;

    wire [15:0] dout_im;
    wire [15:0] dout_re;


always @ ( posedge s_axis_aclk )
//if ( !s_axis_aresetn | FIND)begin
if ( !s_axis_aresetn )begin
    dout_im_reg   <='b0;    
    dout_re_reg   <='b0;    
end else begin
    case(sel_jam)
    'd0: begin      
        dout_im_reg   <= data_sum_q[18-:16];
        dout_re_reg   <= data_sum_i[18-:16];
    end
    'd1: begin      
        dout_im_reg   <= data[31:16];
        dout_re_reg   <= data[15:0];
    end
    default: 
         begin            
        dout_im_reg   <= dout_im_reg;  
        dout_re_reg   <= dout_re_reg;
    end
    endcase
end

assign dout_im         =   dout_im_reg;
assign dout_re         =   dout_re_reg;
assign aim_noise       =   EN_GANRAO ? {dout_im,dout_re} : 0;
//assign aim_noise_valid =   cmpy_0_m_axis_dout_tvalid && en_cnt && ~FIND;

assign aim_noise_valid =   cmpy_0_m_axis_dout_tvalid && en_cnt;


endmodule

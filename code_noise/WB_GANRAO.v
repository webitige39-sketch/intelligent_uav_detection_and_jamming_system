`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
/*
日期：2023.9.9
作者：张子宁
模块功能：产生宽带压制干扰，控制干扰产生时间

*/
//////////////////////////////////////////////////////////////////////////////////


module WB_GANRAO#(
    //parameter       WB_TIME = 30000000 , //30M  对应1s
    parameter       DATA_WIDTH = 32 
)(
    input                            s_axis_aclk,
    input                            s_axis_aresetn ,
    input                            s_axis_tstart ,
	input	[31:0]					 WB_TIME ,
    
    output reg                       FIND_EN ,
    output reg [DATA_WIDTH-1 : 0]    WBnoise ,
    output                           WBnoise_valid ,
	output  reg                         en
    );

reg [ 31:0 ] CNT_EN;
//reg          en;
wire [ 31:0 ] noise_out;



//CNT_EN使能en的计数器，用于控制使能时间
//当计数到100M(1s)时,归零
always @(posedge s_axis_aclk) 
    if( ~s_axis_aresetn | CNT_EN ==( WB_TIME-1 ) )
        begin 
            CNT_EN  <= 0   ;
        end
    else if( en )
        begin
            CNT_EN <= CNT_EN + 1 ;
        end
    else 
        CNT_EN <= 0 ;

//FIND_EN：用于重新拉高门限检测模块中的FIND信号
//当使能计数到1s（干扰发射结束）时，让门限检测模块继续检测门限
always @(posedge s_axis_aclk) 
    if( ~s_axis_aresetn  )
        begin 
            FIND_EN <= 0 ; 
        end
    else if( CNT_EN ==( WB_TIME-1 ) )
        begin
            FIND_EN <= 1 ; 
        end
    else 
        FIND_EN <= 0 ;

//en使能模块，用于产生干扰
//当检测到tstart时，开始给干扰产生模块使能
//当CNT_EN计数到1s时，关闭给干扰产生模块的使能
always@ ( posedge s_axis_aclk )
    if( ~s_axis_aresetn | CNT_EN == (WB_TIME-1) )
        begin
            en <= 0 ;
        end
    else if( s_axis_tstart )
        begin
            en <= 1 ;
        end
    else
        begin
            en <= en ; 
        end

noise_source noise_source_inst0(
.clk            (s_axis_aclk),
.rst            (~s_axis_aresetn),
.noise_en       (en),
.noise_out      (noise_out),
.noise_vld      (WBnoise_valid)
);

//将WBnoise二分频
reg     div_cnt;

always @(posedge s_axis_aclk) 
    if(~s_axis_aresetn | div_cnt == 1)
        div_cnt <= 0 ;
    else if(div_cnt == 0)
        div_cnt <=  div_cnt + 1; 
    else
        div_cnt <= div_cnt ;

always @(posedge s_axis_aclk) 
    if(~s_axis_aresetn)
        WBnoise <= 0 ;
    else if(div_cnt == 1)
        WBnoise <= noise_out ;
    else
        WBnoise <= WBnoise;





endmodule

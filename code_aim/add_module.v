`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company          : None
// Engineer         : Sunzhengyuan
// Create Date      : 2018/9/12
// Design Name      :	
// Module Name      : add_module
// Project Name     : 
// Target Devices   : 
// Tool Versions    :
// Description      : 
// Dependencies     : 
// Revision         :
// Revision 0.01 - File Created
// Additional Comments:
// 2018/9/12 : This module is created by Engineer Sunzhengyuan .
//////////////////////////////////////////////////////////////////////////////////


module add_module
#(
	parameter IS_BUFFERED 	=   0 	,
	parameter DATA_WIDTH	=	8	,
    parameter IS_EN         =   0   ,
    parameter DEBUG         =   0   
)
(
	clk		,
	rst		,
	din_a	,
	din_b	,
    din_vld ,
    dout    ,
    dout_vld
);
/*
    LOCAL PARAMETER
*/
    localparam DW = DATA_WIDTH ;
/*  
    PORT DECLARATION
*/
    input                       clk         ;
    input                       rst         ; 
    input   signed  [DW-1:0]    din_a       ;
    input   signed  [DW-1:0]    din_b       ;
    input                       din_vld     ;
    output  signed  [DW:0]      dout        ;
    output                      dout_vld    ;
/*
    REG & WIRE DECLARATION
*/
    reg [DW:0] dout     ;
    reg        dout_vld ;
    
    generate
        if ( IS_BUFFERED )
            if ( IS_EN )
                //*********************************************************
                begin : BUFFERED_EN
                    always @ ( posedge clk )
                        if ( rst )
                            begin
                                dout        <= 0                ;
                                dout_vld    <= 0                ;
                            end 
                        else if ( din_vld )
                            begin
                                dout        <= din_a + din_b    ;
                                dout_vld    <= 1                ;
                            end
                        else
                            begin
                                dout        <= 0                ;
                                dout_vld    <= 0                ; 
                            end
                end : BUFFERED_EN
                //*********************************************************
            else  
                //--------------------------------------------------------
                begin : BUFFERED_NOT_EN
                    always @ ( posedge clk )
                        if ( rst )
                            begin
                                dout        <= 0                ;
                                dout_vld    <= 0                ;
                            end
                        else 
                            begin
                                dout        <= din_a + din_b    ;
                                dout_vld    <= 1                ;
                            end
                end : BUFFERED_NOT_EN
                //--------------------------------------------------------
        else
            //*******************************************************
            begin : NOT_BUFFERED
                always @ (*)
                    begin
                        dout        = din_a + din_b ;
                        dout_vld    = din_vld       ;
                    end 
            end : NOT_BUFFERED
            //********************************************************
    endgenerate 
    


	
endmodule

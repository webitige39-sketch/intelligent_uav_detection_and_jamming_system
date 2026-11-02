`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: multi_module
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
//////////////////////////////////////////////////////////////////////////////////


module multi_module
#(
	parameter IS_SIGNED					=	1	,
	parameter IS_BUFFERED 				=   0 	,
	parameter DATA_WIDTH_A				=	8	,
	parameter DATA_WIDTH_B 				=	48	,
    parameter DOUT_WIDTH                =   0   
)
(
	clk					,
	rst					,
	din_a				,
	din_b				,
    din_vld             , 
	dout				,
	dout_vld            
);

/*
    LOCAL PARAMETER
*/
    localparam DWA  = DATA_WIDTH_A ;
    localparam DWB  = DATA_WIDTH_B ;
    localparam DOWO = DWA+DWB      ;//Data Out Width Original
    localparam DOW  =(DOUT_WIDTH==0)? DOWO : DOUT_WIDTH ;

/*
	PORT DECLARATION
*/
	input 		        clk		    ;
	input 		        rst		    ;
	input 	signed[DWA-1:0]	din_a	    ;
	input 	signed[DWB-1:0]	din_b	    ;
	input                   din_vld     ;           
    output 	signed[DOW-1:0]	dout	    ;
    output                  dout_vld    ;
/*
	REGS AND WIRES
*/
    reg dout_vld ;
    reg  signed [DOWO-1:0]  result  ;
	generate
        //-------------------------------------------------
       // if ( IS_SIGNED == 1 )
       //     begin : SIGNED
       //         wire signed [DWA-1:0]   din_a   ;
       //         wire signed [DWB-1:0]   din_b   ;
       //         //reg  signed [DOWO-1:0]  result  ;
       //         wire signed [DOW-1:0]   dout    ;
       //     end : SIGNED
       // else
       //     begin : UNSIGNED
       //         wire unsigned [DWA-1:0]   din_a   ;
       //         wire unsigned [DWB-1:0]   din_b   ;
       //         //reg  unsigned [DOWO-1:0]  result  ;
       //         wire unsigned [DOW-1:0]   dout    ;
       //     end :UNSIGNED
       //---------------------------------------------------
       
       //**************************************************
        if ( IS_BUFFERED == 1 )
            begin : BUFFERED
                always @ ( posedge clk )
                    if ( rst )
                        begin
                            result      <= 0 ; 
                            dout_vld    <= 0 ;
                        end
                    else if (din_vld)
                        begin
                            result      <= din_a * din_b ;
                            dout_vld    <= 1 ;
                        end
                    else
                        begin
                            result      <= 0 ;
                            dout_vld    <= 0 ;
                        end
            end : BUFFERED
        else
            begin : NOT_BUFFERED
                always @ (*)
                    begin
                        result      = din_a * din_b ;
                        dout_vld    = din_vld       ;
                    end
            end :NOT_BUFFERED
    //***************************************************        
    
    endgenerate
	
	assign dout = result [DOW-1:0] ;													
								
								
endmodule

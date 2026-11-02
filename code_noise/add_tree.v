`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company          : None
// Engineer         : Sunzhengyuan
// Create Date      : 2018/9/12 
// Design Name      :	
// Module Name      : add_tree
// Project Name     : 
// Target Devices   : 
// Tool Versions    : 
// Description      : this module can compulate sum of several num with structure of addtree.
// Dependencies     : 
// Revision         :
// Revision 0.01 - File Created
// Additional Comments:
//	 
//
//////////////////////////////////////////////////////////////////////////////////


module add_tree
#(
	parameter IS_BUFFERED 	=   1	,
	parameter DATA_WIDTH	=	8	,
	parameter ADD_NUM		=	16  ,
    parameter IMGA_OR_REAL  =   0   	
)
(
	clk     ,
	rst     ,
	din     ,
    din_vld ,
	dout    ,
    dout_vld
);

	function integer blog2(input integer number)	;
		for(blog2=0;number>0;blog2=blog2+1)
			number=number>>1				;
	endfunction
/*
    LOCAL PARAMETER
*/
    localparam AN      =   ADD_NUM      ;
    localparam DW      =   DATA_WIDTH   ;
	localparam PDW	   =   AN*DW	    ;   //Parallel Data Width = ADD_NUM * DATA_WIDTH
	localparam LN	   =   blog2(AN)-1	;   //Add Tree Level Number
	// ADD_NUM = 16    0:16 1:8 2:4 3:2 4:1
    
/*
	PORT DECLARATION
*/

	input 					    clk		    ;
	input 					    rst		    ;
	input 	signed  [PDW-1	:0] din		    ;
    input                       din_vld     ;
	output 	signed  [DW+LN-1:0] dout	    ;
    output                      dout_vld    ;
	
	
/*
	WIRE & REG DECLARATION
*/

	reg  signed [DW+LN-1:0]	    dout					    ;
	wire signed	[DW+LN-1:0  ]   add_result[(1<<(LN+1)):0]	;
    wire         [LN:0]          din_vld_p                  ;
	
/*
	
*/
    
    sync_module
            #(
                .WIDTH			(   1       )   ,
                .SYNC_TIME		(   LN + 1  )   , // Add 1 for register the dout
                .IS_RST_ABLE	(   1       )   ,
                .PASSBY         (!IS_BUFFERED)
            )din_vld_sync_module(
                .clk			(clk        ),
                .rst			(rst        ),
                .async_in	    (din_vld    ),
                .sync_out	    (dout_vld   ),
                .parallel_out   (din_vld_p  ),
                .en             (           ));

	generate
		genvar count,count1;
        
			for(count=0;count<(AN>>1);count=count+1)
                //-------------------------------------------------------------
				begin: first_level
						add_module
					#(
						.IS_BUFFERED	(	IS_BUFFERED	)	,
						.DATA_WIDTH		(	DATA_WIDTH	)	
					)	sum_module_inst_0
					(
						.clk	    (clk						    )	,
						.rst	    (rst						    )	,
						.din_a	    (din[PDW-(count*2)*DW-1-:DW]	)	,
						.din_b	    (din[PDW-(count*2+1)*DW-1-:DW]  )	,
                        .din_vld    (                               )   ,
						.dout	    (add_result[AN-count][DW:0]		)	,
                        .dout_vld   (                               )   
					);	
                //------------------------------------------------------------
				end
				
				
				
				for(count=0;count<LN-1;count=count+1)   // LN为加法器的总级数  -1是第一级已经计算完成
                begin
                    //******************************************************************
						for(count1=0;count1<((AN>>(count+2)));count1=count1+1) //每级的加法器的个数
							begin :brunch_loop
								add_module
								#(
									.IS_BUFFERED	(	IS_BUFFERED			)	,//!(count%2)
									.DATA_WIDTH		(	DATA_WIDTH+count+1	)	  	
								)	sum_module_inst_1
								(
									.clk	    (clk						)	,
									.rst	    (rst						)	,
									.din_a	    (add_result[(AN>>count)-count1*2]  [DW+count:0]		)	,
									.din_b	    (add_result[(AN>>count)-count1*2-1][DW+count:0]		)	,
                                    .din_vld    (                                                   )   ,
									.dout	    (add_result[(AN>>(count+1))-count1][DW+count+1:0]	)	,
                                    .dout_vld   (                                                   )
								);
							end 
                 //******************************************************************
                        end
	endgenerate
	
    
    always @ ( posedge clk )
        if ( rst )
            dout <= 0               ;
        else if ( din_vld_p[LN-1] )
            dout <= add_result[2]   ;
        else
            dout <= 0               ;
/*

Debug   

*/
/*
    integer fid; 
    initial
        begin
            if ( IMGA_OR_REAL )
                begin
                    fid = $fopen("add_real.txt","w");
                end
			else
                begin
                    fid = $fopen("add_imag.txt","w");
                end
			    
        end
    generate
        if ( 1 )
            begin
                always @ ( posedge clk )
                    if ( dout_vld)
					// 抓取和路数据实部虚部
                        begin
                            $fdisplay(fid,"%d",$signed(dout));    //观测到截位从第29位开始为最佳        
                        end
            end
    endgenerate
    */
endmodule


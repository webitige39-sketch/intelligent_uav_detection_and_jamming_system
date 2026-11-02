`timescale 1ns / 1ps

//parallel_out延迟async_in一个时钟周期
//sync_out延迟async_in  SYNC_TIME个时钟周期
module sync_module
#(
    parameter WIDTH			=	1,
    parameter SYNC_TIME		=	1,
    parameter PASSBY		=	0,
	parameter IS_RST_ABLE	=	1,
	parameter IS_ASYNC_REG  =	"false",
	parameter INITIAL_DATA	=   1'b0,
	parameter IS_EN			=	1'b0
)
(
    clk			,
    rst			,
    async_in	,
    sync_out	,
	parallel_out,
	en
 );
 
 /*
    PORT DECLATATION
 */
    input									clk         ;
    input                      				rst     	;
    input 									en			;
	input       [WIDTH-1:0]					async_in    ;
    output  	[WIDTH-1:0]					sync_out    ;
	output      [WIDTH*SYNC_TIME-1:0]		parallel_out; 
    
/*
	REGS AND WIRES
*/	
	wire		[WIDTH-1:0]					sync_out    ;
	wire   		[WIDTH*SYNC_TIME-1:0]		parallel_out; 

/*
    
*/  
   (*async_reg=IS_ASYNC_REG*) reg [WIDTH-1:0]sync_reg[SYNC_TIME-1:0];
    	
    generate 
        genvar sync_time;
        begin
			
            always @(posedge clk)
                if(IS_RST_ABLE&&rst)
                    sync_reg[0]<={WIDTH{INITIAL_DATA}}		;
                else if(IS_EN&&(!en))
                    sync_reg[0]<=sync_reg[0];
				else	
					sync_reg[0]<=async_in	;
            
            for(sync_time=1;sync_time<SYNC_TIME;sync_time=sync_time+1)        
				begin
                    always @(posedge clk)
						if(IS_RST_ABLE&&rst)
							sync_reg[sync_time]<={WIDTH{INITIAL_DATA}};
						else if(IS_EN&&(!en))
							sync_reg[sync_time]<=sync_reg[sync_time];
						else
							sync_reg[sync_time]<=sync_reg[sync_time-1];
				end
				
			for(sync_time=0;sync_time<SYNC_TIME;sync_time=sync_time+1)
				begin	
					assign parallel_out[(sync_time+1)*WIDTH-1-:WIDTH]=sync_reg[sync_time];
				end	
        end
   endgenerate
   
   initial
	begin : register_initial
		integer count;
			for(count=0;count<SYNC_TIME;count=count+1)
				begin
					sync_reg[count]={WIDTH{INITIAL_DATA}};
				end
	end

    assign sync_out=(PASSBY)?async_in:sync_reg[SYNC_TIME-1];
    
    
endmodule
module ad9361_spi(
    input                               clk                        ,
    input                               rst_n                      ,
        //avalon interface
    input                               read                       ,
    input                               write                      ,
    input              [   9:0]         address                    ,
    input              [   7:0]         writedata                  ,
    output reg         [   7:0]         readdata                   ,
    output reg                          waitrequest                ,
        //SPI interface
    output                              spi_clk                    ,
    output reg                          spi_csn                    ,
    output reg                          spi_sdo                    ,
    input                               spi_sdi                     
);
        reg	   [4:0]   bit_cnt;	
        reg	   [23:0]  command;
        reg	   [1:0]   state;
        wire           wr_rdn;//read win over write
        assign wr_rdn=write && !read;
        //spi_clk
        assign spi_clk = ~ clk;                
    //spi_sdo
        always @ (posedge clk or negedge rst_n)
        begin
                if(!rst_n) begin
                        state           <=0;
                        spi_csn         <=1;
                        spi_sdo         <=0;
                        bit_cnt         <=0;
                        waitrequest     <=1;
                end
                else begin
                        case(state)
                        2'd0:begin             
                                if(write|read) begin
                                    state<=1;
                                    bit_cnt<=0;	
                                    command<={wr_rdn,3'b000,2'b00,address,writedata};
                                end
                        end
                        2'd1:begin
                                if(bit_cnt<=23) begin
                                        spi_csn<=0;
                                        spi_sdo<=command[23];
                                        command<=command<<1;
                                        bit_cnt<=bit_cnt+1;
                                end
                                else begin
                                        spi_csn<=1;
                                        spi_sdo<=0;
                                        bit_cnt<=0;
                                        state<=2;
                                        waitrequest<=0;
                                end
                        end
                        2'd2:begin waitrequest<=1;state<=0;end
                        default:state<=0;
                        endcase
                end
        end
                                                
        //spi_sdi
        reg	[7:0]	readdata_shift=0;
        always @ (posedge clk)
        begin
        	readdata_shift<={readdata_shift[6:0],spi_sdi};
        end
        
        always @ (posedge clk)
        begin
          if(bit_cnt==5'd24 && read)begin
	    	readdata<={readdata_shift[6:0],spi_sdi};
          end
        end
endmodule
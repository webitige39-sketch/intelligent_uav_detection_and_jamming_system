`timescale 1ns / 1ps

module ad9361_init2(
	// Input clock and reset signal.
    input                               sys_clk                    ,
    input                               sys_rst                    ,
	input                               state_next                 ,   
	input                               FIND                       ,
//	input                               ila_clk                    ,
	
	// AD9361 SPI interface signal.
    output                              ad9361_spi_cs              ,
    output                              ad9361_spi_sclk            ,
    output                              ad9361_spi_mosi            ,
    input                               ad9361_spi_miso            ,
	
	// AD9361 control signal.
    output                              en_agc                     ,
    output                              enable                     ,
    output                              resetb                     ,
    output                              txnrx                      ,
    output                              sync_in                    ,
    output             [   3:0]         ctrl_in                    ,
    input              [   7:0]         ctrl_out                   ,


	output  	[ 7:0]         			w_readdata_out              ,
    output  	[ 5:0]         			w_state_out                 ,
    output      [31:0]    				w_measured_lock_time        ,
	
	// Output cconfiguration status signal.
	output wire [ 9:0]                  address             ,
    output wire [ 7:0]                  writedata           ,    
	output wire [ 2:0]     				profile_idx         ,     
	output                              rx_valid            ,
    output reg         [   7:0]         cfg_status          ,
	output wire [12:0] init_index,
	output wire ad9361_spi_ok         
);

	// Internal wire.
wire                                    ad9361_id_chk              ;
wire                                    ad9361_bbpll_cal_done      ;
wire                                    ad9361_rx_rfpll_cp_done    ;
wire                                    ad9361_tx_rfpll_cp_done    ;
wire                                    ad9361_rx_rfpll_vco_done   ;
wire                                    ad9361_tx_rfpll_vco_done   ;
wire                                    ad9361_rx_bb_flt_done      ;
wire                                    ad9361_tx_bb_flt_done      ;
wire                                    ad9361_bbdc_cal_done       ;
wire                                    ad9361_rfdc_cal_done       ;
wire                                    ad9361_tx_quad_done        ;


	


	// AD9361 SPI module inst.
    spi_ctrl_2 uut_ad9361_spi_ctrl (
    .sys_clk                           (sys_clk                   ),
    .sys_rst                           (sys_rst                   ),
    .state_next                        (state_next                ),
	.FIND                              (FIND                      ),
//	.ila_clk                           (ila_clk                   ),
	.ctrl_in                           (ctrl_in                   ),
    .spi_csn                           (ad9361_spi_cs             ),
    .spi_clk                           (ad9361_spi_sclk           ),
    .spi_sdo                           (ad9361_spi_mosi           ),
    .spi_sdi                           (ad9361_spi_miso           ),
    .id_chk                            (ad9361_id_chk             ),
    .bbpll_cal_done                    (ad9361_bbpll_cal_done     ),
    .rx_rfpll_cp_done                  (ad9361_rx_rfpll_cp_done   ),
    .tx_rfpll_cp_done                  (ad9361_tx_rfpll_cp_done   ),
    .rx_rfpll_vco_done                 (ad9361_rx_rfpll_vco_done  ),
    .tx_rfpll_vco_done                 (ad9361_tx_rfpll_vco_done  ),
    .rx_bb_flt_done                    (ad9361_rx_bb_flt_done     ),
    .tx_bb_flt_done                    (ad9361_tx_bb_flt_done     ),
    .bbdc_cal_done                     (ad9361_bbdc_cal_done      ),
    .rfdc_cal_done                     (ad9361_rfdc_cal_done      ),
    .tx_quad_done                      (ad9361_tx_quad_done       ),
    .spi_ok                            (ad9361_spi_ok             ),
	.profile_idx                       (profile_idx               ),
	.rx_valid                          (rx_valid                  ),
	.measured_lock_time 			   (w_measured_lock_time      ),
    .readdata_out       			   (w_readdata                ),
    .state_out          			   (w_state                   ),
	.init_index                        (init_index                )
    );
	
	// AD9361 control signal.
	assign en_agc  = 1'b0;
	assign enable  = 1'b0;
	assign resetb  = ~sys_rst;
	assign txnrx   = 1'b0;
	assign sync_in = 1'b0;
	
	/* According to the output flag, control the cfg_status status. */
	always @ (posedge sys_clk or posedge sys_rst) begin
		if (sys_rst)
			cfg_status <= 8'h00;
		else begin
			/* Check the AD9361 product ID. */
			if (ad9361_id_chk)
				cfg_status[0] <= 1'b1;
			
			/* Check AD9361 BBPLL VCO cal done status. */
			if (ad9361_bbpll_cal_done)
				cfg_status[1] <= 1'b1;
			
			/* Check AD9361 Rx RFPLL CP & VCO cal done status. */
			if (ad9361_rx_rfpll_cp_done & ad9361_rx_rfpll_vco_done)
				cfg_status[2] <= 1'b1;
				
			/* Check AD9361 Tx RFPLL CP & VCO cal done status. */
			if (ad9361_tx_rfpll_cp_done & ad9361_tx_rfpll_vco_done)
				cfg_status[3] <= 1'b1;
			
			
			if (ad9361_rx_bb_flt_done & ad9361_tx_bb_flt_done)
				cfg_status[4] <= 1'b1;
			
			/* Check AD9361 BB & RF DC offset cal done status. */
			if (ad9361_bbdc_cal_done & ad9361_rfdc_cal_done)
				cfg_status[5] <= 1'b1;
			
			/* Check AD9361 Tx quad cal done status. */
			if (ad9361_tx_quad_done)
				cfg_status[6] <= 1'b1;
			
			/* Check AD9361 configuration completed status. */
			if (ad9361_spi_ok)
				cfg_status[7] <= 1'b1;
		end
	end

endmodule

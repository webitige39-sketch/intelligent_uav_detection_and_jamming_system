// Old AD9361 design + PS/DMA integration wrapper.
// The original MULT_FREQ_top is deliberately kept independent of the PS
// reset and AXI GPIO signals so that AD9361 reset and SPI initialization stay
// identical to the proven backup project.
`timescale 1 ps / 1 ps

module system_wrapper_dma (
    inout  [14:0] DDR_addr,
    inout  [2:0]  DDR_ba,
    inout         DDR_cas_n,
    inout         DDR_ck_n,
    inout         DDR_ck_p,
    inout         DDR_cke,
    inout         DDR_cs_n,
    inout  [3:0]  DDR_dm,
    inout  [31:0] DDR_dq,
    inout  [3:0]  DDR_dqs_n,
    inout  [3:0]  DDR_dqs_p,
    inout         DDR_odt,
    inout         DDR_ras_n,
    inout         DDR_reset_n,
    inout         DDR_we_n,
    inout         FIXED_IO_ddr_vrn,
    inout         FIXED_IO_ddr_vrp,
    inout  [53:0] FIXED_IO_mio,
    inout         FIXED_IO_ps_clk,
    inout         FIXED_IO_ps_porb,
    inout         FIXED_IO_ps_srstb,

    input         sclk_n,
    input         sclk_p,
    output        spi_clk,
    output        spi_csn,
    input         spi_sdi,
    output        spi_sdo,
    inout         en_agc,
    output        enable,
    output        txnrx,
    inout         resetb,
    inout         sync_in,
    inout  [3:0]  ctrl_in,
    inout  [7:0]  ctrl_out,
    input         rx_clk_in_p,
    input         rx_clk_in_n,
    input         rx_frame_in_p,
    input         rx_frame_in_n,
    input  [5:0]  rx_data_in_p,
    input  [5:0]  rx_data_in_n,
    output        tx_clk_out_p,
    output        tx_clk_out_n,
    output        tx_frame_out_p,
    output        tx_frame_out_n,
    output [5:0]  tx_data_out_p,
    output [5:0]  tx_data_out_n
);

    wire [127:0] axis_s2mm_tdata;
    wire [15:0]  axis_s2mm_tkeep;
    wire         axis_s2mm_tlast;
    wire         axis_s2mm_tready;
    wire         axis_s2mm_tvalid;

    wire         pl_clk;
    wire [0:0]   user_rstn;
    wire [0:0]   user_start;
    wire [31:0]  mode3_cfg0;
    wire [31:0]  mode3_aim_time;
    wire [31:0]  mode3_thred;

    // The AXI-DMA source runs solely in the PS FCLK domain.  Mode3 bit29
    // enables a transfer and bit30 selects the reference Mode1/Mode2 payload.
    // It is intentionally isolated from the AD9361 clock/reset domains.
    wire         dma_enable = mode3_cfg0[29];
    wire         dma_mode1  = mode3_cfg0[30];
    wire         dma_start  = user_start[0] && dma_enable;
    wire         dma_ready;
    wire         dma_busy;
    wire         dma_done;

    uav_mode_axis_src_128 u_dma_reference_source (
        .axis_clk      (pl_clk),
        .axis_rstn     (user_rstn[0]),
        .start_i       (dma_start),
        .mode_select_i (dma_mode1),
        .ready_o       (dma_ready),
        .busy_o        (dma_busy),
        .done_pulse_o  (dma_done),
        .m_axis_tdata  (axis_s2mm_tdata),
        .m_axis_tkeep  (axis_s2mm_tkeep),
        .m_axis_tvalid (axis_s2mm_tvalid),
        .m_axis_tready (axis_s2mm_tready),
        .m_axis_tlast  (axis_s2mm_tlast)
    );

    // Original RF/AD9361 path retains its own power-up reset sequence.  The
    // PS values below enter only the configuration CDC logic; pl_rstn does not
    // reach the AD9361 reset/SPI controller.
    MULT_FREQ_top u_mult_freq_top (
        .sclk_n        (sclk_n),
        .sclk_p        (sclk_p),
        .spi_clk       (spi_clk),
        .spi_csn       (spi_csn),
        .spi_sdi       (spi_sdi),
        .spi_sdo       (spi_sdo),
        .en_agc        (en_agc),
        .enable        (enable),
        .txnrx         (txnrx),
        .resetb        (resetb),
        .sync_in       (sync_in),
        .ctrl_in       (ctrl_in),
        .ctrl_out      (ctrl_out),
        .rx_clk_in_p   (rx_clk_in_p),
        .rx_clk_in_n   (rx_clk_in_n),
        .rx_frame_in_p (rx_frame_in_p),
        .rx_frame_in_n (rx_frame_in_n),
        .rx_data_in_p  (rx_data_in_p),
        .rx_data_in_n  (rx_data_in_n),
        .tx_clk_out_p  (tx_clk_out_p),
        .tx_clk_out_n  (tx_clk_out_n),
        .tx_frame_out_p(tx_frame_out_p),
        .tx_frame_out_n(tx_frame_out_n),
        .tx_data_out_p (tx_data_out_p),
        .tx_data_out_n (tx_data_out_n),
        .pl_clk        (pl_clk),
        .pl_rstn       (user_rstn[0]),
        .pl_start      (user_start[0]),
        .mode3_cfg0    (mode3_cfg0),
        .mode3_aim_time(mode3_aim_time),
        .mode3_thred   (mode3_thred)
    );

    system_dma system_dma_i (
        .DDR_addr(DDR_addr), .DDR_ba(DDR_ba), .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n), .DDR_ck_p(DDR_ck_p), .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n), .DDR_dm(DDR_dm), .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n), .DDR_dqs_p(DDR_dqs_p), .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n), .DDR_reset_n(DDR_reset_n), .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn), .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio), .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb), .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .S_AXIS_S2MM_tdata(axis_s2mm_tdata),
        .S_AXIS_S2MM_tkeep(axis_s2mm_tkeep),
        .S_AXIS_S2MM_tlast(axis_s2mm_tlast),
        .S_AXIS_S2MM_tready(axis_s2mm_tready),
        .S_AXIS_S2MM_tvalid(axis_s2mm_tvalid),
        .mode3_aim_time(mode3_aim_time),
        .mode3_cfg0(mode3_cfg0),
        .mode3_thred(mode3_thred),
        .pl_clk(pl_clk), .user_rstn(user_rstn), .user_start(user_start)
    );

endmodule

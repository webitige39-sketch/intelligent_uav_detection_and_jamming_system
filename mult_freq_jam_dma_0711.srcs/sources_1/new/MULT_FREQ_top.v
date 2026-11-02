`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/05 14:40:22
// Design Name: 
// Module Name: MULT_FREQ_top
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
// 
//////////////////////////////////////////////////////////////////////////////////


module MULT_FREQ_top(

    input                               sclk_n                     ,
    input                               sclk_p                     ,
    output                              spi_clk                    ,
    output                              spi_csn                    ,
    input                               spi_sdi                    ,
    output                              spi_sdo                    ,
    inout                               en_agc                     ,
    output                              enable                     ,
    output                              txnrx                      ,
    inout                               resetb                     ,
    inout                               sync_in                    ,
    inout              [   3:0]         ctrl_in                    ,
    inout              [   7:0]         ctrl_out                   ,
    input                               rx_clk_in_p                ,
    input                               rx_clk_in_n                ,
    input                               rx_frame_in_p              ,
    input                               rx_frame_in_n              ,
    input              [   5:0]         rx_data_in_p               ,
    input              [   5:0]         rx_data_in_n               ,
    output                              tx_clk_out_p               ,
    output                              tx_clk_out_n               ,
    output                              tx_frame_out_p             ,
    output                              tx_frame_out_n             ,
    output             [   5:0]         tx_data_out_p              ,
    output             [   5:0]         tx_data_out_n              ,

    // PS-side configuration.  These signals are used only through dedicated
    // CDC blocks below; they never reset or gate the AD9361 SPI sequencer.
    input                               pl_clk                      ,
    input                               pl_rstn                     ,
    input                               pl_start                    ,
    input              [  31:0]         mode3_cfg0                 ,
    input              [  31:0]         mode3_aim_time             ,
    input              [  31:0]         mode3_thred

    );


    parameter DATA_WIDTH = 32;

    // RX IIR DC removal parameter.
    // K=6: alpha=1/64, equivalent time is 1.6 us at 40 MHz.
    // Increase to K=7/8 if the correlation peak is attenuated by fast tracking.
    localparam RX_DC_K = 6;

    // TX LO leakage cancellation parameters.
    // Tune these two small signed offsets on a spectrum analyzer.
    // They intentionally create a small carrier at the LO frequency
    // to cancel AD9361 TX LO leakage.
  wire signed [11:0] TX_I_CORR;
  wire signed [11:0] TX_Q_CORR;

  reg                                     rstn                       ;
  reg                    [  19:0]         cnt_resetn = 0             ;
  reg                    [  27:0]         cnt_led0                   ;
  wire                                    data_clk                   ;
  wire                                    gclk_div                   ;//20MHz
  wire                                    dac_r1_mode                ;
  wire                                    adc_r1_mode                ;
  wire                                    adc_status                 ;
  wire                                    pl_gclk                    ;//20M
  wire                                    FFT_200MHz_clk             ;
  //reg                                     ila_sclk                 ;//10M
  wire                                    locked                     ;
  wire                                    FIND                       ;


    wire [15 : 0] F_user_40M ;
    wire [15 : 0] F_user_200M;
  reg [31 : 0] s_axis_tdata;
  wire s_axis_tvalid;
  wire [31:0] Thred;
  wire [31:0] Fre_thred;
  wire [31:0] FIND_RST_VALUE;
  wire [31 : 0] data_sum;
  wire [20 : 0] CNT;
  wire [0  : 0] m_axis_tstart_thr;
  wire [0  : 0] m_axis_tlast_thr;
  wire [0  : 0] DATA_LABEL;
  wire [0  : 0] WEA;
  wire [10 : 0] ADDRA;
  wire [ 0 : 0] REA;
  wire [10 : 0] ADDRB;
  wire [31 : 0] m_axis_tdata_ram;
  wire [31 : 0] m_axis_tdata_FFT;
  wire m_axis_tvalid_FFT; 
  wire m_axis_tvalid_ram; 
  wire [18 : 0] Freq_sum_1;
  wire [0  : 0] Freq_Thr_over_1;
  wire [15 : 0] dectection_user_1;
  wire [15 : 0] m_axis_tuser_FFT;

  // 200 MHz CFAR / traces_condense debug signals
  wire [15:0] dbg_data_abs;
  wire        dbg_data_abs_valid;
  wire        dbg_data_abs_last;
  wire [15:0] dbg_cfar_raw_idx;
  wire [15:0] dbg_cfar_cut_amp;
  wire        dbg_cfar_hit;
  wire        dbg_cfar_valid;
  wire        dbg_cfar_last;
  wire [15:0] dbg_condense_peak_idx;
  wire [15:0] dbg_condense_peak_amp;
  wire        dbg_condense_hit;
  wire        dbg_condense_valid;
  wire        dbg_condense_last;
  wire [15:0] dbg_condense_user;
  wire        dbg_frame_has_candidate;

  wire [31:0] dbg_cfar_idx_amp_bus      = {dbg_cfar_raw_idx, dbg_cfar_cut_amp};
  wire [15:0] dbg_cfar_flag_bus         = {13'd0, dbg_cfar_last, dbg_cfar_valid, dbg_cfar_hit};
  wire [31:0] dbg_condense_idx_amp_bus  = {dbg_condense_peak_idx, dbg_condense_peak_amp};
  wire [15:0] dbg_condense_flag_bus     = {13'd0, dbg_condense_last, dbg_condense_valid, dbg_condense_hit};

  wire [   0:0] FIND_RST;
  wire [15:0] F_user;
  wire [15:0] DIV_CNT;
  wire Freq_Thr_over;
  wire [31:0] AIM_TIME;
  wire EN_GANRAO;
  reg FIND_EN_1;
  wire ad9361_clk_div;

  wire FIND_EN_AIM_1 ;
  reg FIND_EN_AIM_1_d;
  wire FIND_UAV;
  
  wire [31:0] sincos;
  wire [31:0] data_2ph;
  wire [31:0] aim_noise;
  wire [31:0] data;
  wire aim_noise_valid;
  wire FIND_EN_AIM;
  wire [3:0] sel_jam;

  // GPIO configuration format:
  // cfg0[15:0] DIV_CNT, cfg0[19:16] jammer selection, cfg0[31] update toggle.
  // The three GPIO words must be written before cfg0[31] is toggled.
  wire [95:0] cfg_bundle_async = {mode3_thred, mode3_aim_time, mode3_cfg0};
  wire [95:0] cfg_bundle_40m;
  wire [95:0] cfg_bundle_200m;
  wire cfg_update_40m;
  wire cfg_update_200m;
  wire rstn_200m;

    reg Freq_Thr_over_1_d ;
    reg Freq_Thr_over_1_dd;
    reg FIND_EN_AIM_1_d_200MHz;
    reg FIND_EN_AIM_1_dd_200MHz;

    wire freq_over_pulse_40m;
    wire FIND_UAV_pulse_40m;
    wire Freq_Thr_over_toggle;
    wire FIND_UAV_toggle;
    wire tr_m_axis_tvalid;
    reg  tr_m_axis_tvalid_d;
    wire empty;
    wire full;
    wire wr_rst_busy;
    wire rd_rst_busy;
    wire fifo_rd_en_F_user;

    wire        F_user_40M_valid;
reg         fifo_rd_en_F_user_d;


  wire                   [   2:0]         profile_idx                ;
  wire [ 9:0]                             address                    ;
  wire [ 7:0]                             writedata                  ;
  wire                   [   7:0]         led                        ;


    wire [127:0] fctr_bus;

  clk_wiz_0 u_clk_d_s
            (
              // Clock out ports
              .clk_out1                          (pl_gclk                   ),// output clk_out1
              .clk_out2                          (FFT_200MHz_clk            ),// output clk_out2
              // Clock in ports
              .clk_in1_p                         (sclk_p                    ),// input clk_in1_p
              .clk_in1_n                         (sclk_n                    )
            );


  assign gclk_div = pl_gclk    ;                                //20M


  always@(posedge gclk_div)
  begin
    if (cnt_resetn >  20'd50000)
    begin
      cnt_resetn <= 20'd50000;
    end
    else if (cnt_resetn<20'd50000)
    begin
      cnt_resetn <= cnt_resetn+1;
    end
    else
      cnt_resetn <= cnt_resetn;


  end

  always@(posedge gclk_div)
  begin
    if (cnt_resetn<20'd50000)
    begin                            //20M 100000   5ms
      rstn <= 1'b0;
    end
    else
    begin
      rstn <= 1'b1;
    end
  end




  wire                                    rst_9361                   ;
  wire                                    dac_valid0                 ;
  wire                   [  11:0]         dac_data0_i_12b            ;
  wire                   [  11:0]         dac_data0_q_12b            ;
  wire                   [  11:0]         dac_data1_i_12b            ;
  wire                   [  11:0]         dac_data1_q_12b            ;
  wire                   [   8:0]         addra                      ;
  wire                                    state_next                 ;

    reg FIND_d;
    reg FIND_dd;

    reg rx_valid_d;
    reg rx_valid_dd;


// ==============================================================
// TX path stable start + single 24-bit I/Q FIFO
// ============================================================== 
// 说明：
// 1) rst_9361 是 AD9361_IF 输出的 data_clk 域复位，顶层不要驱动它。
// 2) rstn 是 gclk_div 域产生的，这里同步到 data_clk / ad9361_clk_div 后再使用。
// 3) I/Q 合成一个 24bit FIFO，避免两个 FIFO 上电后读出相位不一致。

// rstn -> data_clk domain
reg [2:0] rstn_data_sync = 3'b000;
always @(posedge data_clk) begin
    rstn_data_sync <= {rstn_data_sync[1:0], rstn};
end
wire rstn_data = rstn_data_sync[2];

// TX 启动延时：等待 rstn_data 释放、AD9361_IF 内部 rst_9361 释放后，再启动 FIFO/TX。
// 不再使用 &led 门控，避免某些 cfg_status 位不为 1 时 TX 永远不输出。
localparam [23:0] TX_START_DELAY = 24'd200000;

reg [23:0] tx_start_cnt = 24'd0;
always @(posedge data_clk) begin
    if(!rstn_data || rst_9361)
        tx_start_cnt <= 24'd0;
    else if(tx_start_cnt < TX_START_DELAY)
        tx_start_cnt <= tx_start_cnt + 1'b1;
    else
        tx_start_cnt <= tx_start_cnt;
end


wire tx_start_ready      = (tx_start_cnt >= TX_START_DELAY);
wire tx_path_enable_data = rstn_data & tx_start_ready & (~rst_9361);

// rstn -> ad9361_clk_div domain
reg [2:0] rstn_tx_sync = 3'b000;
always @(posedge ad9361_clk_div) begin
    rstn_tx_sync <= {rstn_tx_sync[1:0], rstn};
end
wire rstn_tx = rstn_tx_sync[2];

// DAC valid: 4 个 data_clk 周期拉高一次
reg [1:0] count_dac_vld;
reg       dac_valid;

always @(posedge data_clk) begin
    if(!rstn_data || !tx_path_enable_data)
        count_dac_vld <= 2'd0;
    else
        count_dac_vld <= count_dac_vld + 1'b1;
end

always @(posedge data_clk) begin
    if(!rstn_data || !tx_path_enable_data)
        dac_valid <= 1'b0;
    else if(count_dac_vld[1:0] == 2'b01)
        dac_valid <= 1'b1;
    else
        dac_valid <= 1'b0;
end





// data_clk 域 TX enable 同步到 ad9361_clk_div 写时钟域
reg [2:0] tx_path_enable_wr_sync = 3'b000;
always @(posedge ad9361_clk_div) begin
    if(!rstn_tx)
        tx_path_enable_wr_sync <= 3'b000;
    else
        tx_path_enable_wr_sync <= {tx_path_enable_wr_sync[1:0], tx_path_enable_data};
end
wire tx_path_enable_wr = tx_path_enable_wr_sync[2];

// -----------------------------------------------------------------------------
// TX LO leakage manual DC correction
// -----------------------------------------------------------------------------
// 当前 AD9361 TX 内部校准后，LO/DC 泄露和 IQ 镜像已经正常，因此默认关闭
// FPGA 侧手动 TX DC 补偿，避免人为补偿量破坏 AD9361 校准结果。
// 后续如果某个跳频 profile 的 LO 泄露明显变大，可把 TX_LO_CORR_EN 改为 1'b1，
// 再通过 VIO 的 tx_i/q_corr_* 信号微调。
localparam TX_LO_CORR_EN = 1'b0;

wire signed [11:0] tx_i_corr_sel;
wire signed [11:0] tx_q_corr_sel;

wire signed [11:0] tx_i_corr_neg20;
wire signed [11:0] tx_q_corr_neg20;
wire signed [11:0] tx_i_corr_pos20;
wire signed [11:0] tx_q_corr_pos20;

assign tx_i_corr_sel = (profile_idx == 3'd0) ? tx_i_corr_neg20 :
                       (profile_idx == 3'd1) ? tx_i_corr_pos20 :
                                                12'sd0;

assign tx_q_corr_sel = (profile_idx == 3'd0) ? tx_q_corr_neg20 :
                       (profile_idx == 3'd1) ? tx_q_corr_pos20 :
                                                12'sd0;

wire signed [11:0] tx_i_sig = aim_noise[15:4];
wire signed [11:0] tx_q_sig = aim_noise[31:20];

wire signed [12:0] tx_i_corr_ext = TX_LO_CORR_EN ?
                                   {tx_i_corr_sel[11], tx_i_corr_sel} :
                                   13'sd0;
wire signed [12:0] tx_q_corr_ext = TX_LO_CORR_EN ?
                                   {tx_q_corr_sel[11], tx_q_corr_sel} :
                                   13'sd0;

wire signed [12:0] tx_i_sum = {tx_i_sig[11], tx_i_sig} + tx_i_corr_ext;
wire signed [12:0] tx_q_sum = {tx_q_sig[11], tx_q_sig} + tx_q_corr_ext;

wire signed [11:0] tx_i_to_fifo = (tx_i_sum > 13'sd2047)  ? 12'sd2047  :
                                  (tx_i_sum < -13'sd2048) ? -12'sd2048 :
                                                            tx_i_sum[11:0];
wire signed [11:0] tx_q_to_fifo = (tx_q_sum > 13'sd2047)  ? 12'sd2047  :
                                  (tx_q_sum < -13'sd2048) ? -12'sd2048 :
                                                            tx_q_sum[11:0];

// 24bit I/Q FIFO：高 12bit = Q，低 12bit = I
wire [23:0] fifo_din_IQ  = {tx_q_to_fifo[11:0], tx_i_to_fifo[11:0]};
wire [23:0] fifo_dout_IQ;
wire [11:0] data2dac_Q   = fifo_dout_IQ[23:12];
wire [11:0] data2dac_I   = fifo_dout_IQ[11:0];

wire        fifo_wr_en_IQ = tx_path_enable_wr & aim_noise_valid;
wire        fifo_iq_full;
wire        fifo_iq_empty;
wire [9:0]  rd_data_count_IQ;
wire        fifo_iq_rst = (!rstn_data) | rst_9361 | (!tx_start_ready);
reg fifo_rd_en;

async_fifo_iq_24 #(
    .DATA_WIDTH (24),
    .ADDR_WIDTH (10)
) u_async_fifo_iq_24 (
    .rst           (fifo_iq_rst),
    .wr_clk        (ad9361_clk_div),
    .rd_clk        (data_clk),
    .din           (fifo_din_IQ),
    .wr_en         (fifo_wr_en_IQ),
    .rd_en         (fifo_rd_en),
    .dout          (fifo_dout_IQ),
    .full          (fifo_iq_full),
    .empty         (fifo_iq_empty),
    .rd_data_count (rd_data_count_IQ)
);

// FIFO 读使能：只在 TX 路径启动且 FIFO 水位足够时读。

always @(posedge data_clk) begin
    if(!rstn_data || !tx_path_enable_data)
        fifo_rd_en <= 1'b0;
    else if(dac_valid && (rd_data_count_IQ > 10'd512) && !fifo_iq_empty)
        fifo_rd_en <= 1'b1;
    else
        fifo_rd_en <= 1'b0;
end

// 输出寄存器：同一组 I/Q 复制到两个 TX 通道
reg [47:0] dac_data1;
always @(posedge data_clk) begin
    if(!rstn_data || !tx_path_enable_data) begin
        dac_data1 <= 48'd0;
    end
    else if(fifo_rd_en) begin
        dac_data1[11:0]   <= data2dac_I; // I1
        dac_data1[23:12]  <= data2dac_Q; // Q1
        dac_data1[35:24]  <= data2dac_I; // I2
        dac_data1[47:36]  <= data2dac_Q; // Q2
    end
end

assign dac_data0_i_12b = dac_data1[11:0];
assign dac_data0_q_12b = dac_data1[23:12];
assign dac_data1_i_12b = dac_data1[35:24];
assign dac_data1_q_12b = dac_data1[47:36];

  // B9361 DAC and ADC ctrl


  assign adc_r1_mode = 1'b0;
  assign dac_r1_mode = 1'b0;


  wire                                    adc_valid_out              ;
  wire                   [  11:0]         adc_data0_i                ;
  wire                   [  11:0]         adc_data0_q                ;
  wire                   [  11:0]         adc_data1_i                ;
  wire                   [  11:0]         adc_data1_q                ;
  wire                   [   4:0]         test_signal                ;

  
  AD9361_IF u_AD9361_IF(
                    .adc_r1_mode                       (adc_r1_mode               ),
                    .dac_r1_mode                       (dac_r1_mode               ),
                    .data_clk                          (data_clk                  ),
                    .rst                               (rst_9361                  ),
                    .adc_status                        (adc_status                ),
                    .rx_clk_in_p                       (rx_clk_in_p               ),
                    .rx_clk_in_n                       (rx_clk_in_n               ),
                    .rx_frame_in_p                     (rx_frame_in_p             ),
                    .rx_frame_in_n                     (rx_frame_in_n             ),
                    .rx_data_in_p                      (rx_data_in_p              ),
                    .rx_data_in_n                      (rx_data_in_n              ),
                    .adc_valid_out                     (adc_valid_out             ),
                    .adc_data0_i                       (adc_data0_i               ),
                    .adc_data0_q                       (adc_data0_q               ),
                    .adc_data1_i                       (adc_data1_i               ),
                    .adc_data1_q                       (adc_data1_q               ),
                    .dac_valid_in                      (fifo_rd_en                ),//in 四个周期拉高一次（双通道使用
                    .dac_data0_i_in                    (dac_data0_i_12b           ),
                    .dac_data0_q_in                    (dac_data0_q_12b           ),
                    .dac_data1_i_in                    (dac_data1_i_12b           ),
                    .dac_data1_q_in                    (dac_data1_q_12b           ),
                    .tx_clk_out_p                      (tx_clk_out_p              ),
                    .tx_clk_out_n                      (tx_clk_out_n              ),
                    .tx_frame_out_p                    (tx_frame_out_p            ),
                    .tx_frame_out_n                    (tx_frame_out_n            ),
                    .tx_data_out_p                     (tx_data_out_p             ),
                    .tx_data_out_n                     (tx_data_out_n             ),
                    .test_signal                       (test_signal               )

                  );



   
   parameter NUM_DIV = 4;
   reg [1:0]cnt;
   
 
                  // 1. 修改定义
   reg ad9361_clk_div_raw; // 原来的寄存器改个名

   // 2. 逻辑保持不变，但操作的是 raw 信号
   always @(posedge data_clk) begin
       if(!rstn) begin
           cnt <= 2'd0;
           ad9361_clk_div_raw <= 1'b0; 
       end
       else if(cnt < NUM_DIV / 2 - 1) begin
           cnt <= cnt + 1'b1;
           ad9361_clk_div_raw <= ad9361_clk_div_raw;
       end
       else begin
           cnt <= 2'd0;
           ad9361_clk_div_raw <= ~ad9361_clk_div_raw; // 翻转
       end
   end

   // 3. 【关键】通过 BUFG 将普通信号驱动到全局时钟树
   BUFG u_clk_div_bufg (
       .I (ad9361_clk_div_raw), // 输入：普通逻辑信号
       .O (ad9361_clk_div)      // 输出：低偏斜的全局时钟
   );

  // //ILA
  reg                    [   1:0]         cnt_dac_vaild = 0          ;
  //reg clk_dac_vaild;
  wire                                    clk_dac_vaild_wire         ;
  always @(posedge data_clk)
  begin
    begin
      cnt_dac_vaild <= cnt_dac_vaild + 1;
    end
  end




    wire [7:0]  w_readdata;
    wire [5:0]  w_state;
    wire [31:0] w_measured_lock_time;

  assign clk_dac_vaild_wire = cnt_dac_vaild[1];

  wire                                    rx_valid                   ;
  wire                   [  12:0]         init_index                 ;

                ad9361_init2 u_ad9361_init(
                 .sys_clk                           (gclk_div                  ),//20M
                 .sys_rst                           (!rstn                     ),//rstn低�?�位
                 .state_next                        (state_next                ),
                 .FIND                              (~FIND_dd                  ),
                 .ad9361_spi_cs                     (spi_csn                   ),
                 .ad9361_spi_sclk                   (spi_clk                   ),
                 .ad9361_spi_mosi                   (spi_sdo                   ),
                 .ad9361_spi_miso                   (spi_sdi                   ),
                 .en_agc                            (en_agc                    ),
                 .enable                            (enable                    ),
                 .resetb                            (resetb                    ),
                 .txnrx                             (txnrx                     ),
                 .sync_in                           (sync_in                   ),
                 .ctrl_in                           (ctrl_in                   ),
                 .ctrl_out                          (ctrl_out                  ),
                 .cfg_status                        (led                       ),
                 .init_index                        (init_index                ),
                 .rx_valid                          (rx_valid                  ),
	               .w_measured_lock_time 			        (w_measured_lock_time      ),
                 .w_readdata_out       			        (w_readdata                ),
                 .w_state_out          			        (w_state                   ),
                 .address                           (address                   ),
	               .writedata                         (writedata                 ),
                 .profile_idx                       (profile_idx               ),
                 .ad9361_spi_ok                     (                          )
               );

    wire               rx_adc_valid_for_detect = (~aim_noise_valid) && rx_valid_dd;
    wire signed [11:0] rx_i_raw = adc_data1_i;
    wire signed [11:0] rx_q_raw = adc_data1_q;
    wire signed [11:0] rx_i_dcr;
    wire signed [11:0] rx_q_dcr;
    wire               rx_dc_valid;

    iq_dc_block_iir #(
        .IN_WIDTH (12),
        .DC_WIDTH (28),
        .FRAC     (8),
        .K        (RX_DC_K)
    ) u_rx_dc_block (
        .clk       (ad9361_clk_div),
        .rstn      (rstn),
        .valid_in  (rx_adc_valid_for_detect),
        .i_in      (rx_i_raw),
        .q_in      (rx_q_raw),
        .valid_out (rx_dc_valid),
        .i_out     (rx_i_dcr),
        .q_out     (rx_q_dcr)
    );

    always @(posedge ad9361_clk_div) begin
       if(~rstn) begin
         s_axis_tdata <= 'b0;
       end
       else if(rx_dc_valid) begin
         s_axis_tdata[15:0 ] <= {{4{rx_i_dcr[11]}}, rx_i_dcr};
         s_axis_tdata[31:16] <= {{4{rx_q_dcr[11]}}, rx_q_dcr};
       end
       else begin
         s_axis_tdata <= 'b0;
       end
     end


// PS GPIO configuration is isolated from the radio clock domains.  In
// particular, pl_rstn is *not* connected to rstn or ad9361_init, so a PS
// reset/configuration transaction cannot restart the SPI initialization FSM.
reset_sync_n u_cfg_reset_sync_200m (
    .clk   (FFT_200MHz_clk),
    .arstn (rstn),
    .srstn (rstn_200m)
);

cdc_bus_update #(.WIDTH(96)) u_cfg_cdc_40m (
    .src_clk           (pl_clk),
    .src_rstn          (pl_rstn),
    .src_bus           (cfg_bundle_async),
    .src_update_toggle (mode3_cfg0[31]),
    .dst_clk           (ad9361_clk_div),
    .dst_rstn          (rstn_tx),
    .dst_bus           (cfg_bundle_40m),
    .dst_update_pulse  (cfg_update_40m)
);

cdc_bus_update #(.WIDTH(96)) u_cfg_cdc_200m (
    .src_clk           (pl_clk),
    .src_rstn          (pl_rstn),
    .src_bus           (cfg_bundle_async),
    .src_update_toggle (mode3_cfg0[31]),
    .dst_clk           (FFT_200MHz_clk),
    .dst_rstn          (rstn_200m),
    .dst_bus           (cfg_bundle_200m),
    .dst_update_pulse  (cfg_update_200m)
);

assign DIV_CNT  = cfg_bundle_40m[15:0];
assign sel_jam  = cfg_bundle_40m[19:16];
assign AIM_TIME = cfg_bundle_40m[63:32];
assign Thred    = cfg_bundle_200m[95:64];

// The old VIO-only LO correction knobs were unused in the field design.
// Keep the correction path deterministic while removing that unused VIO core.
assign tx_i_corr_neg20 = 12'sd0;
assign tx_q_corr_neg20 = 12'sd0;
assign tx_i_corr_pos20 = 12'sd0;
assign tx_q_corr_pos20 = 12'sd0;
//需要和另一个信号共同控制
                 aim_noise u_aim_noise
                (
                    .s_axis_aclk                       (ad9361_clk_div            ),

                    .s_axis_aresetn                    (rstn_tx                   ),
                    .F_user                            (F_user_40M                ),
                    .F_user_valid                      (F_user_40M_valid          ),
                    .DIV_CNT                           (DIV_CNT                   ),
                    .Freq_Thr_over                     (freq_over_pulse_40m       ),
                    .NO_UAV                            (FIND_UAV_pulse_40m        ),
                    .AIM_TIME                          (AIM_TIME                  ),



                    .fctr_bus                          (fctr_bus                   ),
                    .FIND                              (FIND_dd                   ),
                    .aim_noise                         (aim_noise                 ),
                    .aim_noise_valid                   (aim_noise_valid           ),
                    .FIND_EN_AIM                       (FIND_EN_AIM_1             ),
                    .EN_GANRAO                         (EN_GANRAO                 ),
                    .data_2ph                          (data_2ph                  ),
                    .sincos                            (sincos                    ),
                    .data                              (                          ),
                    .sel_jam                           (sel_jam                   ),

                    .ADDRB                             (ADDRB                     ),
                    .REA                               (REA                       ),
                    .m_axis_tdata_ram                  (m_axis_tdata_ram          ) 

                );


                DETECT_AIM # (
                    .DATA_WIDTH                        (DATA_WIDTH                ) 
                )
                DETECT_AIM_inst (
                    .s_axis_aclk                       (ad9361_clk_div            ),
                    .data_clk                          (FFT_200MHz_clk            ),                    
                    .s_axis_aresetn                    (rstn_tx                   ),
                    .s_axis_tdata                      (s_axis_tdata              ),
                    .s_axis_tvalid                     ('b1                       ),
                    .Thred                             (Thred                     ),
                    .FIND_EN                           (FIND_EN_1                 ),
                    .FIND_EN_AIM                       (FIND_EN_AIM_1_dd_200MHz   ),

                    .tr_m_axis_tvalid                  (tr_m_axis_tvalid          ),
                    .Freq_Thr_over_toggle              (Freq_Thr_over_toggle      ),
                    .FIND_UAV_toggle                   (FIND_UAV_toggle           ),
                    .FIND_UAV                          (FIND_UAV                  ),
                    .data_sum                          (data_sum                  ),
                    .FIND                              (FIND                      ),
                    .CNT                               (CNT                       ),
                    .m_axis_tstart_thr                 (m_axis_tstart_thr         ),
                    .m_axis_tlast_thr                  (m_axis_tlast_thr          ),
                    .DATA_LABEL                        (DATA_LABEL                ),
                    .WEA                               (WEA                       ),
                    .ADDRA                             (ADDRA                     ),
                    .REA                               (REA                       ),
                    .ADDRB                             (ADDRB                     ),
                    .m_axis_tdata_ram                  (m_axis_tdata_ram          ),
                    .m_axis_tdata_FFT                  (m_axis_tdata_FFT          ),
                    .m_axis_tvalid_FFT                 (m_axis_tvalid_FFT         ),
                    .m_axis_tvalid_ram                 (m_axis_tvalid_ram         ),
                    .F_user_1                          (F_user_200M               ),
                    .Freq_Thr_over_1                   (Freq_Thr_over_1           ),
                    .m_axis_tuser_FFT                  (m_axis_tuser_FFT          ),

                    .dbg_data_abs                      (dbg_data_abs              ),
                    .dbg_data_abs_valid                (dbg_data_abs_valid        ),
                    .dbg_data_abs_last                 (dbg_data_abs_last         ),
                    .dbg_cfar_raw_idx                  (dbg_cfar_raw_idx          ),
                    .dbg_cfar_cut_amp                  (dbg_cfar_cut_amp          ),
                    .dbg_cfar_hit                      (dbg_cfar_hit              ),
                    .dbg_cfar_valid                    (dbg_cfar_valid            ),
                    .dbg_cfar_last                     (dbg_cfar_last             ),
                    .dbg_condense_peak_idx             (dbg_condense_peak_idx     ),
                    .dbg_condense_peak_amp             (dbg_condense_peak_amp     ),
                    .dbg_condense_hit                  (dbg_condense_hit          ),
                    .dbg_condense_valid                (dbg_condense_valid        ),
                    .dbg_condense_last                 (dbg_condense_last         ),
                    .dbg_condense_user                 (dbg_condense_user         ),
                    .dbg_frame_has_candidate           (dbg_frame_has_candidate   )
                );

    wire trig_req;        // 200M 发出的触发请求
    wire ack_from_200m;   // 40M 的回复
    wire ack_from_20m;    // 20M 的回复
    wire combined_ack;    // 合并后的回复



    assign combined_ack = ack_from_200m | ack_from_20m;

    //==============================================================
    // 1. 高速 ILA (200MHz 域) - 主触发源
    //==============================================================
    AIM_ila_200M u_ila_200m (
        .clk           (FFT_200MHz_clk    ),

        // Current cross-trigger direction is unchanged:
        // AIM_ila_40M.trig_out -> AIM_ila_200M.trig_in.
        .trig_in       (trig_req          ),
        .trig_in_ack   (ack_from_200m     ),

        // Basic frame / RAM / FFT observation
        .probe0        (DATA_LABEL        ), // 1 bit
        .probe1        (WEA               ), // 1 bit
        .probe2        (REA               ), // 1 bit
        .probe3        (m_axis_tdata_ram  ), // 32 bit
        .probe4        (m_axis_tdata_FFT  ), // 32 bit
        .probe5        (m_axis_tvalid_FFT ), // 1 bit
        .probe6        (m_axis_tuser_FFT  ), // 16 bit, should be 0~1023 after FFT index zero-extension

        // complex_abs output
        .probe7        (dbg_data_abs       ), // 16 bit
        .probe8        (dbg_data_abs_valid ), // 1 bit
        .probe9        (dbg_data_abs_last  ), // 1 bit

        // Raw CFAR stream
        .probe10       (dbg_cfar_idx_amp_bus),  // 32 bit: {raw_idx[15:0], cut_amp[15:0]}
        .probe11       (dbg_cfar_flag_bus   ),  // 16 bit: {13'd0, cfar_last, cfar_valid, cfar_hit}

        // traces_condense candidate stream
        .probe12       (dbg_condense_idx_amp_bus), // 32 bit: {peak_idx[15:0], peak_amp[15:0]}
        .probe13       (dbg_condense_flag_bus   ), // 16 bit: {13'd0, cond_last, cond_valid, cond_hit}
        .probe14       (dbg_condense_user       ), // 16 bit: {2'b0, target_id[3:0], peak_bin[9:0]}
        .probe15       (dbg_frame_has_candidate ), // 1 bit

        // Current Freq_Thr output to lower modules
        .probe16       (tr_m_axis_tvalid ), // 1 bit
        .probe17       (Freq_Thr_over_1  ), // 1 bit
        .probe18       (F_user_200M      ), // 16 bit
        .probe19       (FIND_UAV         )  // 1 bit

    );

    //==============================================================
    // 2. 中速 ILA (40MHz 域) - 被触发者
    //==============================================================
    AIM_ila_40M u_ila_40m (
        .clk           (ad9361_clk_div    ),
  
        .trig_out      (trig_req          ),// 输入：接收来自 200M 的触发请求
        .trig_out_ack  (combined_ack      ),// 输出：发出“我收到了”的回复
        
        .probe0        (s_axis_tdata       ),
        .probe1        (aim_noise          ),
        .probe2        (data_sum           ),
        .probe3        (aim_noise_valid    ),
        .probe4        (FIND               ),
        .probe5        (freq_over_pulse_40m),
        .probe6        (EN_GANRAO          ),
        .probe7        (F_user_40M         ),
        .probe8        (fctr_bus           ),
        .probe9        (data_2ph           ),
        .probe10       (sincos             ),
        .probe11       (FIND_EN_1          )

      
    );

    //==============================================================
    // 3. 低速 ILA (20MHz 域) - 被触发者
    //==============================================================
    AIM_ila_20M u_ila_20m (
        .clk           (gclk_div             ),
    
        .trig_in       (trig_req             ),// 输入：接收来自 200M 的触发请求
        .trig_in_ack   (ack_from_20m         ),// 输出：发出“我收到了”的回复
            
        .probe0        (profile_idx          ),
        .probe1        (address              ),
        .probe2        (writedata            ),
    
        .probe3        (w_state              ), 
        .probe4        (w_readdata           ), 
        .probe5        (w_measured_lock_time ), 
        .probe6        (rx_valid             )  
    );

         ila_rx_tx ila_rx_tx_inst1 (
             .clk                               (data_clk                  ),// input wire clk
         
             .probe0                            (adc_data0_i               ),// input wire [11:0]  probe0  
             .probe1                            (adc_data0_q               ),// input wire [11:0]  probe1 
             .probe2                            (aim_noise_valid           ),// input wire [ 0:0]  probe2 
             .probe3                            (adc_data1_i               ),// input wire [11:0]  probe3 
             .probe4                            (adc_data1_q               ),// input wire [11:0]  probe4
             .probe5                            (rx_valid_dd               ),// input wire [ 0:0]  probe5
             .probe6                            (dac_data0_i_12b           ),// input wire [11:0]  probe6 
             .probe7                            (dac_data0_q_12b           ),// input wire [11:0]  probe7
             .probe8                            (dac_data1_i_12b           ),// input wire [11:0]  probe8 
             .probe9                            (dac_data1_q_12b           ),// input wire [11:0]  probe9
             .probe10                           (dac_valid                 ) // input wire [11:0]  probe10
         );    




         
fifo_generator_0 fifo_F_user_200MHzto40MHz (
    .rst         (~rstn),                 // active-high reset; do NOT reset on freq_over_pulse_40m
    .wr_clk      (FFT_200MHz_clk),
    .rd_clk      (ad9361_clk_div),
    .din         (F_user_200M),
    .wr_en       (tr_m_axis_tvalid_d && ~wr_rst_busy),
    .rd_en       (fifo_rd_en_F_user),
    .dout        (F_user_40M),
    .full        (full),
    .empty       (empty),
    .wr_rst_busy (wr_rst_busy),
    .rd_rst_busy (rd_rst_busy)
);

// If your FIFO is standard read mode, dout is valid one rd_clk after rd_en.
always @(posedge ad9361_clk_div) begin
    if (!rstn) begin
        fifo_rd_en_F_user_d <= 1'b0;
    end else begin
        fifo_rd_en_F_user_d <= fifo_rd_en_F_user;
    end
end
assign F_user_40M_valid = fifo_rd_en_F_user;

assign fifo_rd_en_F_user = !empty && !rd_rst_busy;


     always @(posedge FFT_200MHz_clk) begin
         if(!rstn) begin
             tr_m_axis_tvalid_d <= 'b0;
         end else begin
             tr_m_axis_tvalid_d <= tr_m_axis_tvalid;
         end
     end



    always @(posedge gclk_div) begin
        if(!rstn) begin
            FIND_d <= 'b0;
            FIND_dd <= 'b0;
        end else begin
            FIND_d <= FIND;
            FIND_dd <= FIND_d;
        end
    end

    always @(posedge ad9361_clk_div) begin
        if(!rstn) begin
            rx_valid_d  <= 'b0;
            rx_valid_dd <= 'b0;
        end else begin
            rx_valid_d  <= rx_valid;
            rx_valid_dd <= rx_valid_d;
        end
    end


    // 2. 将翻转信号同步到40MHz域 (打三拍以消除亚稳态并做边沿检测)
    reg [2:0] freq_over_sync_40m;
    always @(posedge ad9361_clk_div) begin
        if (!rstn) begin
            freq_over_sync_40m <= 3'b0;
        end else begin
            // 移位寄存器：[0]是最新，[2]是最老
            freq_over_sync_40m <= {freq_over_sync_40m[1:0], Freq_Thr_over_toggle};
        end
    end

    assign freq_over_pulse_40m = (freq_over_sync_40m[2] ^ freq_over_sync_40m[1]);



    reg [2:0] FIND_UAV_sync_40m;
    always @(posedge ad9361_clk_div) begin
        if (!rstn) begin
            FIND_UAV_sync_40m <= 3'b0;
        end else begin
            // 移位寄存器：[0]是最新，[2]是最老
            FIND_UAV_sync_40m <= {FIND_UAV_sync_40m[1:0], FIND_UAV_toggle};
        end
    end

    assign  FIND_UAV_pulse_40m = (FIND_UAV_sync_40m[2] ^ FIND_UAV_sync_40m[1]);

    reg FIND_UAV_pulse_40m_d;

    always @(posedge ad9361_clk_div) begin
        if (!rstn) begin
            FIND_UAV_pulse_40m_d <= 'b0;
        end else begin
            FIND_UAV_pulse_40m_d <= FIND_UAV_pulse_40m;
        end
      
    end

    always @(posedge ad9361_clk_div) begin
        if(!rstn) begin
            FIND_EN_AIM_1_d <= 'b0;
        end else begin
            FIND_EN_AIM_1_d <= FIND_EN_AIM_1;
        end
    end

always @(posedge FFT_200MHz_clk) begin
    if(!rstn) begin
        FIND_EN_AIM_1_d_200MHz <= 'b0;
        FIND_EN_AIM_1_dd_200MHz <= 'b0;
    end else begin
        FIND_EN_AIM_1_d_200MHz <= FIND_EN_AIM_1;
        FIND_EN_AIM_1_dd_200MHz <= FIND_EN_AIM_1_d_200MHz;
    end
end


always @(posedge ad9361_clk_div) begin
    if(!rstn | FIND_EN_AIM_1_d|FIND_UAV_pulse_40m_d) begin
        FIND_EN_1 <= 'b0; 
    end else if(FIND_EN_AIM_1|FIND_UAV_pulse_40m)begin
        FIND_EN_1 <= 'b1;
    end else begin
        FIND_EN_1 <= FIND_EN_1;
    end
end


//always @(posedge ad9361_clk_div) begin
//    if(!rstn | FIND_EN_AIM_1_d) begin
//        FIND_EN_1 <= 'b0; 
//    end else if(FIND_EN_AIM_1)begin
//        FIND_EN_1 <= 'b1;
//    end else begin
//        FIND_EN_1 <= FIND_EN_1;
//    end
//end


endmodule



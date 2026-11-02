`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/15 11:27:14
// Design Name: 
// Module Name: AD9361_IF
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

//LVDS
//2024.8.5 一个文件实现功能，内部无需添加文件
module AD9361_IF 
// #(
//     parameter rx_mode = 0,    //接收通道 0为单通道  1为双通道
//     parameter tx_mode = 0
// )
  (
  // physical interface (receive)

    input                               rx_clk_in_p                ,
    input                               rx_clk_in_n                ,
    input                               rx_frame_in_p              ,
    input                               rx_frame_in_n              ,
    input              [   5:0]         rx_data_in_p               ,
    input              [   5:0]         rx_data_in_n               ,

    input                               adc_r1_mode                ,
    output                              data_clk                   ,
    output reg                          rst                        ,

    output                              adc_status                 ,
    output                              adc_valid_out              ,
    output             [  11:0]         adc_data0_i                ,
    output             [  11:0]         adc_data0_q                ,
    output             [  11:0]         adc_data1_i                ,
    output             [  11:0]         adc_data1_q                ,


  //DAC

  // physical interface (transmit)
    output                              tx_clk_out_p               ,
    output                              tx_clk_out_n               ,
    output                              tx_frame_out_p             ,
    output                              tx_frame_out_n             ,
    output             [   5:0]         tx_data_out_p              ,
    output             [   5:0]         tx_data_out_n              ,


    input                               dac_r1_mode                ,

    input                               dac_valid_in               ,
    input              [  11:0]         dac_data0_i_in             ,
    input              [  11:0]         dac_data0_q_in             ,
    input              [  11:0]         dac_data1_i_in             ,
    input              [  11:0]         dac_data1_q_in              ,
    output        wire      [ 4:0]           test_signal

);


wire                                    adc_valid                  ;
wire                   [  11:0]         adc_data_i0                ;
wire                   [  11:0]         adc_data_q0                ;
wire                   [  11:0]         adc_data_i1                ;
wire                   [  11:0]         adc_data_q1                ;
//  reg adc_status         ;
assign adc_valid_out   = adc_valid   ;    
assign adc_data0_i     = adc_data_i0 ;
assign adc_data0_q     = adc_data_q0 ;
assign adc_data1_i     = adc_data_i1 ;
assign adc_data1_q     = adc_data_q1 ;


wire                                    dac_valid                  ;
wire                   [  11:0]         dac_data_i0                ;
wire                   [  11:0]         dac_data_q0                ;
wire                   [  11:0]         dac_data_i1                ;
wire                   [  11:0]         dac_data_q1                ;

assign dac_valid     = dac_valid_in    ; 
assign dac_data_i0   = dac_data0_i_in  ;
assign dac_data_i1   = dac_data1_i_in  ;

// -----------------------------------------------------------------------------
// TX frequency direction fix
// -----------------------------------------------------------------------------
// 实测当前 AD9361 TX 接口时序下，基带 +Fs/4 复数单音会出现在 LO-Fs/4。
// 为了不改上游 aim_noise / 干扰源，在 AD9361_IF 的 TX 入口处统一翻转 Q 路，
// 使基带 +Fs/4 对应 LO+Fs/4。
// 如果后续希望恢复原方向，把该参数改成 1'b0。
localparam TX_Q_INVERT_FOR_UPPER_SIDEBAND = 1'b0;

wire [11:0] dac_data0_q_for_tx;
wire [11:0] dac_data1_q_for_tx;

assign dac_data0_q_for_tx = TX_Q_INVERT_FOR_UPPER_SIDEBAND ? ((~dac_data0_q_in) + 12'd1) : dac_data0_q_in;
assign dac_data1_q_for_tx = TX_Q_INVERT_FOR_UPPER_SIDEBAND ? ((~dac_data1_q_in) + 12'd1) : dac_data1_q_in;

assign dac_data_q0   = dac_data0_q_for_tx;
assign dac_data_q1   = dac_data1_q_for_tx;





reg [19:0]rst_cnt = 0;
always @(posedge data_clk ) begin
  if(rst_cnt == 20'd1000001)
    rst_cnt <=  rst_cnt;
  else if(rst_cnt<20'd1000001)
    rst_cnt <=  rst_cnt + 1;
end
always @(posedge data_clk ) begin
  if(rst_cnt <= 20'd1000000)
    rst  <=  1'b1;
  else 
    rst  <=  1'b0;
end










  //-----------------------ADC---------------------//

//adc data
  reg                 adc_r1_mode_n = 'd0;
  reg                 rx_r1_mode = 'd0;
  reg                 rx_locked_m1 = 'd0;
  reg                 rx_locked = 'd0;
  reg                 rx_valid = 'd0;
  reg     [ 1:0]      rx_frame = 'd0;
  reg     [ 5:0]      rx_data_1 = 'd0;
  reg     [ 5:0]      rx_data_0 = 'd0;
  reg     [ 3:0]      rx_frame_d = 'd0;
  reg     [ 5:0]      rx_data_1_2d = 'd0;
  reg     [ 5:0]      rx_data_0_2d = 'd0;
  reg     [ 5:0]      rx_data_1_d = 'd0;
  reg                 adc_valid_p = 'd0;
  reg     [47:0]      adc_data_p = 'd0;
  reg                 adc_status_p = 'd0;
  reg                 adc_valid_n = 'd0;
  reg     [47:0]      adc_data_n = 'd0;
  reg                 adc_status_n = 'd0;
  reg                 adc_valid_int = 'd0;
  reg     [47:0]      adc_data_int = 'd0;
  reg                 adc_status_int = 'd0;

wire                   [  47:0]         adc_data                   ;
wire                                    clk_ibuf_s                 ;
wire                   [   3:0]         rx_frame_d_s               ;
wire                   [   5:0]         rx_data_1_s                ;
wire                   [   5:0]         rx_data_0_s                ;
wire                   [   1:0]         rx_frame_s                 ;
wire                                    locked_s                   ;
assign {adc_data_i0,adc_data_q0,adc_data_i1,adc_data_q1} = adc_data;

//clock
IBUFGDS i_rx_clk_ibuf (
  .I  (rx_clk_in_p ),
  .IB (rx_clk_in_n ),
  .O (clk_ibuf_s   ));

  BUFG i_clk_gbuf (
    .I (clk_ibuf_s),
    .O (data_clk));




  // r1mode
 
  always @(negedge data_clk) begin
    adc_r1_mode_n <= adc_r1_mode;
  end

  always @(posedge data_clk) begin
    rx_r1_mode <= adc_r1_mode_n;
  end

  // adc-status
 
  // assign delay_locked = locked_s;

  always @(posedge data_clk) begin
    rx_locked_m1 <= locked_s;
    rx_locked <= rx_locked_m1;
  end


  // adc-status
 
  always @(posedge data_clk) begin
    if (rx_valid == 1'b1) begin
      if (rx_frame_d == rx_frame_d_s) begin
        adc_status_p <= rx_locked;
      end else begin
        adc_status_p <= 1'b0;
      end
    end
  end


  // altera-equivalence
 
  always @(posedge data_clk) begin
    rx_valid <= ~rx_valid;
    rx_frame <= rx_frame_s;
    rx_data_1 <= rx_data_1_s;
    rx_data_0 <= rx_data_0_s;
  end


  // frame check
 
  assign rx_frame_d_s = {rx_frame_s, rx_frame};

  always @(posedge data_clk) begin
    if (rx_valid == 1'd1) begin
      if (rx_r1_mode == 1'd1) begin
        rx_frame_d <= rx_frame_d_s;
      end else begin
        rx_frame_d <= ~rx_frame_d_s;
      end
    end
  end


  // data hold
 
  always @(posedge data_clk) begin
    if (rx_valid == 1'd1) begin
      rx_data_1_2d <= rx_data_1_s;
      rx_data_0_2d <= rx_data_0_s;
      rx_data_1_d <= rx_data_1;
    end
  end



//data process out
  assign test_signal = {rx_r1_mode, rx_frame_s, rx_frame};

 always @(posedge data_clk) begin
   if (rx_valid == 1'b1) begin
     case ({rx_r1_mode, rx_frame_s, rx_frame})
       5'b01111: begin
         adc_valid_p <= 1'b0;
         //adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_1, rx_data_1_s};
         adc_data_p[11: 0] <= {rx_data_0, rx_data_0_s};
       end
       5'b00000: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:36] <= {rx_data_1, rx_data_1_s};
         adc_data_p[35:24] <= {rx_data_0, rx_data_0_s};
         adc_data_p[23: 0] <= adc_data_p[23:0];
       end
       5'b00111: begin
         adc_valid_p <= 1'b0;
         //adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_0, rx_data_0_s};
         adc_data_p[11: 0] <= {rx_data_1_2d, rx_data_1};
       end
       5'b01000: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:36] <= {rx_data_0, rx_data_0_s};
         adc_data_p[35:24] <= {rx_data_1_2d, rx_data_1};
         adc_data_p[23: 0] <= adc_data_p[23:0];
       end
       5'b00011: begin
         adc_valid_p <= 1'b0;
         //adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_1_2d, rx_data_1};
         adc_data_p[11: 0] <= {rx_data_0_2d, rx_data_0};
       end
       5'b01100: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:36] <= {rx_data_1_2d, rx_data_1};
         adc_data_p[35:24] <= {rx_data_0_2d, rx_data_0};
         adc_data_p[23: 0] <= adc_data_p[23:0];
       end
       5'b00001: begin
         adc_valid_p <= 1'b0;
         //adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_0_2d, rx_data_0};
         adc_data_p[11: 0] <= {rx_data_1_d, rx_data_1_2d};
       end
       5'b01110: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:36] <= {rx_data_0_2d, rx_data_0};
         adc_data_p[35:24] <= {rx_data_1_d, rx_data_1_2d};
         adc_data_p[23: 0] <= adc_data_p[23:0];
       end
       5'b10011: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_1, rx_data_1_s};
         adc_data_p[11: 0] <= {rx_data_0, rx_data_0_s};
       end
       5'b11001: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_0, rx_data_0_s};
         adc_data_p[11: 0] <= {rx_data_1_2d, rx_data_1};
       end
       5'b11100: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_1_2d, rx_data_1};
         adc_data_p[11: 0] <= {rx_data_0_2d, rx_data_0};
       end
       5'b10110: begin
         adc_valid_p <= 1'b1;
         adc_data_p[47:24] <= 24'd0;
         adc_data_p[23:12] <= {rx_data_0_2d, rx_data_0};
         adc_data_p[11: 0] <= {rx_data_1_d, rx_data_1_2d};
       end
       default: begin
         adc_valid_p <= 1'b0;
         adc_data_p <= 48'd0;
       end
     endcase
   end else begin
     adc_valid_p <= 1'b0;
     adc_data_p <= adc_data_p;
   end
 end




  // transfer to common clock

  always @(negedge data_clk) begin
    adc_valid_n <= adc_valid_p;
    adc_data_n <= adc_data_p;
    adc_status_n <= adc_status_p;
  end

  assign adc_valid = adc_valid_int;
  assign adc_data = adc_data_int;
  assign adc_status = adc_status_int;

  always @(posedge data_clk) begin
    adc_valid_int <= adc_valid_n;
    adc_data_int <= adc_data_n;
    adc_status_int <= adc_status_n;
  end


  assign adc_valid = adc_valid_int;
  assign adc_data = adc_data_int;
  assign adc_status = adc_status_int;


  //-----------------------ADC END---------------------//

  //-----------------------DAC START-------------------//

reg [ 2:0]  tx_data_cnt   = 'd0;
reg [11:0]  tx_data_i1_d  = 'd0;
reg [11:0]  tx_data_q1_d  = 'd0;
reg [11:0]  tx_data_i2_d  = 'd0;
reg [11:0]  tx_data_q2_d  = 'd0;
reg         tx_frame      = 'd0;
reg [ 5:0]  tx_data_p     = 'd0;
reg [ 5:0]  tx_data_n     = 'd0;

wire    [ 5:0]  tx_data_oddr_s;
wire            tx_frame_oddr_s;
wire            tx_clk_oddr_s;
genvar          l_inst;



reg [1:0] tx_data_sel;
reg  [47:0] tx_data;
wire [47:0] tx_data_s;

assign tx_data_s = {dac_data_i0,dac_data_q0,dac_data_i1,dac_data_q1};


  // dac-tx interface

  // -----------------------------------------------------------------------------
  // TX LVDS output scheduler
  // -----------------------------------------------------------------------------
  // 加 reset：保证每次上电后 TX_FRAME / TX_DATA 的起始相位一致，
  // 避免 tx_data_sel 初始值不确定导致 AD9361 把 I/Q 或 MSB/LSB 边界采错。
always @(posedge data_clk) begin
    if (rst) begin
        tx_data_sel <= 2'd0;
        tx_data     <= 48'd0;
    end
    else begin
        tx_data_sel <= tx_data_sel + 1'b1;

        if ((tx_data_sel == 2'd3) && dac_valid)
            tx_data <= tx_data_s;
    end
end
  // always @(posedge clk) begin
    // tx_clk_p <= {~dac_clksel, dac_clksel};
  // end
// 


  always @(posedge data_clk) begin
    if (rst) begin
      tx_frame  <= 1'b0;
      tx_data_p <= 6'd0;
      tx_data_n <= 6'd0;
    end
    else begin
      case ({dac_r1_mode, tx_data_sel})
        // 保留当前已经验证可压低镜像的 TX DDR 排列方式，只增加确定性复位。
        3'b000: begin
          tx_frame <= 1'b1;
          tx_data_p <= tx_data[11:6];
          tx_data_n <= tx_data[23:18];
        end
        3'b001: begin
          tx_frame <= 1'b1;
          tx_data_p <= tx_data[5:0];
          tx_data_n <= tx_data[17:12];
        end
        3'b010: begin
          tx_frame <= 1'b0;
          tx_data_p <= tx_data[35:30];
          tx_data_n <= tx_data[47:42];
        end
        3'b011: begin
          tx_frame <= 1'b0;
          tx_data_p <= tx_data[29:24];
          tx_data_n <= tx_data[41:36];
        end
        3'b100: begin
          tx_frame <= 1'b1;
          tx_data_p <= tx_data[11:6];
          tx_data_n <= tx_data[23:18];
        end
        3'b101: begin
          tx_frame <= 1'b0;
          tx_data_p <= tx_data[5:0];
          tx_data_n <= tx_data[17:12];
        end
        default: begin
          tx_frame  <= 1'b0;
          tx_data_p <= 6'd0;
          tx_data_n <= 6'd0;
        end
      endcase
    end
  end




//-------------------------------RX DATA Interface---------------------------//
// internal signals
  wire    [ 3:0]  tx_data_sel_s;
  wire    [ 5:0]  rx_data_ibuf_s;
  wire    [ 5:0]  rx_data_idelay_s;
  wire    [ 5:0]  rx_data_p_s;
  wire    [ 5:0]  rx_data_n_s;
  wire            rx_frame_ibuf_s;
  wire            rx_frame_p_s;
  wire            rx_frame_n_s;

//frame data


  genvar i;
  generate
  for (i = 0; i < 6; i = i + 1) 
    begin: g_rx_data

      IBUFDS i_rx_data_ibuf (
          .I                                 (rx_data_in_p[i]              ),
          .IB                                (rx_data_in_n[i]              ),
          .O                                 (rx_data_ibuf_s[i]            ) 
        );
      assign rx_data_idelay_s[i] = rx_data_ibuf_s[i];
          // iddr
      IDDR #(.DDR_CLK_EDGE ("SAME_EDGE")) 
      i_rx_data_iddr (
          .CE                                (1'b1                      ),
          .R                                 (1'b0                      ),
          .S                                 (1'b0                      ),
          .C                                 (data_clk                  ),
          .D                                 (rx_data_idelay_s[i]       ),
          .Q1                                (rx_data_1_s[i]            ),
          .Q2                                (rx_data_0_s[i]            ) 

          );
    end
  endgenerate

  //rx_frame
  IBUFDS i_rx_data_ibuf (
    .I                                 (rx_frame_in_p              ),
    .IB                                (rx_frame_in_n              ),
    .O                                 (rx_frame_ibuf_s            ) 
  );
    // iddr
IDDR #(.DDR_CLK_EDGE ("SAME_EDGE")) 
i_rx_data_iddr (
    .CE                                (1'b1                      ),
    .R                                 (1'b0                      ),
    .S                                 (1'b0                      ),
    .C                                 (data_clk                  ),
    .D                                 (rx_frame_ibuf_s           ),
    .Q1                                (rx_frame_s[1]             ),
    .Q2                                (rx_frame_s[0]             ) 

    );
//---------------------------------------------------------------------------//

//-------------------------------TX DATA Interface---------------------------//


// transmit data interface, oddr -> obuf
//  genvar l_inst;
generate
for (l_inst=0;l_inst<=5;l_inst=l_inst+1)
begin: g_tx_data
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ))
i_tx_data_oddr  (   
.CE             (1'b1                   ),
.R              (1'b0                   ),
.S              (1'b0                   ),
.C              (data_clk               ),
.D1             (tx_data_p[l_inst]      ),
.D2             (tx_data_n[l_inst]      ),
.Q              (tx_data_oddr_s[l_inst] ));
OBUFDS i_tx_data_obuf (
  .I(tx_data_oddr_s[l_inst]),
  .O(tx_data_out_p[l_inst]),
  .OB(tx_data_out_n[l_inst])
  );
end endgenerate
// transmit frame interface, oddr -> obuf
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ))
  i_tx_frame_oddr (
    .CE                                (1'b1                      ),
    .R                                 (1'b0                      ),
    .S                                 (1'b0                      ),
    .C                                 (data_clk                  ),
    .D1                                (tx_frame                  ),
    .D2                                (tx_frame                  ),
    .Q                                 (tx_frame_oddr_s           ) 

  );
OBUFDS i_tx_frame_obuf (
  .I(tx_frame_oddr_s),
  .O(tx_frame_out_p),
  .OB(tx_frame_out_n)
  );

// transmit clock interface, oddr -> obuf
ODDR #(
.DDR_CLK_EDGE   ("SAME_EDGE"            ))
  i_tx_clk_oddr   (
    .CE                                (1'b1                      ),
    .R                                 (1'b0                      ),
    .S                                 (1'b0                      ),
    .C                                 (data_clk                  ),
    .D1                                (1'b1                      ),
    .D2                                (1'b0                      ),
    .Q                                 (tx_clk_oddr_s             ) 
  );
  OBUFDS i_tx_clk_obuf (
    .I                                 (tx_clk_oddr_s             ),
    .O                                 (tx_clk_out_p              ),
    .OB                                (tx_clk_out_n              ) 
  );






endmodule

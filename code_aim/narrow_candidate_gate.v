`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// narrow_candidate_gate.v  -- syntax-fixed / timing-safe v7
//
// Fixes compared with v6:
//   1) Removes Verilog-illegal parameter/expression part-selects such as
//      LOCAL_BG_REF_BINS[IDX_WIDTH-1:0].
//   2) Removes out-of-range part-selects such as bg_cnt[IDX_WIDTH-1:0]
//      when bg_cnt is only 8 bits and IDX_WIDTH is 10.
//   3) Adds a wider edge rejection margin so background-window and scan
//      address calculations do not underflow/overflow near FFT frame edges.
//   4) Keeps the same external ports as v4/v5/v6.
//
// cand_user format:
//   [15:14] = 0
//   [13:10] = candidate/target order
//   [9:0]   = FFT bin index
//////////////////////////////////////////////////////////////////////////////////

module narrow_candidate_gate #(
    parameter DATA_WIDTH           = 16,
    parameter FRAME_LENGTH         = 1024,
    parameter IDX_WIDTH            = 10,
    parameter MAX_CAND             = 16,
    parameter MAX_OUT              = 8,

    parameter LOCAL_BG_REF_BINS    = 64,
    parameter LOCAL_BG_TOTAL_SHIFT = 7,   // log2(2*LOCAL_BG_REF_BINS), 128 -> 7
    parameter LOCAL_BG_GUARD_BINS  = 12,
    parameter NARROW_MAX_BINS      = 24,
    parameter PEAK_DROP_Q8         = 81,  // 10 dB amplitude drop: 0.316*256 ~= 81
    parameter BAND_BG_Q8           = 362, // +3 dB over bg: 1.414*256 ~= 362
    parameter MIN_PROM_SHIFT       = 1,   // peak >= bg << 1 -> about 6 dB amplitude
    parameter IGNORE_DC_BINS       = 8    // reject bins [0..7] and [1016..1023]
)(
    input                         clk,
    input                         rstn,
    input                         clear_frame,

    input      [DATA_WIDTH-1:0]   mag_data,
    input                         mag_valid,

    input                         cand_valid,
    input      [15:0]             cand_user,
    input                         cand_last,

    output reg                    out_valid,
    output reg [15:0]             out_user,
    output reg                    out_done,
    output reg                    no_target,

    output reg [3:0]              dbg_cand_cnt,
    output reg [3:0]              dbg_accept_cnt,
    output reg [IDX_WIDTH-1:0]    dbg_peak_idx,
    output reg [DATA_WIDTH-1:0]   dbg_peak_amp,
    output reg [DATA_WIDTH-1:0]   dbg_bg_mean,
    output reg [7:0]              dbg_width_bins,
    output reg [3:0]              dbg_reject_reason
);

    localparam ST_CAPTURE       = 5'd0;
    localparam ST_LOAD_CAND     = 5'd1;
    localparam ST_READ_PEAK_W   = 5'd2;
    localparam ST_READ_PEAK_D   = 5'd3;
    localparam ST_EDGE_CHECK    = 5'd4;
    localparam ST_BG_ADDR       = 5'd5;
    localparam ST_BG_WAIT       = 5'd6;
    localparam ST_BG_DATA       = 5'd7;
    localparam ST_EVAL_PROM     = 5'd8;
    localparam ST_CALC_LEVEL    = 5'd9;
    localparam ST_SET_LEVEL     = 5'd10;
    localparam ST_SCAN_L_ADDR   = 5'd11;
    localparam ST_SCAN_L_WAIT   = 5'd12;
    localparam ST_SCAN_L_DATA   = 5'd13;
    localparam ST_SCAN_R_ADDR   = 5'd14;
    localparam ST_SCAN_R_WAIT   = 5'd15;
    localparam ST_SCAN_R_DATA   = 5'd16;
    localparam ST_NEXT          = 5'd17;
    localparam ST_SEND          = 5'd18;
    localparam ST_DONE          = 5'd19;
    localparam ST_NO_TGT        = 5'd20;

    localparam REJ_NONE         = 4'd0;
    localparam REJ_PROM         = 4'd1;
    localparam REJ_WIDTH        = 4'd2;
    localparam REJ_LIMIT        = 4'd3;
    localparam REJ_DC_EDGE      = 4'd4;

    localparam BG_TOTAL_BINS    = 2 * LOCAL_BG_REF_BINS;

    // Verilog-2001 friendly sized constants.
    // Do not use PARAM[IDX_WIDTH-1:0]; Vivado xlog will report syntax errors.
    localparam [IDX_WIDTH-1:0] FRAME_LAST_IDX          = FRAME_LENGTH - 1;
    localparam [IDX_WIDTH-1:0] LOCAL_BG_REF_BINS_IDX   = LOCAL_BG_REF_BINS;
    localparam [IDX_WIDTH-1:0] LOCAL_BG_GUARD_BINS_IDX = LOCAL_BG_GUARD_BINS;
    localparam [IDX_WIDTH-1:0] IGNORE_DC_BINS_IDX      = IGNORE_DC_BINS;
    localparam [IDX_WIDTH-1:0] DC_HIGH_START_IDX       = FRAME_LENGTH - IGNORE_DC_BINS;
    localparam [7:0] LOCAL_BG_REF_BINS_U8   = LOCAL_BG_REF_BINS;
    localparam [7:0] BG_TOTAL_BINS_U8      = BG_TOTAL_BINS;
    localparam [7:0] NARROW_MAX_BINS_U8    = NARROW_MAX_BINS;
    localparam [3:0] MAX_OUT_U4            = MAX_OUT;


    // This protects the address calculations:
    //   left background  = peak_idx - guard - ref + bg_cnt
    //   right background = peak_idx + guard + 1 + right_cnt
    //   scan             = peak_idx +/- scan_step
    // With the default parameters this rejects bins near [0..76] and [947..1023].
    // If you need to detect very close to DC/edges, implement address clamping instead.
    localparam EDGE_MARGIN_INT = LOCAL_BG_REF_BINS + LOCAL_BG_GUARD_BINS + 1;
    localparam [IDX_WIDTH-1:0] EDGE_LOW_LIMIT_IDX  = EDGE_MARGIN_INT;
    localparam [IDX_WIDTH-1:0] EDGE_HIGH_LIMIT_IDX = FRAME_LENGTH - EDGE_MARGIN_INT - 1;

    reg [4:0] state;

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mag_ram [0:FRAME_LENGTH-1];
    reg [IDX_WIDTH-1:0] mag_wr_idx;
    reg [IDX_WIDTH-1:0] ram_rd_addr;
    reg [DATA_WIDTH-1:0] ram_rd_data;

    reg [15:0] cand_mem [0:MAX_CAND-1];
    reg [15:0] out_mem  [0:MAX_OUT-1];

    reg [3:0] cand_cnt;
    reg [3:0] cand_total;
    reg [3:0] proc_idx;
    reg [3:0] accept_cnt;
    reg [3:0] send_idx;

    reg [15:0] current_cand;
    reg [IDX_WIDTH-1:0] peak_idx;
    reg [DATA_WIDTH-1:0] peak_amp;

    reg [7:0] bg_cnt;
    reg [31:0] bg_sum;
    reg [DATA_WIDTH-1:0] bg_mean;

    reg [DATA_WIDTH+8-1:0] peak_drop_mul_r;
    reg [DATA_WIDTH+9-1:0] bg_band_mul_r;
    reg [DATA_WIDTH-1:0] level_from_peak_r;
    reg [DATA_WIDTH-1:0] level_from_bg_r;

    reg [DATA_WIDTH-1:0] width_level;
    reg [7:0] width_bins;
    reg [7:0] scan_step;
    reg       reject_current;
    reg [3:0] reject_reason;

    wire capture_cand = cand_valid && (cand_cnt < MAX_CAND);
    wire [3:0] cand_cnt_next = cand_cnt + (capture_cand ? 4'd1 : 4'd0);

    // Zero-extend 8-bit counters to IDX_WIDTH.
    // The current design uses IDX_WIDTH=10. If IDX_WIDTH < 8, rewrite this part.
    wire [IDX_WIDTH-1:0] bg_cnt_ext;
    wire [IDX_WIDTH-1:0] bg_cnt_right_ext;
    wire [IDX_WIDTH-1:0] scan_step_ext;
    wire [7:0] bg_cnt_right_u8;

    assign bg_cnt_ext       = {{(IDX_WIDTH-8){1'b0}}, bg_cnt};
    assign bg_cnt_right_u8  = bg_cnt - LOCAL_BG_REF_BINS_U8;
    assign bg_cnt_right_ext = {{(IDX_WIDTH-8){1'b0}}, bg_cnt_right_u8};
    assign scan_step_ext    = {{(IDX_WIDTH-8){1'b0}}, scan_step};

    // Use extended comparison to avoid overflow when bg_mean is shifted left.
    wire [DATA_WIDTH+4-1:0] peak_amp_ext = {{4{1'b0}}, peak_amp};
    wire [DATA_WIDTH+4-1:0] bg_prom_ext  = ({{4{1'b0}}, bg_mean} << MIN_PROM_SHIFT);
    wire prom_ok = (peak_amp_ext >= bg_prom_ext);

    wire peak_in_dc_zone =
        (peak_idx < IGNORE_DC_BINS_IDX) ||
        (peak_idx >= DC_HIGH_START_IDX);

    wire peak_in_addr_edge_zone =
        (peak_idx < EDGE_LOW_LIMIT_IDX) ||
        (peak_idx > EDGE_HIGH_LIMIT_IDX);

    always @(posedge clk) begin
        // True synchronous RAM read: ram_rd_data belongs to ram_rd_addr from
        // the previous clock. Therefore every address issue state must be
        // followed by a WAIT state before the DATA state consumes ram_rd_data.
        ram_rd_data <= mag_ram[ram_rd_addr];

        if (mag_valid) begin
            mag_ram[mag_wr_idx] <= mag_data;
        end

        if (!rstn || clear_frame) begin
            state             <= ST_CAPTURE;
            mag_wr_idx         <= {IDX_WIDTH{1'b0}};
            ram_rd_addr        <= {IDX_WIDTH{1'b0}};
            cand_cnt           <= 4'd0;
            cand_total         <= 4'd0;
            proc_idx           <= 4'd0;
            accept_cnt         <= 4'd0;
            send_idx           <= 4'd0;
            current_cand       <= 16'd0;
            out_valid          <= 1'b0;
            out_user           <= 16'd0;
            out_done           <= 1'b0;
            no_target          <= 1'b0;
            peak_idx           <= {IDX_WIDTH{1'b0}};
            peak_amp           <= {DATA_WIDTH{1'b0}};
            bg_cnt             <= 8'd0;
            bg_sum             <= 32'd0;
            bg_mean            <= {DATA_WIDTH{1'b0}};
            peak_drop_mul_r    <= {(DATA_WIDTH+8){1'b0}};
            bg_band_mul_r      <= {(DATA_WIDTH+9){1'b0}};
            level_from_peak_r  <= {DATA_WIDTH{1'b0}};
            level_from_bg_r    <= {DATA_WIDTH{1'b0}};
            width_level        <= {DATA_WIDTH{1'b0}};
            width_bins         <= 8'd0;
            scan_step          <= 8'd1;
            reject_current     <= 1'b0;
            reject_reason      <= REJ_NONE;
            dbg_cand_cnt       <= 4'd0;
            dbg_accept_cnt     <= 4'd0;
            dbg_peak_idx       <= {IDX_WIDTH{1'b0}};
            dbg_peak_amp       <= {DATA_WIDTH{1'b0}};
            dbg_bg_mean        <= {DATA_WIDTH{1'b0}};
            dbg_width_bins     <= 8'd0;
            dbg_reject_reason  <= REJ_NONE;
        end
        else begin
            out_valid <= 1'b0;
            out_done  <= 1'b0;
            no_target <= 1'b0;

            if (mag_valid) begin
                if (mag_wr_idx == FRAME_LAST_IDX)
                    mag_wr_idx <= {IDX_WIDTH{1'b0}};
                else
                    mag_wr_idx <= mag_wr_idx + 1'b1;
            end

            case (state)
                ST_CAPTURE: begin
                    if (capture_cand) begin
                        cand_mem[cand_cnt] <= cand_user;
                        cand_cnt <= cand_cnt_next;
                    end

                    if (cand_last) begin
                        dbg_cand_cnt   <= cand_cnt_next;
                        dbg_accept_cnt <= 4'd0;

                        if (cand_cnt_next == 4'd0) begin
                            state <= ST_NO_TGT;
                        end
                        else begin
                            cand_total     <= cand_cnt_next;
                            proc_idx       <= 4'd0;
                            accept_cnt     <= 4'd0;
                            send_idx       <= 4'd0;
                            reject_current <= 1'b0;
                            reject_reason  <= REJ_NONE;
                            state          <= ST_LOAD_CAND;
                        end
                    end
                end

                ST_LOAD_CAND: begin
                    current_cand <= cand_mem[proc_idx];
                    peak_idx     <= cand_mem[proc_idx][IDX_WIDTH-1:0];
                    ram_rd_addr  <= cand_mem[proc_idx][IDX_WIDTH-1:0];
                    state        <= ST_READ_PEAK_W;
                end

                ST_READ_PEAK_W: begin
                    state <= ST_READ_PEAK_D;
                end

                ST_READ_PEAK_D: begin
                    peak_amp          <= ram_rd_data;
                    dbg_peak_idx      <= peak_idx;
                    dbg_peak_amp      <= ram_rd_data;
                    bg_cnt            <= 8'd0;
                    bg_sum            <= 32'd0;
                    reject_current    <= 1'b0;
                    reject_reason     <= REJ_NONE;
                    dbg_reject_reason <= REJ_NONE;
                    state             <= ST_EDGE_CHECK;
                end

                ST_EDGE_CHECK: begin
                    if (peak_in_dc_zone || peak_in_addr_edge_zone) begin
                        reject_current    <= 1'b1;
                        reject_reason     <= REJ_DC_EDGE;
                        dbg_reject_reason <= REJ_DC_EDGE;
                        width_bins        <= 8'd1;
                        bg_mean           <= {DATA_WIDTH{1'b0}};
                        dbg_bg_mean       <= {DATA_WIDTH{1'b0}};
                        state             <= ST_NEXT;
                    end
                    else begin
                        state <= ST_BG_ADDR;
                    end
                end

                ST_BG_ADDR: begin
                    if (bg_cnt < LOCAL_BG_REF_BINS_U8) begin
                        ram_rd_addr <= peak_idx
                                     - LOCAL_BG_GUARD_BINS_IDX
                                     - LOCAL_BG_REF_BINS_IDX
                                     + bg_cnt_ext;
                    end
                    else begin
                        ram_rd_addr <= peak_idx
                                     + LOCAL_BG_GUARD_BINS_IDX
                                     + {{(IDX_WIDTH-1){1'b0}},1'b1}
                                     + bg_cnt_right_ext;
                    end
                    state <= ST_BG_WAIT;
                end

                ST_BG_WAIT: begin
                    state <= ST_BG_DATA;
                end

                ST_BG_DATA: begin
                    bg_sum <= bg_sum + ram_rd_data;
                    if (bg_cnt == BG_TOTAL_BINS_U8-1'b1) begin
                        bg_mean     <= (bg_sum + ram_rd_data) >> LOCAL_BG_TOTAL_SHIFT;
                        dbg_bg_mean <= (bg_sum + ram_rd_data) >> LOCAL_BG_TOTAL_SHIFT;
                        bg_cnt      <= 8'd0;
                        state       <= ST_EVAL_PROM;
                    end
                    else begin
                        bg_cnt <= bg_cnt + 1'b1;
                        state  <= ST_BG_ADDR;
                    end
                end

                ST_EVAL_PROM: begin
                    if (!prom_ok) begin
                        reject_current    <= 1'b1;
                        reject_reason     <= REJ_PROM;
                        dbg_reject_reason <= REJ_PROM;
                        width_bins        <= 8'd1;
                        state             <= ST_NEXT;
                    end
                    else begin
                        peak_drop_mul_r <= peak_amp * PEAK_DROP_Q8;
                        bg_band_mul_r   <= bg_mean  * BAND_BG_Q8;
                        state           <= ST_CALC_LEVEL;
                    end
                end

                ST_CALC_LEVEL: begin
                    level_from_peak_r <= peak_drop_mul_r[DATA_WIDTH+8-1:8];

                    // Saturate bg*BAND_BG_Q8/256 to DATA_WIDTH bits.
                    if (bg_band_mul_r[DATA_WIDTH+9-1:DATA_WIDTH+8] != 1'b0)
                        level_from_bg_r <= {DATA_WIDTH{1'b1}};
                    else
                        level_from_bg_r <= bg_band_mul_r[DATA_WIDTH+8-1:8];

                    state <= ST_SET_LEVEL;
                end

                ST_SET_LEVEL: begin
                    width_level <= (level_from_peak_r >= level_from_bg_r) ?
                                   level_from_peak_r : level_from_bg_r;
                    width_bins  <= 8'd1;
                    scan_step   <= 8'd1;
                    state       <= ST_SCAN_L_ADDR;
                end

                ST_SCAN_L_ADDR: begin
                    ram_rd_addr <= peak_idx - scan_step_ext;
                    state       <= ST_SCAN_L_WAIT;
                end

                ST_SCAN_L_WAIT: begin
                    state <= ST_SCAN_L_DATA;
                end

                ST_SCAN_L_DATA: begin
                    if (ram_rd_data >= width_level) begin
                        if (width_bins >= NARROW_MAX_BINS_U8) begin
                            reject_current    <= 1'b1;
                            reject_reason     <= REJ_WIDTH;
                            dbg_reject_reason <= REJ_WIDTH;
                            state             <= ST_NEXT;
                        end
                        else begin
                            width_bins <= width_bins + 1'b1;
                            scan_step  <= scan_step + 1'b1;
                            state      <= ST_SCAN_L_ADDR;
                        end
                    end
                    else begin
                        scan_step <= 8'd1;
                        state     <= ST_SCAN_R_ADDR;
                    end
                end

                ST_SCAN_R_ADDR: begin
                    ram_rd_addr <= peak_idx + scan_step_ext;
                    state       <= ST_SCAN_R_WAIT;
                end

                ST_SCAN_R_WAIT: begin
                    state <= ST_SCAN_R_DATA;
                end

                ST_SCAN_R_DATA: begin
                    if (ram_rd_data >= width_level) begin
                        if (width_bins >= NARROW_MAX_BINS_U8) begin
                            reject_current    <= 1'b1;
                            reject_reason     <= REJ_WIDTH;
                            dbg_reject_reason <= REJ_WIDTH;
                            state             <= ST_NEXT;
                        end
                        else begin
                            width_bins <= width_bins + 1'b1;
                            scan_step  <= scan_step + 1'b1;
                            state      <= ST_SCAN_R_ADDR;
                        end
                    end
                    else begin
                        state <= ST_NEXT;
                    end
                end

                ST_NEXT: begin
                    dbg_width_bins <= width_bins;

                    if (!reject_current) begin
                        if (accept_cnt < MAX_OUT_U4) begin
                            out_mem[accept_cnt] <= {2'b0, accept_cnt[3:0], peak_idx[9:0]};
                            accept_cnt <= accept_cnt + 1'b1;
                            dbg_reject_reason <= REJ_NONE;
                        end
                        else begin
                            dbg_reject_reason <= REJ_LIMIT;
                        end
                    end

                    if (proc_idx == cand_total - 1'b1) begin
                        dbg_accept_cnt <= accept_cnt + ((!reject_current && (accept_cnt < MAX_OUT_U4)) ? 4'd1 : 4'd0);
                        send_idx       <= 4'd0;
                        state          <= ST_SEND;
                    end
                    else begin
                        proc_idx       <= proc_idx + 1'b1;
                        reject_current <= 1'b0;
                        reject_reason  <= REJ_NONE;
                        state          <= ST_LOAD_CAND;
                    end
                end

                ST_SEND: begin
                    if (accept_cnt == 4'd0) begin
                        state <= ST_NO_TGT;
                    end
                    else begin
                        out_user  <= out_mem[send_idx];
                        out_valid <= 1'b1;
                        if (send_idx == accept_cnt - 1'b1) begin
                            send_idx <= 4'd0;
                            state    <= ST_DONE;
                        end
                        else begin
                            send_idx <= send_idx + 1'b1;
                        end
                    end
                end

                ST_DONE: begin
                    out_done   <= 1'b1;
                    cand_cnt   <= 4'd0;
                    cand_total <= 4'd0;
                    proc_idx   <= 4'd0;
                    accept_cnt <= 4'd0;
                    state      <= ST_CAPTURE;
                end

                ST_NO_TGT: begin
                    no_target  <= 1'b1;
                    cand_cnt   <= 4'd0;
                    cand_total <= 4'd0;
                    proc_idx   <= 4'd0;
                    accept_cnt <= 4'd0;
                    state      <= ST_CAPTURE;
                end

                default: begin
                    state <= ST_CAPTURE;
                end
            endcase
        end
    end

endmodule

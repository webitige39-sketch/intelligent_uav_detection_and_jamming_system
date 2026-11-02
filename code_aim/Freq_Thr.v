`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Freq_Thr.v -- CFAR + traces_condense debug version, no narrow_candidate_gate.
//
// Purpose of this version:
//   1) Verify complex_abs -> CA-CFAR -> traces_condense correctness first.
//   2) Do not instantiate narrow_candidate_gate.
//   3) Export all important CFAR / condense debug signals to AIM_ila_200M.
//
// Output policy in this debug version:
//   - F_user updates only when traces_condense outputs a candidate.
//   - Freq_Thr_over pulses at candidate-stream tlast only if this frame has at
//     least one condensed candidate.
//   - FIND_UAV pulses at candidate-stream tlast if this frame has no candidate.
//////////////////////////////////////////////////////////////////////////////////

module Freq_Thr #(
    parameter DATA_WIDTH   = 32,
    parameter FRAME_LENGTH = 1024
)(
    input                            s_axis_aclk,
    input                            s_axis_aresetn,
    input      [DATA_WIDTH-1 : 0]    s_axis_tdata,
    input                            s_axis_tvalid,
    input                            s_axis_tlast,
    input      [15 : 0]              s_axis_tuser,
    input                            FIND_EN_AIM,

    output                           tr_m_axis_tvalid,
    output                           Freq_Thr_over_toggle,
    output                           FIND_UAV_toggle,
    output reg                       FIND_UAV,
    output reg [15:0]                F_user,
    output reg                       Freq_Thr_over,

    // Debug: magnitude stream
    output     [15:0]                dbg_data_abs,
    output                           dbg_data_abs_valid,
    output                           dbg_data_abs_last,

    // Debug: raw CFAR stream
    output     [15:0]                dbg_cfar_raw_idx,
    output     [15:0]                dbg_cfar_cut_amp,
    output                           dbg_cfar_hit,
    output                           dbg_cfar_valid,
    output                           dbg_cfar_last,

    // Debug: traces_condense candidate stream
    output     [15:0]                dbg_condense_peak_idx,
    output     [15:0]                dbg_condense_peak_amp,
    output                           dbg_condense_hit,
    output                           dbg_condense_valid,
    output                           dbg_condense_last,
    output     [15:0]                dbg_condense_user,
    output                           dbg_frame_has_candidate
);

    localparam DW = DATA_WIDTH;

    wire [15:0] data_abs_2;
    wire        data_abs_valid_2;
    wire        data_abs_last;

    complex_abs #(
        .DW        (DW/2),
        .HAS_TLAST (1)
    ) u_complex_abs_cfar (
        .s_axis_aclk     (s_axis_aclk),
        .s_axis_aresetn  (s_axis_aresetn),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tlast    (s_axis_tlast),

        .m_axis_tdata    (data_abs_2),
        .m_axis_tvalid   (data_abs_valid_2),
        .m_axis_tlast    (data_abs_last)
    );

    wire [15:0] cfar_condense_user;
    wire        cfar_condense_tdata;
    wire        cfar_condense_tlast;
    wire        cfar_condense_valid_pass;

    top_cfar #(
        .DATA_WIDTH     (16),
        .FRAME_LENGTH   (FRAME_LENGTH),
        .PLUSE_NUM      (2),
        .SUM_NUM        (36),
        .CFAR_PROT_LEN  (16),
        .CFAR_REF_LEN   (32),
        .CFAR_K         (8'd6),
        .HIT_GAP_MAX    (3),
        .DC_REJECT_BINS (8),
        .SPUR_REJECT_EN  (0),
        .SPUR_REJECT_LOW (0),
        .SPUR_REJECT_HIGH(0)
    ) fft_cfar (
        .m_axis_aclk           (s_axis_aclk),
        .s_axis_aresetn        (s_axis_aresetn),
        .s_axis_tdata          (data_abs_2),
        .s_axis_tvalid         (data_abs_valid_2),

        .tr_m_axis_user        (cfar_condense_user),
        .tr_m_axis_tvalid      (cfar_condense_valid_pass),
        .tr_m_axis_tdata       (cfar_condense_tdata),
        .tr_m_axis_tlast       (cfar_condense_tlast),

        .dbg_cfar_raw_idx      (dbg_cfar_raw_idx),
        .dbg_cfar_cut_amp      (dbg_cfar_cut_amp),
        .dbg_cfar_hit          (dbg_cfar_hit),
        .dbg_cfar_valid        (dbg_cfar_valid),
        .dbg_cfar_last         (dbg_cfar_last),

        .dbg_condense_peak_idx (dbg_condense_peak_idx),
        .dbg_condense_peak_amp (dbg_condense_peak_amp),
        .dbg_condense_hit      (dbg_condense_hit),
        .dbg_condense_valid    (dbg_condense_valid),
        .dbg_condense_last     (dbg_condense_last),
        .dbg_target_cnt        ()
    );


    // Final safety filter. Even though top_cfar already filters DC candidates,
    // keep one more guard here so F_user/FIFO can never see bin 0-neighbour data.
    localparam [9:0] DC_REJECT_BINS_10 = 10'd8;
    localparam [9:0] DC_HIGH_START_10  = FRAME_LENGTH[9:0] - DC_REJECT_BINS_10;
    wire [9:0] cfar_user_bin = cfar_condense_user[9:0];
    wire cfar_user_is_dc = (cfar_user_bin < DC_REJECT_BINS_10) ||
                           (cfar_user_bin >= DC_HIGH_START_10);

    assign tr_m_axis_tvalid = cfar_condense_valid_pass && !cfar_user_is_dc;

    reg frame_has_candidate_r;

    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn || FIND_EN_AIM) begin
            F_user <= 16'd0;
        end
        else if (tr_m_axis_tvalid) begin
            // Only non-DC candidates can assert tr_m_axis_tvalid.
            F_user <= cfar_condense_user;
        end
        else if (cfar_condense_valid_pass && cfar_user_is_dc) begin
            // A rejected DC candidate appeared. Clear the bus immediately so ILA
            // and downstream logic never see F_user=1 as a valid-looking value.
            F_user <= 16'd0;
        end
        else if (cfar_condense_tlast &&
                 !(frame_has_candidate_r || tr_m_axis_tvalid)) begin
            // Avoid displaying/sending a stale frequency after a DC-only frame.
            F_user <= 16'd0;
        end
        else begin
            F_user <= F_user;
        end
    end

    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn || FIND_EN_AIM) begin
            frame_has_candidate_r <= 1'b0;
        end
        else if (tr_m_axis_tvalid) begin
            frame_has_candidate_r <= 1'b1;
        end
        else if (cfar_condense_tlast) begin
            frame_has_candidate_r <= 1'b0;
        end
        else begin
            frame_has_candidate_r <= frame_has_candidate_r;
        end
    end

    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            Freq_Thr_over <= 1'b0;
        end
        else begin
            Freq_Thr_over <= cfar_condense_tlast &&
                             (frame_has_candidate_r || tr_m_axis_tvalid);
        end
    end

    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            FIND_UAV <= 1'b0;
        end
        else begin
            FIND_UAV <= cfar_condense_tlast &&
                        !(frame_has_candidate_r || tr_m_axis_tvalid);
        end
    end

    reg Freq_Thr_over_toggle_r;
    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            Freq_Thr_over_toggle_r <= 1'b0;
        end
        else if (Freq_Thr_over) begin
            Freq_Thr_over_toggle_r <= ~Freq_Thr_over_toggle_r;
        end
    end
    assign Freq_Thr_over_toggle = Freq_Thr_over_toggle_r;

    reg FIND_UAV_toggle_r;
    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            FIND_UAV_toggle_r <= 1'b0;
        end
        else if (FIND_UAV) begin
            FIND_UAV_toggle_r <= ~FIND_UAV_toggle_r;
        end
    end
    assign FIND_UAV_toggle = FIND_UAV_toggle_r;

    assign dbg_data_abs            = data_abs_2;
    assign dbg_data_abs_valid      = data_abs_valid_2;
    assign dbg_data_abs_last       = data_abs_last;
    assign dbg_condense_user       = cfar_condense_user;
    assign dbg_frame_has_candidate = frame_has_candidate_r;

endmodule

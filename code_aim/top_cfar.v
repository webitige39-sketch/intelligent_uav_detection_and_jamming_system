`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// top_cfar.v -- CFAR + hit condenser, debug-visible version.
//
// This version intentionally does NOT instantiate narrow_candidate_gate.
// It only verifies:
//   1) serial CA-CFAR raw hit stream
//   2) traces_condense candidate peak output
//////////////////////////////////////////////////////////////////////////////////

module top_cfar #(
    parameter DATA_WIDTH       = 16,
    parameter FRAME_LENGTH     = 1024,
    parameter PLUSE_NUM        = 2,
    parameter SUM_NUM          = 36,
    parameter CFAR_PROT_LEN    = 16,
    parameter CFAR_REF_LEN     = 32,
    parameter CFAR_K           = 8'd6,
    parameter HIT_GAP_MAX      = 3,
    // Natural-order FFT: DC is around bin 0 and wraps to the high end.
    // DC_REJECT_BINS=4 rejects bins 0..3 and 1020..1023 for a 1024-point FFT.
    parameter DC_REJECT_BINS   = 8,
    // Optional extra notch for a measured fixed spur/LO leakage bin range.
    // Disabled when SPUR_REJECT_EN=0. Range is inclusive.
    parameter SPUR_REJECT_EN  = 0,
    parameter SPUR_REJECT_LOW = 0,
    parameter SPUR_REJECT_HIGH= 0
)(
    input                               m_axis_aclk,
    input                               s_axis_aresetn,
    input              [DATA_WIDTH-1:0] s_axis_tdata,
    input                               s_axis_tvalid,

    output             [15:0]           tr_m_axis_user,
    output                              tr_m_axis_tvalid,
    output                              tr_m_axis_tdata,
    output                              tr_m_axis_tlast,

    // Debug: raw CFAR stream
    output             [15:0]           dbg_cfar_raw_idx,
    output             [15:0]           dbg_cfar_cut_amp,
    output                              dbg_cfar_hit,
    output                              dbg_cfar_valid,
    output                              dbg_cfar_last,

    // Debug: condensed candidate stream
    output             [15:0]           dbg_condense_peak_idx,
    output             [15:0]           dbg_condense_peak_amp,
    output                              dbg_condense_hit,
    output                              dbg_condense_valid,
    output                              dbg_condense_last,
    output             [3:0]            dbg_target_cnt
);

    localparam DW = DATA_WIDTH;
    localparam PER_CFAR_CHAN_NUM = 1;

    wire        s_axis_tready;
    wire        sc_m_axis_tdata;
    wire [DW-1:0] sc_m_axis_tuser;
    wire [17:0] sc_m_axis_user_dpl_idx;
    wire        sc_m_axis_tvalid;
    wire        sc_m_axis_tlast;

    serial_cfar_2048 #(
        .DW                 (DW),
        .PN                 (PER_CFAR_CHAN_NUM),
        .PROT_UNIT_LENGTH   (CFAR_PROT_LEN),
        .REF_UNIT_LENGTH    (CFAR_REF_LEN),
        .FRAME_LEN          (FRAME_LENGTH),
        .BASE_CHAN_IDX      (PER_CFAR_CHAN_NUM),
        .K_WIDTH            (8)
    ) serial_cfar_1024_inst (
        .s_axis_aclk         (m_axis_aclk),
        .s_axis_aresetn      (s_axis_aresetn),
        .s_axis_tdata        (s_axis_tdata),
        .s_axis_tvalid       (s_axis_tvalid),
        .s_axis_tstart       (1'b0),
        .s_axis_tlast        (1'b0),
        .s_axis_tready       (s_axis_tready),
        .s_axis_user_k       (CFAR_K),

        .m_axis_tdata        (sc_m_axis_tdata),
        .m_axis_tuser        (sc_m_axis_tuser),
        .m_axis_user_dpl_idx (sc_m_axis_user_dpl_idx),
        .m_axis_user_dst_idx (),
        .m_axis_tvalid       (sc_m_axis_tvalid),
        .m_axis_tlast        (sc_m_axis_tlast)
    );

    wire [15:0] sc_raw_idx16 = sc_m_axis_user_dpl_idx[15:0];
    wire [32:0] cfar_data    = {sc_raw_idx16, sc_m_axis_tuser, sc_m_axis_tdata};

    wire [15:0] condense_peak_idx;
    wire [15:0] condense_peak_amp;
    wire        condense_tdata_raw;
    wire        condense_valid_raw;
    wire        condense_last_raw;

    localparam [15:0] DC_LOW_END_EXCL = DC_REJECT_BINS;
    localparam [15:0] DC_HIGH_START   = FRAME_LENGTH - DC_REJECT_BINS;

    wire condense_is_dc_edge = (condense_peak_idx < DC_LOW_END_EXCL) ||
                               (condense_peak_idx >= DC_HIGH_START);

    wire condense_is_spur = (SPUR_REJECT_EN != 0) &&
                            (condense_peak_idx >= SPUR_REJECT_LOW[15:0]) &&
                            (condense_peak_idx <= SPUR_REJECT_HIGH[15:0]);

    // Reject DC / fixed spur candidates. Keep raw condenser outputs visible
    // on debug probes, but only forward passed candidates to Freq_Thr.
    wire condense_reject = condense_is_dc_edge || condense_is_spur;
    wire condense_pass   = condense_valid_raw && !condense_reject;

    traces_condense #(
        .DW                (DW),
        .PROT_UNIT_LENGTH  (CFAR_PROT_LEN),
        .REF_UNIT_LENGTH   (CFAR_REF_LEN),
        .HIT_GAP_MAX       (HIT_GAP_MAX),
        .PN                (1),
        .IDW               (33),
        .ODW               (16)
    ) u_traces_condense (
        .s_axis_aclk         (m_axis_aclk),
        .s_axis_aresetn      (s_axis_aresetn),
        .s_axis_tdata        (cfar_data),
        .s_axis_tvalid       (sc_m_axis_tvalid),
        .s_axis_tstart       (1'b0),
        .s_axis_tlast        (sc_m_axis_tlast),
        .s_axis_tready       (),

        .m_axis_tdata        (condense_tdata_raw),
        .m_axis_tuser        (condense_peak_amp),
        .m_axis_user_dpl_idx (condense_peak_idx),
        .m_axis_user_dst_idx (),
        .m_axis_tvalid       (condense_valid_raw),
        .m_axis_tlast        (condense_last_raw)
    );

    assign tr_m_axis_tvalid = condense_pass;
    assign tr_m_axis_tdata  = condense_tdata_raw && condense_pass;
    assign tr_m_axis_tlast  = condense_last_raw;

    reg [3:0] cnt_freq;

    always @(posedge m_axis_aclk) begin
        if (!s_axis_aresetn || tr_m_axis_tlast) begin
            cnt_freq <= 4'd0;
        end
        else if (tr_m_axis_tvalid) begin
            cnt_freq <= cnt_freq + 1'b1;
        end
        else begin
            cnt_freq <= cnt_freq;
        end
    end

    // IMPORTANT: do not leave a rejected DC candidate on the user bus.
    // This makes ILA reading unambiguous and gives Freq_Thr a second safety layer.
    assign tr_m_axis_user = condense_pass ? {2'b0, cnt_freq, condense_peak_idx[9:0]}
                                          : 16'd0;

    assign dbg_cfar_raw_idx      = sc_raw_idx16;
    assign dbg_cfar_cut_amp      = sc_m_axis_tuser;
    assign dbg_cfar_hit          = sc_m_axis_tdata;
    assign dbg_cfar_valid        = sc_m_axis_tvalid;
    assign dbg_cfar_last         = sc_m_axis_tlast;

    assign dbg_condense_peak_idx = condense_peak_idx;
    assign dbg_condense_peak_amp = condense_peak_amp;
    // Raw condenser debug remains unfiltered, so the ILA can prove that a
    // bin-1 DC candidate was detected and then intentionally blocked.
    assign dbg_condense_hit      = condense_tdata_raw;
    assign dbg_condense_valid    = condense_valid_raw;
    assign dbg_condense_last     = condense_last_raw;
    assign dbg_target_cnt        = cnt_freq;

endmodule

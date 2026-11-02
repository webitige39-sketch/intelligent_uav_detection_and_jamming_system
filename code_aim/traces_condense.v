`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CFAR hit condenser.
//
// Function:
//   Convert raw per-bin CFAR hits into candidate peaks.
//   This module does NOT decide wideband/narrowband.
//
// Input s_axis_tdata format from top_cfar:
//   [32:17] = raw CFAR bin index
//   [16:1]  = CFAR CUT magnitude
//   [0]     = CFAR hit bit
//
// Output:
//   m_axis_tvalid       : one-cycle candidate valid pulse
//   m_axis_tdata        : candidate hit bit, always 1 when valid
//   m_axis_tuser        : candidate peak amplitude
//   m_axis_user_dpl_idx : corrected candidate peak FFT bin index
//   m_axis_tlast        : candidate stream frame end. If the last candidate is
//                         emitted at frame end, tlast is delayed by one cycle.
//////////////////////////////////////////////////////////////////////////////////

module traces_condense #(
    parameter DW                = 16,
    parameter PN                = 1,
    parameter PROT_UNIT_LENGTH  = 16,
    parameter REF_UNIT_LENGTH   = 32,
    parameter HIT_GAP_MAX       = 3,
    parameter IDW               = 33,
    parameter ODW               = 16
)(
    input                 s_axis_aclk,
    input                 s_axis_aresetn,
    input     [IDW-1:0]   s_axis_tdata,
    input                 s_axis_tvalid,
    input                 s_axis_tstart,
    input                 s_axis_tlast,

    output  reg           s_axis_tready,
    output  reg           m_axis_tdata,
    output  reg [ODW-1:0] m_axis_tuser,
    output  reg [15:0]    m_axis_user_dpl_idx,
    output  reg [15:0]    m_axis_user_dst_idx,
    output  reg           m_axis_tvalid,
    output  reg           m_axis_tlast
);

    localparam [15:0] CFAR_IDX_OFFSET = PROT_UNIT_LENGTH + REF_UNIT_LENGTH;

    wire        in_hit   = s_axis_tvalid && s_axis_tdata[0];
    wire [15:0] raw_idx  = s_axis_tdata[32:17];
    wire [15:0] hit_amp  = s_axis_tdata[16:1];
    wire [15:0] corr_idx = (raw_idx > CFAR_IDX_OFFSET) ?
                           (raw_idx - CFAR_IDX_OFFSET) : 16'd0;

    reg        in_cluster;
    reg [15:0] max_idx;
    reg [15:0] max_amp;
    reg [15:0] hit_count;
    reg [7:0]  gap_count;
    reg        pending_tlast;

    task emit_candidate;
        input [15:0] idx;
        input [15:0] amp;
        begin
            m_axis_tdata        <= 1'b1;
            m_axis_tuser        <= amp;
            m_axis_user_dpl_idx <= idx;
            m_axis_user_dst_idx <= 16'd0;
            m_axis_tvalid       <= 1'b1;
        end
    endtask

    wire [15:0] tlast_emit_idx = (!in_cluster) ? corr_idx :
                                 ((hit_amp >= max_amp) ? corr_idx : max_idx);
    wire [15:0] tlast_emit_amp = (!in_cluster) ? hit_amp :
                                 ((hit_amp >= max_amp) ? hit_amp : max_amp);

    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) begin
            s_axis_tready       <= 1'b1;
            m_axis_tdata        <= 1'b0;
            m_axis_tuser        <= {ODW{1'b0}};
            m_axis_user_dpl_idx <= 16'd0;
            m_axis_user_dst_idx <= 16'd0;
            m_axis_tvalid       <= 1'b0;
            m_axis_tlast        <= 1'b0;
            in_cluster          <= 1'b0;
            max_idx             <= 16'd0;
            max_amp             <= 16'd0;
            hit_count           <= 16'd0;
            gap_count           <= 8'd0;
            pending_tlast       <= 1'b0;
        end
        else begin
            s_axis_tready <= 1'b1;
            m_axis_tdata  <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;

            if (pending_tlast) begin
                m_axis_tlast  <= 1'b1;
                pending_tlast <= 1'b0;
            end
            else if (s_axis_tstart) begin
                in_cluster    <= 1'b0;
                max_idx       <= 16'd0;
                max_amp       <= 16'd0;
                hit_count     <= 16'd0;
                gap_count     <= 8'd0;
                pending_tlast <= 1'b0;
            end
            else if (s_axis_tlast) begin
                // Robust handling for either style:
                // 1) tlast is a separate end pulse, or
                // 2) tlast is asserted together with the final valid data.
                if (in_hit) begin
                    emit_candidate(tlast_emit_idx, tlast_emit_amp);
                    in_cluster    <= 1'b0;
                    hit_count     <= 16'd0;
                    gap_count     <= 8'd0;
                    pending_tlast <= 1'b1;
                end
                else if (in_cluster) begin
                    emit_candidate(max_idx, max_amp);
                    in_cluster    <= 1'b0;
                    hit_count     <= 16'd0;
                    gap_count     <= 8'd0;
                    pending_tlast <= 1'b1;
                end
                else begin
                    m_axis_tlast <= 1'b1;
                end
            end
            else if (in_hit) begin
                if (!in_cluster) begin
                    in_cluster <= 1'b1;
                    max_idx    <= corr_idx;
                    max_amp    <= hit_amp;
                    hit_count  <= 16'd1;
                    gap_count  <= 8'd0;
                end
                else begin
                    if (hit_amp >= max_amp) begin
                        max_amp <= hit_amp;
                        max_idx <= corr_idx;
                    end
                    hit_count <= hit_count + 1'b1;
                    gap_count <= 8'd0;
                end
            end
            else if (s_axis_tvalid && in_cluster) begin
                if (gap_count >= HIT_GAP_MAX) begin
                    emit_candidate(max_idx, max_amp);
                    in_cluster <= 1'b0;
                    hit_count  <= 16'd0;
                    gap_count  <= 8'd0;
                end
                else begin
                    gap_count <= gap_count + 1'b1;
                end
            end
        end
    end

endmodule

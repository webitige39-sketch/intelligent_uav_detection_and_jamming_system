`timescale 1ns / 1ps
/*
    RAM_data CDC fixed version

    Function:
    1. Write FRAME_LENGTH IQ samples into dual-port RAM in s_axis_aclk domain.
    2. After the last sample is actually written, generate wr_done_toggle.
    3. Synchronize wr_done_toggle into data_clk domain using a 3-FF synchronizer.
    4. Start RAM read in data_clk domain after detecting the synchronized toggle edge.

    Important CDC fix:
    The read clock domain no longer directly samples addra.
*/

module RAM_data#(
    parameter DATA_WIDTH          = 32,
    parameter FRAME_LENGTH        = 1024
)(
    input                         s_axis_aclk,
    input                         data_clk,
    input                         s_axis_aresetn,
    input  [DATA_WIDTH-1:0]       s_axis_tdata,
    input                         s_axis_tvalid,
    input                         s_axis_tstart,
    input                         s_axis_tlast,

    output                        WEA,
    output [10:0]                 ADDRA,
    output                        REA,
    output [10:0]                 ADDRB,
    output                        DATA_LABEL,

    output [DATA_WIDTH-1:0]       m_axis_tdata,
    output reg                    m_axis_tvalid,
    output reg                    m_axis_tlast
);

// -----------------------------------------------------------------------------
// Local parameters
// -----------------------------------------------------------------------------
// Current project uses 1024-point FFT, so RAM address width is 10 bits.
// ADDRA/ADDRB ports remain 11 bits to keep the external debug interface unchanged.
localparam ADDR_WIDTH = 10;
localparam [ADDR_WIDTH-1:0] LAST_ADDR = FRAME_LENGTH - 1;

// -----------------------------------------------------------------------------
// Reset synchronization: asynchronous assert, synchronous release
// -----------------------------------------------------------------------------
reg [1:0] wr_rstn_sync;
reg [1:0] rd_rstn_sync;

always @(posedge s_axis_aclk or negedge s_axis_aresetn) begin
    if (!s_axis_aresetn)
        wr_rstn_sync <= 2'b00;
    else
        wr_rstn_sync <= {wr_rstn_sync[0], 1'b1};
end

always @(posedge data_clk or negedge s_axis_aresetn) begin
    if (!s_axis_aresetn)
        rd_rstn_sync <= 2'b00;
    else
        rd_rstn_sync <= {rd_rstn_sync[0], 1'b1};
end

wire wr_rstn = wr_rstn_sync[1];
wire rd_rstn = rd_rstn_sync[1];

// -----------------------------------------------------------------------------
// Write clock domain: s_axis_aclk
// -----------------------------------------------------------------------------
reg                  data_label;
reg                  wea;
reg [ADDR_WIDTH-1:0] addra;
reg                  wr_done_toggle;

assign WEA        = wea;
assign ADDRA      = {1'b0, addra};
assign DATA_LABEL = data_label;

// data_label marks the capture window between start and last.
always @(posedge s_axis_aclk) begin
    if (!wr_rstn)
        data_label <= 1'b0;
    else if (s_axis_tstart)
        data_label <= 1'b1;
    else if (s_axis_tlast)
        data_label <= 1'b0;
    else
        data_label <= data_label;
end

// Write enable. Keep the original behavior: write during data_label window.
// s_axis_tvalid is added to avoid writing invalid samples if upstream later uses it.
always @(posedge s_axis_aclk) begin
    if (!wr_rstn)
        wea <= 1'b0;
    else
        wea <= data_label && s_axis_tvalid;
end

// Write address. The address advances only on actual BRAM write cycles.
always @(posedge s_axis_aclk) begin
    if (!wr_rstn)
        addra <= {ADDR_WIDTH{1'b0}};
    else if (wea) begin
        if (addra == LAST_ADDR)
            addra <= {ADDR_WIDTH{1'b0}};
        else
            addra <= addra + 1'b1;
    end
    else
        addra <= {ADDR_WIDTH{1'b0}};
end

// Generate a frame-done toggle only after the last address is actually written.
// This is the only signal that crosses from s_axis_aclk to data_clk.
always @(posedge s_axis_aclk) begin
    if (!wr_rstn)
        wr_done_toggle <= 1'b0;
    else if (wea && (addra == LAST_ADDR))
        wr_done_toggle <= ~wr_done_toggle;
    else
        wr_done_toggle <= wr_done_toggle;
end

// -----------------------------------------------------------------------------
// Read clock domain CDC: synchronize wr_done_toggle into data_clk domain
// -----------------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg wr_done_meta;
(* ASYNC_REG = "TRUE" *) reg wr_done_sync1;
(* ASYNC_REG = "TRUE" *) reg wr_done_sync2;
reg wr_done_sync2_d;

always @(posedge data_clk) begin
    if (!rd_rstn) begin
        wr_done_meta    <= 1'b0;
        wr_done_sync1   <= 1'b0;
        wr_done_sync2   <= 1'b0;
        wr_done_sync2_d <= 1'b0;
    end
    else begin
        wr_done_meta    <= wr_done_toggle;
        wr_done_sync1   <= wr_done_meta;
        wr_done_sync2   <= wr_done_sync1;
        wr_done_sync2_d <= wr_done_sync2;
    end
end

wire wr_done_event = wr_done_sync2 ^ wr_done_sync2_d;

// -----------------------------------------------------------------------------
// Read clock domain: data_clk
// -----------------------------------------------------------------------------
reg                  rea;
reg [ADDR_WIDTH-1:0] addrb;
reg                  rd_pending;

assign REA   = rea;
assign ADDRB = {1'b0, addrb};

// Keep one pending read request. This prevents losing one frame-done event if it
// arrives while a read is already in progress. In the current design, read is
// much faster than write, so one pending bit is sufficient.
always @(posedge data_clk) begin
    if (!rd_rstn)
        rd_pending <= 1'b0;
    else if (wr_done_event)
        rd_pending <= 1'b1;
    else if (!rea && rd_pending)
        rd_pending <= 1'b0;
    else
        rd_pending <= rd_pending;
end

// Read enable and read address. The read domain no longer looks at addra.
always @(posedge data_clk) begin
    if (!rd_rstn) begin
        rea   <= 1'b0;
        addrb <= {ADDR_WIDTH{1'b0}};
    end
    else begin
        if (!rea && rd_pending) begin
            rea   <= 1'b1;
            addrb <= {ADDR_WIDTH{1'b0}};
        end
        else if (rea) begin
            if (addrb == LAST_ADDR) begin
                rea   <= 1'b0;
                addrb <= {ADDR_WIDTH{1'b0}};
            end
            else begin
                rea   <= 1'b1;
                addrb <= addrb + 1'b1;
            end
        end
        else begin
            rea   <= 1'b0;
            addrb <= {ADDR_WIDTH{1'b0}};
        end
    end
end

// -----------------------------------------------------------------------------
// Dual-port RAM
// -----------------------------------------------------------------------------
blk_mem_gen_0 ram_data (
    .clka   (s_axis_aclk),
    .wea    (wea),
    .addra  (addra),
    .dina   (s_axis_tdata),

    .enb    (rea),
    .clkb   (data_clk),
    .addrb  (addrb),
    .doutb  (m_axis_tdata)
);

// -----------------------------------------------------------------------------
// Output valid/last in data_clk domain
// -----------------------------------------------------------------------------
// This keeps the original assumption: blk_mem_gen_0 read latency is 1 clock.
// If your BRAM IP enables an extra output register, delay these by one more cycle.
always @(posedge data_clk) begin
    if (!rd_rstn)
        m_axis_tvalid <= 1'b0;
    else
        m_axis_tvalid <= rea;
end

always @(posedge data_clk) begin
    if (!rd_rstn)
        m_axis_tlast <= 1'b0;
    else
        m_axis_tlast <= rea && (addrb == LAST_ADDR);
end

endmodule

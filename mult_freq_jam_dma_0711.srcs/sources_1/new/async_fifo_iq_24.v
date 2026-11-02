`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/23 14:48:29
// Design Name: 
// Module Name: async_fifo_iq_24
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

// ==============================================================
// Simple asynchronous FIFO for I/Q pair, DATA_WIDTH=24 by default
// High 12 bits: Q, Low 12 bits: I
// ============================================================== 
module async_fifo_iq_24 #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 10
)(
    input                       rst,
    input                       wr_clk,
    input                       rd_clk,
    input      [DATA_WIDTH-1:0] din,
    input                       wr_en,
    input                       rd_en,
    output reg [DATA_WIDTH-1:0] dout,
    output                      full,
    output                      empty,
    output     [9:0]            rd_data_count
);

localparam DEPTH = (1 << ADDR_WIDTH);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

reg [ADDR_WIDTH:0] wr_ptr_bin  = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_bin  = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray = {ADDR_WIDTH+1{1'b0}};

reg [ADDR_WIDTH:0] rd_ptr_gray_w1 = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_w2 = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_r1 = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_r2 = {ADDR_WIDTH+1{1'b0}};

function [ADDR_WIDTH:0] bin2gray;
    input [ADDR_WIDTH:0] bin;
    begin
        bin2gray = (bin >> 1) ^ bin;
    end
endfunction

function [ADDR_WIDTH:0] gray2bin;
    input [ADDR_WIDTH:0] gray;
    integer i;
    begin
        gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
            gray2bin[i] = gray2bin[i+1] ^ gray[i];
    end
endfunction

wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + ((wr_en && !full) ? 1'b1 : 1'b0);
wire [ADDR_WIDTH:0] wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);

wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + ((rd_en && !empty) ? 1'b1 : 1'b0);
wire [ADDR_WIDTH:0] rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

assign full = (wr_ptr_gray_next == {~rd_ptr_gray_w2[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_w2[ADDR_WIDTH-2:0]});
assign empty = (rd_ptr_gray == wr_ptr_gray_r2);

always @(posedge wr_clk) begin
    if(rst) begin
        wr_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
    end
    else begin
        if(wr_en && !full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;
        wr_ptr_bin  <= wr_ptr_bin_next;
        wr_ptr_gray <= wr_ptr_gray_next;
    end
end

always @(posedge rd_clk) begin
    if(rst) begin
        rd_ptr_bin  <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray <= {ADDR_WIDTH+1{1'b0}};
        dout        <= {DATA_WIDTH{1'b0}};
    end
    else begin
        if(rd_en && !empty)
            dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        rd_ptr_bin  <= rd_ptr_bin_next;
        rd_ptr_gray <= rd_ptr_gray_next;
    end
end

// pointer synchronizers
always @(posedge wr_clk) begin
    if(rst) begin
        rd_ptr_gray_w1 <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_w2 <= {ADDR_WIDTH+1{1'b0}};
    end
    else begin
        rd_ptr_gray_w1 <= rd_ptr_gray;
        rd_ptr_gray_w2 <= rd_ptr_gray_w1;
    end
end

always @(posedge rd_clk) begin
    if(rst) begin
        wr_ptr_gray_r1 <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_r2 <= {ADDR_WIDTH+1{1'b0}};
    end
    else begin
        wr_ptr_gray_r1 <= wr_ptr_gray;
        wr_ptr_gray_r2 <= wr_ptr_gray_r1;
    end
end

wire [ADDR_WIDTH:0] wr_ptr_bin_rd = gray2bin(wr_ptr_gray_r2);
wire [ADDR_WIDTH:0] rd_count_full = wr_ptr_bin_rd - rd_ptr_bin;
assign rd_data_count = (rd_count_full[ADDR_WIDTH]) ? 10'd1023 : rd_count_full[9:0];

endmodule

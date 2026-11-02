`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/06/15 14:14:28
// Design Name: 
// Module Name: iq_dc_block_iir
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

module iq_dc_block_iir #(
    parameter IN_WIDTH = 12,
    parameter DC_WIDTH = 28,
    parameter FRAC     = 8,
    parameter K        = 8
)(
    input                              clk,
    input                              rstn,
    input                              valid_in,
    input  signed [IN_WIDTH-1:0]       i_in,
    input  signed [IN_WIDTH-1:0]       q_in,
    output                             valid_out,
    output signed [IN_WIDTH-1:0]       i_out,
    output signed [IN_WIDTH-1:0]       q_out
);

    wire valid_i;
    wire valid_q;

    dc_block_iir_signed #(
        .IN_WIDTH (IN_WIDTH),
        .DC_WIDTH (DC_WIDTH),
        .FRAC     (FRAC),
        .K        (K)
    ) u_i_dc_block (
        .clk       (clk),
        .rstn      (rstn),
        .valid_in  (valid_in),
        .x_in      (i_in),
        .valid_out (valid_i),
        .y_out     (i_out)
    );

    dc_block_iir_signed #(
        .IN_WIDTH (IN_WIDTH),
        .DC_WIDTH (DC_WIDTH),
        .FRAC     (FRAC),
        .K        (K)
    ) u_q_dc_block (
        .clk       (clk),
        .rstn      (rstn),
        .valid_in  (valid_in),
        .x_in      (q_in),
        .valid_out (valid_q),
        .y_out     (q_out)
    );

    assign valid_out = valid_i & valid_q;

endmodule



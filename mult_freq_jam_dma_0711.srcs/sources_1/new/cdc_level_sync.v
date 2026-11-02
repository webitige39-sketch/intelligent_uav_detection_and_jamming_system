`timescale 1ns / 1ps

module cdc_level_sync #(
    parameter integer WIDTH = 1
)(
    input  wire             src_clk,
    input  wire             dst_clk,
    input  wire             dst_rstn,
    input  wire [WIDTH-1:0] async_in,
    output wire [WIDTH-1:0] sync_out
);
    wire [WIDTH-1:0] xpm_sync_out;
    xpm_cdc_array_single #(
        .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0),
        .SRC_INPUT_REG(0), .WIDTH(WIDTH)
    ) u_xpm_cdc_array_single (
        .src_clk(src_clk), .src_in(async_in),
        .dest_clk(dst_clk), .dest_out(xpm_sync_out)
    );
    assign sync_out = dst_rstn ? xpm_sync_out : {WIDTH{1'b0}};
endmodule

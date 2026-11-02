`timescale 1ns / 1ps

// Transfers a GPIO configuration bundle after the source toggles update.
module cdc_bus_update #(
    parameter integer WIDTH = 32
)(
    input  wire             src_clk,
    input  wire             src_rstn,
    input  wire [WIDTH-1:0] src_bus,
    input  wire             src_update_toggle,
    input  wire             dst_clk,
    input  wire             dst_rstn,
    output reg  [WIDTH-1:0] dst_bus,
    output reg              dst_update_pulse
);
    wire [WIDTH-1:0] bus_sync;
    wire toggle_sync;

    xpm_cdc_array_single #(
        .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0),
        .SRC_INPUT_REG(0), .WIDTH(WIDTH)
    ) u_bus_sync (
        .src_clk(src_clk), .src_in(src_bus), .dest_clk(dst_clk), .dest_out(bus_sync)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF(3), .INIT_SYNC_FF(1), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0)
    ) u_toggle_sync (
        .src_clk(src_clk), .src_in(src_update_toggle),
        .dest_clk(dst_clk), .dest_out(toggle_sync)
    );

    reg toggle_sync_d;
    reg [1:0] settle_count;
    reg pending;

    always @(posedge dst_clk) begin
        if (!dst_rstn) begin
            toggle_sync_d    <= 1'b0;
            settle_count     <= 2'd0;
            pending          <= 1'b0;
            dst_bus          <= {WIDTH{1'b0}};
            dst_update_pulse <= 1'b0;
        end else begin
            toggle_sync_d    <= toggle_sync;
            dst_update_pulse <= 1'b0;
            if (toggle_sync != toggle_sync_d) begin
                pending      <= 1'b1;
                settle_count <= 2'd2;
            end else if (pending) begin
                if (settle_count != 0)
                    settle_count <= settle_count - 1'b1;
                else begin
                    dst_bus          <= bus_sync;
                    dst_update_pulse <= 1'b1;
                    pending          <= 1'b0;
                end
            end
        end
    end

    wire unused_src_rstn = src_rstn;
endmodule

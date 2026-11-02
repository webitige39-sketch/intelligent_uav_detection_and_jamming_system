`timescale 1ns / 1ps

// Asynchronous assertion, synchronous deassertion for one clock domain.
module reset_sync_n #(
    parameter integer STAGES = 3
)(
    input  wire clk,
    input  wire arstn,
    output wire srstn
);
    (* ASYNC_REG = "TRUE" *) reg [STAGES-1:0] sync_ff = {STAGES{1'b0}};
    always @(posedge clk or negedge arstn) begin
        if (!arstn)
            sync_ff <= {STAGES{1'b0}};
        else
            sync_ff <= {sync_ff[STAGES-2:0], 1'b1};
    end
    assign srstn = sync_ff[STAGES-1];
endmodule

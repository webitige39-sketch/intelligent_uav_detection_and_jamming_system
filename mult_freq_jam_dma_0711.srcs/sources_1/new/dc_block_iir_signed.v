module dc_block_iir_signed #(
    parameter IN_WIDTH = 12,
    parameter DC_WIDTH = 28,
    parameter FRAC     = 8,
    parameter K        = 8
)(
    input                              clk,
    input                              rstn,
    input                              valid_in,
    input  signed [IN_WIDTH-1:0]       x_in,
    output reg                         valid_out,
    output reg signed [IN_WIDTH-1:0]   y_out
);

    localparam signed [DC_WIDTH-1:0] Y_MAX = (1 << (IN_WIDTH-1)) - 1;
    localparam signed [DC_WIDTH-1:0] Y_MIN = - (1 << (IN_WIDTH-1));

    reg  signed [DC_WIDTH-1:0] dc_est;

    wire signed [DC_WIDTH-1:0] x_ext;
    wire signed [DC_WIDTH-1:0] err;
    wire signed [DC_WIDTH-1:0] dc_next;
    wire signed [DC_WIDTH-1:0] y_tmp;
    wire signed [DC_WIDTH-1:0] y_shift;

    assign x_ext   = {{(DC_WIDTH-IN_WIDTH-FRAC){x_in[IN_WIDTH-1]}}, x_in, {FRAC{1'b0}}};
    assign err     = x_ext - dc_est;
    assign dc_next = dc_est + (err >>> K);
    assign y_tmp   = x_ext - dc_next;
    assign y_shift = y_tmp >>> FRAC;

    always @(posedge clk) begin
        if (!rstn) begin
            dc_est   <= {DC_WIDTH{1'b0}};
            valid_out <= 1'b0;
            y_out    <= {IN_WIDTH{1'b0}};
        end
        else if (valid_in) begin
            dc_est   <= dc_next;
            valid_out <= 1'b1;

            if (y_shift > Y_MAX)
                y_out <= {1'b0, {(IN_WIDTH-1){1'b1}}};
            else if (y_shift < Y_MIN)
                y_out <= {1'b1, {(IN_WIDTH-1){1'b0}}};
            else
                y_out <= y_shift[IN_WIDTH-1:0];
        end
        else begin
            valid_out <= 1'b0;
            y_out     <= {IN_WIDTH{1'b0}};
        end
    end

endmodule

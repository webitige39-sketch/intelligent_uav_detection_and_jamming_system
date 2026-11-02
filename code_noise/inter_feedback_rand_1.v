`define FEXPR sr_a[23]^(sr_a[22]^(sr_a[17]^sr_a[0]))
module inter_feedback_rand_1(
    output wire    [10:0] orbit,
    input  wire           clk,
    input  wire           resetup,    //置数,高电平有效
    input  wire    [23:0] initval
    );
reg[23:0] sr_a;
assign orbit[10:0]=sr_a[10:0];
always@(posedge clk or posedge resetup)
begin
    if(resetup)
        sr_a<=initval;
    else
    begin
        sr_a[22:0]<=sr_a[23:1];
        sr_a[23]<=`FEXPR;
    end
end
endmodule
`undef FEXPR
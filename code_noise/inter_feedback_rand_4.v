`define FEXPR sr_a[23]^(sr_a[21]^(sr_a[11]^sr_a[0]))
module inter_feedback_rand_4(
    output wire    [9:0] orbit,
    input  wire          clk,
    input  wire          resetup,    //置数,高电平有效
    input  wire    [23:0] initval    
    );
reg[23:0] sr_a;
assign   orbit[9]=sr_a[0],
         orbit[8]=sr_a[1],
         orbit[7]=sr_a[2],
         orbit[6]=sr_a[3],
         orbit[5]=sr_a[4],
         orbit[4]=sr_a[5],
         orbit[3]=sr_a[6],
         orbit[2]=sr_a[7],
         orbit[1]=sr_a[8],
         orbit[0]=sr_a[9];      
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
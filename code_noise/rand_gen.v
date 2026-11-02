module rand_gen#(
parameter    initval_1=24'b010110010010110111110001,
parameter    initval_2=24'b100000111100010111010001,
parameter    initval_3=24'b001101000001010010010001,
parameter    initval_4=24'b111010100110010011110001
)(
      input  wire  clk,
      input  wire  rst,        
      output  reg [10:0]    orbit_sin_addr, //rand number for sin ROM addr, [10:]
      output  reg [9:0]     orbit_log_addr //rand number for log ROM addr, [9:0]
    );
wire   resetup;        // asynchronous clear, high active
wire   [10:0]   orbit_1;
wire   [10:0]   orbit_2;
wire   [9:0]    orbit_3;
wire   [9:0]    orbit_4;   

// 交错异或子模块  
inter_feedback_rand_1 inter_feedback_rand_1_inst (
    .orbit(orbit_1),     //[10:0]
    .clk(clk), 
    .resetup(resetup), 
    .initval(initval_1) //[23:0]
    );
//////////////////////////////////////////////////////////////////////////////////
inter_feedback_rand_2 inter_feedback_rand_2_inst (
    .orbit(orbit_2),    //[10:0]
    .clk(clk), 
    .resetup(resetup), 
    .initval(initval_2)  //[23:0]
    );
//////////////////////////////////////////////////////////////////////////////////
inter_feedback_rand_3 inter_feedback_rand_3_inst (
    .orbit(orbit_3),    //[9:0]
    .clk(clk), 
    .resetup(resetup), 
    .initval(initval_3)  //[23:0]
    );
//////////////////////////////////////////////////////////////////////////////////
inter_feedback_rand_4 inter_feedback_rand_4_inst (
    .orbit(orbit_4),    //[9:0]
    .clk(clk), 
    .resetup(resetup), 
    .initval(initval_4)  //[23:0]
    );
//////////////////////////////////////////////////////////////////////////////////
//                          orbit_sin_addr   [10:0]                             //
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk or posedge rst) begin
    if(rst) begin
        orbit_sin_addr <= 11'b0;
    end
    else 
    orbit_sin_addr <= orbit_1 ^ orbit_2;
    end
//////////////////////////////////////////////////////////////////////////////////
//                            orbit_log_addr   [9:0 ]                           //
//////////////////////////////////////////////////////////////////////////////////
always @ (posedge clk or posedge rst) begin
    if(rst) begin
        orbit_log_addr <= 10'b0;
    end
    else 
    orbit_log_addr <= orbit_3 ^ orbit_4;
    end
//////////////////////////////////////////////////////////////////////////////////
//                               resetup                                        //
//////////////////////////////////////////////////////////////////////////////////
reg      resetup_r = 1'b0;
assign   resetup = resetup_r;
always @ (posedge clk or posedge rst) begin
        if(rst)
        resetup_r <= 1'd1;
        else
        resetup_r <= 1'd0;
        end            
endmodule
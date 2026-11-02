module noise_gen(
      input  wire  clk,
      input  wire  rst,
      input  wire  noise_en,
      input  wire  [9:0] orbit_sin_addr,
      input  wire  [9:0] orbit_log_addr,
      output wire  [15:0] noise_out,   
      output reg          noise_vld    
    );
wire   [7:0]    sin_data;
wire   [7:0]    log_data;
reg    [5:0]        creg=0;
wire   [16:0]   P;
// 正弦、对数、乘法IP核
rom_sin Sin_inst (                               
  .clka(clk), // input clka
  .ena(noise_en), // input ena
  .addra(orbit_sin_addr), // input [10 : 0] addra
  .douta(sin_data) // output [7 : 0] douta
);
rom_log Log_inst (                      
  .clka(clk), // input clka
  .ena(noise_en), // input ena
  .addra(orbit_log_addr), // input [9 : 0] addra
  .douta(log_data) // output [7 : 0] douta
);
xbip_multadd_0 xbip_multadd_0_inst0 (
  .CLK(clk),            // input wire CLK
  .CE(noise_en),              // input wire CE
  .SCLR(rst),          // input wire SCLR
  .A(sin_data),                // input wire [7 : 0] A
  .B(log_data),                // input wire [7 : 0] B
  .C(0),
  .P(P)                // output wire [16 : 0] P
);
assign noise_out=P[15:0];
always@(posedge clk)
begin
    creg[5]<=noise_en;
    creg[4]<=creg[5];
    creg[3]<=creg[4];
    creg[2]<=creg[3];
    creg[1]<=creg[2];
    creg[0]<=creg[1];
    noise_vld<=creg[0];
end
endmodule
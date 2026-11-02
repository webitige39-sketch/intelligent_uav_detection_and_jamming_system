module noise_source(
input clk,
input rstn,
input noise_en,
output[31:0] noise_out,
output       noise_vld
);

wire [9:0]  orbit_sin_addr_1;
wire [9:0]  orbit_log_addr_1;
wire [15:0] noise_out_re;
wire        noise_vld_re;
wire [9:0]  orbit_sin_addr_2;
wire [9:0]  orbit_log_addr_2;
wire [15:0] noise_out_im;
wire noise_vld_im;

assign rst = ~rstn;
//产生噪声信实部
 rand_gen rand_gen_inst_1 (
  .clk(clk), 
  .rst(rst), 
  .orbit_sin_addr(orbit_sin_addr_1),   
  .orbit_log_addr(orbit_log_addr_1)    
  );
 noise_gen noise_gen_inst_1 (
  .clk(clk), 
  .rst(rst), 
  .noise_en(noise_en), 
  .orbit_sin_addr(orbit_sin_addr_1), 
  .orbit_log_addr(orbit_log_addr_1), 
  .noise_out(noise_out_re),
  .noise_vld(noise_vld_re)
  );
  //产生噪声信号虚部
  /*
     .initval_1(24'b010110010010110111110001),
   .initval_2(24'b100000111100010111010001),
   .initval_3(24'b001101000001010010010001),
   .initval_4(24'b111010100110010011110001)
  */
   rand_gen #(
   .initval_1(24'b101001010101100110110011),
   .initval_2(24'b110011000100110101011011),
   .initval_3(24'b101101001010100110101101),
   .initval_4(24'b001010110111000111000101)
   )
   rand_gen_inst_2 (
  .clk(clk), 
  .rst(rst), 
  .orbit_sin_addr(orbit_sin_addr_2),   
  .orbit_log_addr(orbit_log_addr_2)    
  );
 noise_gen noise_gen_inst_2 (
  .clk(clk), 
  .rst(rst), 
  .noise_en(noise_en), 
  .orbit_sin_addr(orbit_sin_addr_2), 
  .orbit_log_addr(orbit_log_addr_2), 
  .noise_out(noise_out_im),
  .noise_vld(noise_vld_im)
  );
  assign noise_out={noise_out_im[14:0],1'd0,noise_out_re[14:0],1'd0};
  assign noise_vld=noise_vld_im&noise_vld_re;
  endmodule
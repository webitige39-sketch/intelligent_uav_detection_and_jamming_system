`timescale 1ns / 1ps
// 20MHz System Clock for delay calculations
`define SPI_CLK_FREQ 20 

module spi_ctrl_2(
    input           sys_clk,
    input           sys_rst,
    input           state_next, 
    input           FIND,

    output          spi_clk,
    output          spi_csn,
    output          spi_sdo,
    input           spi_sdi,

    output  [3:0]   ctrl_in,
    output  reg     id_chk,
    output  reg     bbpll_cal_done,
    output  reg     rx_rfpll_cp_done,
    output  reg     tx_rfpll_cp_done,
    output  reg     rx_rfpll_vco_done,
    output  reg     tx_rfpll_vco_done,
    output  reg     rx_bb_flt_done,
    output  reg     tx_bb_flt_done,
    output  reg     bbdc_cal_done,
    output  reg     rfdc_cal_done,
    output  reg     tx_quad_done,
    output  reg     spi_ok, 
    output  reg     rx_valid,
    output  reg [2:0]     profile_idx,
    output  reg [9:0]     address,
    output  reg [7:0]     writedata,     
    output  [12:0]  init_index,
    
    output  [7:0]         readdata_out, // 引出 SPI 回读数据
    output  [5:0]         state_out,     // 引出当前状态机状态
    output  reg [31:0]    measured_lock_time // [NEW] 锁定时间测量输出
);

    parameter AD9361_INIT = 3'b100;
    parameter AD9361_WORK = 3'b010;

    integer MODE; 
    
    reg [5:0]   state;
    reg [12:0]  index;       
    wire rst_n;
    
    reg [18:0]  command;     
    reg         read;
    reg         write;
    wire [7:0]  readdata;
    wire        waitrequest;
    
    reg [31:0]  delay_cnt;
    reg [31:0]  lock_timer_cnt; // [NEW] 内部计时器
    reg         state_next_d;
    wire        state_next_pos_edge;
    
    `include "ad9361_lut.v"

    assign init_index = index;
    assign ctrl_in = 4'b0;
    assign state_next_pos_edge = state_next & (~state_next_d);
    
    always @(posedge sys_clk) state_next_d <= state_next;

    always @(posedge sys_clk) begin
        if(MODE == AD9361_INIT) begin
            command <= ad9361_lut(index);
        end
    end

    assign rst_n = ~sys_rst;

    always @(posedge sys_clk) begin
        if(!rst_n) begin
            state <= 0;
            index <= 0;
            profile_idx <= 0;
            spi_ok <= 0;
            MODE <= AD9361_INIT;
            delay_cnt <= 0;
            lock_timer_cnt <= 0;   // [NEW] 复位计时器
            measured_lock_time <= 0; // [NEW] 复位测量结果
            read <= 0; write <= 0;
            id_chk <= 0; bbpll_cal_done <= 0; rx_rfpll_cp_done <= 0;
            tx_rfpll_cp_done <= 0; rx_rfpll_vco_done <= 0; tx_rfpll_vco_done <= 0;
            rx_bb_flt_done <= 0; tx_bb_flt_done <= 0; bbdc_cal_done <= 0;
            rfdc_cal_done <= 0; tx_quad_done <= 0;
            rx_valid <= 0;
        end 
        else begin
            // [NEW] 独立的计时器逻辑：在状态 17 到 24 期间自由累加
            if (state >= 6'd17 && state <= 6'd24) begin
                lock_timer_cnt <= lock_timer_cnt + 1;
            end
            
            case(state)
                6'd1: begin
                    {write,address,writedata} <= command        ; 
                    read <= ~command[18];
                    state <= 6'd2;
                end
                6'd2: begin 
                    if(~waitrequest) begin
                        state <= read ? 6'd3 : 6'd4;
                    end 
                end

                6'd3: begin
                    case(command)
                      {1'b0,10'h037,8'h08}:begin if( readdata[3])begin state<=state+1; id_chk            <=1 ; end  else state<=1;end//ReadPartNumber          
                      {1'b0,10'h05E,8'h80}:begin if( readdata[7])begin state<=state+1; bbpll_cal_done    <=1 ; end  else state<=1;end//BBPLL_INDEX              
                      {1'b0,10'h244,8'h80}:begin if( readdata[7])begin state<=state+1; rx_rfpll_cp_done  <=1 ; end  else state<=1;end//RX_CPCAL_INDEX       
                      {1'b0,10'h284,8'h80}:begin if( readdata[7])begin state<=state+1; tx_rfpll_cp_done  <=1 ; end  else state<=1;end//TX_CPCAL_INDEX       
                      {1'b0,10'h247,8'h00}:begin if( readdata[1])begin state<=state+1; rx_rfpll_vco_done <=1 ; end  else begin state<=1; rx_rfpll_vco_done <=0 ;end end//RX_PLL_LOCK_INDEX

                      {1'b0,10'h247,8'h02}:begin if( readdata[1])begin state<=state+1; rx_rfpll_vco_done <=1 ; end  else state<=1;end//RX_PLL_LOCK_INDEX
                      {1'b0,10'h287,8'h00}:begin if( readdata[1])begin state<=state+1; tx_rfpll_vco_done <=1 ; end  else begin state<=1;tx_rfpll_vco_done <=0 ;end end//TX_PLL_LOCK_INDEX 

                      {1'b0,10'h287,8'h02}:begin if( readdata[1])begin state<=state+1; tx_rfpll_vco_done <=1 ; end  else state<=1;end//TX_PLL_LOCK_INDEX            
                      {1'b0,10'h016,8'h80}:begin if(!readdata[7])begin state<=state+1; rx_bb_flt_done    <=1 ; end  else state<=1;end//RX_FIR_TUNE_INDEX        
                      {1'b0,10'h016,8'h40}:begin if(!readdata[6])begin state<=state+1; tx_bb_flt_done    <=1 ; end  else state<=1;end//TX_FIR_TUNE_INDEX        
                      {1'b0,10'h016,8'h01}:begin if(!readdata[0])begin state<=state+1; bbdc_cal_done     <=1 ; end  else state<=1;end//BBDC_OFFSET_CAL_INDEX    
                      {1'b0,10'h016,8'h02}:begin if(!readdata[1])begin state<=state+1; rfdc_cal_done     <=1 ; end  else state<=1;end//RFDC_OFFSET_CAL_INDEX    
                      {1'b0,10'h016,8'h10}:begin if(!readdata[4])begin state<=state+1; tx_quad_done      <=1 ; end  else state<=1;end//TX_QUAD_CAL_INDEX
                      {1'b0,10'h25E,8'h00}:begin state<=state+1; end
                      {1'b0,10'h29E,8'h00}:begin state<=state+1; end    
                      {1'b0,10'h017,8'h1A}:begin if(readdata[3:0]==4'd10) state<=state+1;else state<=1;end//RX_QUAD_CAL_INDEX   
                      {1'b0,10'h3FF,8'h01}: begin                                           //wait 200ms
                            if(delay_cnt!=`SPI_CLK_FREQ*200000) delay_cnt<=delay_cnt+1;                             
                            else begin delay_cnt<=0;state<=state+1;end
                          end
                      {1'b0,10'h3FF,8'h14}: begin                                           //wait 20ms
                            if(delay_cnt!=`SPI_CLK_FREQ*20000) delay_cnt<=delay_cnt+1;                          
                            else begin delay_cnt<=0;state<=state+1;end  
                          end                                                               
                      {1'b0,10'h3FF,8'hFF}:begin state<=7;end                               //command end
                      {1'b0,10'h000,8'h00}:begin state<=1;end
                    
                          default:begin state<=state+1;end
                    endcase
                  end
                6'd4: begin index       <=index+1;state<=state+1;end
                6'd5: begin state       <=state+1;end
                6'd6: begin state       <=1;      end
                6'd7: begin spi_ok <= 1; state <= 6'd8; end

                6'd8: if(~waitrequest) begin
                     state <= 6'd9; 
                     profile_idx <= 0; // Initialize Profile Index
                end

                // ============================================================
                // 1. 静态配置阶段
                // ============================================================
                6'd9: begin {write, address, writedata} <= {1'b1, 10'h230, 8'h55}; read <= 0; state <= 6'd10; end
                6'd10: if(~waitrequest) state <= 6'd11;

                6'd11: begin {write, address, writedata} <= {1'b1, 10'h270, 8'h55}; read <= 0; state <= 6'd12; end
                6'd12: if(~waitrequest) state <= 6'd13;

                6'd13: begin {write, address, writedata} <= {1'b1, 10'h25B, 8'h14}; read <= 0; state <= 6'd14; end
                6'd14: if(~waitrequest) state <= 6'd15;
                
                6'd15: begin {write, address, writedata} <= {1'b1, 10'h29B, 8'h14}; read <= 0; state <= 6'd16; end
                6'd16: if(~waitrequest) begin
                    lock_timer_cnt <= 0; // [NEW] 首次进入跳频循环前，清零计时器
                    state <= 6'd17; 
                end

                // ============================================================
                // 2. 极速跳频循环开始 (HOPPING LOOP)
                // ============================================================
                
                // 步骤A：调用 RX Profile (计时器此时开始自由累加)
                6'd17: begin 
                    {write, address, writedata} <= {1'b1, 10'h25A, {profile_idx, 5'b00001}};
                    read <= 0;
                    state <= 6'd18;
                end
                6'd18: if(~waitrequest) state <= 6'd19;

                // 步骤B：调用 TX Profile
                6'd19: begin 
                    {write, address, writedata} <= {1'b1, 10'h29A, {profile_idx, 5'b00001}};
                    read <= 0;
                    state <= 6'd20;
                end
                6'd20: if(~waitrequest) state <= 6'd21; 

                // 步骤C：闭环回读 RX RFPLL 锁定状态 (0x247)
                6'd21: begin
                    {write, address, writedata} <= {1'b0, 10'h247, 8'h00};
                    read <= 1;
                    state <= 6'd22;
                end
                6'd22: if(~waitrequest) begin
                    if(readdata[1]) begin 
                        state <= 6'd23;   
                    end else begin
                        state <= 6'd21;   
                    end
                end

                // 步骤D：闭环回读 TX RFPLL 锁定状态 (0x287)
                6'd23: begin
                    {write, address, writedata} <= {1'b0, 10'h287, 8'h00};
                    read <= 1;
                    state <= 6'd24;
                end
                6'd24: if(~waitrequest) begin
                    if(readdata[1]) begin 
                        measured_lock_time <= lock_timer_cnt; // [NEW] 锁定成功！锁存耗费的时钟周期数
                        delay_cnt <= 0;   
                        state <= 6'd25;   
                    end else begin
                        state <= 6'd23;   
                    end
                end

                // 步骤E：驻留接收阶段 (10us)
                6'd25: begin 
                    read <= 0;
                    
                    if(delay_cnt < `SPI_CLK_FREQ * 10) begin 
                        delay_cnt <= delay_cnt + 1;
                        rx_valid  <= 1'b1; 
                        if(FIND == 1'b1) state <= 6'd26;
                    end 
                    else begin
                        delay_cnt <= 0;
                        rx_valid  <= 1'b0; 
                        
                        if(profile_idx < 1)
                            profile_idx <= profile_idx + 1; 
                        else
                            profile_idx <= 0;
                            
                        lock_timer_cnt <= 0; // [NEW] 准备下一次换频，提前清零计时器
                        state <= 6'd17; 
                    end
                end

                // 目标驻留 (Hold) 阶段
                6'd26: begin 
                    if(FIND == 1'b1) begin
                        state <= 6'd26; // 无限驻留
                        rx_valid <= 1'b1;
                    end else begin
                        rx_valid <= 1'b0;
                        delay_cnt <= 0;
                        profile_idx <= (profile_idx < 1) ? profile_idx + 1 : 0;
                        lock_timer_cnt <= 0; state <= 6'd17;
                    end
                end    
                default: state <= 6'd1;
            endcase
        end
    end

    ad9361_spi u_ad9361_spi(
       .clk        (sys_clk),
       .rst_n      (rst_n),
       .write      (write),
       .read       (read),
       .address    (address),
       .writedata  (writedata),
       .readdata   (readdata),
       .waitrequest(waitrequest),
       .spi_clk    (spi_clk),
       .spi_csn    (spi_csn),
       .spi_sdo    (spi_sdo),
       .spi_sdi    (spi_sdi)
    );

   u_ila ila_hopping_debug  (
       .clk(sys_clk),
       .probe0(state),
       .probe1(profile_idx),
       .probe2(index),
       .probe3(spi_ok),
       .probe4(write),
       .probe5(read),
       .probe6(address),
       .probe7(writedata),
       .probe8(readdata),
       .probe9(waitrequest),
       .probe10(spi_clk),
       .probe11(spi_csn),
       .probe12(spi_sdo),
       .probe13(spi_sdi),
       .probe14(rx_valid)
    );

    assign readdata_out = readdata;
    assign state_out = state;

endmodule
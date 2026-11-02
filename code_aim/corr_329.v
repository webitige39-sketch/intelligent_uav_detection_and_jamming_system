`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/07 13:48:13
// Design Name: 
// Module Name: corr
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module corr #(
    parameter DATA_WIDTH = 16,      // 输入数据位宽
    parameter WINDOW_LEN = 128      // 积分窗口长度 (需与 MATLAB N 一致)
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         valid_in, // 输入数据有效指示
    input  wire signed [DATA_WIDTH-1:0] din_i,    // I 路输入
    input  wire signed [DATA_WIDTH-1:0] din_q,    // Q 路输入
    
    output reg                          valid_out,      // 输出有效指示
    output wire signed [31:0] dout_pwr_sq     // 模的平方 (位宽较大，后级可截位)
);

     //==============================================================
    // Stage 1: 输入打拍与 Lag-1 延迟生成
    //==============================================================
    reg signed [DATA_WIDTH-1:0] r_curr_i, r_curr_q; // x[n]
    reg signed [DATA_WIDTH-1:0] r_prev_i, r_prev_q; // x[n-1]
    reg                         vld_stg1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_curr_i <= 0; r_curr_q <= 0;
            r_prev_i <= 0; r_prev_q <= 0;
            vld_stg1 <= 0;
        end else if (valid_in) begin
            // 保存当前值
            r_curr_i <= din_i;
            r_curr_q <= din_q;
            // 保存前一拍的值 (实现 Lag-1)
            r_prev_i <= r_curr_i;
            r_prev_q <= r_curr_q;
            vld_stg1 <= 1;
        end else begin
            vld_stg1 <= 0;
        end
    end

    //==============================================================
    // Stage 2: 复数乘法 (Conjugate Multiply)
    // 公式: P = x[n] * conj(x[n-1])
    // (a+bi) * (c-di) = (ac + bd) + j(bc - ad)
    // a=curr_i, b=curr_q, c=prev_i, d=prev_q
    //==============================================================
    reg signed [2*DATA_WIDTH:0] prod_re; // 乘积结果位宽 = 16+16+1 = 33bit
    reg signed [2*DATA_WIDTH:0] prod_im;
    reg                         vld_stg2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prod_re <= 0;
            prod_im <= 0;
            vld_stg2 <= 0;
        end else if (vld_stg1) begin
            // 实部: I[n]*I[n-1] + Q[n]*Q[n-1]
            prod_re <= (r_curr_i * r_prev_i) + (r_curr_q * r_prev_q);
            // 虚部: Q[n]*I[n-1] - I[n]*Q[n-1]
            prod_im <= (r_curr_q * r_prev_i) - (r_curr_i * r_prev_q);
            vld_stg2 <= 1;
        end else begin
            vld_stg2 <= 0;
        end
    end

    //==============================================================
    // Stage 3: 滑动窗口累加 (Moving Average)
    // 算法: Acc[n] = Acc[n-1] + New_Data - Old_Data(Delayed by N)
    //==============================================================
    
    // 定义累加器位宽: 33bit(乘积) + log2(128)(7bit) = 40bit
    localparam ACC_WIDTH = 2*DATA_WIDTH + 1 + $clog2(WINDOW_LEN); 
    
    // 延迟线 (FIFO)，用于存储需要减去的旧数据
    // 使用 reg 数组，综合器通常会自动映射为 Distributed RAM 或 Block RAM
    reg signed [2*DATA_WIDTH:0] delay_line_re [0:WINDOW_LEN-1];
    reg signed [2*DATA_WIDTH:0] delay_line_im [0:WINDOW_LEN-1];
    
    reg signed [ACC_WIDTH-1:0] acc_re;
    reg signed [ACC_WIDTH-1:0] acc_im;
    reg                        vld_stg3;
    
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_re <= 0;
            acc_im <= 0;
            vld_stg3 <= 0;
            // 清空延迟线
            for (k=0; k<WINDOW_LEN; k=k+1) begin
                delay_line_re[k] <= 0;
                delay_line_im[k] <= 0;
            end
        end else if (vld_stg2) begin
            // 移位寄存器/延迟线更新
            delay_line_re[0] <= prod_re;
            delay_line_im[0] <= prod_im;
            for (k=1; k<WINDOW_LEN; k=k+1) begin
                delay_line_re[k] <= delay_line_re[k-1];
                delay_line_im[k] <= delay_line_im[k-1];
            end

            // 递归累加: + 新值 - 旧值(延迟线的最末端)
            acc_re <= acc_re + prod_re - delay_line_re[WINDOW_LEN-1];
            acc_im <= acc_im + prod_im - delay_line_im[WINDOW_LEN-1];
            
            vld_stg3 <= 1;
        end else begin
            vld_stg3 <= 0;
        end
    end

    //==============================================================
    // Stage 4: 计算模的平方 (Magnitude Squared)
    // Out = Re^2 + Im^2
    //==============================================================
    reg signed [2*ACC_WIDTH:0] mag_sq_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mag_sq_reg <= 0;
            valid_out  <= 0;
        end else if (vld_stg3) begin
            // 这一步位宽会翻倍，实际使用中通常会先截断 acc_re/im 的低位再平方
            // 此处为了演示算法完整性，保留全精度
            mag_sq_reg <= (acc_re * acc_re) + (acc_im * acc_im);
            valid_out  <= 1;
        end else begin
            valid_out <= 0;
        end
    end

    assign dout_pwr_sq = mag_sq_reg[64-:32];

endmodule

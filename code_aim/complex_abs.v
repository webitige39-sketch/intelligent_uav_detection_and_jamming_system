`timescale 1ns / 1ps
/*
	2023.5.26：编写程�?(未测�?)
	本模块：对上层的数据求模比较并输�? 输入32位数据，输出�?17�? 大于门限输出值，小于门限输出0，添加user信号，与tdata互补
	子模块：async_module:用来同步
	父模块：mult_ifft: 输入本模块的tdata tvalid tlast
*/


module complex_abs
#(
	parameter	DW = 16	,
	parameter	HAS_TLAST = 1
)
(
	input				s_axis_aclk		,
	input				s_axis_aresetn	,
	input	[2*DW-1:0]	s_axis_tdata	,
	input				s_axis_tvalid	,
	input				s_axis_tlast	,
	
	output	[DW-1:0]		m_axis_tdata	,
	output				m_axis_tvalid	,
	output				m_axis_tlast	
);

/*
	REG & WIRE DECLARATION
*/
wire signed	  [DW-1:0]		din_real = s_axis_tdata[DW-1:0]	   ;
wire signed	  [DW-1:0]		din_imag = s_axis_tdata[2*DW-1-:DW];

reg	 unsigned [2*DW-1:0]	real_squre	;	//实部平方
reg  unsigned [2*DW-1:0]	imag_squre	;	//虚部平方
reg							squre_vld	;	//平方vld

reg	 unsigned [2*DW:0]		sum_squre	;	//平方和数�?
reg							squre_sum_vld;	//平方和vld

wire						sqrt_m_axis_tvalid; //sqrt后valid
wire unsigned [23:0]		sqrt_m_axis_tdata;	//sqrt后tdata
//计算实部和虚部平方和
always @ (posedge s_axis_aclk)
	if(~s_axis_aresetn)
		begin
			real_squre <= 0;
			imag_squre <= 0;
			squre_vld  <= 0;
		end
	else if(s_axis_tvalid)
		begin
			real_squre <= din_real*din_real	;
			imag_squre <= din_imag*din_imag	;
			squre_vld  <= 1	;
		end
	else
		begin
			real_squre <= 0;
			imag_squre <= 0;
			squre_vld  <= 0;
		end
//计算实部和虚部平方和相加结果		
always @ (posedge s_axis_aclk)
	if(~s_axis_aresetn)
		begin
			sum_squre <= 0	;
			squre_sum_vld<=0;
		end
	else if(squre_vld)
		begin
			sum_squre <= real_squre + imag_squre;
			squre_sum_vld<=1;
		end
	else
		begin
			sum_squre <=0	;
			squre_sum_vld<=0;
		end
	
//data_in[32:0] data_out[16:0]	 17 Latency
cordic_0 sqrt_inst0 (
	.aclk					(s_axis_aclk		),  // input wire aclk
	.aresetn				(s_axis_aresetn		),  // input wire aresetn
	.s_axis_cartesian_tvalid(squre_sum_vld		),  // input wire s_axis_cartesian_tvalid
	.s_axis_cartesian_tdata	(sum_squre	        ),  // input wire [32 : 0] s_axis_cartesian_tdata  7'd0,
	.m_axis_dout_tvalid		(sqrt_m_axis_tvalid	),  // output wire m_axis_dout_tvalid
	.m_axis_dout_tdata		(sqrt_m_axis_tdata	)   // output wire [16 : 0] m_axis_dout_tdata
);
//cfar比较
assign m_axis_tdata = sqrt_m_axis_tdata[16:1];  //sqrt_m_axis_tdata[23-:17]
assign m_axis_tvalid= sqrt_m_axis_tvalid;


// // 产生tlast信号接口
// generate 
// 	if (HAS_TLAST==0)
// 		assign m_axis_tlast = 1'b0 ;
// 	else
// 		sync_module
//         #(
//             .WIDTH			(   1       	),
//             .SYNC_TIME		(   19  		), // 注意该延时需要根据该模块的实际处理延迟进行修�?
//             .IS_RST_ABLE	(   1       	),
//             .PASSBY         (	0			)
//         )tlast_delay(
//             .clk			(s_axis_aclk    ),
//             .rst			(~s_axis_aresetn),
//             .async_in	    (s_axis_tlast   ),
//             .sync_out	    (m_axis_tlast   ),
//             .parallel_out   (  				),
//             .en             (           	)
// 		);
// endgenerate



endmodule

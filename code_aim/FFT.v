`timescale 1ns / 1ps
/*
	2023.5.25: 测试,上层FIFO间隔读是131us,  FFT采用基4 80Mhz处理周期91.2us   采用基2需180Mhz以上
			   pipelined  DSP:15个  BRAM:11个 ;基4资源：DSP 9个  BRAM:7个  ;基2资源：DSP 3个  BRAM:5
	做2048点FFT(不加窗) 上层数据为2048点、


    2023.9.4
    张子宁
    模块作用：对ram中读取到的1024点做FFT
*/

module FFT
#(
	parameter	DATA_WIDTH	=	32	,	
	parameter	FRAME_LENGTH=	1024,
	parameter	PRINT_LOG	=	1	
	//parameter	LOG_NAME_RE	=	"fft_data_re.txt",
	//parameter	LOG_NAME_IM	=	"fft_data_im.txt"
)
(
	s_axis_aclk		,
	s_axis_aresetn	,
	s_axis_tdata	,
	s_axis_tvalid	,
	s_axis_tlast	,
	
	m_axis_tuser    ,
	m_axis_tdata	,
	m_axis_tvalid	,
	m_axis_tlast	,
	m_axis_tstart	
);
/*
	FUNCTION DECLARATION
*/
	function integer blog2(input integer number);
		for(blog2=0;number>0;blog2=blog2+1)
			number=number>>1;
	endfunction
	
/*
	LOCAL PARAMETER DECLARATION
*/
	localparam	DW		=DATA_WIDTH	;
	localparam	PC_FFTN	=blog2(FRAME_LENGTH-1);  //11=1011
	
/*
	WIRE & REG DECLARATION
*/
//输入输出定义
	input	wire		 	s_axis_aclk			;
	input	wire			s_axis_aresetn		;
	input	wire [DW-1:0]	s_axis_tdata		;
	input	wire			s_axis_tvalid		;
	input	wire			s_axis_tlast		;
								
	output	wire [DW-1:0]	m_axis_tdata		;
	output	wire			m_axis_tvalid		;
	output	wire			m_axis_tlast		;
	output	wire			m_axis_tstart		;
	output	wire [15 :0]	m_axis_tuser		;
//FFT 核输出状态信号
    wire            event_frame_started         ;
    wire            event_tlast_unexpected      ;
    wire            event_tlast_missing         ;
    wire            event_status_channel_halt   ;
    wire            event_data_in_channel_halt  ;
    wire            event_data_out_channel_halt ;
	
    wire            fft_s_axis_data_tready      ;
	wire			s_axis_config_tready		;
	wire [7:0]      m_axis_status_tdata         ;
	wire		    m_axis_status_tvalid		;
	reg				nfft_we,nfft_we_done		;

// 进行FFT处理
    always @ ( posedge s_axis_aclk )
        if ( ~s_axis_aresetn ) nfft_we <= 0 ;
        else if (!nfft_we_done) nfft_we <= 1 ;
        else nfft_we <= 0;
        
    always @ ( posedge s_axis_aclk )
        if ( ~s_axis_aresetn ) nfft_we_done <= 0;
        else if ( nfft_we&&s_axis_config_tready ) nfft_we_done <= 1 ;
        else nfft_we_done <= nfft_we_done ;
	
//s_axis_config_tdata_2048 [22:1]:SCALE_SCH_0  [0:0]:FWD_INV_0  1:FFT   0:IFFT
//s_axis_data_tdata[31:16]:IM  [15:0]:RE
//m_axis_data_tdata[31:16]:IM  [15:0]:RE
//wire [15:0] s_axis_config_tdata_2048 = {{6{2'b10}},1'b1}	; //放缩4096
//前12位标志放缩倍数，最后一位表示fft/ifft
//wire [15:0] s_axis_config_tdata_2048 = {12'b00_10_10_10_10_11,1'b1}	; 

wire [23:0] m_axis_tuser_1;
wire [7:0] s_axis_config_tdata_2048 = {7'b0,1'b1}	; 			
wire [15:0]	fft_re_s_axis_tdata = s_axis_tvalid ? s_axis_tdata[DW/2-1:0]:0;
wire [15:0]	fft_im_s_axis_tdata = s_axis_tvalid ? s_axis_tdata[DW-1-:DW/2]:0;
/*xfft_0 xfft_0_inst0 (
	.aclk						(s_axis_aclk		),                  		// input wire aclk
	.aresetn					(s_axis_aresetn		),              			// input wire aresetn
	.s_axis_config_tdata		(s_axis_config_tdata_2048),   					// input wire [15 : 0] s_axis_config_tdata
	.s_axis_config_tvalid		(nfft_we			),    						// input wire s_axis_config_tvalid
	.s_axis_config_tready		(s_axis_config_tready),  						// output wire s_axis_config_tready
	.s_axis_data_tdata			({fft_im_s_axis_tdata,fft_re_s_axis_tdata}),    // input wire [31 : 0] s_axis_data_tdata
	.s_axis_data_tvalid			(s_axis_tvalid 				),  				// input wire s_axis_data_tvalid
	.s_axis_data_tready			(fft_s_axis_data_tready),   					// output wire s_axis_data_tready
	.s_axis_data_tlast			(s_axis_tlast	), 								// input wire s_axis_data_tlast
	
	.m_axis_data_tuser          (m_axis_tuser ),								// output wire [15 : 0]
	.m_axis_data_tdata			(m_axis_tdata	),  						    // output wire [31 : 0] m_axis_data_tdata
	.m_axis_data_tvalid			(m_axis_tvalid	),  							// output wire m_axis_data_tvalid
	.m_axis_data_tready			(1'b1			),  							// input wire m_axis_data_tready
	.m_axis_data_tlast			(m_axis_tlast		),    						// output wire m_axis_data_tlast
	
	.event_frame_started		(event_frame_started),   						// output wire event_frame_started
	.event_tlast_unexpected		(event_tlast_unexpected),   					// output wire event_tlast_unexpected
	.event_tlast_missing		(event_tlast_missing),      				 	// output wire event_tlast_missing
	.event_status_channel_halt	(event_status_channel_halt),    				// output wire event_status_channel_halt
	.event_data_in_channel_halt	(event_data_in_channel_halt),    				// output wire event_data_in_channel_halt
	.event_data_out_channel_halt(event_data_out_channel_halt)  					// output wire event_data_out_channel_halt
);
*/

xfft_0 xfft_0_inst0 (
    .aclk                              (s_axis_aclk               ),// input wire aclk
    .aresetn                           (s_axis_aresetn            ),// input wire aresetn
    .s_axis_config_tdata               (s_axis_config_tdata_2048  ),// input wire [7 : 0] s_axis_config_tdata
    .s_axis_config_tvalid              (nfft_we                   ),// input wire s_axis_config_tvalid
    .s_axis_config_tready              (s_axis_config_tready      ),// output wire s_axis_config_tready
    .s_axis_data_tdata                 ({fft_im_s_axis_tdata,fft_re_s_axis_tdata}),// input wire [31 : 0] s_axis_data_tdata
    .s_axis_data_tvalid                (s_axis_tvalid             ),// input wire s_axis_data_tvalid
    .s_axis_data_tready                (fft_s_axis_data_tready    ),// output wire s_axis_data_tready
    .s_axis_data_tlast                 (s_axis_tlast              ),// input wire s_axis_data_tlast

    .m_axis_data_tdata                 (m_axis_tdata              ),// output wire [31 : 0] m_axis_data_tdata
    .m_axis_data_tuser                 (m_axis_tuser_1            ),// output wire [7 : 0] m_axis_data_tuser
    .m_axis_data_tvalid                (m_axis_tvalid             ),// output wire m_axis_data_tvalid
    .m_axis_data_tready                (1'b1                      ),// input wire m_axis_data_tready
    .m_axis_data_tlast                 (m_axis_tlast              ),// output wire m_axis_data_tlast

    .m_axis_status_tdata               (m_axis_status_tdata       ),// output wire [7 : 0] m_axis_status_tdata
    .m_axis_status_tvalid              (m_axis_status_tvalid      ),// output wire m_axis_status_tvalid
    .m_axis_status_tready              (1'b1                      ),// input wire m_axis_status_tready

    .event_frame_started               (event_frame_started       ),// output wire event_frame_started
    .event_tlast_unexpected            (event_tlast_unexpected    ),// output wire event_tlast_unexpected
    .event_tlast_missing               (event_tlast_missing       ),// output wire event_tlast_missing
    .event_status_channel_halt         (event_status_channel_halt ),// output wire event_status_channel_halt
    .event_data_in_channel_halt        (event_data_in_channel_halt),// output wire event_data_in_channel_halt
    .event_data_out_channel_halt       (event_data_out_channel_halt) // output wire event_data_out_channel_halt
);

assign m_axis_tuser = {6'b0, m_axis_tuser_1[9:0]};
// /*
//     数据打印存储为TXT文件
// */
//     integer fid_re,fid_im ; 
//     initial
//         begin
//             if ( PRINT_LOG )
//                 begin
//                     fid_re = $fopen(LOG_NAME_RE,"w");
//                     fid_im = $fopen(LOG_NAME_IM,"w");
//                 end
//         end
//     generate
//         if ( PRINT_LOG )
//             begin
//                 always @ ( posedge s_axis_aclk )
//                     if ( s_axis_tvalid ) // 抓取和路数据实部虚部
//                         begin
                            
//                             $fdisplay(fid_re,"%d",$signed(fft_re_s_axis_tdata));
//                             $fdisplay(fid_im,"%d",$signed(fft_im_s_axis_tdata));
//                         end
//             end
// 	endgenerate
	

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/04 22:15:27
// Design Name: 
// Module Name: Top
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


module DETECT_AIM#(
    parameter                           DATA_WIDTH          = 32    // Input & Output Data Width
          
)(
 
    input                               s_axis_aclk                ,
    input                               data_clk                   ,

    input                               s_axis_aresetn             ,
    input              [DATA_WIDTH-1 : 0]s_axis_tdata              ,
    input                               s_axis_tvalid              ,
    input              [  31:0]         Thred                      ,
    input                               FIND_EN                    ,
    input                               FIND_EN_AIM                ,
   

    output                              tr_m_axis_tvalid           ,
    output                              Freq_Thr_over_toggle       ,
    output                              FIND_UAV_toggle            ,
    output                              FIND_UAV                   ,
    output             [  31:0]         data_sum                   ,// input [31 : 0] PROBE1 //40MHz
    output             [   0:0]         FIND                       ,// input [0 : 0] PROBE2  //40MHz
    output             [  20:0]         CNT                        ,// input [20 : 0] PROBE3  //40MHz
    output             [   0:0]         m_axis_tstart_thr          ,// input [0 : 0] PROBE4  //40MHz
    output             [   0:0]         m_axis_tlast_thr           ,// input [0 : 0] PROBE5  //40MHz
    output             [   0:0]         DATA_LABEL                 ,// input [0 : 0] PROBE6
    output             [   0:0]         WEA                        ,// input [0 : 0] PROBE7
    output             [  10:0]         ADDRA                      ,// input [10 : 0] PROBE8
    output             [   0:0]         REA                        ,// input [0 : 0] PROBE9
    output             [  10:0]         ADDRB                      ,// input [10 : 0] PROBE10
    output             [  31:0]         m_axis_tdata_ram           ,// input [31 : 0] PROBE11
    output             [  31:0]         m_axis_tdata_FFT           ,// input [31 : 0] PROBE12
    output                              m_axis_tvalid_FFT          ,
    output                              m_axis_tvalid_ram          ,
    output             [  15:0]         F_user_1                   ,// input [15 : 0] PROBE13
    output             [   0:0]         Freq_Thr_over_1            ,// input [0 : 0] PROBE15
    output             [  15:0]         m_axis_tuser_FFT,

    // 200 MHz CFAR / traces_condense debug outputs
    output             [  15:0]         dbg_data_abs,
    output                              dbg_data_abs_valid,
    output                              dbg_data_abs_last,
    output             [  15:0]         dbg_cfar_raw_idx,
    output             [  15:0]         dbg_cfar_cut_amp,
    output                              dbg_cfar_hit,
    output                              dbg_cfar_valid,
    output                              dbg_cfar_last,
    output             [  15:0]         dbg_condense_peak_idx,
    output             [  15:0]         dbg_condense_peak_amp,
    output                              dbg_condense_hit,
    output                              dbg_condense_valid,
    output                              dbg_condense_last,
    output             [  15:0]         dbg_condense_user,
    output                              dbg_frame_has_candidate
    );


wire                            m_axis_tlast_ram ;
//wire                            m_axis_tvalid_ram ;
//wire                            m_axis_tvalid_FFT ;
wire                            m_axis_tlast_FFT  ;
//wire [DATA_WIDTH/2-1 : 0]       m_axis_tuser_FFT  ; 



        Thr_detection
            #(
                .DATA_WIDTH			(   32       ),
                .FRAME_LENGTH       (  1024       )
                
            )Thr_detection(
                .Thred                  (Thred              ),
                .s_axis_aclk			(s_axis_aclk        ),
                .s_axis_aresetn			(s_axis_aresetn     ),
                .s_axis_tdata	        (s_axis_tdata       ),
                .s_axis_tvalid	        (s_axis_tvalid      ),
                .Freq_Thr_over          (Freq_Thr_over_1    ),//FIND_EN
                .FIND_EN                (FIND_EN            ),

                .m_axis_tstart          (m_axis_tstart_thr     ),
                .m_axis_tlast           (m_axis_tlast_thr      ),
				.FIND                   (FIND                  ),
                .CNT					(CNT                   ),
			    .data_sum               (data_sum              )
				);
				
                
                
          RAM_data
            #(
                .DATA_WIDTH			(   32       )
            )RAM_data(
                .s_axis_aclk			(s_axis_aclk        ),
                .data_clk               (data_clk           ),
                .s_axis_aresetn			(s_axis_aresetn     ),
                .s_axis_tdata	        (s_axis_tdata       ),
                .s_axis_tvalid	        (s_axis_tvalid      ),
                .s_axis_tstart          (m_axis_tstart_thr     ),
                .s_axis_tlast           (m_axis_tlast_thr      ),

                .WEA		            (WEA                   ),
	            .ADDRA	                (ADDRA                 ),
	            .REA		            (REA                   ),
	            .ADDRB                  (ADDRB                 ),
                .DATA_LABEL             (DATA_LABEL            ),

                .m_axis_tlast           (m_axis_tlast_ram      ),
                .m_axis_tdata           (m_axis_tdata_ram      ),
                .m_axis_tvalid          (m_axis_tvalid_ram     ));

            FFT
            #(
                .DATA_WIDTH			(   32       ),
                .FRAME_LENGTH       (  1024       ),
                .PRINT_LOG          (    1       )
            )FFT(
                .s_axis_aclk			(data_clk          ),
                .s_axis_aresetn			(s_axis_aresetn    ),
                .s_axis_tdata	        (m_axis_tdata_ram      ),
                .s_axis_tvalid	        (m_axis_tvalid_ram     ),
                .s_axis_tlast           (m_axis_tlast_ram      ),

                .m_axis_tuser           (m_axis_tuser_FFT      ),
                .m_axis_tdata           (m_axis_tdata_FFT      ),
                .m_axis_tvalid          (m_axis_tvalid_FFT     ),
                .m_axis_tlast	        (m_axis_tlast_FFT      ),
	            .m_axis_tstart          (     ));


            Freq_Thr
            #(
                .DATA_WIDTH			(   32       ),
                .FRAME_LENGTH       ( 1024       )
            )Freq_Thr(
                .s_axis_aclk			(data_clk           ),
                .s_axis_aresetn			(s_axis_aresetn     ),
                .s_axis_tdata	        (m_axis_tdata_FFT   ),
                .s_axis_tvalid	        (m_axis_tvalid_FFT  ),
                .s_axis_tlast           (m_axis_tlast_FFT   ),
                .s_axis_tuser           (m_axis_tuser_FFT   ),
                .FIND_EN_AIM            (FIND_EN_AIM        ),

                .tr_m_axis_tvalid       (tr_m_axis_tvalid    ),
                .Freq_Thr_over_toggle   (Freq_Thr_over_toggle),
                .FIND_UAV_toggle        (FIND_UAV_toggle     ),
                .FIND_UAV               (FIND_UAV            ),
                .F_user                 (F_user_1            ),
                .Freq_Thr_over          (Freq_Thr_over_1     ),

                .dbg_data_abs           (dbg_data_abs        ),
                .dbg_data_abs_valid     (dbg_data_abs_valid  ),
                .dbg_data_abs_last      (dbg_data_abs_last   ),
                .dbg_cfar_raw_idx       (dbg_cfar_raw_idx    ),
                .dbg_cfar_cut_amp       (dbg_cfar_cut_amp    ),
                .dbg_cfar_hit           (dbg_cfar_hit        ),
                .dbg_cfar_valid         (dbg_cfar_valid      ),
                .dbg_cfar_last          (dbg_cfar_last       ),
                .dbg_condense_peak_idx  (dbg_condense_peak_idx),
                .dbg_condense_peak_amp  (dbg_condense_peak_amp),
                .dbg_condense_hit       (dbg_condense_hit    ),
                .dbg_condense_valid     (dbg_condense_valid  ),
                .dbg_condense_last      (dbg_condense_last   ),
                .dbg_condense_user      (dbg_condense_user   ),
                .dbg_frame_has_candidate(dbg_frame_has_candidate)
            );       
               
            
   


endmodule
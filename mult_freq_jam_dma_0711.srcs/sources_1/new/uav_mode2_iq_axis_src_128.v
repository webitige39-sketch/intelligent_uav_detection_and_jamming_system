`timescale 1 ns / 1 ps

// ================================================================
// UAV Mode1/Mode2 AXI-Stream test source, 128-bit data width.
//
// mode_select_i = 0: Mode2, 256 x 1024 IQ points, counter pattern.
//                  I[n] = (n + frame_seq) & 0x7fff, Q[n] = -I[n]
//                  Payload = 1,048,576 bytes.
//
// mode_select_i = 1: Mode1, RX 1024 IQ points + JAM 4096 IQ points.
//                  RX  = complex sine, about +1.25 MHz @ Fs=40 MHz.
//                  JAM = complex sine, about +5.00 MHz @ Fs=40 MHz.
//                  Payload = 20,480 bytes.
// ================================================================

module uav_mode_axis_src_128 #(
    parameter integer MODE2_POINTS = 262144,
    parameter integer MODE1_RX_POINTS = 1024,
    parameter integer MODE1_JAM_POINTS = 4096
)(
    input  wire         axis_clk,
    input  wire         axis_rstn,

    input  wire         start_i,
    input  wire         mode_select_i,   // 0: Mode2 counter, 1: Mode1 sine

    output wire         ready_o,
    output reg          busy_o,
    output reg          done_pulse_o,

    output reg  [127:0] m_axis_tdata,
    output wire [15:0]  m_axis_tkeep,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast
);

    localparam integer POINTS_PER_BEAT    = 4;
    localparam integer MODE2_BEATS        = MODE2_POINTS / POINTS_PER_BEAT;
    localparam integer MODE1_TOTAL_POINTS = MODE1_RX_POINTS + MODE1_JAM_POINTS;
    localparam integer MODE1_BEATS        = MODE1_TOTAL_POINTS / POINTS_PER_BEAT;

    reg        start_d;
    wire       start_rise;
    reg        active_mode;
    reg [31:0] beat_idx;
    reg [31:0] frame_seq;

    assign start_rise   = start_i & ~start_d;
    assign ready_o      = ~busy_o;
    assign m_axis_tkeep = 16'hFFFF;

    function signed [15:0] quarter_sin;
        input [7:0] off;
        begin
            case (off)
                8'd0: quarter_sin = 16'sd0;
                8'd1: quarter_sin = 16'sd99;
                8'd2: quarter_sin = 16'sd197;
                8'd3: quarter_sin = 16'sd296;
                8'd4: quarter_sin = 16'sd394;
                8'd5: quarter_sin = 16'sd493;
                8'd6: quarter_sin = 16'sd591;
                8'd7: quarter_sin = 16'sd690;
                8'd8: quarter_sin = 16'sd788;
                8'd9: quarter_sin = 16'sd887;
                8'd10: quarter_sin = 16'sd985;
                8'd11: quarter_sin = 16'sd1083;
                8'd12: quarter_sin = 16'sd1182;
                8'd13: quarter_sin = 16'sd1280;
                8'd14: quarter_sin = 16'sd1378;
                8'd15: quarter_sin = 16'sd1476;
                8'd16: quarter_sin = 16'sd1574;
                8'd17: quarter_sin = 16'sd1672;
                8'd18: quarter_sin = 16'sd1770;
                8'd19: quarter_sin = 16'sd1868;
                8'd20: quarter_sin = 16'sd1966;
                8'd21: quarter_sin = 16'sd2064;
                8'd22: quarter_sin = 16'sd2162;
                8'd23: quarter_sin = 16'sd2259;
                8'd24: quarter_sin = 16'sd2357;
                8'd25: quarter_sin = 16'sd2454;
                8'd26: quarter_sin = 16'sd2552;
                8'd27: quarter_sin = 16'sd2649;
                8'd28: quarter_sin = 16'sd2746;
                8'd29: quarter_sin = 16'sd2843;
                8'd30: quarter_sin = 16'sd2940;
                8'd31: quarter_sin = 16'sd3037;
                8'd32: quarter_sin = 16'sd3134;
                8'd33: quarter_sin = 16'sd3230;
                8'd34: quarter_sin = 16'sd3327;
                8'd35: quarter_sin = 16'sd3423;
                8'd36: quarter_sin = 16'sd3519;
                8'd37: quarter_sin = 16'sd3615;
                8'd38: quarter_sin = 16'sd3711;
                8'd39: quarter_sin = 16'sd3807;
                8'd40: quarter_sin = 16'sd3903;
                8'd41: quarter_sin = 16'sd3998;
                8'd42: quarter_sin = 16'sd4093;
                8'd43: quarter_sin = 16'sd4189;
                8'd44: quarter_sin = 16'sd4284;
                8'd45: quarter_sin = 16'sd4379;
                8'd46: quarter_sin = 16'sd4473;
                8'd47: quarter_sin = 16'sd4568;
                8'd48: quarter_sin = 16'sd4662;
                8'd49: quarter_sin = 16'sd4756;
                8'd50: quarter_sin = 16'sd4850;
                8'd51: quarter_sin = 16'sd4944;
                8'd52: quarter_sin = 16'sd5038;
                8'd53: quarter_sin = 16'sd5131;
                8'd54: quarter_sin = 16'sd5225;
                8'd55: quarter_sin = 16'sd5318;
                8'd56: quarter_sin = 16'sd5411;
                8'd57: quarter_sin = 16'sd5503;
                8'd58: quarter_sin = 16'sd5596;
                8'd59: quarter_sin = 16'sd5688;
                8'd60: quarter_sin = 16'sd5780;
                8'd61: quarter_sin = 16'sd5872;
                8'd62: quarter_sin = 16'sd5963;
                8'd63: quarter_sin = 16'sd6055;
                8'd64: quarter_sin = 16'sd6146;
                8'd65: quarter_sin = 16'sd6237;
                8'd66: quarter_sin = 16'sd6327;
                8'd67: quarter_sin = 16'sd6418;
                8'd68: quarter_sin = 16'sd6508;
                8'd69: quarter_sin = 16'sd6598;
                8'd70: quarter_sin = 16'sd6687;
                8'd71: quarter_sin = 16'sd6777;
                8'd72: quarter_sin = 16'sd6866;
                8'd73: quarter_sin = 16'sd6955;
                8'd74: quarter_sin = 16'sd7043;
                8'd75: quarter_sin = 16'sd7132;
                8'd76: quarter_sin = 16'sd7220;
                8'd77: quarter_sin = 16'sd7308;
                8'd78: quarter_sin = 16'sd7395;
                8'd79: quarter_sin = 16'sd7483;
                8'd80: quarter_sin = 16'sd7569;
                8'd81: quarter_sin = 16'sd7656;
                8'd82: quarter_sin = 16'sd7743;
                8'd83: quarter_sin = 16'sd7829;
                8'd84: quarter_sin = 16'sd7914;
                8'd85: quarter_sin = 16'sd8000;
                8'd86: quarter_sin = 16'sd8085;
                8'd87: quarter_sin = 16'sd8170;
                8'd88: quarter_sin = 16'sd8255;
                8'd89: quarter_sin = 16'sd8339;
                8'd90: quarter_sin = 16'sd8423;
                8'd91: quarter_sin = 16'sd8507;
                8'd92: quarter_sin = 16'sd8590;
                8'd93: quarter_sin = 16'sd8673;
                8'd94: quarter_sin = 16'sd8756;
                8'd95: quarter_sin = 16'sd8838;
                8'd96: quarter_sin = 16'sd8920;
                8'd97: quarter_sin = 16'sd9001;
                8'd98: quarter_sin = 16'sd9083;
                8'd99: quarter_sin = 16'sd9164;
                8'd100: quarter_sin = 16'sd9244;
                8'd101: quarter_sin = 16'sd9325;
                8'd102: quarter_sin = 16'sd9405;
                8'd103: quarter_sin = 16'sd9484;
                8'd104: quarter_sin = 16'sd9563;
                8'd105: quarter_sin = 16'sd9642;
                8'd106: quarter_sin = 16'sd9721;
                8'd107: quarter_sin = 16'sd9799;
                8'd108: quarter_sin = 16'sd9876;
                8'd109: quarter_sin = 16'sd9954;
                8'd110: quarter_sin = 16'sd10031;
                8'd111: quarter_sin = 16'sd10107;
                8'd112: quarter_sin = 16'sd10184;
                8'd113: quarter_sin = 16'sd10259;
                8'd114: quarter_sin = 16'sd10335;
                8'd115: quarter_sin = 16'sd10410;
                8'd116: quarter_sin = 16'sd10485;
                8'd117: quarter_sin = 16'sd10559;
                8'd118: quarter_sin = 16'sd10633;
                8'd119: quarter_sin = 16'sd10706;
                8'd120: quarter_sin = 16'sd10779;
                8'd121: quarter_sin = 16'sd10852;
                8'd122: quarter_sin = 16'sd10924;
                8'd123: quarter_sin = 16'sd10996;
                8'd124: quarter_sin = 16'sd11067;
                8'd125: quarter_sin = 16'sd11138;
                8'd126: quarter_sin = 16'sd11209;
                8'd127: quarter_sin = 16'sd11279;
                8'd128: quarter_sin = 16'sd11349;
                8'd129: quarter_sin = 16'sd11418;
                8'd130: quarter_sin = 16'sd11487;
                8'd131: quarter_sin = 16'sd11555;
                8'd132: quarter_sin = 16'sd11623;
                8'd133: quarter_sin = 16'sd11690;
                8'd134: quarter_sin = 16'sd11758;
                8'd135: quarter_sin = 16'sd11824;
                8'd136: quarter_sin = 16'sd11890;
                8'd137: quarter_sin = 16'sd11956;
                8'd138: quarter_sin = 16'sd12021;
                8'd139: quarter_sin = 16'sd12086;
                8'd140: quarter_sin = 16'sd12150;
                8'd141: quarter_sin = 16'sd12214;
                8'd142: quarter_sin = 16'sd12278;
                8'd143: quarter_sin = 16'sd12341;
                8'd144: quarter_sin = 16'sd12403;
                8'd145: quarter_sin = 16'sd12465;
                8'd146: quarter_sin = 16'sd12527;
                8'd147: quarter_sin = 16'sd12588;
                8'd148: quarter_sin = 16'sd12649;
                8'd149: quarter_sin = 16'sd12709;
                8'd150: quarter_sin = 16'sd12768;
                8'd151: quarter_sin = 16'sd12827;
                8'd152: quarter_sin = 16'sd12886;
                8'd153: quarter_sin = 16'sd12944;
                8'd154: quarter_sin = 16'sd13002;
                8'd155: quarter_sin = 16'sd13059;
                8'd156: quarter_sin = 16'sd13116;
                8'd157: quarter_sin = 16'sd13172;
                8'd158: quarter_sin = 16'sd13228;
                8'd159: quarter_sin = 16'sd13283;
                8'd160: quarter_sin = 16'sd13338;
                8'd161: quarter_sin = 16'sd13392;
                8'd162: quarter_sin = 16'sd13446;
                8'd163: quarter_sin = 16'sd13499;
                8'd164: quarter_sin = 16'sd13551;
                8'd165: quarter_sin = 16'sd13603;
                8'd166: quarter_sin = 16'sd13655;
                8'd167: quarter_sin = 16'sd13706;
                8'd168: quarter_sin = 16'sd13757;
                8'd169: quarter_sin = 16'sd13807;
                8'd170: quarter_sin = 16'sd13856;
                8'd171: quarter_sin = 16'sd13905;
                8'd172: quarter_sin = 16'sd13954;
                8'd173: quarter_sin = 16'sd14002;
                8'd174: quarter_sin = 16'sd14049;
                8'd175: quarter_sin = 16'sd14096;
                8'd176: quarter_sin = 16'sd14143;
                8'd177: quarter_sin = 16'sd14188;
                8'd178: quarter_sin = 16'sd14234;
                8'd179: quarter_sin = 16'sd14278;
                8'd180: quarter_sin = 16'sd14323;
                8'd181: quarter_sin = 16'sd14366;
                8'd182: quarter_sin = 16'sd14409;
                8'd183: quarter_sin = 16'sd14452;
                8'd184: quarter_sin = 16'sd14494;
                8'd185: quarter_sin = 16'sd14535;
                8'd186: quarter_sin = 16'sd14576;
                8'd187: quarter_sin = 16'sd14617;
                8'd188: quarter_sin = 16'sd14657;
                8'd189: quarter_sin = 16'sd14696;
                8'd190: quarter_sin = 16'sd14734;
                8'd191: quarter_sin = 16'sd14773;
                8'd192: quarter_sin = 16'sd14810;
                8'd193: quarter_sin = 16'sd14847;
                8'd194: quarter_sin = 16'sd14884;
                8'd195: quarter_sin = 16'sd14920;
                8'd196: quarter_sin = 16'sd14955;
                8'd197: quarter_sin = 16'sd14990;
                8'd198: quarter_sin = 16'sd15024;
                8'd199: quarter_sin = 16'sd15057;
                8'd200: quarter_sin = 16'sd15090;
                8'd201: quarter_sin = 16'sd15123;
                8'd202: quarter_sin = 16'sd15155;
                8'd203: quarter_sin = 16'sd15186;
                8'd204: quarter_sin = 16'sd15217;
                8'd205: quarter_sin = 16'sd15247;
                8'd206: quarter_sin = 16'sd15277;
                8'd207: quarter_sin = 16'sd15306;
                8'd208: quarter_sin = 16'sd15334;
                8'd209: quarter_sin = 16'sd15362;
                8'd210: quarter_sin = 16'sd15389;
                8'd211: quarter_sin = 16'sd15416;
                8'd212: quarter_sin = 16'sd15442;
                8'd213: quarter_sin = 16'sd15467;
                8'd214: quarter_sin = 16'sd15492;
                8'd215: quarter_sin = 16'sd15517;
                8'd216: quarter_sin = 16'sd15540;
                8'd217: quarter_sin = 16'sd15564;
                8'd218: quarter_sin = 16'sd15586;
                8'd219: quarter_sin = 16'sd15608;
                8'd220: quarter_sin = 16'sd15630;
                8'd221: quarter_sin = 16'sd15650;
                8'd222: quarter_sin = 16'sd15671;
                8'd223: quarter_sin = 16'sd15690;
                8'd224: quarter_sin = 16'sd15709;
                8'd225: quarter_sin = 16'sd15728;
                8'd226: quarter_sin = 16'sd15745;
                8'd227: quarter_sin = 16'sd15763;
                8'd228: quarter_sin = 16'sd15779;
                8'd229: quarter_sin = 16'sd15795;
                8'd230: quarter_sin = 16'sd15811;
                8'd231: quarter_sin = 16'sd15825;
                8'd232: quarter_sin = 16'sd15840;
                8'd233: quarter_sin = 16'sd15853;
                8'd234: quarter_sin = 16'sd15866;
                8'd235: quarter_sin = 16'sd15879;
                8'd236: quarter_sin = 16'sd15891;
                8'd237: quarter_sin = 16'sd15902;
                8'd238: quarter_sin = 16'sd15912;
                8'd239: quarter_sin = 16'sd15922;
                8'd240: quarter_sin = 16'sd15932;
                8'd241: quarter_sin = 16'sd15941;
                8'd242: quarter_sin = 16'sd15949;
                8'd243: quarter_sin = 16'sd15956;
                8'd244: quarter_sin = 16'sd15963;
                8'd245: quarter_sin = 16'sd15970;
                8'd246: quarter_sin = 16'sd15975;
                8'd247: quarter_sin = 16'sd15981;
                8'd248: quarter_sin = 16'sd15985;
                8'd249: quarter_sin = 16'sd15989;
                8'd250: quarter_sin = 16'sd15992;
                8'd251: quarter_sin = 16'sd15995;
                8'd252: quarter_sin = 16'sd15997;
                8'd253: quarter_sin = 16'sd15999;
                8'd254: quarter_sin = 16'sd16000;
                8'd255: quarter_sin = 16'sd16000;
                default: quarter_sin = 16'sd0;
            endcase
        end
    endfunction

    function signed [15:0] sin1024;
        input [9:0] addr;
        reg [7:0] off;
        reg [7:0] inv;
        begin
            off = addr[7:0];
            inv = 8'd255 - off;
            case (addr[9:8])
                2'b00: sin1024 = quarter_sin(off);
                2'b01: sin1024 = quarter_sin(inv);
                2'b10: sin1024 = -quarter_sin(off);
                2'b11: sin1024 = -quarter_sin(inv);
                default: sin1024 = 16'sd0;
            endcase
        end
    endfunction

    function signed [15:0] cos1024;
        input [9:0] addr;
        begin
            cos1024 = sin1024(addr + 10'd256);
        end
    endfunction

    function [31:0] iq_word;
        input signed [15:0] i_val;
        input signed [15:0] q_val;
        begin
            iq_word = {q_val[15:0], i_val[15:0]};
        end
    endfunction

    function [31:0] mode2_iq_at_point;
        input [31:0] point_index;
        reg signed [15:0] i_val;
        reg signed [15:0] q_val;
        reg [15:0] tmp;
        begin
            tmp = (point_index + frame_seq) & 16'h7FFF;
            i_val = $signed(tmp);
            q_val = -i_val;
            mode2_iq_at_point = iq_word(i_val, q_val);
        end
    endfunction

    function [31:0] mode1_iq_at_point;
        input [31:0] point_index;
        reg [31:0] local_idx;
        reg [9:0]  phase_addr;
        reg signed [15:0] i_val;
        reg signed [15:0] q_val;
        begin
            if (point_index < MODE1_RX_POINTS) begin
                // RX: +1.25 MHz, 32 samples/cycle at Fs=40 MHz.
                local_idx  = point_index;
                phase_addr = {local_idx[4:0], 5'b00000};
                i_val = cos1024(phase_addr);
                q_val = sin1024(phase_addr);
            end else begin
                // JAM: +5.00 MHz, 8 samples/cycle at Fs=40 MHz.
                local_idx  = point_index - MODE1_RX_POINTS;
                phase_addr = {local_idx[2:0], 7'b0000000};
                i_val = cos1024(phase_addr);
                q_val = sin1024(phase_addr);
            end
            mode1_iq_at_point = iq_word(i_val, q_val);
        end
    endfunction

    always @(*) begin
        if (!active_mode) begin
            m_axis_tdata = {
                mode2_iq_at_point(beat_idx * 4 + 3),
                mode2_iq_at_point(beat_idx * 4 + 2),
                mode2_iq_at_point(beat_idx * 4 + 1),
                mode2_iq_at_point(beat_idx * 4 + 0)
            };
            m_axis_tlast = (beat_idx == MODE2_BEATS - 1);
        end else begin
            m_axis_tdata = {
                mode1_iq_at_point(beat_idx * 4 + 3),
                mode1_iq_at_point(beat_idx * 4 + 2),
                mode1_iq_at_point(beat_idx * 4 + 1),
                mode1_iq_at_point(beat_idx * 4 + 0)
            };
            m_axis_tlast = (beat_idx == MODE1_BEATS - 1);
        end
    end

    always @(posedge axis_clk) begin
        if (!axis_rstn) begin
            start_d       <= 1'b0;
            busy_o        <= 1'b0;
            done_pulse_o  <= 1'b0;
            m_axis_tvalid <= 1'b0;
            beat_idx      <= 32'd0;
            frame_seq     <= 32'd0;
            active_mode   <= 1'b0;
        end else begin
            start_d      <= start_i;
            done_pulse_o <= 1'b0;

            if (!busy_o) begin
                m_axis_tvalid <= 1'b0;
                beat_idx      <= 32'd0;

                if (start_rise) begin
                    active_mode   <= mode_select_i;
                    busy_o        <= 1'b1;
                    m_axis_tvalid <= 1'b1;
                    beat_idx      <= 32'd0;
                end
            end else begin
                m_axis_tvalid <= 1'b1;

                if (m_axis_tvalid && m_axis_tready) begin
                    if (m_axis_tlast) begin
                        busy_o        <= 1'b0;
                        m_axis_tvalid <= 1'b0;
                        beat_idx      <= 32'd0;
                        done_pulse_o  <= 1'b1;
                        if (!active_mode) begin
                            frame_seq <= frame_seq + 1'b1;
                        end
                    end else begin
                        beat_idx <= beat_idx + 1'b1;
                    end
                end
            end
        end
    end

endmodule

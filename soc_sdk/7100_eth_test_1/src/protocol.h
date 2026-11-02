#ifndef UAV_PROTOCOL_H
#define UAV_PROTOCOL_H

#include "xil_types.h"

/* ============================================================
 * UAV Mode2 protocol, PL->DMA version
 *
 * PC/Qt  -> ZYNQ PS : 4-byte START/STOP command, network byte order
 * ZYNQ PS -> PC/Qt : 48-byte header + 1,048,576-byte int16 IQ payload
 *
 * Payload order:
 *   int16 I0, int16 Q0, int16 I1, int16 Q1, ...
 * ============================================================ */

#define TCP_START_CMD              0xAA55FFA0U
#define TCP_STOP_CMD               0xAA55FFB1U

#define TCP_START_MODE1_CMD          0xAA55FFA1U
#define TCP_STOP_MODE1_CMD           0xAA55FFB2U
#define TCP_MODE3_CTRL_CMD          0xAA55FFC3U

#define UAV_CMD_START_MODE2        TCP_START_CMD
#define UAV_CMD_STOP_MODE2         TCP_STOP_CMD
#define UAV_CMD_START_MODE1        TCP_START_MODE1_CMD
#define UAV_CMD_STOP_MODE1         TCP_STOP_MODE1_CMD
#define UAV_CMD_MODE3_CTRL          TCP_MODE3_CTRL_CMD

#define UAV_MODE_IDLE              0U
#define UAV_MODE1_WORK             1U
#define UAV_MODE2_INFER            2U

#define UAV_PROTOCOL_VERSION       0x0003U
#define UAV_MAGIC_MODE2            0x32444F4DU  /* little-endian ASCII: MOD2 */
#define UAV_MAGIC_MODE1            0x31444F4DU  /* little-endian ASCII: MOD1 */

#define UAV_SAMPLE_RATE_HZ         40000000U
#define UAV_MODE2_ROWS             256U
#define UAV_MODE2_COLS             1024U
#define UAV_MODE2_POINTS           (UAV_MODE2_ROWS * UAV_MODE2_COLS)

#define UAV_IQ_FORMAT_INT16        0U
#define UAV_IQ_BYTES_PER_POINT     4U
#define UAV_MODE2_PAYLOAD_BYTES    (UAV_MODE2_POINTS * UAV_IQ_BYTES_PER_POINT)

#define UAV_MODE2_FPS              10U
#define UAV_MODE2_FRAME_PERIOD_MS  (1000U / UAV_MODE2_FPS)

#define UAV_MODE1_RX_POINTS         1024U
#define UAV_MODE1_JAM_POINTS        4096U
#define UAV_MODE1_TOTAL_POINTS      (UAV_MODE1_RX_POINTS + UAV_MODE1_JAM_POINTS)
#define UAV_MODE1_PAYLOAD_BYTES     (UAV_MODE1_TOTAL_POINTS * UAV_IQ_BYTES_PER_POINT)
#define UAV_MODE1_FPS               2U
#define UAV_MODE1_FRAME_PERIOD_MS   (1000U / UAV_MODE1_FPS)
#define UAV_MODE1_PAYLOAD_BASE_ADDR 0x09400000U
#define UAV_MODE1_DMA_BUF_ADDR      UAV_MODE1_PAYLOAD_BASE_ADDR

/* PL stream generator mode select. Wrapper maps mode3_cfg0[30] to mode_select_i. */
#define UAV_PL_STREAM_MODE_MODE2    0U
#define UAV_PL_STREAM_MODE_MODE1    1U
#define UAV_MODE3_STREAM_ENABLE_BIT 29U
#define UAV_MODE3_STREAM_MODE_BIT   30U

#define UAV_TCP_CHUNK_BYTES        (16U * 1024U)
#define UAV_TCP_MIN_WRITE_BYTES    1024U

/* DDR buffer layout. Keep these away from ELF/heap/stack and old DAQ buffers. */
#define UAV_MODE2_HEADER_BASE_ADDR   0x08F00000U
#define UAV_MODE2_DMA_BUF0_ADDR      0x09000000U
#define UAV_MODE2_DMA_BUF1_ADDR      0x09200000U
#define UAV_MODE2_DMA_BUF_BYTES      UAV_MODE2_PAYLOAD_BYTES
#define TCP_RXBUFFER_BASE_ADDR       0x0F000000U

/* GPIO output convention. */
#define UAV_PL_RESET_ASSERT          0U
#define UAV_PL_RESET_RELEASE         1U
#define UAV_PL_START_LOW             0U
#define UAV_PL_START_HIGH            1U

/* Allow AXI-GPIO mode bits to cross into 20/40/200 MHz domains. */
#define UAV_PL_MODE_SETTLE_US        2000U
#define UAV_PL_STOP_SETTLE_US        2000U

/* Header length is 48 bytes. Payload follows in the TCP byte stream. */

/* ============================================================
 * Mode3 control command: Qt -> PS -> AXI-GPIO -> PL.
 * Qt sends 24 bytes in network byte order:
 *   u32 cmd      = 0xAA55FFC3
 *   u32 seq      = command sequence
 *   u32 sel_jam  = 0..15
 *   u32 div_cnt  = 0..65535
 *   u32 aim_time = 32-bit
 *   u32 thred    = 32-bit
 *
 * AXI-GPIO mapping on PL side:
 *   gpio_mode3_cfg0 channel 1 [15:0]  -> DIV_CNT
 *                              [19:16] -> sel_jam
 *                              [31]    -> update toggle
 *   gpio_mode3_cfg0 channel 2 [31:0]  -> AIM_TIME
 *   gpio_mode3_thred channel 1 [31:0] -> Thred
 * ============================================================ */
#define UAV_MODE3_CMD_BYTES       24U
#define UAV_MODE3_UPDATE_BIT      31U
#define UAV_MODE3_DIVCNT_MASK     0x0000FFFFU
#define UAV_MODE3_SELJAM_MASK     0x0000000FU

/* Canonical jammer selector mapping. Keep Qt, PS and PL identical. */
#define UAV_JAM_NARROW_AIM       0U
#define UAV_JAM_WIDEBAND_BLOCK   1U
#define UAV_JAM_COMB             2U
#define UAV_JAM_SLICE_FORWARD    3U
#define UAV_JAM_SWEEP            4U
#define UAV_JAM_MODE_MAX         UAV_JAM_SWEEP

typedef struct uav_mode3_cmd
{
    u32 cmd;
    u32 seq;
    u32 sel_jam;
    u32 div_cnt;
    u32 aim_time;
    u32 thred;
} uav_mode3_cmd_t;

typedef struct uav_mode2_header
{
    u32 magic;
    u16 version;
    u16 header_len;

    u32 mode;
    u32 frame_seq;

    u32 sample_rate_hz;
    u32 rows;
    u32 cols;
    u32 iq_format;

    u32 payload_bytes;
    u32 crc32;          /* payload CRC32 */

    u32 reserved0;      /* timestamp low / debug */
    u32 reserved1;      /* timestamp high / debug */
} uav_mode2_header_t;

/* ============================================================
 * Compatibility definitions retained from 09_daq7606_lwip_tcp_dma.
 * ============================================================ */
#define FDMA_DBUF_BASE_ADDR        0x43C00000U

#define UIFDMA_DBUF_WBASEADDR      0x08000000U
#define UIFDMA_DBUF_BUFSIZE        0x200000U

#define RX_BUFFER0_BASE            (UIFDMA_DBUF_WBASEADDR + UIFDMA_DBUF_BUFSIZE * 0U)
#define RX_BUFFER1_BASE            (UIFDMA_DBUF_WBASEADDR + UIFDMA_DBUF_BUFSIZE * 1U)
#define RX_BUFFER2_BASE            (UIFDMA_DBUF_WBASEADDR + UIFDMA_DBUF_BUFSIZE * 2U)

#define HEADER_ID0                 0xAA55AA55U
#define HEADER_ID1                 0xAA55AA55U
#define HEADER_KSPS                200U
#define HEADER_RESOLUTION          16U
#define HEADER_CHANNLES_SIGNBIT    0x81U
#define HEADER_LENGTH              1024U
#define HEADER_SIZE                16U

#define TOTAL_PKG_SIZE             (1024U * 16U * 64U)
#define TCP_PACKEG_SIZE            (1024U * 16U)
#define TCP_SEND_TIMES             (TOTAL_PKG_SIZE / TCP_PACKEG_SIZE)
#define TCP_SEND_LAST_SIZE         (TOTAL_PKG_SIZE - (TCP_PACKEG_SIZE * TCP_SEND_TIMES))
#define TCP_FIRST_SEND_SIZE        (HEADER_SIZE + TCP_PACKEG_SIZE)

typedef struct packet_header
{
    u32 ID0;
    u32 ID1;
    u16 KSPS;
    u8  Resolution;
    u8  channels_signbit;
    u16 length;
    u16 fram_counter;
} packet_header;

typedef struct packet_data
{
    u16 ADC0;
    u16 ADC1;
    u16 ADC2;
    u16 ADC3;
    u16 ADC4;
    u16 ADC5;
    u16 ADC6;
    u16 ADC7;
} packet_data;

typedef struct fdma_buf_st
{
    u8  record[64];
    u8  circle_cnt;
    u8  next;
    u8  pkg_done_cnt;
    u16 fram_cnt;
    u16 pkg_cnt;
} fdma_buf_st;

void fdma_wr_set(u32 set);

#endif /* UAV_PROTOCOL_H */

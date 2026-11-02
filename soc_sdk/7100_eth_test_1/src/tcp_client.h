/*
 * TCP client for UAV Mode2 test.
 * Based on the Xilinx lwIP raw TCP client style used in 09_daq7606_lwip_tcp_dma.
 */

#ifndef __TCP_PERF_CLIENT_H_
#define __TCP_PERF_CLIENT_H_

#include "lwipopts.h"
#include "lwip/ip_addr.h"
#include "lwip/err.h"
#include "lwip/tcp.h"
#include "lwip/inet.h"
#include "xil_printf.h"
#include "platform.h"

/* used as indices into kLabel[] */
enum {
    KCONV_UNIT,
    KCONV_KILO,
    KCONV_MEGA,
    KCONV_GIGA,
};

/* used as type of print */
enum measure_t {
    BYTES,
    SPEED
};

/* Report Type */
enum report_type {
    INTER_REPORT,
    TCP_DONE_CLIENT,
    TCP_ABORTED_REMOTE
};

struct interim_report {
    u64_t start_time;
    u64_t last_report_time;
    u32_t total_bytes;
    u32_t report_interval_time;
};

struct perf_stats {
    u8_t client_id;
    u64_t start_time;
    u64_t end_time;
    u64_t total_bytes;
    struct interim_report i_report;
};

/* seconds between periodic bandwidth reports */
#define INTERIM_REPORT_INTERVAL 5

/* PC TCP server port. Qt/Python should listen on this port. */
#define TCP_CONN_PORT 5001

/* time in seconds to transmit packets; kept for original report logic */
#define TCP_TIME_INTERVAL 300

#if LWIP_IPV6==1
#define TCP_SERVER_IPV6_ADDRESS "fe80::6600:6aff:fe71:fde6"
#else
/* Change this to the PC upper-computer IP address.
 * Keep board IP and PC IP in the same subnet.
 * Original 09 demo often uses board 192.168.137.10 and PC 192.168.137.209.
 */
#define TCP_SERVER_IP_ADDRESS "192.168.137.100"
#endif

#define TCP_SEND_BUFSIZE (5 * TCP_MSS)

void print_app_header(void);
void start_application(void);
void transfer_data(void);

#endif /* __TCP_PERF_CLIENT_H_ */

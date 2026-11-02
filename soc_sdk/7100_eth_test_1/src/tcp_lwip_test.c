/*
 * lwIP RAW Mode TCP Client Application for UAV Mode2 stage-1 test.
 *
 * Compared with the original 09_daq7606 example:
 *   - Network initialization is kept.
 *   - DMA initialization is kept for compatibility with the copied hardware.
 *   - Data upload uses PL -> AXI-DMA S2MM -> DDR Mode2 IQ data.
 */

#include <stdio.h>
#include "xparameters.h"
#include "netif/xadapter.h"
#include "platform.h"
#include "platform_config.h"
#include "lwipopts.h"
#include "xil_printf.h"
#include "sleep.h"
#include "lwip/priv/tcp_priv.h"
#include "lwip/init.h"
#include "lwip/inet.h"
#include "dma_intr.h"
#include "sys_intr.h"

#if LWIP_IPV6==1
#include "lwip/ip6_addr.h"
#include "lwip/ip6.h"
#else
#if LWIP_DHCP==1
#include "lwip/dhcp.h"
extern volatile int dhcp_timoutcntr;
#endif

/* Board static IP. Modify it according to your PC subnet. */
#define DEFAULT_IP_ADDRESS  "192.168.137.10"
#define DEFAULT_IP_MASK     "255.255.255.0"
#define DEFAULT_GW_ADDRESS  "192.168.137.1"
#endif

extern struct tcp_pcb *request_pcb;
extern volatile u8 client_connected;
extern u8 tcp_trans_start;
extern u8 first_trans_start;

extern volatile int TcpFastTmrFlag;
extern volatile int TcpSlowTmrFlag;
extern XAxiDma AxiDma;
extern XScuGic Intc;

void platform_enable_interrupts(void);
void start_application(void);
void transfer_data(void);
void print_app_header(void);
void fdma_wr_set(u32 set);

#if defined (__arm__) && !defined (ARMR5)
#if XPAR_GIGE_PCS_PMA_SGMII_CORE_PRESENT == 1 || \
    XPAR_GIGE_PCS_PMA_1000BASEX_CORE_PRESENT == 1
int ProgramSi5324(void);
int ProgramSfpPhy(void);
#endif
#endif

#ifdef XPS_BOARD_ZCU102
#ifdef XPAR_XIICPS_0_DEVICE_ID
int IicPhyReset(void);
#endif
#endif

struct netif server_netif;

#if LWIP_IPV6==1
static void print_ipv6(char *msg, ip_addr_t *ip)
{
    print(msg);
    xil_printf(" %s\n\r", inet6_ntoa(*ip));
}
#else
static void print_ip(char *msg, ip_addr_t *ip)
{
    print(msg);
    xil_printf("%d.%d.%d.%d\r\n", ip4_addr1(ip), ip4_addr2(ip),
               ip4_addr3(ip), ip4_addr4(ip));
}

static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
    print_ip("Board IP:       ", ip);
    print_ip("Netmask :       ", mask);
    print_ip("Gateway :       ", gw);
}

static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
    int err;

    xil_printf("Configuring default IP %s \r\n", DEFAULT_IP_ADDRESS);

    err = inet_aton(DEFAULT_IP_ADDRESS, ip);
    if (!err) {
        xil_printf("Invalid default IP address: %d\r\n", err);
    }

    err = inet_aton(DEFAULT_IP_MASK, mask);
    if (!err) {
        xil_printf("Invalid default IP MASK: %d\r\n", err);
    }

    err = inet_aton(DEFAULT_GW_ADDRESS, gw);
    if (!err) {
        xil_printf("Invalid default gateway address: %d\r\n", err);
    }
}
#endif

static void init_intr_sys(void)
{
    Init_Intr_System(&Intc);

    /* DMA interrupt is used for AXI-DMA S2MM completion. The surrounding lwIP
     * initialization is kept identical to the verified fake-data version.
     */
    DMA_Intr_Init(&AxiDma, 0);
    DMA_Setup_Intr_System(&Intc, &AxiDma, RX_INTR_ID);
    DMA_Intr_Enable(&Intc, &AxiDma);

    init_platform();
    Setup_Intr_Exception(&Intc);
}

int main(void)
{
    struct netif *netif;

    unsigned char mac_ethernet_address[] = {
        0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

    netif = &server_netif;

#if defined (__arm__) && !defined (ARMR5)
#if XPAR_GIGE_PCS_PMA_SGMII_CORE_PRESENT == 1 || \
    XPAR_GIGE_PCS_PMA_1000BASEX_CORE_PRESENT == 1
    ProgramSi5324();
    ProgramSfpPhy();
#endif
#endif

#ifdef XPS_BOARD_ZCU102
    IicPhyReset();
#endif

    init_intr_sys();

    xil_printf("\r\n\r\n");
    xil_printf("----- UAV Mode2 lwIP RAW TCP Client DMA-on-FakeBase Test -----\r\n");

    lwip_init();

    if (!xemac_add(netif, NULL, NULL, NULL, mac_ethernet_address,
                   PLATFORM_EMAC_BASEADDR)) {
        xil_printf("Error adding N/W interface\r\n");
        return -1;
    }

#if LWIP_IPV6==1
    netif->ip6_autoconfig_enabled = 1;
    netif_create_ip6_linklocal_address(netif, 1);
    netif_ip6_addr_set_state(netif, 0, IP6_ADDR_VALID);
    print_ipv6("\n\rlink local IPv6 address is:", &netif->ip6_addr[0]);
#endif

    netif_set_default(netif);
    platform_enable_interrupts();
    netif_set_up(netif);

#if (LWIP_IPV6==0)
#if (LWIP_DHCP==1)
    dhcp_start(netif);
    dhcp_timoutcntr = 24;
    while (((netif->ip_addr.addr) == 0) && (dhcp_timoutcntr > 0)) {
        xemacif_input(netif);
    }

    if (dhcp_timoutcntr <= 0) {
        if ((netif->ip_addr.addr) == 0) {
            xil_printf("ERROR: DHCP request timed out\r\n");
            assign_default_ip(&(netif->ip_addr), &(netif->netmask), &(netif->gw));
        }
    }
#else
    assign_default_ip(&(netif->ip_addr), &(netif->netmask), &(netif->gw));
#endif
    print_ip_settings(&(netif->ip_addr), &(netif->netmask), &(netif->gw));
#endif

    xil_printf("\r\n");
    print_app_header();
    start_application();
    xil_printf("\r\n");

    while (1) {
        if (TcpFastTmrFlag) {
            if ((request_pcb == NULL) ||
                request_pcb->state == CLOSED ||
                (request_pcb->state == SYN_SENT && request_pcb->nrtx == TCP_SYNMAXRTX)) {
                xil_printf("TCP reconnect...\r\n");
                start_application();
            }

            tcp_fasttmr();
            TcpFastTmrFlag = 0;
        }

        if (TcpSlowTmrFlag) {
            tcp_slowtmr();
            TcpSlowTmrFlag = 0;
        }

        xemacif_input(netif);

        if (client_connected && tcp_trans_start) {
            transfer_data();
        } else {
            fdma_wr_set(0);
            first_trans_start = 0;
        }
    }

    cleanup_platform();
    return 0;
}

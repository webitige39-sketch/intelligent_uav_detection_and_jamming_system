#ifndef DMA_INTR_H
#define DMA_INTR_H

#include "xaxidma.h"
#include "xparameters.h"
#include "xil_exception.h"
#include "xdebug.h"
#include "xscugic.h"
#include "xil_types.h"

#define DMA_DEV_ID      XPAR_AXIDMA_0_DEVICE_ID
#define RX_INTR_ID      XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR

#define RESET_TIMEOUT_COUNTER 1000000

extern XAxiDma AxiDma;
extern volatile int g_dma_rx_done;
extern volatile int g_dma_error;
extern volatile u32 g_dma_last_irq_status;
extern volatile u32 g_dma_last_rx_status;

int DMA_Setup_Intr_System(XScuGic *IntcInstancePtr, XAxiDma *AxiDmaPtr, u16 RxIntrId);
int DMA_Intr_Enable(XScuGic *IntcInstancePtr, XAxiDma *DMAPtr);
int DMA_Intr_Init(XAxiDma *DMAPtr, u32 DeviceId);
int DMA_RxRecover(XAxiDma *AxiDmaPtr);
void DMA_Clear_Flags(void);

#endif

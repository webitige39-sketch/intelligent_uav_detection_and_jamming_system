#include "dma_intr.h"
#include "xil_printf.h"

XAxiDma AxiDma;
volatile int g_dma_rx_done = 0;
volatile int g_dma_error   = 0;
volatile u32 g_dma_last_irq_status = 0U;
volatile u32 g_dma_last_rx_status  = 0U;

void DMA_Clear_Flags(void)
{
    g_dma_rx_done = 0;
    g_dma_error = 0;
    g_dma_last_irq_status = 0U;
    g_dma_last_rx_status = 0U;
}

static void DMA_RxIntrHandler(void *Callback)
{
    u32 IrqStatus;
    u32 RxStatus;
    XAxiDma *AxiDmaInst = (XAxiDma *)Callback;

    IrqStatus = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq(AxiDmaInst, IrqStatus, XAXIDMA_DEVICE_TO_DMA);

    if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK)) {
        return;
    }

    RxStatus = XAxiDma_ReadReg(AxiDmaInst->RegBase + XAXIDMA_RX_OFFSET,
                               XAXIDMA_SR_OFFSET);
    g_dma_last_irq_status = IrqStatus;
    g_dma_last_rx_status = RxStatus;

    /*
     * Do not reset the DMA inside the interrupt handler. A reset can take many
     * cycles and also clears the DMA interrupt enable bits. Recovery is done in
     * the foreground by DMA_RxRecover(), where the PL stream is already stopped.
     */
    if (IrqStatus & XAXIDMA_IRQ_ERROR_MASK) {
        xil_printf("DMA RX error, irq=0x%08lx, s2mm_dmasr=0x%08lx\r\n",
                   (unsigned long)IrqStatus,
                   (unsigned long)RxStatus);
        g_dma_error = 1;
        return;
    }

    if (IrqStatus & XAXIDMA_IRQ_IOC_MASK) {
        g_dma_rx_done = 1;
    }
}

int DMA_RxRecover(XAxiDma *AxiDmaPtr)
{
    int TimeOut;
    u32 Pending;

    if (AxiDmaPtr == NULL) {
        return XST_FAILURE;
    }

    XAxiDma_IntrDisable(AxiDmaPtr,
                        XAXIDMA_IRQ_ALL_MASK,
                        XAXIDMA_DEVICE_TO_DMA);

    XAxiDma_Reset(AxiDmaPtr);
    TimeOut = RESET_TIMEOUT_COUNTER;
    while (TimeOut > 0) {
        if (XAxiDma_ResetIsDone(AxiDmaPtr)) {
            break;
        }
        TimeOut--;
    }

    if (TimeOut == 0) {
        xil_printf("ERROR: AXI DMA reset timed out\r\n");
        return XST_FAILURE;
    }

    /* Clear any old IOC/error interrupt that survived until reset completion. */
    Pending = XAxiDma_IntrGetIrq(AxiDmaPtr, XAXIDMA_DEVICE_TO_DMA);
    if (Pending != 0U) {
        XAxiDma_IntrAckIrq(AxiDmaPtr, Pending, XAXIDMA_DEVICE_TO_DMA);
    }

    DMA_Clear_Flags();

    /* DMA reset clears the channel interrupt-enable bits. Re-enable them. */
    XAxiDma_IntrEnable(AxiDmaPtr,
                       XAXIDMA_IRQ_ALL_MASK,
                       XAXIDMA_DEVICE_TO_DMA);

    return XST_SUCCESS;
}

int DMA_Setup_Intr_System(XScuGic *IntcInstancePtr, XAxiDma *AxiDmaPtr, u16 RxIntrId)
{
    int Status;

    XScuGic_SetPriorityTriggerType(IntcInstancePtr, RxIntrId, 0xA0, 0x3);

    Status = XScuGic_Connect(IntcInstancePtr, RxIntrId,
                             (Xil_InterruptHandler)DMA_RxIntrHandler,
                             AxiDmaPtr);
    if (Status != XST_SUCCESS) {
        xil_printf("XScuGic_Connect DMA RX failed: %d\r\n", Status);
        return Status;
    }

    XScuGic_Enable(IntcInstancePtr, RxIntrId);
    return XST_SUCCESS;
}

int DMA_Intr_Enable(XScuGic *IntcInstancePtr, XAxiDma *DMAPtr)
{
    (void)IntcInstancePtr;

    XAxiDma_IntrDisable(DMAPtr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrEnable(DMAPtr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    return XST_SUCCESS;
}

int DMA_Intr_Init(XAxiDma *DMAPtr, u32 DeviceId)
{
    int Status;
    XAxiDma_Config *Config = NULL;

    Config = XAxiDma_LookupConfig(DeviceId);
    if (!Config) {
        xil_printf("No DMA config found for device %lu\r\n", (unsigned long)DeviceId);
        return XST_FAILURE;
    }

    Status = XAxiDma_CfgInitialize(DMAPtr, Config);
    if (Status != XST_SUCCESS) {
        xil_printf("DMA initialization failed = %d\r\n", Status);
        return XST_FAILURE;
    }

    if (XAxiDma_HasSg(DMAPtr)) {
        xil_printf("DMA configured as SG mode, but this code needs Direct Register mode\r\n");
        return XST_FAILURE;
    }

    DMA_Clear_Flags();
    return XST_SUCCESS;
}


/********************MILIANKE**************************

*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2021/10/15
*File Name: sccb_iic.h
*Description:
*Declaration:
*The reference demo provided by Milianke is only used for learning.
*We cannot ensure that the demo itself is free of bugs, so users
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0

****************************************************/


#ifndef SSCB_IIC_H_
#define SSCB_IIC_H_

#include  "xil_types.h"

#include "xgpio.h"


void sccb_gpio_init(XGpio *sscb_gpio , u16 DeviceId);
void write_i2c(XGpio sscb_gpio,u16 addr,u8 value);

#endif

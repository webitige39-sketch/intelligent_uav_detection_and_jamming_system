
/********************MILIANKE**************************

*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2021/10/15
*File Name: sccb_iic.c
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

#include "sleep.h"
#include "xgpio.h"
#include "sccb_iic.h"


#define CAM_OV5640	   0x78

#define AXI_GPIO_BIT0  0x1
#define AXI_GPIO_BIT1  0x2


void SCL_HIGH(XGpio sscb_gpio)  {XGpio_DiscreteSet(&sscb_gpio,1,AXI_GPIO_BIT0);  }
void SCL_LOW (XGpio sscb_gpio)  {XGpio_DiscreteClear(&sscb_gpio,1,AXI_GPIO_BIT0);}
void SDA_HIGH(XGpio sscb_gpio)  {XGpio_DiscreteSet(&sscb_gpio,1,AXI_GPIO_BIT1);  }
void SDA_LOW (XGpio sscb_gpio)  {XGpio_DiscreteClear(&sscb_gpio,1,AXI_GPIO_BIT1);}

void sccb_gpio_init(XGpio *psscb_gpio , u16 DeviceId)
{
	XGpio_Initialize(psscb_gpio, DeviceId);
	XGpio_SetDataDirection(psscb_gpio, 1, 0x0);
	XGpio_DiscreteWrite(psscb_gpio, 1, 0x3);
}

void sccb_start(XGpio sscb_gpio)
{
		SCL_HIGH(sscb_gpio);
		SDA_HIGH(sscb_gpio);
		usleep(10);
		SDA_LOW(sscb_gpio);
		usleep(10);
		SCL_LOW(sscb_gpio);
		usleep(10);
}

void sccb_end(XGpio sscb_gpio)
{
		SDA_LOW(sscb_gpio);
		usleep(10);
		SCL_HIGH(sscb_gpio);
		usleep(10);
		SDA_HIGH(sscb_gpio);
		usleep(10);
}

void sccb_sendbyte(XGpio sscb_gpio, u8 value )
{
	//并行数据转串行输出，串行数据输出的顺序为先高位再低位
	u8  i=0;

	for(i=0; i<8; i++)
	{
		if(value & 0x80 )
		SDA_HIGH(sscb_gpio);
		else
		SDA_LOW(sscb_gpio);
		usleep(10);
		SCL_HIGH(sscb_gpio);
		usleep(10);
		SCL_LOW(sscb_gpio);
		usleep(10);
		value<<=1;
	}
	//第9位，Don’t Care
	SDA_LOW(sscb_gpio);
	usleep(10);
	SCL_HIGH(sscb_gpio);
	usleep(10);
	SCL_LOW(sscb_gpio);
	usleep(10);
}

void write_i2c(XGpio sscb_gpio ,u16 addr,u8 value)
{
	u8 buf[3];
	buf[0] = addr >>8;
	buf[1] = addr;
	buf[2] = value;

	sccb_start(sscb_gpio);
	sccb_sendbyte(sscb_gpio,CAM_OV5640);
	sccb_sendbyte(sscb_gpio,buf[0]);
	sccb_sendbyte(sscb_gpio,buf[1]);
	sccb_sendbyte(sscb_gpio,buf[2]);
	sccb_end(sscb_gpio);

	usleep(2000);
}


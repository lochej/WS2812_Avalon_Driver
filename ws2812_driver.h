/*
 * ws2812_driver.h
 * This header file offers a friendly way to write WS2812 driver using fast Macros
 *
 *	Choose if you are using a NIOS2 processor address accessing or use a HPS to drive the LEDs.
 *
 *	For each call to a Macro function, you need to provide the LED driver base address.
 *	This address is available in Qsys for you component.
 *
 *	On Linux HPS, you need to memory map this address with you FPGA bridge.
 *	On NIOS2, simply use the HAL macro to get the WS2812_Driver_BASE address.
 *
 *  Created on: Nov 7, 2019
 *      Author: LOCHE Jeremy
 */

#ifndef WS2812_DRIVER_H_
#define WS2812_DRIVER_H_

//#define NIOS2
#define HPS_CV

#ifdef HPS_CV
#include "soc_cv_av/socal/socal.h"
#endif

#ifdef NIOS2
#include "io.h"
#endif


//utility functions to scale calculate scale to reduce intensity
//utility functions to swap R and G colors for the WS2812 data bus
#define WS2812_RGB_TO_GRB(rgb) (((rgb) &0xFF0000)>>8 | ((rgb) & 0x00FF00) << 8|((rgb)&0x0000FF))
#define WS2812_GRB_TO_RGB(rgb) WS2812_RGB_TO_GRB((rgb))
#define WS2812_SCALE8(rgb,scale)  (((((rgb)>>16)&0xFF)*(scale)/0xFF)<<16) | (((((rgb)>>8)&0xFF)*(scale)/0xFF)<<8) | (((((rgb)>>0)&0xFF)*(scale)/0xFF)<<0)

//Low level reading and writing to the registers of the component
//For and HPS processor, use alt_write_word macros
//For NIOS2 processor, use IOWR and IORD macros from

#ifdef NIOS2
#define WS2812_IOWR(base,regnum,value) IOWR(base,regnum,value)
#define WS2812_IORD(base,regnum) IORD(base,regnum)
#endif

#ifdef HPS_CV
#define WS2812_IOWR(base,regnum,value) alt_write_word(((base)+4*(regnum)),(value));
#define WS2812_IORD(base,regnum) alt_read_word((base)+4*(regnum))
#endif


/**
 * Write Control register SYNC bit
 * Calling this macro will issue a SYNC request to the driver, refreshing the LEDs
 */
#define WS2812_SYNC(base) WS2812_IOWR((base),1,0x2)

/**
 * Write Control register RESET bit
 * Calling this macro will issue a RESET request to the driver. Resetting the LED count and putting DOUT low.
 */
#define WS2812_RESET(base) WS2812_IOWR((base),1,0x1)

/**
 * Read the status register IDLE bit
 * Calling this macro will read the IDLE bit from status register.
 * If true, then the driver is free for another SYNC or LEDNUMBER SET request.
 */
#define WS2812_IDLE(base) WS2812_IORD((base),0)

/**
 * Writing LEDNUMBER register value
 * Calling this macro while WS2812_IDLE() is TRUE will reconfigure the number of LEDs in the chain
 * This should not exceed the LED_MAX_NUMBER value of the component.
 */
#define WS2812_SET_LEDNUMBER(base,nb) WS2812_IOWR((base),2,(nb))

/**
 * Raw writing of the LED "idled" register value
 * Calling this macro will set LED[idled] register to the value "data" passed in parameter
 * This doesn't refresh the LED, for this, you need to call WS2812_SYNC()
 */
#define WS2812_SET_DATA(base,idled,data) WS2812_IOWR((base),3+(idled),(data))


/**
 * Register values reading
 */
#define WS2812_GET_LEDNUMBER(base) WS2812_IORD((base),2)
#define WS2812_GET_CONTROL(base) WS2812_IORD((base),1)
#define WS2812_GET_DATA(base,idled) WS2812_IORD((base),3+(idled))

/**
 * Simplicity functions to convert set RGB values on the LEDs instead of GRB.
 * Converts under the hood
 */
#define WS2812_SET_RGB(base,idled,rgb) WS2812_SET_DATA(base,idled,WS2812_RGB_TO_GRB(rgb))
#define WS2812_GET_RGB(base,idled) WS2812_GRB_TO_RGB(WS2812_GET_DATA(base,(idled)))

#endif /* WS2812_DRIVER_H_ */

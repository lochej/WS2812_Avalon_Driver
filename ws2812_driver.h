/*
 * ws2812_drive.h
 *
 *  Created on: Nov 7, 2019
 *      Author: fpga
 */

#ifndef WS2812_DRIVER_H_
#define WS2812_DRIVER_H_

#include "soc_cv_av/socal/socal.h"

//utility functions to scale
#define WS2812_RGB_TO_GRB(rgb) (((rgb) &0xFF0000)>>8 | ((rgb) & 0x00FF00) << 8|((rgb)&0x0000FF))
#define WS2812_GRB_TO_RGB(rgb) WS2812_RGB_TO_GRB((rgb))
#define WS2812_SCALE8(rgb,scale)  (((((rgb)>>16)&0xFF)*(scale)/0xFF)<<16) | (((((rgb)>>8)&0xFF)*(scale)/0xFF)<<8) | (((((rgb)>>0)&0xFF)*(scale)/0xFF)<<0)

#define WS2812_IOWR(base,regnum,value) alt_write_word(((base)+4*(regnum)),(value));
#define WS2812_IORD(base,regnum) alt_read_word((base)+4*(regnum))

#define WS2812_SYNC(base) WS2812_IOWR((base),1,0x2)
#define WS2812_RESET(base) WS2812_IOWR((base),1,0x1)
#define WS2812_IDLE(base) WS2812_IORD((base),0)
#define WS2812_SET_LEDNUMBER(base,nb) WS2812_IOWR((base),2,(nb))
#define WS2812_SET_DATA(base,idled,data) WS2812_IOWR((base),3+(idled),(data))



#define WS2812_GET_LEDNUMBER(base) WS2812_IORD((base),2)
#define WS2812_GET_CONTROL(base) WS2812_IORD((base),1)
#define WS2812_GET_DATA(base,idled) WS2812_IORD((base),3+(idled))


#define WS2812_SET_RGB(base,idled,rgb) WS2812_SET_DATA(base,idled,WS2812_RGB_TO_GRB(rgb))
#define WS2812_GET_RGB(base,idled) WS2812_GRB_TO_RGB(WS2812_GET_DATA(base,(idled)))
#endif /* WS2812_DRIVER_H_ */

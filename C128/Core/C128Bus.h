// SPDX-License-Identifier: GPL-3.0-or-later
#import "C64Bus.h"
#import "VDC8563.h"
@interface C128Bus : C64Bus {
@public
  uint8_t bank1[65536], basic128[32768], system128[16384], characters128[8192];
  uint8_t mmu[12], page0Latch, page1Latch, color1[1024];
  VDC8563 *vdc;
  BOOL columns80, hasC64ROMs, unsupportedCPU;
}
- (void)setMMU:(uint8_t)value reg:(unsigned)reg;
- (BOOL)isC64;
- (uint8_t *)ramPointer:(uint16_t)address;
@end

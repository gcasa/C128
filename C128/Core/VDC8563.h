// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#include <stdint.h>
enum { VDCWidth = 640, VDCHeight = 200 };
@interface VDC8563 : NSObject {
@public
  uint8_t ram[65536], registers[64], selected;
  NSUInteger frames;
}
- (void)reset;
- (uint8_t)read:(uint16_t)address;
- (void)write:(uint8_t)value address:(uint16_t)address;
- (void)renderRGBA:(uint8_t *)pixels;
@end

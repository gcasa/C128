// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#include <stdint.h>
@interface CIA6526 : NSObject {
@public
  unsigned serialEdges;
  uint8_t registers[16], pending, mask;
  uint16_t timerA, timerB, latchA, latchB;
}
- (void)reset;
- (uint8_t)read:(uint8_t)reg;
- (void)write:(uint8_t)value reg:(uint8_t)reg;
- (void)tick;
- (BOOL)irq;
- (uint8_t)port:(NSUInteger)port input:(uint8_t)input;
@end

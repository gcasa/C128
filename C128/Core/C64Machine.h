// SPDX-License-Identifier: GPL-3.0-or-later
#import "C64Bus.h"
#import "CPU6502.h"
@interface C64CPU : CPU6502
- (void)nmi;
@end
@interface C64Machine : NSObject {
@public
  C64Bus *memory;
  C64CPU *cpu;
  BOOL previousNMI;
}
- (void)reset;
- (void)runCycles:(NSUInteger)count;
- (void)restore;
@end

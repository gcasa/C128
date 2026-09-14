// SPDX-License-Identifier: GPL-3.0-or-later
#import "C128Bus.h"
#import "C64Machine.h"
@interface C128Machine : NSObject {
@public
  C128Bus *memory;
  C64CPU *cpu;
  BOOL previousNMI;
}
- (void)reset;
- (void)runCycles:(NSUInteger)count;
- (void)restore;
@end

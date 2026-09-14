// SPDX-License-Identifier: GPL-3.0-or-later
#import "CIA6526.h"
@implementation CIA6526
- (id)init { if ((self = [super init])) [self reset]; return self; }
- (void)reset {
  memset(registers, 0, sizeof registers); pending = mask = 0; serialEdges = 0;
  timerA = timerB = latchA = latchB = 0xffff;
}
- (BOOL)irq { return (pending & mask & 31) != 0; }
- (uint8_t)port:(NSUInteger)p input:(uint8_t)input {
  return (registers[p] & registers[p + 2]) | (input & ~registers[p + 2]);
}
- (uint8_t)read:(uint8_t)r {
  r &= 15;
  switch (r) {
    case 0: case 1: return [self port:r input:255];
    case 4: return timerA; case 5: return timerA >> 8;
    case 6: return timerB; case 7: return timerB >> 8;
    case 13: { uint8_t value = pending | ([self irq] ? 128 : 0); pending = 0; return value; }
    default: return registers[r];
  }
}
- (void)write:(uint8_t)v reg:(uint8_t)r {
  r &= 15;
  switch (r) {
    case 4: latchA = (latchA & 0xff00) | v; break;
    case 5: latchA = (latchA & 255) | (v << 8); if (!(registers[14] & 1)) timerA = latchA; break;
    case 6: latchB = (latchB & 0xff00) | v; break;
    case 7: latchB = (latchB & 255) | (v << 8); if (!(registers[15] & 1)) timerB = latchB; break;
    case 12: if (registers[14] & 64) serialEdges = 16; break;
    case 13: if (v & 128) mask |= v & 31; else mask &= ~(v & 31); return;
    case 14: if (v & 16) timerA = latchA; v &= ~16; break;
    case 15: if (v & 16) timerB = latchB; v &= ~16; break;
  }
  registers[r] = v;
}
- (void)tick {
  BOOL underflowA = NO;
  if ((registers[14] & 0x21) == 1) {
    if (timerA == 0) { timerA = latchA; pending |= 1; underflowA = YES;
      if (registers[14] & 8) registers[14] &= ~1;
    } else timerA--;
  }
  if (underflowA && (registers[14] & 64) && serialEdges && --serialEdges == 0) pending |= 8;
  unsigned mode = (registers[15] >> 5) & 3;
  if ((registers[15] & 1) && (mode == 0 || (mode == 2 && underflowA))) {
    if (timerB == 0) { timerB = latchB; pending |= 2;
      if (registers[15] & 8) registers[15] &= ~1;
    } else timerB--;
  }
}
@end

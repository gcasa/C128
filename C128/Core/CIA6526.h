/* SPDX-License-Identifier: GPL-3.0-or-later */
#import <Foundation/Foundation.h>
#include <stdint.h>
/**
 * Models CIA parallel ports, timer A/B, interrupt masks and acknowledgement,
 * and timer-driven serial output completion. TOD, external serial reception,
 * CNT/FLAG pins, and timer-driven port outputs are not implemented.
 */
@interface CIA6526 : NSObject
{
@public
  /**
   * Remaining half-clock edges before serial output completes.
   */
  unsigned serialEdges;
  /**
   * Register file and latched interrupt pending/mask bits.
   */
  uint8_t registers[16];
  /** Latched CIA interrupt sources. */
  uint8_t pending;
  /** Enabled CIA interrupt sources. */
  uint8_t mask;
  /**
   * Live timer counters and reload latches.
   */
  uint16_t timerA;
  /** Live timer-B counter. */
  uint16_t timerB;
  /** Timer-A reload value. */
  uint16_t latchA;
  /** Timer-B reload value. */
  uint16_t latchB;
}
/**
 * Clears port registers, pending interrupts, masks, and serial progress; sets
 * timer counters and latches to $FFFF.
 */
- (void)reset;
/**
 * Reads reg modulo 16. Port reads combine output latches with pulled-high
 * inputs; reading interrupt control acknowledges and clears all pending
 * sources.
 */
- (uint8_t)read:(uint8_t)reg;
/**
 * Writes value to reg modulo 16, applying timer reload, interrupt-mask
 * set/clear, and serial-output start semantics.
 */
- (void)write:(uint8_t)value reg:(uint8_t)reg;
/**
 * Advances timers by one input clock and completes serial output after sixteen
 * timer-A underflows when output mode is enabled.
 */
- (void)tick;
/**
 * Returns YES if any pending interrupt source is enabled by its mask.
 */
- (BOOL)irq;
/**
 * Returns the port value for port 0 (A) or 1 (B), combining the output latch
 * and direction register with externally supplied input levels. Other port
 * indices are invalid.
 */
- (uint8_t)port:(NSUInteger)port input:(uint8_t)input;
@end

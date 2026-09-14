/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C128Bus.h"
#import "C64Machine.h"
/**
 * Coordinates one C128Bus and the reused 6502 instruction engine acting as an
 * 8502. Owns both objects and advances peripherals after each instruction.
 * Timing is instruction-granular and currently fixed to the PAL slow clock;
 * Z80 execution and 2 MHz scheduling are not implemented.
 */
@interface C128Machine : NSObject
{
@public
  /**
   * Retained C128 bus, including devices and all machine memory.
   */
  C128Bus *memory;
  /**
   * Retained processor instruction engine attached to memory.
   */
  C64CPU *cpu;
  /**
   * Previous CIA2 IRQ level used to detect an NMI rising edge.
   */
  BOOL previousNMI;
}
/**
 * Clears RAM and device state, preserves loaded ROMs and the column-key
 * selection, and enters the 8502 reset vector. The initial Z80 bootstrap is
 * bypassed. The CPU's accumulated cycle counter is preserved.
 */
- (void)reset;
/**
 * Runs until at least count additional CPU cycles have elapsed, completing
 * whole instructions and clocking peripherals. May overshoot by one instruction
 * and interrupt entry. Returns early if an unsupported CPU mode is selected.
 */
- (void)runCycles:(NSUInteger)count;
/**
 * Delivers a RESTORE NMI and advances peripheral clocks by its seven-cycle
 * entry.
 */
- (void)restore;
@end

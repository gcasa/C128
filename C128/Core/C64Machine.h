/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C64Bus.h"
#import "CPU6502.h"
/**
 * Adds nonmaskable interrupt entry to CPU6502. This helper is shared by the
 * C64 and C128 machines; the attached bus supplies the appropriate memory map.
 */
@interface C64CPU : CPU6502
/**
 * Pushes the return address and status, sets interrupt-disable, and loads
 * the mapped $FFFA/$FFFB vector regardless of the current interrupt-disable
 * flag. Adds seven CPU cycles; the caller is responsible for peripheral clocks.
 */
- (void)nmi;
@end
/**
 * Owns a C64Bus and C64CPU, schedules instructions, and delivers VIC/CIA
 * interrupts. Device clocks advance by the elapsed instruction cycle count.
 */
@interface C64Machine : NSObject
{
@public
  /**
   * Retained C64 memory bus and peripheral devices.
   */
  C64Bus *memory;
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
 * Resets bus and CPU state and clears the remembered CIA2 NMI edge; loaded ROMs
 * and accumulated CPU cycles are preserved.
 */
- (void)reset;
/**
 * Executes whole instructions until at least count additional CPU cycles
 * elapse, delivering IRQ/NMI and advancing devices. May overshoot the requested
 * count.
 */
- (void)runCycles:(NSUInteger)count;
/**
 * Delivers RESTORE as an NMI and advances devices by the seven-cycle interrupt
 * entry.
 */
- (void)restore;
@end

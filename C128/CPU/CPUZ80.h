/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef CPUZ80_H_INCLUDED
#define CPUZ80_H_INCLUDED
#import "CPUZ80Bus.h"

/** Z80 flag masks, including the undocumented result bits 3 and 5. */
enum
{
  CPUZ80Carry = 0x01,
  CPUZ80Subtract = 0x02,
  CPUZ80ParityOverflow = 0x04,
  CPUZ80X = 0x08,
  CPUZ80HalfCarry = 0x10,
  CPUZ80Y = 0x20,
  CPUZ80Zero = 0x40,
  CPUZ80Sign = 0x80
};

/** Copyable CPU state. Register pairs are numeric values, independent of host
 * byte order. AF has A in the high byte. Alternate registers use the same
 * layout. EI delay, interrupt lines and the pending NMI latch are included for
 * debugging and deterministic restoration. cycles counts T-states, not machine
 * cycles. */
typedef struct
{
  uint16_t af, bc, de, hl, alternateAF, alternateBC, alternateDE, alternateHL;
  uint16_t ix, iy, sp, pc, wz;
  uint8_t i, r, interruptMode, eiDelay, prefixIndex, q;
  BOOL iff1, iff2, halted, intLine, nmiLine, nmiPending;
  uint64_t cycles;
} CPUZ80State;

/** Original, instruction-level Z80 implementation in Objective-C 1.0. Supports
 * base, CB, ED, DD, FD, DDCB and FDCB instructions, including index halves,
 * SLL and opcode aliases. No ARC or machine-specific dependencies.
 * The CPU retains its bus. All methods must run on the emulation thread.
 * WAIT/BUSRQ, pin-level timing and silicon-specific undocumented flag quirks
 * are outside this instruction-level interface. */
@interface CPUZ80 : NSObject
{
  id<CPUZ80Bus> bus;
  CPUZ80State registers;
  BOOL flagsWritten;
}
/** Initializes and resets the CPU with a non-nil retained bus. */
- (id)initWithBus:(id<CPUZ80Bus>)addressBus;
/** Sets PC/I/R/IM to zero, disables interrupts and exits HALT. Other registers
 * are deterministically zeroed, with AF/SP=$FFFF. Preserves accumulated cycles;
 * memory and devices are untouched. */
- (void)reset;
/** Executes an instruction, one block-repeat iteration, interrupt entry, or
 * four T-states of HALT. Returns elapsed T-states. Repeated index prefixes are
 * consumed together; an address space containing only prefixes is bounded to
 * 65536 fetches per call, with no interrupt accepted inside that prefix stream.
 */
- (NSUInteger)step;
/** Sets the level-sensitive maskable interrupt input. */
- (void)setInterruptLine:(BOOL)asserted;
/** Sets NMI; only a rising edge latches a request. */
- (void)setNMILine:(BOOL)asserted;
/** Latches a single NMI pulse for the next instruction boundary. */
- (void)nmi;
/** Returns a value copy of the complete execution state. */
- (CPUZ80State)state;
/** Restores state. interruptMode, eiDelay and prefixIndex must be 0..2. */
- (void)setState:(CPUZ80State)state;
/** Returns the current program counter. */
- (uint16_t)getProgramCounter;
/** Sets the program counter without changing other state. */
- (void)setProgramCounter:(uint16_t)address;
/** Returns accumulated T-states. */
- (uint64_t)getCycleCount;
@end
#endif

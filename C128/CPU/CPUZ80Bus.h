/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef CPUZ80_BUS_H_INCLUDED
#define CPUZ80_BUS_H_INCLUDED
#import <Foundation/Foundation.h>
#include <stdint.h>

/** Host memory and isolated 16-bit I/O bus for CPUZ80. All accesses may have
 * side effects. The host clocks devices using the T-states returned by -step.
 * Interrupt acknowledge supplies the IM 0 opcode or IM 2 vector byte. */
@protocol CPUZ80Bus <NSObject>
/** Reads one byte of memory. */
- (uint8_t)readMemory:(uint16_t)address;
/** Writes one byte of memory. */
- (void)writeMemory:(uint8_t)value address:(uint16_t)address;
/** Reads one byte from the full 16-bit I/O address. */
- (uint8_t)readPort:(uint16_t)port;
/** Writes one byte to the full 16-bit I/O address. */
- (void)writePort:(uint8_t)value address:(uint16_t)port;
/** Acknowledges INT and returns the byte supplied by the interrupting device.
 * Return $FF for an undriven bus (RST $38 in IM 0). */
- (uint8_t)acknowledgeInterrupt;
/** Notifies daisy-chain devices when the documented RETI opcode executes. */
- (void)didReturnFromInterrupt;
@end
#endif

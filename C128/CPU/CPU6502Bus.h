/*
 * VIC20 - a Commodore VIC-20 emulator.
 * Copyright (C) 2018-2026 Gregory John Casamento
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef CPU6502_BUS_H_INCLUDED
#define CPU6502_BUS_H_INCLUDED

#import <Foundation/Foundation.h>

#ifndef VIC20_UINT_TYPES_DEFINED
#define VIC20_UINT_TYPES_DEFINED
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;
#endif

/**
 * Host-provided address bus used by the reusable 6502 core.
 *
 * A consumer can implement RAM, memory-mapped devices, tracing, or any other
 * machine layout without introducing a dependency from the CPU onto that
 * machine. The CPU does not assume that reads and writes are side-effect free.
 */
@protocol CPU6502Bus <NSObject>
/** Reads and returns the byte mapped at address. */
- (uint8)readMemory:(uint16)address;

/** Writes value to the byte mapped at address. */
- (void)writeMemory:(uint8)value address:(uint16)address;
@end

#endif /* CPU6502_BUS_H_INCLUDED */

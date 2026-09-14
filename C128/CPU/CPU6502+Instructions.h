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

#ifndef VIC20_PROCESSOR_CPU6502_INSTRUCTIONS_H_INCLUDED
#define VIC20_PROCESSOR_CPU6502_INSTRUCTIONS_H_INCLUDED

#import "CPU6502.h"

/**
 * CPU6502 provides the cpu6502 services used by the VIC-20 emulator.
 */
@interface CPU6502 (Instructions)
/** Performs the execute opcode operation. */
- (NSUInteger)executeOpcode:(uint8)opcode;

@end

#endif /* VIC20_PROCESSOR_CPU6502_INSTRUCTIONS_H_INCLUDED */

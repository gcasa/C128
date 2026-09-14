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

#ifndef VIC20_PROCESSOR_CPU6502_H_INCLUDED
#define VIC20_PROCESSOR_CPU6502_H_INCLUDED

#import "CPU6502Bus.h"
#import <Foundation/Foundation.h>

/*
 * Define CPU6502_STANDALONE=1 when embedding only the reusable CPU core.
 * The normal VIC-20 target leaves it undefined and retains its existing API.
 */
#if !defined(CPU6502_STANDALONE)
#import "KeyboardMatrix.h"
#import "VIA6522.h"
#import "VIC20MemoryManager.h"
#import "VIC6560.h"
#endif

// Type definitions for GNUstep compatibility
#ifndef VIC20_UINT_TYPES_DEFINED
#define VIC20_UINT_TYPES_DEFINED
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;
#endif

@class RAM, ROM;
#if !defined(CPU6502_STANDALONE)
@class Datasette;
@class DiskDrive;
@class FallbackBASIC;
#endif

#define ZEROPAGE 0x0000    // 0x0000 - 0x00FF
#define STACKBASE 0x0100   // 0x0100 - 0x01FF
#define RESETVECTOR 0xFFFC // 0xFFFC - 0xFFFD
#define IRQVECTOR 0xFFFE   // 0xFFFE - 0xFFFF

struct status
{
  unsigned int c : 1;
  unsigned int z : 1;
  unsigned int i : 1;
  unsigned int d : 1;
  unsigned int b : 1;
  unsigned int unused : 1;
  unsigned int v : 1;
  unsigned int n : 1;
};

/**
 * CPU6502 provides the cpu6502 services used by the VIC-20 emulator.
 */
@interface CPU6502 : NSObject
{
  // Registers...
  uint8 a;   // Accumulator
  uint8 x;   // X register
  uint8 y;   // Y register
  uint16 pc; // Program counter
  uint8 sp;  // stack pointer
  union
  {
    struct status status; // status register...
    uint8 sr;
  } s;

  // Memory and I/O...
  id<CPU6502Bus> bus;
  RAM *ram; // Owned flat-memory bus used by initWithSize:
#if !defined(CPU6502_STANDALONE)
  VIC6561 *vic;
  VIA6522 *via1;
  VIA6522 *via2;
  KeyboardMatrix *keyboard;
  VIC20MemoryManager *memoryManager;
  Datasette *datasette;
  DiskDrive *diskDrive;
  FallbackBASIC *fallbackBASIC;
  BOOL fallbackROMActive;
#endif

  NSUInteger cycles;
  BOOL debug;

  // Current instruction
  NSNumber *currentInstruction;
}

// Initialize with memory...
/** Initializes the receiver with the supplied emulator state. */
- (id)initWithSize:(NSUInteger)size;

/** Initializes a reusable CPU with a caller-supplied 16-bit address bus. */
- (id)initWithBus:(id<CPU6502Bus>)addressBus;

#if !defined(CPU6502_STANDALONE)
/** Initializes the receiver with the supplied emulator state. */
- (id)initWithRAM:(RAM *)memory VIC:(VIC6561 *)vicChip;

/** Initializes a complete VIC-20 system and all of its emulated devices. */
- (id)initVIC20System;
#endif

// Reset/Interrupt...
/** Restores the receiver to its initial emulated state. */
- (void)reset;

#if !defined(CPU6502_STANDALONE)
/** Restores the receiver to its initial emulated state. */
- (void)resetVIC20System;
#endif

/** Performs the interrupt operation. */
- (void)interrupt;

// Instruction fetch and interpret...
/** Performs the fetch operation. */
- (void)fetch;

/** Performs the execute operation. */
- (void)execute;

/** Performs the execute at location operation. */
- (void)executeAtLocation:(uint16)loc;

/** Performs the execute operation operation. */
- (void)executeOperation:(NSNumber *)operation;

/** Loads the supplied data into the emulator. */
- (void)loadProgramFile:(NSString *)fileName atLocation:(uint16)loc;

/** Performs the run at location operation. */
- (void)runAtLocation:(uint16)loc;

// Memory access (with VIC integration)
/** Returns the requested emulator value. */
- (uint8)readMemory:(uint16)address;

/** Updates the requested emulator value. */
- (void)writeMemory:(uint8)value address:(uint16)address;

/** Updates the requested emulator value. */
- (void)writeMemory:(uint8)value loc:(uint16)address;

/** Updates the requested emulator value. */
- (void)setProgramCounter:(uint16)address;

/** Returns the requested emulator value. */
- (uint16)getProgramCounter;

/** Returns the requested emulator value. */
- (uint8)getAccumulator;

/** Returns the requested emulator value. */
- (uint8)getXRegister;

/** Returns the requested emulator value. */
- (uint8)getYRegister;

/** Returns the current stack pointer. */
- (uint8)getStackPointer;

/** Returns the requested emulator value. */
- (uint8)getStatusRegister;

/** Returns a short disassembly of the instruction at the program counter. */
- (NSString *)getCurrentInstructionDescription;

/** Returns the requested emulator value. */
- (NSUInteger)getCycleCount;

/** Updates the requested emulator value. */
- (void)setDebug:(BOOL)enabled;

// Component access
#if !defined(CPU6502_STANDALONE)
/** Returns the requested emulator value. */
- (VIC6561 *)getVIC;

/** Returns the requested emulator value. */
- (VIA6522 *)getVIA1;

/** Returns the requested emulator value. */
- (VIA6522 *)getVIA2;

/** Returns the requested emulator value. */
- (KeyboardMatrix *)getKeyboard;

/** Returns the requested emulator value. */
- (VIC20MemoryManager *)getMemoryManager;

/** Returns the requested emulator value. */
- (Datasette *)getDatasette;

/** Returns the requested emulator value. */
- (DiskDrive *)getDiskDrive;

// System control
/** Loads the supplied data into the emulator. */
- (void)loadROMs:(NSString *)romPath;

/** Loads the supplied data into the emulator. */
- (BOOL)loadFallbackROMs;

/** Performs the enqueue fallback character operation. */
- (void)enqueueFallbackCharacter:(unichar)character;

/** Loads the supplied data into the emulator. */
- (BOOL)insertCartridge:(NSData *)cartridgeData;

/** Removes the installed cartridge image. */
- (void)removeCartridge;

/** Performs the configure memory expansion operation. */
- (void)configureMemoryExpansion:(BOOL)enable3K
                       enable8K1:(BOOL)enable8K1
                       enable8K2:(BOOL)enable8K2;
#endif

// Run...
/** Performs the run operation. */
- (void)run;

/** Performs the step operation. */
- (void)step;

/** Performs the state operation. */
- (void)state;

/** Performs the tick operation. */
- (void)tick;

// Stack...
/** Performs the push operation. */
- (void)push:(uint8)value;

/** Performs the pop operation. */
- (uint8)pop;

// Debug
/** Performs the debug log with format operation. */
- (void)debugLogWithFormat:(NSString *)formatString, ...;

// Helper methods for flag calculations
/** Performs the update nzflags operation. */
- (void)updateNZFlags:(uint8)value;

/** Updates the requested emulator value. */
- (void)setCarryFlag:(BOOL)carry;

/** Updates the requested emulator value. */
- (void)setOverflowFlag:(BOOL)overflow;

@end

#endif /* VIC20_PROCESSOR_CPU6502_H_INCLUDED */

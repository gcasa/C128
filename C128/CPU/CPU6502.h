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

/* Type definitions for GNUstep compatibility */
#ifndef VIC20_UINT_TYPES_DEFINED
#define VIC20_UINT_TYPES_DEFINED
/** Unsigned 8-bit CPU data value. */
typedef unsigned char uint8;
/** Unsigned 16-bit CPU address value. */
typedef unsigned short uint16;
/** Unsigned 32-bit CPU helper value. */
typedef unsigned int uint32;
#endif

@class RAM, ROM;
#if !defined(CPU6502_STANDALONE)
@class Datasette;
@class DiskDrive;
@class FallbackBASIC;
#endif

/** Base address of the 256-byte zero page. */
#define ZEROPAGE 0x0000 /* 0x0000 - 0x00FF */
/** Base address of the 256-byte hardware stack page. */
#define STACKBASE 0x0100 /* 0x0100 - 0x01FF */
/** Low-byte address of the reset vector. */
#define RESETVECTOR 0xFFFC /* 0xFFFC - 0xFFFD */
/** Low-byte address of the maskable interrupt vector. */
#define IRQVECTOR 0xFFFE /* 0xFFFE - 0xFFFF */

/**
 * Processor status flags in bit order: carry, zero, interrupt-disable, decimal,
 * break, unused, overflow, and negative.
 */
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
 * Reusable 6502 instruction engine. C64 and C128 machines provide CPU6502Bus
 * implementations for their hardware memory maps. Define
 * <code>CPU6502_STANDALONE=1</code> to omit the original VIC-20 device API.
 * The CPU retains its bus; the owning machine advances external devices.
 * Public execution methods operate on the emulation thread.
 */
@interface CPU6502 : NSObject
{
  /* Registers... */
  /** Accumulator register. */
  uint8 a; /* Accumulator */
  /** X index register. */
  uint8 x; /* X register */
  /** Y index register. */
  uint8 y; /* Y register */
  /** Current program counter. */
  uint16 pc; /* Program counter */
  /** Byte offset within the emulated stack page. */
  uint8 sp; /* stack pointer */

  union
  {
    struct status status; /* status register... */
    uint8 sr;
  } s;

  /* Memory and I/O... */
  /** Retained host address bus. */
  id<CPU6502Bus> bus;
  /** Owned flat-memory backing for the original non-standalone initializer. */
  RAM *ram; /* Owned flat-memory bus used by initWithSize: */
#if !defined(CPU6502_STANDALONE)
  /** Original VIC-20 video device, absent in standalone builds. */
  VIC6561 *vic;
  /** Original VIC-20 VIA1 device, absent in standalone builds. */
  VIA6522 *via1;
  /** Original VIC-20 VIA2 device, absent in standalone builds. */
  VIA6522 *via2;
  /** Original VIC-20 keyboard matrix. */
  KeyboardMatrix *keyboard;
  /** Original VIC-20 memory map. */
  VIC20MemoryManager *memoryManager;
  /** Original VIC-20 tape device. */
  Datasette *datasette;
  /** Original VIC-20 disk device. */
  DiskDrive *diskDrive;
  /** Original VIC-20 fallback interpreter. */
  FallbackBASIC *fallbackBASIC;
  /** Whether original VIC-20 fallback firmware is active. */
  BOOL fallbackROMActive;
#endif

  /** Accumulated CPU cycles; preserved across reset. */
  NSUInteger cycles;
  /** Whether diagnostic logging is enabled. */
  BOOL debug;

  /* Current instruction */
  /** Retained opcode wrapper populated by instruction fetch. */
  NSNumber *currentInstruction;
}

/* Initialize with memory... */
/**
 * Creates an owned flat-memory bus of size bytes and initializes the CPU with
 * it. Does not fetch the reset vector; call -reset after initializing memory.
 */
- (id)initWithSize:(NSUInteger)size;

/**
 * <init /> Initializes the CPU with non-nil addressBus and retains it. The
 * caller supplies memory and I/O behavior. Call -reset to load the reset vector
 * before execution.
 */
- (id)initWithBus:(id<CPU6502Bus>)addressBus;

#if !defined(CPU6502_STANDALONE)
/**
 * Initializes the original VIC-20 integration using memory and vicChip.
 * Available only outside standalone builds.
 */
- (id)initWithRAM:(RAM *)memory VIC:(VIC6561 *)vicChip;

/**
 * Creates the original VIC-20 device graph. Not available in standalone C128
 * builds.
 */
- (id)initVIC20System;
#endif

/* Reset/Interrupt... */
/**
 * Clears CPU registers and flags, sets the stack pointer to $FF and
 * interrupt-disable, and reads the mapped reset vector at $FFFC/$FFFD. Does not
 * clear memory or the accumulated cycle count.
 */
- (void)reset;

#if !defined(CPU6502_STANDALONE)
/**
 * Resets the original VIC-20 devices and keyboard while preserving ROM/media
 * selection. Available only outside standalone builds.
 */
- (void)resetVIC20System;
#endif

/**
 * Enters the mapped IRQ vector at $FFFE/$FFFF and adds seven cycles unless
 * interrupts are disabled, in which case it does nothing. The standalone
 * machine must clock peripherals separately.
 */
- (void)interrupt;

/* Instruction fetch and interpret... */
/**
 * Reads the opcode at the program counter into the current instruction without
 * advancing the counter.
 */
- (void)fetch;

/**
 * Fetches and executes one instruction at the current program counter, updating
 * registers, memory, and the cycle count.
 */
- (void)execute;

/**
 * Sets the program counter to loc and executes one instruction there.
 */
- (void)executeAtLocation:(uint16)loc;

/**
 * Executes the opcode represented by operation at the current program counter
 * and advances the CPU by its reported cycle count.
 */
- (void)executeOperation:(NSNumber *)operation;

/**
 * Writes all bytes from fileName through the bus beginning at loc. Treats the
 * file as raw bytes, including any prefix; addresses wrap at 16 bits. Use the
 * machine PRG loader for validated PRG loading.
 */
- (void)loadProgramFile:(NSString *)fileName atLocation:(uint16)loc;

/**
 * Starts at loc and runs the legacy synchronous instruction loop until the
 * current opcode is zero. This loop is unbounded for nonterminating programs;
 * application scheduling uses -step instead.
 */
- (void)runAtLocation:(uint16)loc;

/* Memory access (with VIC integration) */
/**
 * Reads one byte at address through the attached bus, including any
 * memory-mapped I/O side effects.
 */
- (uint8)readMemory:(uint16)address;

/**
 * Writes value to address through the attached bus.
 */
- (void)writeMemory:(uint8)value address:(uint16)address;

/**
 * Compatibility spelling of -writeMemory:address: using address as the
 * location.
 */
- (void)writeMemory:(uint8)value loc:(uint16)address;

/**
 * Sets the program counter to address without executing or resetting the CPU.
 */
- (void)setProgramCounter:(uint16)address;

/**
 * Returns the current 16-bit program counter.
 */
- (uint16)getProgramCounter;

/**
 * Returns the accumulator register.
 */
- (uint8)getAccumulator;

/**
 * Returns the X index register.
 */
- (uint8)getXRegister;

/**
 * Returns the Y index register.
 */
- (uint8)getYRegister;

/**
 * Returns the stack offset within page $01.
 */
- (uint8)getStackPointer;

/**
 * Returns the processor status byte with the unused bit forced to one.
 */
- (uint8)getStatusRegister;

/**
 * Returns an autoreleased disassembly summary of the instruction at the program
 * counter. Reads instruction bytes through the bus.
 */
- (NSString *)getCurrentInstructionDescription;

/**
 * Returns the accumulated CPU cycle count; -reset does not zero it.
 */
- (NSUInteger)getCycleCount;

/**
 * Enables diagnostic logging when enabled is YES.
 */
- (void)setDebug:(BOOL)enabled;

/* Component access */
#if !defined(CPU6502_STANDALONE)
/**
 * Returns the borrowed original VIC-20 video device in non-standalone builds.
 */
- (VIC6561 *)getVIC;

/**
 * Returns the borrowed original VIC-20 VIA1 device in non-standalone builds.
 */
- (VIA6522 *)getVIA1;

/**
 * Returns the borrowed original VIC-20 VIA2 device in non-standalone builds.
 */
- (VIA6522 *)getVIA2;

/**
 * Returns the borrowed original VIC-20 keyboard matrix in non-standalone
 * builds.
 */
- (KeyboardMatrix *)getKeyboard;

/**
 * Returns the borrowed original VIC-20 memory manager in non-standalone builds.
 */
- (VIC20MemoryManager *)getMemoryManager;

/**
 * Returns the borrowed original VIC-20 tape device in non-standalone builds.
 */
- (Datasette *)getDatasette;

/**
 * Returns the borrowed original VIC-20 disk device in non-standalone builds.
 */
- (DiskDrive *)getDiskDrive;

/* System control */
/**
 * Loads original VIC-20 firmware from romPath in non-standalone builds; not the
 * C128 ROM loader.
 */
- (void)loadROMs:(NSString *)romPath;

/**
 * Installs original VIC-20 fallback firmware and reports success. Not available
 * in standalone C128 builds.
 */
- (BOOL)loadFallbackROMs;

/**
 * Queues character for the original VIC-20 fallback interpreter in
 * non-standalone builds.
 */
- (void)enqueueFallbackCharacter:(unichar)character;

/**
 * Attempts to insert cartridgeData into the original VIC-20 memory map and
 * reports success. Not available in standalone C128 builds.
 */
- (BOOL)insertCartridge:(NSData *)cartridgeData;

/**
 * Removes the original VIC-20 cartridge in non-standalone builds.
 */
- (void)removeCartridge;

/**
 * Configures original VIC-20 expansion blocks using enable3K, enable8K1, and
 * enable8K2. Not available in standalone C128 builds.
 */
- (void)configureMemoryExpansion:(BOOL)enable3K
                       enable8K1:(BOOL)enable8K1
                       enable8K2:(BOOL)enable8K2;
#endif

/* Run... */
/**
 * Invokes the legacy synchronous run loop at address zero. Application
 * schedulers should use -step for bounded execution.
 */
- (void)run;

/**
 * Executes one instruction and accounts for its CPU cycles. In standalone
 * builds, external peripheral clocks remain the machine scheduler's
 * responsibility.
 */
- (void)step;

/**
 * Logs current CPU registers and flags; debug mode may also log original VIC-20
 * device state.
 */
- (void)state;

/**
 * Adds one CPU cycle. Original VIC-20 integrations also clock their devices;
 * standalone C128 builds leave external devices to the machine scheduler.
 */
- (void)tick;

/* Stack... */
/**
 * Writes value to the stack at $0100 plus the stack pointer, then decrements
 * the pointer with byte wraparound.
 */
- (void)push:(uint8)value;

/**
 * Increments the stack pointer with byte wraparound and returns the byte at the
 * resulting stack address.
 */
- (uint8)pop;

/* Debug */
/**
 * Logs formatString and its variadic arguments only when debug logging is
 * enabled.
 */
- (void)debugLogWithFormat:(NSString *)formatString, ...;

/* Helper methods for flag calculations */
/**
 * Sets negative from bit 7 of value and zero according to whether value is
 * zero.
 */
- (void)updateNZFlags:(uint8)value;

/**
 * Sets the carry flag to carry.
 */
- (void)setCarryFlag:(BOOL)carry;

/**
 * Sets the overflow flag to overflow.
 */
- (void)setOverflowFlag:(BOOL)overflow;

@end

#endif /* VIC20_PROCESSOR_CPU6502_H_INCLUDED */

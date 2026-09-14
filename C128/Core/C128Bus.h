/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C64Bus.h"
#import "VDC8563.h"
/**
 * <p>C128 address bus with 128 KiB of main RAM, MMU-controlled ROM overlays,
 * shared RAM, relocated zero/stack pages, and independent VIC-II and VDC
 * memory. Inherited C64 mapping is used after a GO64 transition.</p> <p>The
 * public arrays are owned by this object and exposed to the machine, renderers,
 * and tests. Device objects are retained for the lifetime of the bus. Access is
 * confined to the emulation thread. Z80 execution, function ROMs, and reverse
 * page exchange are not implemented.</p>
 * <p>The inherited ROM loader is overridden to require basiclo.rom,
 * basichi.rom, and kernal.rom at 16384 bytes each, plus characters.rom at
 * 8192 bytes. Optional basic64.rom and kernal64.rom must both be 8192 bytes.
 * Validation is atomic. The PRG loader writes bank 0 in native mode and
 * updates BASIC 7.0 text/end pointers for a $1C01 load address. Neither
 * loader starts execution; both return NO and an optional NSError on
 * failure.</p>
 */
@interface C128Bus : C64Bus
{
@public
  /**
   * Additional RAM bank and C128 firmware images, owned by the bus.
   */
  uint8_t bank1[65536];
  /** Native BASIC low and high ROM images. */
  uint8_t basic128[32768];
  /** Native editor, Z80 BIOS, and KERNAL image. */
  uint8_t system128[16384];
  /** Native character-generator image. */
  uint8_t characters128[8192];
  /**
   * MMU registers, pending relocation bank latches, and the second color-RAM
   * bank.
   */
  uint8_t mmu[12];
  /** Pending zero-page bank latch. */
  uint8_t page0Latch;
  /** Pending stack-page bank latch. */
  uint8_t page1Latch;
  /** Second 1024-cell color RAM bank. */
  uint8_t color1[1024];
  /**
   * Retained 80-column video controller with independent video RAM.
   */
  VDC8563 *vdc;
  /**
   * Column-key selection, optional C64-ROM availability, and unsupported-mode
   * stop flag.
   */
  BOOL columns80;
  /** Whether both optional C64 firmware images are loaded. */
  BOOL hasC64ROMs;
  /** Scheduler stop flag for unsupported processor or firmware selection. */
  BOOL unsupportedCPU;
}
/**
 * Writes value to MMU register reg. Register numbers outside 0 through 10
 * are ignored. Page-bank high bytes latch until the corresponding low byte is
 * written. Selecting Z80 execution, or C64 mode without its ROM pair, marks the
 * machine as unsupported so its scheduler stops.
 */
- (void)setMMU:(uint8_t)value reg:(unsigned)reg;
/**
 * Returns YES when MMU mode bit 6 selects the C64 memory map.
 */
- (BOOL)isC64;
/**
 * Returns a borrowed pointer into physical RAM for logical address, applying
 * the current RAM bank, shared-memory window, and forward zero/stack-page
 * relocation. This bypasses ROM and I/O decoding. The pointer remains allocated
 * while the bus exists, but must be resolved again after mapping changes.
 */
- (uint8_t *)ramPointer:(uint16_t)address;
@end

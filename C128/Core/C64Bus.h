/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * AutogsdocSource: C64Bus.m
 * AutogsdocSource: C64Video.m
 */
#import "CPU6502Bus.h"
#import "CIA6526.h"

/** VIC-II output dimensions, including the emulated border. */
enum
{
  C64Width = 384,
  C64Height = 272
};

/**
 * <p>C64 address bus with 64 KiB RAM, 6510 processor port, ROM overlays,
 * VIC-II/SID registers, color RAM, and two CIA6526 devices. Writes beneath ROM
 * reach RAM. SID registers are stored without sound synthesis.</p>
 * <p>Public arrays belong to the bus; CIA devices are retained by it. The
 * machine, renderers, and tests access this state on the same thread.</p>
 */
@interface C64Bus : NSObject <CPU6502Bus>
{
@public
  /**
   * Main RAM and validated BASIC, KERNAL, and character ROM storage.
   */
  uint8_t ram[65536];
  /** C64 BASIC image. */
  uint8_t basic[8192];
  /** C64 KERNAL image. */
  uint8_t kernal[8192];
  /** C64 character image. */
  uint8_t characters[4096];
  /**
   * Color RAM and stored VIC-II/SID register values.
   */
  uint8_t color[1024];
  /** Stored VIC-II registers. */
  uint8_t vic[64];
  /** Stored SID registers; no synthesis is performed. */
  uint8_t sid[32];
  /**
   * Keyboard switches indexed by CIA1 port-A row and port-B column, plus ROM
   * availability.
   */
  BOOL keys[8][8];
  /** Whether the required firmware set has loaded successfully. */
  BOOL hasROMs;
  /**
   * Retained keyboard/timer CIA1 and VIC-bank/serial CIA2 devices.
   */
  CIA6526 *cia1;
  /** Retained serial/video-bank CIA device. */
  CIA6526 *cia2;
  /**
   * Current PAL scan line and cycle within that line.
   */
  NSUInteger raster;
  /** Cycle offset within the current PAL line. */
  NSUInteger rasterCycle;
}
/**
 * Clears RAM, registers, keyboard state, and CIA/raster state while preserving
 * loaded ROM images.
 */
- (void)reset;
/**
 * Loads basic.rom and kernal.rom (8192 bytes each) and characters.rom
 * (4096 bytes) from path. Returns YES on success. All images are validated
 * before any active ROM is replaced. On failure returns NO and, if error is
 * non-NULL, supplies an autoreleased NSError. Does not reset the machine.
 */
- (BOOL)loadROMDirectory:(NSString *)path error:(NSError **)error;
/**
 * Loads data using its two-byte little-endian address prefix. Returns YES
 * and writes the load address through start when non-NULL. BASIC programs at
 * $0801 update the interpreter's end pointers; execution is not started.
 * Rejects empty payloads, address-space overflow, and BASIC programs beyond
 * $9FFF before writing RAM. On failure returns NO and supplies an autoreleased
 * NSError through error when non-NULL.
 */
- (BOOL)loadPRG:(NSData *)data start:(uint16_t *)start error:(NSError **)error;
/**
 * Advances both CIAs by one slow-clock cycle and updates the PAL raster counter
 * and raster interrupt condition.
 */
- (void)tick;
/**
 * Returns YES when CIA1 or an enabled VIC-II interrupt is pending.
 */
- (BOOL)irq;
/**
 * Reads address through the VIC-II view using CIA2 bank selection,
 * independently of CPU ROM banking.
 */
- (uint8_t)videoRead:(uint16_t)address;
/**
 * Releases all switches in the emulated keyboard matrix.
 */
- (void)releaseKeys;
@end

/**
 * Frame-based VIC-II rendering shared by the C64 and C128 buses.
 */
@interface C64Bus (Video)
/**
 * Renders the current VIC-II state into caller-owned pixels. The buffer must
 * hold at least <code>C64Width * C64Height * 4</code> bytes of tightly packed
 * red, green, blue, alpha components. Alpha is always 255. No CPU cycles are
 * executed; raster-sensitive effects are approximated from current registers.
 */
- (void)renderRGBA:(uint8_t *)pixels;
@end

/* SPDX-License-Identifier: GPL-3.0-or-later */
#import <Foundation/Foundation.h>
#include <stdint.h>

/** Standard VDC output dimensions before host-side vertical scaling. */
enum
{
  VDCWidth = 640,
  VDCHeight = 200
};

/**
 * <p>Models an indexed VDC register interface and 64 KiB of private video RAM.
 * RAM transfers, fills, and copies complete immediately; status always reports
 * ready and vertical blank.</p>
 * <p>The renderer targets standard 80-column text and basic bitmap output.
 * It does not emulate programmable geometry or raster timing fully. All RAM
 * and registers are owned by the receiver.</p>
 */
@interface VDC8563 : NSObject
{
@public
  /**
   * Private video RAM, indexed register file, and selected register number.
   */
  uint8_t ram[65536];
  /** Device register storage. */
  uint8_t registers[64];
  /** Currently selected VDC register. */
  uint8_t selected;
  /**
   * Render-call counter used for approximate blinking.
   */
  NSUInteger frames;
}
/**
 * Clears video RAM, all registers, the selected register, and the render-frame
 * counter.
 */
- (void)reset;
/**
 * Reads status at an even address or the selected register at an odd address.
 * Reading data register 31 fetches video RAM and increments the 16-bit update
 * address.
 */
- (uint8_t)read:(uint16_t)address;
/**
 * Selects a register with value at an even address, or writes the selected
 * register at an odd address. Data transfers and block operations update video
 * RAM immediately; addresses wrap at 64 KiB.
 */
- (void)write:(uint8_t)value address:(uint16_t)address;
/**
 * Renders into caller-owned pixels, which must hold at least <code>VDCWidth *
 * VDCHeight * 4</code> tightly packed RGBA bytes. Alpha is 255. Advances the
 * frame counter used for approximate cursor and attribute blinking; no CPU
 * cycles are executed.
 */
- (void)renderRGBA:(uint8_t *)pixels;
@end

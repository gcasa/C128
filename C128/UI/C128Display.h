/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef C128_DISPLAY_H
#define C128_DISPLAY_H

#import <AppKit/AppKit.h>
@class C128Machine;

/**
 * Scales either the VIC-II or VDC bitmap and translates host key events into
 * the shared keyboard matrix. The application delegate owns the machine;
 * machine is a borrowed pointer that must be assigned
 * before drawing or handling input. A true wide selects
 * the VDC. Bitmap storage and held-key state are owned by the view.
 */
@interface C128Display : NSView
{
@public
  /** Borrowed machine pointer assigned by AppDelegate before use. */
  C128Machine *machine;
  /** Owned VIC-II and VDC output bitmaps. */
  NSBitmapImageRep *bitmap;
  /** Owned VDC output bitmap. */
  NSBitmapImageRep *wideBitmap;
  /** YES selects the 80-column VDC; NO selects the 40-column VIC-II. */
  BOOL wide;
  /** Owned mapping from host key codes to emulated matrix switches. */
  NSMutableDictionary *held;
  /** Current host modifier-key mask. */
  NSUInteger modifiers;
}
/**
 * Clears this view's held keys and modifier flags and releases the shared
 * emulated keyboard matrix. Used when focus changes, a window closes, or the
 * machine resets.
 */
- (void)clearKeys;
@end

#endif

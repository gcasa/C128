// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef C128_DISPLAY_H
#define C128_DISPLAY_H

#import <AppKit/AppKit.h>
@class C128Machine;

@interface C128Display : NSView {
@public
  C128Machine *machine;
  NSBitmapImageRep *bitmap, *wideBitmap;
  BOOL wide;
  NSMutableDictionary *held;
  NSUInteger modifiers;
}
- (void)clearKeys;
@end

#endif

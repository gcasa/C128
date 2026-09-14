/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef C128_APP_DELEGATE_H
#define C128_APP_DELEGATE_H

#import <AppKit/AppKit.h>
@class C128Machine, C128Display;

/**
 * Owns the emulated machine, display windows, and frame timer. Builds the
 * AppKit menus, handles ROM/PRG panels, and coordinates both monitors through
 * one machine. All callbacks and emulation run on the application thread.
 */
@interface AppDelegate : NSObject
{
  /** Owned machine shared by both monitor windows. */
  C128Machine *machine;
  /** Owned primary and optional secondary windows. */
  NSWindow *window;
  /** Owned optional secondary monitor window. */
  NSWindow *secondWindow;
  /** Owned display views for the primary and optional secondary windows. */
  C128Display *display;
  /** Owned optional secondary display view. */
  C128Display *secondDisplay;
  /** Retained timer driving frame pacing and redraws. */
  NSTimer *timer;
  /** Whether instruction execution is paused. */
  BOOL paused;
  /** Wall-clock timestamp of the previous frame callback. */
  NSTimeInterval lastTime;
  /** Unspent CPU cycles carried between frame callbacks. */
  double cycleBudget;
}
/**
 * Resets the machine when ROMs are loaded, clears both views' held keys,
 * resumes execution, and refreshes window titles. sender is an optional action
 * source and is ignored.
 */
- (void)reset:(id)sender;
/**
 * Refreshes both monitor titles and redraws them. When a second display exists,
 * its selected video device is kept opposite to the first display.
 */
- (void)updateDisplayTitles;
/**
 * Clears held keys and modifiers in both display views and releases the shared
 * keyboard matrix.
 */
- (void)clearKeys;
@end

#endif

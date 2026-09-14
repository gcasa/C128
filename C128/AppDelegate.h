// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef C128_APP_DELEGATE_H
#define C128_APP_DELEGATE_H

#import <AppKit/AppKit.h>
@class C128Machine, C128Display;

@interface AppDelegate : NSObject {
  C128Machine *machine;
  NSWindow *window, *secondWindow;
  C128Display *display, *secondDisplay;
  NSTimer *timer;
  BOOL paused;
  NSTimeInterval lastTime;
  double cycleBudget;
}
- (void)reset:(id)sender;
- (void)updateDisplayTitles;
- (void)clearKeys;
@end

#endif

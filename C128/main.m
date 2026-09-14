// SPDX-License-Identifier: GPL-3.0-or-later
#import "AppDelegate.h"

int main(int argc, char **argv) {
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess(argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new]; {
    [NSApplication sharedApplication]; 
#ifndef GNUSTEP
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
#endif
    AppDelegate *delegate = [AppDelegate new]; [NSApp setDelegate:(id)delegate];
    [NSApp run]; [delegate release];
  }
  [pool drain]; return 0;
}

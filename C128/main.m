// SPDX-License-Identifier: GPL-3.0-or-later
#import <AppKit/AppKit.h>
#import "C128Machine.h"

@interface C128Display : NSView {
@public
  C128Machine *machine;
  NSBitmapImageRep *bitmap, *wideBitmap;
  BOOL wide;
  NSMutableDictionary *held;
  NSUInteger modifiers;
}
@end
@implementation C128Display
- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:C64Width
      pixelsHigh:C64Height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
      colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:C64Width * 4 bitsPerPixel:32];
    wideBitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:VDCWidth pixelsHigh:VDCHeight bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:VDCWidth*4 bitsPerPixel:32];
    held = [NSMutableDictionary new];
  }
  return self;
}
- (void)dealloc { [held release]; [bitmap release]; [wideBitmap release]; [super dealloc]; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)drawRect:(NSRect)rect {
  [[NSColor blackColor] setFill]; NSRectFill([self bounds]);
  if (!machine->memory->hasROMs) {
    NSString *message = @"C128\nChoose ROM Folder… from the File menu to start.\n\nRequires C128 BASIC low/high, KERNAL, and character ROMs.";
    [message drawInRect:NSInsetRect([self bounds], 60, 100) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFixedPitchFontOfSize:18], NSFontAttributeName, [NSColor greenColor], NSForegroundColorAttributeName, nil]];
    return;
  }
  NSBitmapImageRep *active = wide ? wideBitmap : bitmap;
  unsigned width = wide ? VDCWidth : C64Width, height = wide ? VDCHeight : C64Height;
  if (wide) [machine->memory->vdc renderRGBA:[active bitmapData]];
  else [machine->memory renderRGBA:[active bitmapData]];
  NSSize size = [self bounds].size;
  unsigned displayHeight = wide ? height * 2 : height;
  CGFloat scale = MIN(size.width / width, size.height / displayHeight);
  NSRect target = NSMakeRect((size.width - width * scale) / 2,
      (size.height - displayHeight * scale) / 2, width * scale, displayHeight * scale);
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
  [active drawInRect:target];
}
- (void)rebuildKeys {
  [machine->memory releaseKeys];
  NSEnumerator *enumerator = [[held allValues] objectEnumerator];
  NSArray *key;
  while ((key = [enumerator nextObject])) {
    machine->memory->keys[[[key objectAtIndex:0] intValue]][[[key objectAtIndex:1] intValue]] = YES;
    if ([[key objectAtIndex:2] boolValue]) machine->memory->keys[1][7] = YES;
  }
  if (modifiers & NSControlKeyMask) machine->memory->keys[7][2] = YES;
  if (modifiers & NSAlternateKeyMask) machine->memory->keys[7][5] = YES;
  if ((modifiers & NSShiftKeyMask) && ![held count]) machine->memory->keys[1][7] = YES;
}
- (void)clearKeys { [held removeAllObjects]; modifiers = 0; [self rebuildKeys]; }
- (void)flagsChanged:(NSEvent *)event { modifiers = [event modifierFlags]; [self rebuildKeys]; }
- (void)keyDown:(NSEvent *)event {
  if ([event modifierFlags] & NSCommandKeyMask) { [super keyDown:event]; return; }
  if ([event isARepeat]) return;
  NSString *text = [event characters];
  if (![text length]) return;
  unichar c = [text characterAtIndex:0];
  BOOL shifted = NO; int row = -1, col = -1;
  // Row = CIA1 port A bit; column = CIA1 port B bit.
  NSArray *rows = [NSArray arrayWithObjects:@"\177\r→⑦①③⑤↓", @"3WA4ZSE⇧", @"5RD6CFTX", @"7YG8BHUV",
                    @"9IJ0MKON", @"+PL-.:@,", @"£*;⌂⇧=↑/", @"1←⌃2 ⌘Q⎋", nil];
  if (c >= 'a' && c <= 'z') c -= 32;
  else if (c >= 'A' && c <= 'Z') shifted = ([event modifierFlags] & NSShiftKeyMask) != 0;
  NSString *symbols = @"!\"#$%&'()<>?";
  NSRange symbol = [symbols rangeOfString:[NSString stringWithCharacters:&c length:1]];
  if (symbol.location != NSNotFound) {
    c = [@"123456789,./" characterAtIndex:symbol.location]; shifted = YES;
  }
  switch (c) {
    case NSLeftArrowFunctionKey: c = 0x2192; shifted = YES; break;
    case NSRightArrowFunctionKey: c = 0x2192; break;
    case NSUpArrowFunctionKey: c = 0x2193; shifted = YES; break;
    case NSDownArrowFunctionKey: c = 0x2193; break;
    case NSHomeFunctionKey: c = 0x2302; break;
    case NSF1FunctionKey: c = 0x2460; break;
    case NSF2FunctionKey: c = 0x2460; shifted = YES; break;
    case NSF3FunctionKey: c = 0x2462; break;
    case NSF4FunctionKey: c = 0x2462; shifted = YES; break;
    case NSF5FunctionKey: c = 0x2464; break;
    case NSF6FunctionKey: c = 0x2464; shifted = YES; break;
    case NSF7FunctionKey: c = 0x2466; break;
    case NSF8FunctionKey: c = 0x2466; shifted = YES; break;
    case 27: c = 0x238b; break;
    case '\n': c = '\r'; break;
  }
  for (int r = 0; r < 8; r++) for (int k = 0; k < 8; k++)
    if ([[rows objectAtIndex:r] characterAtIndex:k] == c) { row = r; col = k; }
  if (row >= 0) [held setObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:row], [NSNumber numberWithInt:col], [NSNumber numberWithBool:shifted], nil] forKey:[NSNumber numberWithUnsignedInt:[event keyCode]]];
  modifiers = [event modifierFlags]; [self rebuildKeys];
}
- (void)keyUp:(NSEvent *)event { [held removeObjectForKey:[NSNumber numberWithUnsignedInt:[event keyCode]]]; [self rebuildKeys]; }
@end

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
@implementation AppDelegate
- (void)addItem:(NSString *)title action:(SEL)action key:(NSString *)key menu:(NSMenu *)menu {
  NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
  [item setTarget:self];
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
  machine = [C128Machine new];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Main"];
  [NSApp setMainMenu:menu]; [menu release];
  NSMenuItem *appItem = [menu addItemWithTitle:@"C128" action:NULL keyEquivalent:@""];
  NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"C128"] autorelease]; [appItem setSubmenu:appMenu];
  [appMenu addItemWithTitle:@"Quit C128" action:@selector(terminate:) keyEquivalent:@"q"];
  NSMenuItem *fileItem = [menu addItemWithTitle:@"File" action:NULL keyEquivalent:@""];
  NSMenu *file = [[[NSMenu alloc] initWithTitle:@"File"] autorelease]; [fileItem setSubmenu:file];
  [self addItem:@"Choose ROM Folder…" action:@selector(chooseROMs:) key:@"" menu:file];
  [self addItem:@"Load PRG…" action:@selector(loadPRG:) key:@"o" menu:file];
  NSMenuItem *machineItem = [menu addItemWithTitle:@"Machine" action:NULL keyEquivalent:@""];
  NSMenu *controls = [[[NSMenu alloc] initWithTitle:@"Machine"] autorelease]; [machineItem setSubmenu:controls];
  [self addItem:@"Reset" action:@selector(reset:) key:@"r" menu:controls];
  [self addItem:@"Pause / Resume" action:@selector(pause:) key:@"p" menu:controls];
  [self addItem:@"Show 40 / 80 Column Display" action:@selector(toggleDisplay:) key:@"8" menu:controls];
  [self addItem:@"Show Both Displays" action:@selector(toggleBothDisplays:) key:@"b" menu:controls];
  [self addItem:@"Boot in 40 / 80 Columns" action:@selector(toggleBoot:) key:@"" menu:controls];
  [self addItem:@"RESTORE" action:@selector(restore:) key:@"" menu:controls];
  window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 768, 544)
      styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
      backing:NSBackingStoreBuffered defer:NO];
  [window setReleasedWhenClosed:NO]; [window setDelegate:(id)self];
  [window setContentMinSize:NSMakeSize(384, 272)];
  display = [[C128Display alloc] initWithFrame:NSMakeRect(0, 0, 768, 544)];
  display->machine = machine; [window setContentView:display];
  [self updateDisplayTitles];
  [window center]; [window makeKeyAndOrderFront:nil]; [window makeFirstResponder:display];
  NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"ROMDirectory"];
  NSString *local = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"roms"];
  NSString *adjacent = [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"../roms"];
  if ((saved && [machine->memory loadROMDirectory:saved error:NULL]) ||
      [machine->memory loadROMDirectory:local error:NULL] ||
      [machine->memory loadROMDirectory:adjacent error:NULL]) [machine reset];
  lastTime = [NSDate timeIntervalSinceReferenceDate];
  timer = [[NSTimer scheduledTimerWithTimeInterval:1.0/60 target:self selector:@selector(frame:)
      userInfo:nil repeats:YES] retain];
  [NSApp activateIgnoringOtherApps:YES];
}
- (void)frame:(NSTimer *)sender {
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  double elapsed = MAX(0.0, MIN(now - lastTime, 0.05)); lastTime = now;
  if (!paused && machine->memory->hasROMs) {
    cycleBudget += elapsed * 985248.0;
    NSUInteger before = [machine->cpu getCycleCount];
    if (cycleBudget >= 1) [machine runCycles:(NSUInteger)cycleBudget];
    cycleBudget -= [machine->cpu getCycleCount] - before;
    if (machine->memory->unsupportedCPU) { paused = YES; [self updateDisplayTitles]; }
  }
  [display setNeedsDisplay:YES];
  if ([secondWindow isVisible]) [secondDisplay setNeedsDisplay:YES];
}
- (void)showError:(NSError *)error { [[NSAlert alertWithError:error] runModal]; }
- (void)chooseROMs:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel]; [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO]; [panel setAllowsMultipleSelection:NO];
  if ([panel runModal] != NSOKButton) return;
  NSError *error = nil;
  if (![machine->memory loadROMDirectory:[panel filename] error:&error]) { [self showError:error]; return; }
  [[NSUserDefaults standardUserDefaults] setObject:[panel filename] forKey:@"ROMDirectory"];
  [self reset:nil];
}
- (void)loadPRG:(id)sender {
  if (!machine->memory->hasROMs) { [self chooseROMs:nil]; return; }
  NSOpenPanel *panel = [NSOpenPanel openPanel]; [panel setAllowsMultipleSelection:NO];
  if ([panel runModal] != NSOKButton) return;
  NSError *error = nil; uint16_t start = 0;
  NSData *data = [NSData dataWithContentsOfFile:[panel filename]];
  if (!data) { NSRunAlertPanel(@"Cannot read PRG", @"The selected file could not be read.", @"OK", nil, nil); return; }
  if (![machine->memory loadPRG:data start:&start error:&error]) { [self showError:error]; return; }
  NSAlert *alert = [NSAlert new]; [alert setMessageText:@"Program loaded"];
  [alert setInformativeText:start == ([machine->memory isC64] ? 0x0801 : 0x1c01) ? @"Type RUN at the BASIC prompt to start the program."
      : [NSString stringWithFormat:@"Loaded at $%04X (%u). Use the program's documented SYS entry address to start it.", start, start]];
  [alert runModal]; [alert release];
}
- (void)clearKeys { [display clearKeys]; [secondDisplay clearKeys]; }
- (void)updateDisplayTitles {
  NSString *status = machine->memory->unsupportedCPU ? @"Stopped: Z80 or missing C64 ROMs" : (paused ? @"Paused" : @"PAL");
  [window setTitle:[NSString stringWithFormat:@"C128 — %@ — %@", display->wide ? @"80 Columns (VDC)" : @"40 Columns (VIC-II)", status]];
  if (secondDisplay) {
    secondDisplay->wide = !display->wide;
    [secondWindow setTitle:[NSString stringWithFormat:@"C128 — %@ — %@", secondDisplay->wide ? @"80 Columns (VDC)" : @"40 Columns (VIC-II)", status]];
    [secondDisplay setNeedsDisplay:YES];
  }
  [display setNeedsDisplay:YES];
}
- (void)reset:(id)sender {
  if (machine->memory->hasROMs) [machine reset];
  [self clearKeys]; paused = NO; cycleBudget = 0; [self updateDisplayTitles];
}
- (void)pause:(id)sender {
  paused = !paused; cycleBudget = 0; [self clearKeys]; [self updateDisplayTitles];
}
- (void)toggleDisplay:(id)sender {
  display->wide = !display->wide; [self updateDisplayTitles];
}
- (void)toggleBothDisplays:(id)sender {
  [self clearKeys];
  if ([window isVisible] && [secondWindow isVisible]) {
    [secondWindow orderOut:nil]; [window makeKeyAndOrderFront:nil]; return;
  }
  if (!secondWindow) {
    secondWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 768, 544)
      styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
      backing:NSBackingStoreBuffered defer:NO];
    [secondWindow setReleasedWhenClosed:NO]; [secondWindow setDelegate:(id)self];
    [secondWindow setContentMinSize:NSMakeSize(384, 272)];
    secondDisplay = [[C128Display alloc] initWithFrame:NSMakeRect(0, 0, 768, 544)];
    secondDisplay->machine = machine; [secondWindow setContentView:secondDisplay];
    [secondWindow makeFirstResponder:secondDisplay];
    // Arrange both monitors within the current screen; users can resize them independently.
    NSScreen *screen = [window screen]; if (!screen) screen = [NSScreen mainScreen];
    NSRect available = NSInsetRect([screen visibleFrame], 12, 12);
    CGFloat width = MIN(768, (available.size.width - 12) / 2);
    CGFloat height = MIN(566, available.size.height);
    NSRect left = NSMakeRect(available.origin.x, NSMaxY(available) - height, width, height);
    [window setFrame:left display:YES];
    left.origin.x += width + 12; [secondWindow setFrame:left display:YES];
  }
  [self updateDisplayTitles];
  [window orderFront:nil]; [secondWindow makeKeyAndOrderFront:nil];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
  if ([item action] == @selector(toggleBothDisplays:))
    [item setState:([window isVisible] && [secondWindow isVisible]) ? NSOnState : NSOffState];
  return YES;
}
- (void)toggleBoot:(id)sender {
  machine->memory->columns80 = !machine->memory->columns80;
  display->wide = machine->memory->columns80; [self reset:nil];
}
- (void)restore:(id)sender { if (machine->memory->hasROMs) [machine restore]; }
- (void)windowDidResignKey:(NSNotification *)note { [self clearKeys]; }
- (void)windowWillClose:(NSNotification *)note { [self clearKeys]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return YES; }
- (void)applicationWillTerminate:(NSNotification *)note { [timer invalidate]; }
- (void)dealloc { [timer release]; [secondDisplay release]; [secondWindow release]; [display release]; [window release]; [machine release]; [super dealloc]; }
@end
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

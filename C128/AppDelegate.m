/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "AppDelegate.h"
#import "Core/C128Machine.h"
#import "UI/C128Display.h"

@implementation AppDelegate

- (void)addItem:(NSString *)title
         action:(SEL)action
            key:(NSString *)key
           menu:(NSMenu *)menu
{
  NSMenuItem *item = [menu addItemWithTitle:title
                                     action:action
                              keyEquivalent:key];
  [item setTarget:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
  machine = [C128Machine new];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Main"];
  [NSApp setMainMenu:menu];
  [menu release];
  NSMenuItem *appItem = [menu addItemWithTitle:@"C128"
                                        action:NULL
                                 keyEquivalent:@""];
  NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"C128"] autorelease];
  [appItem setSubmenu:appMenu];
  [appMenu addItemWithTitle:@"Quit C128"
                     action:@selector (terminate:)
              keyEquivalent:@"q"];
  NSMenuItem *fileItem = [menu addItemWithTitle:@"File"
                                         action:NULL
                                  keyEquivalent:@""];
  NSMenu *file = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
  [fileItem setSubmenu:file];
  [self addItem:@"Choose ROM Folder…"
         action:@selector (chooseROMs:)
            key:@""
           menu:file];
  [self addItem:@"Load PRG…" action:@selector (loadPRG:) key:@"o" menu:file];
  NSMenuItem *machineItem = [menu addItemWithTitle:@"Machine"
                                            action:NULL
                                     keyEquivalent:@""];
  NSMenu *controls = [[[NSMenu alloc] initWithTitle:@"Machine"] autorelease];
  [machineItem setSubmenu:controls];
  [self addItem:@"Reset" action:@selector (reset:) key:@"r" menu:controls];
  [self addItem:@"Pause / Resume"
         action:@selector (pause:)
            key:@"p"
           menu:controls];
  [self addItem:@"Show 40 / 80 Column Display"
         action:@selector (toggleDisplay:)
            key:@"8"
           menu:controls];
  [self addItem:@"Show Both Displays"
         action:@selector (toggleBothDisplays:)
            key:@"b"
           menu:controls];
  [self addItem:@"Boot in 40 / 80 Columns"
         action:@selector (toggleBoot:)
            key:@""
           menu:controls];
  [self addItem:@"RESTORE" action:@selector (restore:) key:@"" menu:controls];
  window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect (0, 0, 768, 544)
                styleMask:NSTitledWindowMask | NSClosableWindowMask
                          | NSMiniaturizableWindowMask | NSResizableWindowMask
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [window setReleasedWhenClosed:NO];
  [window setDelegate:(id)self];
  [window setContentMinSize:NSMakeSize (384, 272)];
  display = [[C128Display alloc] initWithFrame:NSMakeRect (0, 0, 768, 544)];
  display->machine = machine;
  [window setContentView:display];
  [self updateDisplayTitles];
  NSString *bundled = [[[NSBundle mainBundle] resourcePath]
      stringByAppendingPathComponent:@"roms"];
  NSString *besideExecutable = [[[[NSBundle mainBundle] executablePath]
      stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"roms"];
  NSString *saved =
      [[NSUserDefaults standardUserDefaults] stringForKey:@"ROMDirectory"];
  NSString *local = [[[NSFileManager defaultManager] currentDirectoryPath]
      stringByAppendingPathComponent:@"roms"];
  NSString *adjacent =
      [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent]
          stringByAppendingPathComponent:@"../roms"];
  if ([machine->memory loadROMDirectory:bundled error:NULL] ||
      [machine->memory loadROMDirectory:besideExecutable error:NULL] ||
      (saved && [machine->memory loadROMDirectory:saved error:NULL]) ||
      [machine->memory loadROMDirectory:local error:NULL] ||
      [machine->memory loadROMDirectory:adjacent error:NULL])
    [machine reset];
  [window center];
  [window makeKeyAndOrderFront:nil];
  [window makeFirstResponder:display];
  lastTime = [NSDate timeIntervalSinceReferenceDate];
  timer = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 60
                                            target:self
                                          selector:@selector (frame:)
                                          userInfo:nil
                                           repeats:YES] retain];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)frame:(NSTimer *)sender
{
  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  double elapsed = MAX (0.0, MIN (now - lastTime, 0.05));
  lastTime = now;
  if (!paused && machine->memory->hasROMs)
    {
      cycleBudget += elapsed * 985248.0;
      NSUInteger before = [machine->cpu getCycleCount];
      if (cycleBudget >= 1)
        [machine runCycles:(NSUInteger)cycleBudget];
      cycleBudget -= [machine->cpu getCycleCount] - before;
      if (machine->memory->unsupportedCPU)
        {
          paused = YES;
          [self updateDisplayTitles];
        }
    }
  [display setNeedsDisplay:YES];
  if ([secondWindow isVisible])
    [secondDisplay setNeedsDisplay:YES];
}

- (void)showError:(NSError *)error
{
  [[NSAlert alertWithError:error] runModal];
}

- (void)chooseROMs:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO];
  [panel setAllowsMultipleSelection:NO];
  if ([panel runModal] != NSOKButton)
    return;
  NSError *error = nil;
  if (![machine->memory loadROMDirectory:[panel filename] error:&error])
    {
      [self showError:error];
      return;
    }
  [[NSUserDefaults standardUserDefaults] setObject:[panel filename]
                                            forKey:@"ROMDirectory"];
  [self reset:nil];
}

- (void)loadPRG:(id)sender
{
  if (!machine->memory->hasROMs)
    {
      [self chooseROMs:nil];
      return;
    }
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setAllowsMultipleSelection:NO];
  if ([panel runModal] != NSOKButton)
    return;
  NSError *error = nil;
  uint16_t start = 0;
  NSData *data = [NSData dataWithContentsOfFile:[panel filename]];
  if (!data)
    {
      NSRunAlertPanel (@"Cannot read PRG",
                       @"The selected file could not be read.", @"OK", nil,
                       nil);
      return;
    }
  if (![machine->memory loadPRG:data start:&start error:&error])
    {
      [self showError:error];
      return;
    }
  NSAlert *alert = [NSAlert new];
  [alert setMessageText:@"Program loaded"];
  [alert
      setInformativeText:
          start == ([machine->memory isC64] ? 0x0801 : 0x1c01)
              ? @"Type RUN at the BASIC prompt to start the program."
              : [NSString
                    stringWithFormat:
                        @"Loaded at $%04X (%u). Use the program's documented SYS entry address to start it.",
                        start, start]];
  [alert runModal];
  [alert release];
}

- (void)clearKeys
{
  [display clearKeys];
  [secondDisplay clearKeys];
}

- (void)updateDisplayTitles
{
  NSString *status = machine->memory->unsupportedCPU
                         ? @"Stopped: Z80 or missing C64 ROMs"
                         : (paused ? @"Paused" : @"PAL");
  [window setTitle:[NSString stringWithFormat:@"C128 — %@ — %@",
                                              display->wide
                                                  ? @"80 Columns (VDC)"
                                                  : @"40 Columns (VIC-II)",
                                              status]];
  if (secondDisplay)
    {
      secondDisplay->wide = !display->wide;
      [secondWindow
          setTitle:[NSString stringWithFormat:@"C128 — %@ — %@",
                                              secondDisplay->wide
                                                  ? @"80 Columns (VDC)"
                                                  : @"40 Columns (VIC-II)",
                                              status]];
      [secondDisplay setNeedsDisplay:YES];
    }
  [display setNeedsDisplay:YES];
}

- (void)reset:(id)sender
{
  if (machine->memory->hasROMs)
    [machine reset];
  [self clearKeys];
  paused = NO;
  cycleBudget = 0;
  [self updateDisplayTitles];
}

- (void)pause:(id)sender
{
  paused = !paused;
  cycleBudget = 0;
  [self clearKeys];
  [self updateDisplayTitles];
}

- (void)toggleDisplay:(id)sender
{
  display->wide = !display->wide;
  [self updateDisplayTitles];
}

- (void)toggleBothDisplays:(id)sender
{
  [self clearKeys];
  if ([window isVisible] && [secondWindow isVisible])
    {
      [secondWindow orderOut:nil];
      [window makeKeyAndOrderFront:nil];
      return;
    }
  if (!secondWindow)
    {
      secondWindow = [[NSWindow alloc]
          initWithContentRect:NSMakeRect (0, 0, 768, 544)
                    styleMask:NSTitledWindowMask | NSClosableWindowMask
                              | NSMiniaturizableWindowMask
                              | NSResizableWindowMask
                      backing:NSBackingStoreBuffered
                        defer:NO];
      [secondWindow setReleasedWhenClosed:NO];
      [secondWindow setDelegate:(id)self];
      [secondWindow setContentMinSize:NSMakeSize (384, 272)];
      secondDisplay =
          [[C128Display alloc] initWithFrame:NSMakeRect (0, 0, 768, 544)];
      secondDisplay->machine = machine;
      [secondWindow setContentView:secondDisplay];
      [secondWindow makeFirstResponder:secondDisplay];
      /* Arrange both monitors within the current screen; users can resize them
       * independently. */
      NSScreen *screen = [window screen];
      if (!screen)
        screen = [NSScreen mainScreen];
      NSRect available = NSInsetRect ([screen visibleFrame], 12, 12);
      CGFloat width = MIN (768, (available.size.width - 12) / 2);
      CGFloat height = MIN (566, available.size.height);
      NSRect left = NSMakeRect (available.origin.x, NSMaxY (available) - height,
                                width, height);
      [window setFrame:left display:YES];
      left.origin.x += width + 12;
      [secondWindow setFrame:left display:YES];
    }
  [self updateDisplayTitles];
  [window orderFront:nil];
  [secondWindow makeKeyAndOrderFront:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
  if ([item action] == @selector (toggleBothDisplays:))
    [item setState:([window isVisible] && [secondWindow isVisible])
                       ? NSOnState
                       : NSOffState];
  return YES;
}

- (void)toggleBoot:(id)sender
{
  machine->memory->columns80 = !machine->memory->columns80;
  display->wide = machine->memory->columns80;
  [self reset:nil];
}

- (void)restore:(id)sender
{
  if (machine->memory->hasROMs)
    [machine restore];
}

- (void)windowDidResignKey:(NSNotification *)note
{
  [self clearKeys];
}

- (void)windowWillClose:(NSNotification *)note
{
  [self clearKeys];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)note
{
  [timer invalidate];
}

- (void)dealloc
{
  [timer release];
  [secondDisplay release];
  [secondWindow release];
  [display release];
  [window release];
  [machine release];
  [super dealloc];
}

@end

/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C128Display.h"
#import "../Core/C128Machine.h"

@implementation C128Display

- (id)initWithFrame:(NSRect)frame
{
  if ((self = [super initWithFrame:frame]))
    {
      bitmap = [[NSBitmapImageRep alloc]
          initWithBitmapDataPlanes:NULL
                        pixelsWide:C64Width
                        pixelsHigh:C64Height
                     bitsPerSample:8
                   samplesPerPixel:4
                          hasAlpha:YES
                          isPlanar:NO
                    colorSpaceName:NSDeviceRGBColorSpace
                       bytesPerRow:C64Width * 4
                      bitsPerPixel:32];
      wideBitmap = [[NSBitmapImageRep alloc]
          initWithBitmapDataPlanes:NULL
                        pixelsWide:VDCWidth
                        pixelsHigh:VDCHeight
                     bitsPerSample:8
                   samplesPerPixel:4
                          hasAlpha:YES
                          isPlanar:NO
                    colorSpaceName:NSDeviceRGBColorSpace
                       bytesPerRow:VDCWidth * 4
                      bitsPerPixel:32];
      held = [NSMutableDictionary new];
    }
  return self;
}

- (void)dealloc
{
  [held release];
  [bitmap release];
  [wideBitmap release];
  [super dealloc];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
  [[NSColor blackColor] setFill];
  NSRectFill ([self bounds]);
  if (!machine->memory->hasROMs)
    {
      NSString *message
          = @"C128\nChoose ROM Folder… from the File menu to start.\n\nRequires C128 BASIC low/high, KERNAL, and character ROMs.";
      [message drawInRect:NSInsetRect ([self bounds], 60, 100)
           withAttributes:[NSDictionary
                              dictionaryWithObjectsAndKeys:
                                  [NSFont userFixedPitchFontOfSize:18],
                                  NSFontAttributeName, [NSColor greenColor],
                                  NSForegroundColorAttributeName, nil]];
      return;
    }
  NSBitmapImageRep *active = wide ? wideBitmap : bitmap;
  unsigned width = wide ? VDCWidth : C64Width,
           height = wide ? VDCHeight : C64Height;
  if (wide)
    [machine->memory->vdc renderRGBA:[active bitmapData]];
  else
    [machine->memory renderRGBA:[active bitmapData]];
  NSSize size = [self bounds].size;
  unsigned displayHeight = wide ? height * 2 : height;
  CGFloat scale = MIN (size.width / width, size.height / displayHeight);
  NSRect target = NSMakeRect ((size.width - width * scale) / 2,
                              (size.height - displayHeight * scale) / 2,
                              width * scale, displayHeight * scale);
  [[NSGraphicsContext currentContext]
      setImageInterpolation:NSImageInterpolationNone];
  [active drawInRect:target];
}

- (void)rebuildKeys
{
  [machine->memory releaseKeys];
  NSEnumerator *enumerator = [[held allValues] objectEnumerator];
  NSArray *key;
  while ((key = [enumerator nextObject]))
    {
      machine->memory->keys[[[key objectAtIndex:0] intValue]]
                           [[[key objectAtIndex:1] intValue]] = YES;
      if ([[key objectAtIndex:2] boolValue])
        machine->memory->keys[1][7] = YES;
    }
  if (modifiers & NSControlKeyMask)
    machine->memory->keys[7][2] = YES;
  if (modifiers & NSAlternateKeyMask)
    machine->memory->keys[7][5] = YES;
  if ((modifiers & NSShiftKeyMask) && ![held count])
    machine->memory->keys[1][7] = YES;
}

- (void)clearKeys
{
  [held removeAllObjects];
  modifiers = 0;
  [self rebuildKeys];
}

- (void)flagsChanged:(NSEvent *)event
{
  modifiers = [event modifierFlags];
  [self rebuildKeys];
}

- (void)keyDown:(NSEvent *)event
{
  if ([event modifierFlags] & NSCommandKeyMask)
    {
      [super keyDown:event];
      return;
    }
  if ([event isARepeat])
    return;
  NSString *text = [event characters];
  if (![text length])
    return;
  unichar c = [text characterAtIndex:0];
  BOOL shifted = NO;
  int row = -1, col = -1;
  /* Row = CIA1 port A bit; column = CIA1 port B bit. */
  NSArray *rows = [NSArray
      arrayWithObjects:@"\177\r→⑦①③⑤↓", @"3WA4ZSE⇧", @"5RD6CFTX", @"7YG8BHUV",
                       @"9IJ0MKON", @"+PL-.:@,", @"£*;⌂⇧=↑/", @"1←⌃2 ⌘Q⎋", nil];
  if (c >= 'a' && c <= 'z')
    c -= 32;
  else if (c >= 'A' && c <= 'Z')
    shifted = ([event modifierFlags] & NSShiftKeyMask) != 0;
  NSString *symbols = @"!\"#$%&'()<>?";
  NSRange symbol = [symbols rangeOfString:[NSString stringWithCharacters:&c
                                                                  length:1]];
  if (symbol.location != NSNotFound)
    {
      c = [@"123456789,./" characterAtIndex:symbol.location];
      shifted = YES;
    }
  switch (c)
    {
    case NSLeftArrowFunctionKey:
      c = 0x2192;
      shifted = YES;
      break;
    case NSRightArrowFunctionKey:
      c = 0x2192;
      break;
    case NSUpArrowFunctionKey:
      c = 0x2193;
      shifted = YES;
      break;
    case NSDownArrowFunctionKey:
      c = 0x2193;
      break;
    case NSHomeFunctionKey:
      c = 0x2302;
      break;
    case NSF1FunctionKey:
      c = 0x2460;
      break;
    case NSF2FunctionKey:
      c = 0x2460;
      shifted = YES;
      break;
    case NSF3FunctionKey:
      c = 0x2462;
      break;
    case NSF4FunctionKey:
      c = 0x2462;
      shifted = YES;
      break;
    case NSF5FunctionKey:
      c = 0x2464;
      break;
    case NSF6FunctionKey:
      c = 0x2464;
      shifted = YES;
      break;
    case NSF7FunctionKey:
      c = 0x2466;
      break;
    case NSF8FunctionKey:
      c = 0x2466;
      shifted = YES;
      break;
    case 27:
      c = 0x238b;
      break;
    case '\n':
      c = '\r';
      break;
    }
  for (int r = 0; r < 8; r++)
    for (int k = 0; k < 8; k++)
      if ([[rows objectAtIndex:r] characterAtIndex:k] == c)
        {
          row = r;
          col = k;
        }
  if (row >= 0)
    [held setObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:row],
                                              [NSNumber numberWithInt:col],
                                              [NSNumber numberWithBool:shifted],
                                              nil]
             forKey:[NSNumber numberWithUnsignedInt:[event keyCode]]];
  modifiers = [event modifierFlags];
  [self rebuildKeys];
}

- (void)keyUp:(NSEvent *)event
{
  [held removeObjectForKey:[NSNumber numberWithUnsignedInt:[event keyCode]]];
  [self rebuildKeys];
}

@end

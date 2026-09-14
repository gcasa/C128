/*
 * VIC20 - a Commodore VIC-20 emulator.
 * Copyright (C) 2018-2026 Gregory John Casamento
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#import "CPU6502.h"
#import <Foundation/Foundation.h>

@interface TestBus : NSObject <CPU6502Bus>
{
  uint8 bytes[65536];
}
- (void)loadBytes:(const uint8 *)data
           length:(NSUInteger)length
               at:(uint16)start;
@end

@implementation TestBus
- (uint8)readMemory:(uint16)address
{
  return bytes[address];
}

- (void)writeMemory:(uint8)value address:(uint16)address
{
  bytes[address] = value;
}

- (void)loadBytes:(const uint8 *)data
           length:(NSUInteger)length
               at:(uint16)start
{
  NSParameterAssert (length <= 65536 - start);
  memcpy (bytes + start, data, length);
}
@end

int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess(argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TestBus *bus = [[TestBus alloc] init];
  const uint8 program[] = {
    0xA9, 0x2A,       // LDA #$2A
    0x8D, 0x00, 0x20, // STA $2000
    0xA2, 0x05,       // LDX #$05
    0xE8              // INX
  };
  [bus loadBytes:program length:sizeof (program) at:0x8000];
  [bus writeMemory:0x00 address:RESETVECTOR];
  [bus writeMemory:0x80 address:RESETVECTOR + 1];

  CPU6502 *cpu = [[CPU6502 alloc] initWithBus:bus];
  [cpu reset];
  for (NSUInteger instruction = 0; instruction < 4; instruction++)
    [cpu step];

  BOOL passed = [bus readMemory:0x2000] == 0x2A && [cpu getAccumulator] == 0x2A
                && [cpu getXRegister] == 0x06 &&
                [cpu getProgramCounter] == 0x8008 && [cpu getCycleCount] == 10;
  NSLog (@"Reusable CPU/bus test: %@", passed ? @"PASS" : @"FAIL");

  [cpu release];
  [bus release];
  [pool drain];
  return passed ? 0 : 1;
}

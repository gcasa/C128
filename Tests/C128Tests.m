/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C128Machine.h"
#include <stdio.h>
#define CHECK(c)                                                               \
  do                                                                           \
    {                                                                          \
      if (!(c))                                                                \
        {                                                                      \
          fprintf (stderr, "FAIL %d: %s\n", __LINE__, #c);                     \
          return 1;                                                            \
        }                                                                      \
    }                                                                          \
  while (0)

static NSString *
screen (C128Bus *b)
{
  NSMutableString *s = [NSMutableString string];
  unsigned i;
  for (i = 0; i < 1000; i++)
    {
      unsigned c = b->ram[0x400 + i] & 127;
      [s appendFormat:@"%c", c < 32 ? c + 64 : c];
    }
  return s;
}

static void
type (C128Machine *m, NSString *s)
{
  unsigned i;
  for (i = 0; i < [s length]; i++)
    {
      m->memory->ram[0x34a] = [s characterAtIndex:i];
      m->memory->ram[0xd0] = 1;
      [m runCycles:70000];
    }
}

int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  C128Machine *m = [C128Machine new];
  C128Bus *b = m->memory;
  NSError *error = nil;
  [b writeMemory:0x3f address:0xff00];
  [b writeMemory:0x12 address:0x4000];
  [b writeMemory:0x7f address:0xff00];
  [b writeMemory:0x34 address:0x4000];
  CHECK (b->ram[0x4000] == 0x12 && b->bank1[0x4000] == 0x34);
  [b setMMU:4 reg:6];
  [b writeMemory:0x56 address:0x300];
  CHECK (b->ram[0x300] == 0x56);
  [b setMMU:1 reg:8];
  [b setMMU:0x30 reg:7];
  [b writeMemory:0x78 address:0x80];
  CHECK (b->bank1[0x3080] == 0x78);
  [b reset];
  b->basic128[0] = 0xaa;
  [b writeMemory:0xbb address:0x4000];
  CHECK ([b readMemory:0x4000] == 0xaa && b->ram[0x4000] == 0xbb);
  [b setMMU:0x7f reg:1];
  [b writeMemory:0 address:0xff01];
  CHECK (b->mmu[0] == 0x7f);
  [b reset];
  VDC8563 *v = b->vdc;
  [v write:18 address:0];
  [v write:0x20 address:1];
  [v write:19 address:0];
  [v write:0 address:1];
  [v write:31 address:0];
  [v write:0x55 address:1];
  CHECK (v->ram[0x2000] == 0x55 && v->registers[19] == 1);
  [v write:30 address:0];
  [v write:3 address:1];
  CHECK (v->ram[0x2003] == 0x55 && v->registers[19] == 4);
  const uint8_t prg[] = { 1, 28, 0, 0 };
  CHECK ([b loadPRG:[NSData dataWithBytes:prg length:4]
              start:NULL
              error:&error]);
  CHECK (b->ram[0x1210] == 3 && b->ram[0x1211] == 28);
  const uint8_t bad[] = { 255, 255, 1, 2 };
  CHECK (![b loadPRG:[NSData dataWithBytes:bad length:4]
               start:NULL
               error:&error]);
  [b reset];
  [b setMMU:0x7f reg:0];
  [b setMMU:8 reg:6];
  [b writeMemory:0x91 address:0xffff];
  CHECK (b->ram[0xffff] == 0x91 && b->bank1[0xffff] == 0);
  [b setMMU:1 reg:8];
  CHECK (b->mmu[8] == 0);
  [b setMMU:0x20 reg:7];
  CHECK (b->mmu[8] == 1);
  [b reset];
  [b writeMemory:0x12 address:0xd800];
  b->ram[1] &= ~1;
  [b writeMemory:0x34 address:0xd800];
  CHECK (b->color[0] == 4 && b->color1[0] == 2);
  CIA6526 *cia = b->cia1;
  [cia write:0 reg:4];
  [cia write:0 reg:5];
  [cia write:0x41 reg:14];
  [cia write:0x88 reg:13];
  [cia write:0xa5 reg:12];
  unsigned j;
  for (j = 0; j < 15; j++)
    [cia tick];
  CHECK (!(cia->pending & 8));
  [cia tick];
  CHECK ([cia irq] && ([cia read:13] & 0x88) == 0x88 && ![cia irq]);
  [v reset];
  v->registers[1] = 80;
  v->registers[6] = 25;
  v->registers[9] = 7;
  v->registers[26] = 0xf0;
  v->registers[28] = 0x20;
  v->registers[10] = 0x20;
  v->ram[0x2000] = 128;
  uint8_t *pixels = malloc (VDCWidth * VDCHeight * 4);
  [v renderRGBA:pixels];
  CHECK (pixels[0] == 255 && pixels[4] == 0);
  free (pixels);
  [v reset];
  v->registers[18] = 0xff;
  v->registers[19] = 0xff;
  v->registers[24] = 128;
  v->registers[32] = 0x10;
  v->ram[0x1000] = 0x42;
  v->ram[0x1001] = 0x43;
  [v write:30 address:0];
  [v write:2 address:1];
  CHECK (v->ram[65535] == 0x42 && v->ram[0] == 0x43);
  [m reset];
  [b setMMU:0 reg:5];
  NSUInteger stopped = [m->cpu getCycleCount];
  [m runCycles:100];
  CHECK (b->unsupportedCPU && [m->cpu getCycleCount] == stopped);
  [m reset];
  CHECK (!b->unsupportedCPU);
  puts (
      "PASS: RAM banks, common RAM, page relocation, ROM overlay, MMU presets, VDC transfer/fill, PRG bounds");
  if (argc > 1)
    {
      CHECK ([b loadROMDirectory:[NSString stringWithUTF8String:argv[1]]
                           error:&error]);
      uint8_t first = b->basic128[0];
      CHECK (![b loadROMDirectory:@"/nonexistent-c128-roms" error:&error]
             && b->hasROMs && b->basic128[0] == first);
      [m reset];
      [m runCycles:8000000];
      CHECK ([screen (b) rangeOfString:@"122365 BYTES FREE"].location
             != NSNotFound);
      CHECK ([screen (b) rangeOfString:@"READY."].location != NSNotFound);
      type (m, @"PRINT 2+2\r");
      [m runCycles:300000];
      CHECK ([screen (b) rangeOfString:@" 4"].location != NSNotFound);
      NSUInteger count = [[screen (b) componentsSeparatedByString:@"A"] count];
      b->keys[1][2] = YES;
      [m runCycles:80000];
      b->keys[1][2] = NO;
      [m runCycles:80000];
      CHECK ([[screen (b) componentsSeparatedByString:@"A"] count]
             == count + 1);
      type (m, @"\r");
      const uint8_t hello[]
          = { 1, 28, 0x0b, 28, 10, 0, 0x99, '"', 'O', 'K', '"', 0, 0, 0 };
      CHECK ([b loadPRG:[NSData dataWithBytes:hello length:sizeof hello]
                  start:NULL
                  error:&error]);
      type (m, @"RUN\r");
      [m runCycles:300000];
      CHECK ([screen (b) rangeOfString:@"OK"].location != NSNotFound);
      b->columns80 = YES;
      [m reset];
      [m runCycles:8000000];
      NSMutableString *wide = [NSMutableString string];
      unsigned i;
      unsigned base = (v->registers[12] << 8) | v->registers[13];
      for (i = 0; i < 2000; i++)
        {
          unsigned c = v->ram[(base + i) & 65535] & 127;
          [wide appendFormat:@"%c", c < 32 ? c + 64 : c];
        }

      CHECK ([wide rangeOfString:@"READY."].location != NSNotFound);
      b->columns80 = NO;
      [m reset];
      [m runCycles:8000000];
      type (m, @"GO64\rY\r");
      [m runCycles:3000000];

      CHECK ([b isC64] && !b->unsupportedCPU &&
             [screen (b) rangeOfString:@"38911 BASIC BYTES FREE"].location
                 != NSNotFound);
      puts (
          "PASS: C128 40/80 boot, BASIC arithmetic, keyboard, PRG execution, GO64");
    }
  else
    puts ("SKIP: firmware tests (pass ROM directory to this executable)");
  [m release];
  [pool drain];
  return 0;
}

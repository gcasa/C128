/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "CPUZ80.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned checks;
#define CHECK(expr)                                                            \
  do                                                                           \
    {                                                                          \
      checks++;                                                                \
      if (!(expr))                                                             \
        {                                                                      \
          fprintf (stderr, "FAIL line %d: %s\n", __LINE__, #expr);             \
          exit (1);                                                            \
        }                                                                      \
    }                                                                          \
  while (0)
@interface Z80TestBus : NSObject <CPUZ80Bus>
{
@public
  uint8_t memory[65536], ports[65536], vector;
  unsigned acknowledgements, returns, reads, writes;
  uint16_t lastPort;
}
@end
@implementation Z80TestBus

- (uint8_t)readMemory:(uint16_t)address
{
  return memory[address];
}

- (void)writeMemory:(uint8_t)value address:(uint16_t)address
{
  memory[address] = value;
}

- (uint8_t)readPort:(uint16_t)port
{
  reads++;
  lastPort = port;
  return ports[port];
}

- (void)writePort:(uint8_t)value address:(uint16_t)port
{
  writes++;
  lastPort = port;
  ports[port] = value;
}

- (uint8_t)acknowledgeInterrupt
{
  acknowledgements++;
  return vector;
}

- (void)didReturnFromInterrupt
{
  returns++;
}

@end

static CPUZ80State
fresh (CPUZ80 *cpu, Z80TestBus *bus)
{
  [cpu reset];
  memset (bus->memory, 0, sizeof (bus->memory));
  memset (bus->ports, 0, sizeof (bus->ports));
  bus->acknowledgements = bus->returns = bus->reads = bus->writes = 0;
  bus->vector = 255;
  CPUZ80State s = [cpu state];
  s.cycles = 0;
  [cpu setState:s];
  return s;
}

static unsigned
evenParity (unsigned v)
{
  unsigned bits = 0;
  for (unsigned i = 0; i < 8; i++)
    bits += (v >> i) & 1;
  return (bits % 2) == 0 ? 4 : 0;
}

static unsigned
resultFlags (unsigned v)
{
  return (v & 0xa8) | (v == 0 ? 0x40 : 0);
}

/* Exhaust every input and carry for all eight ALU operations. Expected carry,
 * half carry and signed overflow use range checks independent of the decoder.
 */
static void
arithmetic (CPUZ80 *cpu, Z80TestBus *bus)
{
  CPUZ80State s = fresh (cpu, bus);
  for (unsigned op = 0; op < 8; op++)
    {
      bus->memory[0] = 0xc6 + op * 8;
      for (unsigned a = 0; a < 256; a++)
        for (unsigned b = 0; b < 256; b++)
          for (unsigned c = 0; c < 2; c++)
            {
              s.pc = 0;
              s.af = (a << 8) | c;
              s.cycles = 0;
              bus->memory[1] = b;
              [cpu setState:s];
              CHECK ([cpu step] == 7);
              unsigned flags, value;
              if (op < 4 || op == 7)
                {
                  BOOL sub = op == 2 || op == 3 || op == 7;
                  unsigned carry = op == 1 || op == 3 ? c : 0;
                  int full = sub ? (int)a - b - carry : (int)a + b + carry;
                  int signedFull
                      = sub ? (int)(int8_t)a - (int8_t)b - (int)carry
                            : (int)(int8_t)a + (int8_t)b + (int)carry;
                  int nibble = sub ? (int)(a & 15) - (int)(b & 15) - (int)carry
                                   : (int)(a & 15) + (int)(b & 15) + (int)carry;
                  value = full & 255;
                  flags = resultFlags (value);
                  if (full < 0 || full > 255)
                    flags |= 1;
                  if (nibble < 0 || nibble > 15)
                    flags |= 16;
                  if (signedFull < -128 || signedFull > 127)
                    flags |= 4;
                  if (sub)
                    flags |= 2;
                  if (op == 7)
                    {
                      flags = (flags & ~0x28) | (b & 0x28);
                      value = a;
                    }
                }
              else
                {
                  value = op == 4 ? a & b : op == 5 ? a ^ b : a | b;
                  flags = resultFlags (value) | evenParity (value)
                          | (op == 4 ? 16 : 0);
                }
              CHECK ([cpu state].af == ((value << 8) | flags));
            }
    }
  /* DAA after all valid two-digit packed-BCD additions and subtractions. */
  for (unsigned sub = 0; sub < 2; sub++)
    for (unsigned a = 0; a < 100; a++)
      for (unsigned b = 0; b < 100; b++)
        {
          s.pc = 0;
          s.af = ((a / 10 * 16 + a % 10) << 8);
          [cpu setState:s];
          bus->memory[0] = sub ? 0xd6 : 0xc6;
          bus->memory[1] = b / 10 * 16 + b % 10;
          bus->memory[2] = 0x27;
          [cpu step];
          CHECK ([cpu step] == 4);
          int decimal = sub ? (int)a - (int)b : (int)a + (int)b;
          unsigned wrapped = (decimal + 100) % 100;
          CHECK (([cpu state].af >> 8) == wrapped / 10 * 16 + wrapped % 10);
          CHECK (([cpu state].af & 1) == (decimal < 0 || decimal > 99));
        }
  for (unsigned dec = 0; dec < 2; dec++)
    for (unsigned v = 0; v < 256; v++)
      for (unsigned c = 0; c < 2; c++)
        {
          s.pc = 0;
          s.bc = v << 8;
          s.af = c;
          [cpu setState:s];
          bus->memory[0] = dec ? 5 : 4;
          [cpu step];
          unsigned result = (v + (dec ? -1 : 1)) & 255;
          unsigned flags = resultFlags (result) | c | (dec ? 2 : 0);
          if (dec ? (v & 15) == 0 : (v & 15) == 15)
            flags |= 16;
          if (v == (dec ? 128 : 127))
            flags |= 4;
          CHECK ([cpu state].bc == result << 8
                 && ([cpu state].af & 255) == flags);
        }
}

/* Exercise 16-bit arithmetic boundaries and every conditional control flow
 * path independently of the optional reference vectors. */
static void
wordsAndFlow (CPUZ80 *cpu, Z80TestBus *bus)
{
  const unsigned edges[]
      = { 0, 1, 15, 16, 0xfff, 0x1000, 0x7fff, 0x8000, 0xfffe, 0xffff };
  CPUZ80State s = fresh (cpu, bus);
  for (unsigned sub = 0; sub < 2; sub++)
    for (unsigned l = 0; l < 10; l++)
      for (unsigned r = 0; r < 10; r++)
        for (unsigned c = 0; c < 2; c++)
          {
            unsigned a = edges[l], b = edges[r];
            s.pc = 0;
            s.hl = a;
            s.bc = b;
            s.af = c;
            [cpu setState:s];
            bus->memory[0] = 0xed;
            bus->memory[1] = sub ? 0x42 : 0x4a;
            CHECK ([cpu step] == 15);
            int full
                = sub ? (int)a - (int)b - (int)c : (int)a + (int)b + (int)c;
            int signedFull = sub ? (int)(int16_t)a - (int16_t)b - (int)c
                                 : (int)(int16_t)a + (int16_t)b + (int)c;
            int nibble = sub ? (int)(a & 0xfff) - (int)(b & 0xfff) - (int)c
                             : (int)(a & 0xfff) + (int)(b & 0xfff) + (int)c;
            unsigned result = full & 65535, flags = ((result >> 8) & 0xa8)
                                                    | (result ? 0 : 64)
                                                    | (sub ? 2 : 0);
            if (full < 0 || full > 65535)
              flags |= 1;
            if (signedFull < -32768 || signedFull > 32767)
              flags |= 4;
            if (nibble < 0 || nibble > 4095)
              flags |= 16;
            CHECK ([cpu state].hl == result && ([cpu state].af & 255) == flags);
          }
  const unsigned masks[] = { 64, 64, 1, 1, 4, 4, 128, 128 };
  for (unsigned cc = 0; cc < 8; cc++)
    for (unsigned flags = 0; flags < 256; flags++)
      {
        BOOL taken = (flags & masks[cc]) != 0;
        if (!(cc & 1))
          taken = !taken;
        s.pc = 0;
        s.af = flags;
        s.sp = 0;
        [cpu setState:s];
        bus->memory[0] = 0xc2 + cc * 8;
        bus->memory[1] = 0x34;
        bus->memory[2] = 0x12;
        CHECK ([cpu step] == 10 &&
               [cpu getProgramCounter] == (taken ? 0x1234 : 3));
        [cpu setState:s];
        bus->memory[0] = 0xc4 + cc * 8;
        CHECK ([cpu step] == (taken ? 17 : 10));
        CHECK ([cpu getProgramCounter] == (taken ? 0x1234 : 3));
        if (taken)
          CHECK ([cpu state].sp == 65534 && bus->memory[65534] == 3
                 && bus->memory[65535] == 0);
        s.pc = 0;
        s.sp = 65535;
        [cpu setState:s];
        bus->memory[0] = 0xc0 + cc * 8;
        bus->memory[65535] = 0x78;
        CHECK ([cpu step] == (taken ? 11 : 5));
        CHECK ([cpu getProgramCounter]
               == (taken ? ((0xc0 + cc * 8) << 8) | 0x78 : 1));
        CHECK ([cpu state].sp == (taken ? 1 : 65535));
      }
  /* WZ for IN C,(C) is based on BC before C is replaced. */
  s = fresh (cpu, bus);
  s.bc = 0x1234;
  bus->ports[0x1234] = 0x56;
  bus->memory[0] = 0xed;
  bus->memory[1] = 0x48;
  [cpu setState:s];
  CHECK ([cpu step] == 12 && [cpu state].bc == 0x1256 &&
         [cpu state].wz == 0x1235);
  /* SCF after an instruction that leaves flags alone uses the old X/Y bits. */
  s = fresh (cpu, bus);
  s.af = 0x0028;
  [cpu setState:s];
  bus->memory[0] = 0;
  bus->memory[1] = 0x37;
  [cpu step];
  [cpu step];
  CHECK ([cpu state].af == 0x0029);
}

static void
prefixes (CPUZ80 *cpu, Z80TestBus *bus)
{
  CPUZ80State s = fresh (cpu, bus);
  const uint8_t program[] = {
    0xdd, 0x21, 0x00, 0x20, /* LD IX,$2000 */
    0xfd, 0x21, 0x00, 0x30, /* LD IY,$3000 */
    0xdd, 0x36, 0xff, 0x81, /* LD (IX-1),$81 */
    0xdd, 0xcb, 0xff, 0x00, /* RLC (IX-1),B */
    0xfd, 0x70, 0x02,       /* LD (IY+2),B */
    0xdd, 0x66, 0xff,       /* LD H,(IX-1) uses H */
    0xdd, 0x26, 0x44,       /* LD IXH,$44 */
    0xdd, 0xfd, 0x2e, 0x55, /* Last prefix wins */
    0xdd, 0xed, 0x44        /* Prefix ignored before NEG */
  };
  memcpy (bus->memory, program, sizeof (program));
  s.af = 0x0100;
  [cpu setState:s];
  unsigned cycles[] = { 14, 14, 19, 23, 19, 19, 11, 15, 12 };
  for (unsigned i = 0; i < 9; i++)
    CHECK ([cpu step] == cycles[i]);
  s = [cpu state];
  CHECK (s.ix == 0x4400 && s.iy == 0x3055 && s.hl == 0x0300 && s.bc == 0x0300);
  CHECK (bus->memory[0x1fff] == 3 && bus->memory[0x3002] == 3
         && (s.af >> 8) == 255);
  CHECK (s.pc == sizeof (program) && s.r == 20);
  /* All CB operations on B, including SLL and flag preservation for RES/SET. */
  for (unsigned op = 0; op < 32; op++)
    for (unsigned value = 0; value < 256; value++)
      for (unsigned carry = 0; carry < 2; carry++)
        {
          s = fresh (cpu, bus);
          s.bc = value << 8;
          s.af = 0x54 | carry;
          [cpu setState:s];
          bus->memory[0] = 0xcb;
          bus->memory[1] = op * 8;
          CHECK ([cpu step] == 8);
          unsigned group = op / 8, bit = op % 8, result = value,
                   flags = 0x54 | carry;
          if (group == 0)
            {
              switch (bit)
                {
                case 0:
                  result = ((value * 2) + (value / 128)) & 255;
                  break;
                case 1:
                  result = value / 2 + (value % 2) * 128;
                  break;
                case 2:
                  result = (value * 2 + carry) & 255;
                  break;
                case 3:
                  result = value / 2 + carry * 128;
                  break;
                case 4:
                  result = (value * 2) & 255;
                  break;
                case 5:
                  result = value / 2 + (value & 128);
                  break;
                case 6:
                  result = (value * 2 + 1) & 255;
                  break;
                case 7:
                  result = value / 2;
                  break;
                }
              flags = resultFlags (result) | evenParity (result)
                      | ((bit == 1 || bit == 3 || bit == 5 || bit == 7)
                             ? value % 2
                             : value / 128);
            }
          else if (group == 1)
            flags = carry | 16 | (value & 0x28)
                    | ((value & (1 << bit)) ? (bit == 7 ? 128 : 0) : 0x44);
          else if (group == 2)
            result = value & ~(1 << bit);
          else
            result = value | (1 << bit);
          CHECK ([cpu state].bc == result << 8
                 && ([cpu state].af & 255) == flags);
        }
  /* An all-prefix address space must yield and preserve interrupt exclusion. */
  s = fresh (cpu, bus);
  memset (bus->memory, 0xdd, sizeof (bus->memory));
  CHECK ([cpu step] == 262144 && [cpu state].prefixIndex == 1);
  [cpu nmi];
  bus->memory[0] = 0x21;
  bus->memory[1] = 0x34;
  bus->memory[2] = 0x12;
  CHECK ([cpu step] == 10 && [cpu state].ix == 0x1234);
  CHECK ([cpu step] == 11 && [cpu getProgramCounter] == 0x66);
}

static void
interrupts (CPUZ80 *cpu, Z80TestBus *bus)
{
  CPUZ80State s = fresh (cpu, bus);
  s.sp = 0;
  s.interruptMode = 1;
  [cpu setState:s];
  bus->memory[0] = 0xfb;
  bus->memory[1] = 0x76;
  [cpu setInterruptLine:YES];
  CHECK ([cpu step] == 4 && [cpu state].eiDelay == 1);
  CHECK ([cpu step] == 4 && [cpu state].halted);
  CHECK ([cpu step] == 13 && [cpu getProgramCounter] == 0x38);
  CHECK (bus->memory[0xfffe] == 2 && bus->memory[0xffff] == 0
         && bus->acknowledgements == 1);
  CHECK (![cpu state].iff1 && ![cpu state].iff2 && ![cpu state].halted &&
         [cpu state].r == 3);
  bus->memory[0x38] = 0xed;
  bus->memory[0x39] = 0x4d;
  CHECK ([cpu step] == 14 && [cpu getProgramCounter] == 2 && bus->returns == 1);
  s = fresh (cpu, bus);
  s.pc = 0x1234;
  s.sp = 0x8000;
  s.i = 255;
  s.interruptMode = 2;
  s.iff1 = s.iff2 = YES;
  s.r = 255;
  [cpu setState:s];
  bus->memory[65535] = 0x78;
  bus->memory[0] = 0x56;
  [cpu setInterruptLine:YES];
  CHECK ([cpu step] == 19 && [cpu getProgramCounter] == 0x5678 &&
         [cpu state].r == 128);
  CHECK (bus->memory[0x7ffe] == 0x34 && bus->memory[0x7fff] == 0x12);
  /* IM 0 executes the acknowledged opcode, fetching operands at PC. */
  s = fresh (cpu, bus);
  s.pc = 0x1000;
  s.iff1 = s.iff2 = YES;
  [cpu setState:s];
  bus->vector = 0xcd;
  bus->memory[0x1000] = 0x34;
  bus->memory[0x1001] = 0x12;
  [cpu setInterruptLine:YES];
  CHECK ([cpu step] == 19 && [cpu getProgramCounter] == 0x1234);
  CHECK (bus->memory[0xfffd] == 2 && bus->memory[0xfffe] == 0x10);
  s = fresh (cpu, bus);
  s.iff1 = s.iff2 = YES;
  s.pc = 0x100;
  [cpu setState:s];
  [cpu setInterruptLine:YES];
  [cpu setNMILine:YES];
  CHECK ([cpu step] == 11 && [cpu getProgramCounter] == 0x66
         && bus->acknowledgements == 0);
  CHECK (![cpu state].iff1 && [cpu state].iff2);
  bus->memory[0x66] = 0xed;
  bus->memory[0x67] = 0x45;
  [cpu setNMILine:YES];
  CHECK ([cpu step] == 14 && [cpu getProgramCounter] == 0x100 &&
         [cpu state].iff1);
  CHECK (bus->returns == 0);
  [cpu setNMILine:NO];
  [cpu setNMILine:YES];
  CHECK ([cpu step] == 11);
  uint64_t cycles = [cpu getCycleCount];
  [cpu reset];
  s = [cpu state];
  CHECK (s.cycles == cycles && s.pc == 0 && s.sp == 65535 && !s.iff1
         && !s.nmiPending);
  bus->memory[0] = 0x76;
  CHECK ([cpu step] == 4 && [cpu step] == 4 && [cpu getProgramCounter] == 1);
  [cpu setInterruptLine:YES];
  CHECK ([cpu step] == 4 && [cpu state].halted);
  [cpu nmi];
  CHECK ([cpu step] == 11 && ![cpu state].halted);
}

static void
blocksAndIO (CPUZ80 *cpu, Z80TestBus *bus)
{
  CPUZ80State s = fresh (cpu, bus);
  s.hl = 0xffff;
  s.de = 0x8000;
  s.bc = 2;
  s.pc = 0x100;
  bus->memory[0xffff] = 0x11;
  bus->memory[0] = 0x22;
  bus->memory[0x100] = 0xed;
  bus->memory[0x101] = 0xb0;
  [cpu setState:s];
  CHECK ([cpu step] == 21 && [cpu getProgramCounter] == 0x100);
  CHECK ([cpu step] == 16 && [cpu getProgramCounter] == 0x102);
  CHECK (bus->memory[0x8000] == 0x11 && bus->memory[0x8001] == 0x22 &&
         [cpu state].hl == 1 && [cpu state].bc == 0);
  s = fresh (cpu, bus);
  s.af = 0x2201;
  s.bc = 3;
  s.hl = 0x8000;
  bus->memory[0] = 0xed;
  bus->memory[1] = 0xb1;
  bus->memory[0x8000] = 0x11;
  bus->memory[0x8001] = 0x22;
  [cpu setState:s];
  CHECK ([cpu step] == 21 && [cpu step] == 16);
  CHECK ([cpu state].bc == 1 && ([cpu state].af & 0x41) == 0x41);
  s = fresh (cpu, bus);
  s.af = 0x1234;
  bus->memory[0] = 0xdb;
  bus->memory[1] = 0xfe;
  bus->ports[0x12fe] = 0x56;
  [cpu setState:s];
  CHECK ([cpu step] == 11 && [cpu state].af == 0x5634
         && bus->lastPort == 0x12fe);
  bus->memory[2] = 0xd3;
  bus->memory[3] = 0x80;
  CHECK ([cpu step] == 11 && bus->ports[0x5680] == 0x56);
  s = fresh (cpu, bus);
  s.bc = 0x0280;
  s.hl = 0x8000;
  bus->ports[0x0280] = 0xaa;
  bus->ports[0x0180] = 0xbb;
  bus->memory[0] = 0xed;
  bus->memory[1] = 0xb2;
  [cpu setState:s];
  CHECK ([cpu step] == 21 && [cpu step] == 16 && bus->reads == 2);
  CHECK (bus->memory[0x8000] == 0xaa && bus->memory[0x8001] == 0xbb &&
         [cpu state].bc == 0x80);
  s = fresh (cpu, bus);
  s.bc = 0x0280;
  s.hl = 0x8001;
  bus->memory[0x8001] = 0xaa;
  bus->memory[0x8000] = 0xbb;
  bus->memory[0] = 0xed;
  bus->memory[1] = 0xbb;
  [cpu setState:s];
  CHECK ([cpu step] == 21 && [cpu step] == 16 && bus->writes == 2);
  CHECK (bus->ports[0x0180] == 0xaa && bus->ports[0x0080] == 0xbb &&
         [cpu state].hl == 0x7fff);
}

/* Optional Fuse vector runner. Input/expected files are supplied separately;
 * only architectural state, aggregate T-states and final memory are compared.
 * The reference's bus-event timestamps describe Spectrum contention, which
 * does not belong in this reusable instruction-level core. */
static NSArray *
lines (NSString *block)
{
  return [block componentsSeparatedByString:@"\n"];
}

static CPUZ80State
vectorState (NSString *pairs, NSString *control, unsigned *cycles)
{
  unsigned r[13], i, refresh, iff1, iff2, mode, halt;
  CHECK (sscanf ([pairs UTF8String], "%x %x %x %x %x %x %x %x %x %x %x %x %x",
                 &r[0], &r[1], &r[2], &r[3], &r[4], &r[5], &r[6], &r[7], &r[8],
                 &r[9], &r[10], &r[11], &r[12])
         == 13);
  CHECK (sscanf ([control UTF8String], "%x %x %u %u %u %u %u", &i, &refresh,
                 &iff1, &iff2, &mode, &halt, cycles)
         == 7);
  CPUZ80State s;
  memset (&s, 0, sizeof (s));
  s.af = r[0];
  s.bc = r[1];
  s.de = r[2];
  s.hl = r[3];
  s.alternateAF = r[4];
  s.alternateBC = r[5];
  s.alternateDE = r[6];
  s.alternateHL = r[7];
  s.ix = r[8];
  s.iy = r[9];
  s.sp = r[10];
  s.pc = r[11];
  s.wz = r[12];
  s.i = i;
  s.r = refresh;
  s.iff1 = iff1;
  s.iff2 = iff2;
  s.interruptMode = mode;
  s.halted = halt;
  return s;
}

static void
vectorMemory (NSString *line, Z80TestBus *bus, BOOL compare)
{
  const char *cursor = [line UTF8String];
  char *end;
  long address = strtol (cursor, &end, 16);
  if (end == cursor || address < 0)
    return;
  cursor = end;
  for (;;)
    {
      long value = strtol (cursor, &end, 16);
      if (end == cursor || value < 0)
        break;
      if (compare)
        CHECK (bus->memory[address & 65535] == value);
      else
        bus->memory[address & 65535] = value;
      address++;
      cursor = end;
    }
}

static void
fuse (CPUZ80 *cpu, Z80TestBus *bus, NSString *directory)
{
  NSString *input = [NSString
      stringWithContentsOfFile:[directory
                                   stringByAppendingPathComponent:@"tests.in"]
                      encoding:NSUTF8StringEncoding
                         error:NULL];
  NSString *expected =
      [NSString stringWithContentsOfFile:
                    [directory stringByAppendingPathComponent:@"tests.expected"]
                                encoding:NSUTF8StringEncoding
                                   error:NULL];
  CHECK (input != nil && expected != nil);
  NSArray *inputs = [input componentsSeparatedByString:@"\n\n"],
          *outputs = [expected componentsSeparatedByString:@"\n\n"];
  unsigned tested = 0, failures = 0;
  for (NSUInteger n = 0; n < [inputs count]; n++)
    {
      NSArray *in = lines ([inputs objectAtIndex:n]);
      if ([in count] < 3)
        continue;
      CHECK (n < [outputs count]);
      NSArray *out = lines ([outputs objectAtIndex:n]);
      CHECK ([[in objectAtIndex:0] isEqual:[out objectAtIndex:0]]);
      fresh (cpu, bus);
      unsigned target, expectedCycles;
      CPUZ80State s
          = vectorState ([in objectAtIndex:1], [in objectAtIndex:2], &target);
      for (NSUInteger l = 3; l < [in count]; l++)
        vectorMemory ([in objectAtIndex:l], bus, NO);
      NSUInteger row = 1;
      while (row < [out count] && [[out objectAtIndex:row] hasPrefix:@" "])
        {
          unsigned time, port, value;
          char type[3];
          if (sscanf ([[out objectAtIndex:row] UTF8String], "%u %2s %x %x",
                      &time, type, &port, &value)
                  == 4
              && !strcmp (type, "PR"))
            bus->ports[port] = value;
          row++;
        }
      CPUZ80State e
          = vectorState ([out objectAtIndex:row], [out objectAtIndex:row + 1],
                         &expectedCycles);
      [cpu setState:s];
      while ([cpu getCycleCount] < target)
        [cpu step];
      s = [cpu state];
      /* Fuse represents HALT with PC pointing at the opcode. */
      if (s.halted)
        s.pc--;
      BOOL ok
          = s.af == e.af && s.bc == e.bc && s.de == e.de && s.hl == e.hl
            && s.alternateAF == e.alternateAF && s.alternateBC == e.alternateBC
            && s.alternateDE == e.alternateDE && s.alternateHL == e.alternateHL
            && s.ix == e.ix && s.iy == e.iy && s.sp == e.sp && s.pc == e.pc
            && s.wz == e.wz && s.i == e.i && s.r == e.r && s.iff1 == e.iff1
            && s.iff2 == e.iff2 && s.interruptMode == e.interruptMode
            && s.halted == e.halted && s.cycles == expectedCycles;
      if (!ok)
        {
          failures++;
          fprintf (
              stderr,
              "Fuse %s: AF %04x/%04x BC %04x/%04x HL %04x/%04x PC %04x/%04x WZ %04x/%04x R %02x/%02x cycles %llu/%u\n",
              [[in objectAtIndex:0] UTF8String], s.af, e.af, s.bc, e.bc, s.hl,
              e.hl, s.pc, e.pc, s.wz, e.wz, s.r, e.r,
              (unsigned long long)s.cycles, expectedCycles);
        }
      for (NSUInteger l = row + 2; l < [out count]; l++)
        vectorMemory ([out objectAtIndex:l], bus, YES);
      tested++;
    }
  fprintf (stderr, "Fuse: %u vectors, %u failures\n", tested, failures);
  CHECK (failures == 0);
}

int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  Z80TestBus *bus = [Z80TestBus new];
  CPUZ80 *cpu = [[CPUZ80 alloc] initWithBus:bus];
  arithmetic (cpu, bus);
  wordsAndFlow (cpu, bus);
  prefixes (cpu, bus);
  interrupts (cpu, bus);
  blocksAndIO (cpu, bus);
  if (argc > 1)
    fuse (cpu, bus, [NSString stringWithUTF8String:argv[1]]);
  printf ("Z80: %u checks passed\n", checks);
  [cpu release];
  [bus release];
  [pool drain];
  return 0;
}

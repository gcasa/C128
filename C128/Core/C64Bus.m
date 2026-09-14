// SPDX-License-Identifier: GPL-3.0-or-later
#import "C64Bus.h"
static BOOL failure(NSError **error, NSString *message) {
  if (error) *error = [NSError errorWithDomain:@"C64" code:1
      userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
  return NO;
}
@implementation C64Bus
- (id)init {
  if ((self = [super init])) { cia1 = [CIA6526 new]; cia2 = [CIA6526 new]; [self reset]; }
  return self;
}
- (void)dealloc { [cia1 release]; [cia2 release]; [super dealloc]; }
- (void)releaseKeys { memset(keys, 0, sizeof keys); }
- (void)reset {
  memset(ram, 0, sizeof ram); memset(color, 0, sizeof color);
  memset(vic, 0, sizeof vic); memset(sid, 0, sizeof sid); [self releaseKeys];
  ram[0] = 0x2f; ram[1] = 0x37;
  [cia1 reset]; [cia2 reset]; raster = rasterCycle = 0;
}
- (BOOL)loadROMDirectory:(NSString *)path error:(NSError **)error {
  NSArray *names = [NSArray arrayWithObjects:@"basic.rom", @"kernal.rom", @"characters.rom", nil];
  NSMutableArray *images = [NSMutableArray array];
  for (NSUInteger i = 0; i < 3; i++) {
    NSData *image = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:[names objectAtIndex:i]]];
    NSUInteger size = i == 2 ? 4096 : 8192;
    if ([image length] != size) return failure(error, [NSString stringWithFormat:
        @"%@ must contain exactly %lu bytes. Select a folder containing all three C64 ROMs.", [names objectAtIndex:i], (unsigned long)size]);
    [images addObject:image];
  }
  memcpy(basic, [[images objectAtIndex:0] bytes], 8192); memcpy(kernal, [[images objectAtIndex:1] bytes], 8192);
  memcpy(characters, [[images objectAtIndex:2] bytes], 4096); hasROMs = YES; return YES;
}
- (uint8_t)keyboardPort:(NSUInteger)p {
  uint8_t a = [cia1 port:0 input:255], b = [cia1 port:1 input:255];
  // Propagate low levels through closed switches, including reverse scanning.
  for (int pass = 0; pass < 8; pass++) for (int row = 0; row < 8; row++)
    for (int col = 0; col < 8; col++) if (keys[row][col]) {
      if (!(a & (1 << row))) b &= ~(1 << col);
      if (!(b & (1 << col))) a &= ~(1 << row);
    }
  return p == 0 ? a : b;
}
- (uint8_t)readMemory:(uint16_t)a {
  uint8_t port = (ram[1] & ram[0]) | ~ram[0];
  if (a == 1) return port;
  if (a >= 0xa000 && a < 0xc000 && (port & 3) == 3) return basic[a - 0xa000];
  if (a >= 0xe000 && (port & 2)) return kernal[a - 0xe000];
  if (a >= 0xd000 && a < 0xe000 && (port & 3)) {
    if (!(port & 4)) return characters[a & 4095];
    if (a < 0xd400) {
      uint8_t r = a & 63;
      if (r == 0x11) return (vic[r] & 127) | ((raster & 256) >> 1);
      if (r == 0x12) return raster;
      if (r == 0x19) return vic[r] | 0x70 | ((vic[0x19] & vic[0x1a] & 15) ? 128 : 0);
      if (r == 0x1a) return vic[r] | 0xf0;
      if (r == 0x1e || r == 0x1f) { uint8_t v = vic[r]; vic[r] = 0; return v; }
      if (r >= 0x2f) return 255;
      return vic[r];
    }
    if (a < 0xd800) return (a & 31) == 0x19 || (a & 31) == 0x1a ? 255 : 0;
    if (a < 0xdc00) return color[a & 1023] | 0xf0;
    if (a < 0xdd00) return (a & 15) < 2 ? [self keyboardPort:a & 1] : [cia1 read:a & 15];
    if (a < 0xde00) return [cia2 read:a & 15];
    return 255;
  }
  return ram[a];
}
- (void)writeMemory:(uint8_t)v address:(uint16_t)a {
  uint8_t port = (ram[1] & ram[0]) | ~ram[0];
  if (a >= 0xd000 && a < 0xe000 && (port & 3) && (port & 4)) {
    if (a < 0xd400) {
      uint8_t r = a & 63;
      if (r == 0x19) vic[r] &= ~(v & 15);
      else if (r != 0x1e && r != 0x1f && r < 0x2f) vic[r] = v;
    } else if (a < 0xd800) sid[a & 31] = v;
    else if (a < 0xdc00) color[a & 1023] = v & 15;
    else if (a < 0xdd00) [cia1 write:v reg:a & 15];
    else if (a < 0xde00) [cia2 write:v reg:a & 15];
    return;
  }
  ram[a] = v; // RAM beneath ROM remains writable.
}
- (uint8_t)videoRead:(uint16_t)a {
  uint16_t bank = ((~[cia2 port:0 input:255]) & 3) << 14;
  a = bank | (a & 0x3fff);
  if ((a & 0x7000) == 0x1000) return characters[a & 4095];
  return ram[a];
}
- (BOOL)irq { return [cia1 irq] || (vic[0x19] & vic[0x1a] & 15); }
- (void)tick {
  [cia1 tick]; [cia2 tick];
  if (++rasterCycle == 63) {
    rasterCycle = 0; raster = (raster + 1) % 312;
    if (raster == (NSUInteger)(vic[0x12] | ((vic[0x11] & 128) << 1))) vic[0x19] |= 1;
  }
}
- (BOOL)loadPRG:(NSData *)data start:(uint16_t *)start error:(NSError **)error {
  if ([data length] < 3) return failure(error, @"A PRG needs a two-byte load address and program data.");
  const uint8_t *bytes = [data bytes];
  NSUInteger address = bytes[0] | (bytes[1] << 8), length = [data length] - 2;
  if (length > 65536 - address) return failure(error, @"The PRG extends past the end of C64 memory.");
  if (address == 0x0801 && address + length > 0xa000)
    return failure(error, @"This BASIC PRG extends beyond BASIC RAM ($9FFF).");
  memcpy(ram + address, bytes + 2, length);
  if (address == 0x0801) {
    uint16_t end = address + length;
    ram[0x2b] = 1; ram[0x2c] = 8;
    for (int p = 0x2d; p <= 0x31; p += 2) { ram[p] = end; ram[p + 1] = end >> 8; }
  }
  if (start) *start = address;
  return YES;
}
@end

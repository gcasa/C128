// SPDX-License-Identifier: GPL-3.0-or-later
#import "C128Bus.h"
static BOOL fail(NSError **error, NSString *message) {
  if (error) *error = [NSError errorWithDomain:@"C128" code:1 userInfo:
    [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
  return NO;
}
@implementation C128Bus
- (id)init { if ((self = [super init])) { vdc = [VDC8563 new]; [self reset]; } return self; }
- (void)dealloc { [vdc release]; [super dealloc]; }
- (void)reset {
  [super reset]; memset(bank1, 0, sizeof bank1); memset(color1, 0, sizeof color1);
  memset(mmu, 0, sizeof mmu); mmu[5] = 1; mmu[9] = 1;
  page0Latch = page1Latch = 0; unsupportedCPU = NO; [vdc reset];
}
- (BOOL)isC64 { return (mmu[5] & 64) != 0; }
- (void)setMMU:(uint8_t)v reg:(unsigned)r {
  if (r >= 11) return;
  if (r == 8) { page0Latch = v & 1; return; }
  if (r == 10) { page1Latch = v & 1; return; }
  if (r == 7) mmu[8] = page0Latch;
  if (r == 9) mmu[10] = page1Latch;
  mmu[r] = v;
  if (r == 5) unsupportedCPU = !(v & 1) || ((v & 64) && !hasC64ROMs);
}
- (uint8_t *)ramPointer:(uint16_t)a {
  unsigned bank = (mmu[0] >> 6) & 1;
  unsigned shared = (mmu[6] & 3) == 0 ? 1024 : 2048 << (mmu[6] & 3);
  if (a < 0x200) { unsigned r = a < 256 ? 7 : 9; bank = mmu[r+1] & 1; a = (mmu[r] << 8) | (a & 255); }
  if (((mmu[6] & 4) && a < shared) || ((mmu[6] & 8) && a >= 65536 - shared)) bank = 0;
  return (bank ? bank1 : ram) + a;
}
- (BOOL)loadROMDirectory:(NSString *)path error:(NSError **)error {
  NSArray *names = [NSArray arrayWithObjects:@"basiclo.rom", @"basichi.rom", @"kernal.rom", @"characters.rom", nil];
  NSMutableArray *images = [NSMutableArray array]; unsigned i;
  for (i = 0; i < 4; i++) {
    NSData *data = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:[names objectAtIndex:i]]];
    unsigned size = i == 3 ? 8192 : 16384;
    if ([data length] != size) return fail(error, [NSString stringWithFormat:@"%@ must contain exactly %u bytes.", [names objectAtIndex:i], size]);
    [images addObject:data];
  }
  NSData *b64 = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:@"basic64.rom"]];
  NSData *k64 = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:@"kernal64.rom"]];
  if ((b64 || k64) && ([b64 length] != 8192 || [k64 length] != 8192)) return fail(error, @"Optional basic64.rom and kernal64.rom must both contain 8192 bytes.");
  memcpy(basic128, [[images objectAtIndex:0] bytes], 16384);
  memcpy(basic128+16384, [[images objectAtIndex:1] bytes], 16384);
  memcpy(system128, [[images objectAtIndex:2] bytes], 16384);
  memcpy(characters128, [[images objectAtIndex:3] bytes], 8192);
  memcpy(characters, characters128+4096, 4096);
  hasC64ROMs = b64 != nil;
  if (hasC64ROMs) { memcpy(basic, [b64 bytes], 8192); memcpy(kernal, [k64 bytes], 8192); }
  else { memset(basic, 255, sizeof basic); memset(kernal, 255, sizeof kernal); }
  hasROMs = YES; return YES;
}
- (uint8_t)readMemory:(uint16_t)a {
  if ([self isC64]) return [super readMemory:a];
  if (a == 0) return ram[0];
  if (a == 1) return (ram[1] & ram[0]) | (0x57 & ~ram[0]);
  if (a >= 0xff00 && a <= 0xff04) return mmu[a & 15];
  if (a >= 0xd000 && a < 0xe000 && !(mmu[0] & 1)) {
    if (a >= 0xd500 && a < 0xd600) {
      unsigned r = a & 255;
      if (r == 5) return (mmu[5] & 15) | 0x30 | (columns80 ? 0 : 128);
      if (r == 11) return 0x20;
      return r < 12 ? mmu[r] | ((r == 8 || r == 10) ? 0xf0 : 0) : 255;
    }
    if (a >= 0xd600 && a < 0xd700) return [vdc read:a];
    if (a >= 0xd800 && a < 0xdc00) return ((ram[1] & 1) ? color1 : color)[a & 1023] | 0xf0;
    if (a < 0xd400 && (a & 63) >= 0x2f && (a & 63) <= 0x30) return vic[a & 63] | ((a & 63) == 0x2f ? 0xf8 : 0xfc);
    uint8_t old0 = ram[0], old1 = ram[1]; ram[0] = 0x2f; ram[1] = 0x37;
    uint8_t result = [super readMemory:a]; ram[0] = old0; ram[1] = old1; return result;
  }
  if (a >= 0x4000 && a < 0x8000 && !(mmu[0] & 2)) return basic128[a-0x4000];
  if (a >= 0x8000 && a < 0xc000) { unsigned mode = (mmu[0] >> 2) & 3;
    if (!mode) return basic128[a-0x4000];
    if (mode != 3) return 255;
  }
  if (a >= 0xc000) { unsigned mode = (mmu[0] >> 4) & 3;
    if (!mode) { if (a >= 0xd000 && a < 0xe000) return characters128[(a & 4095) + ((ram[1] & 64) ? 0 : 4096)]; return system128[a-0xc000]; }
    if (mode != 3) return 255;
  }
  return *[self ramPointer:a];
}
- (void)writeMemory:(uint8_t)v address:(uint16_t)a {
  if ([self isC64]) { [super writeMemory:v address:a]; return; }
  if (a < 2) { ram[a] = v; return; }
  if (a >= 0xff00 && a <= 0xff04) { [self setMMU:a == 0xff00 ? v : mmu[a & 15] reg:0]; return; }
  if (a >= 0xd000 && a < 0xe000 && !(mmu[0] & 1)) {
    if (a >= 0xd500 && a < 0xd600) { [self setMMU:v reg:a & 255]; return; }
    if (a >= 0xd600 && a < 0xd700) { [vdc write:v address:a]; return; }
    if (a >= 0xd800 && a < 0xdc00) { ((ram[1] & 1) ? color1 : color)[a & 1023] = v & 15; return; }
    if (a < 0xd400 && (a & 63) >= 0x2f && (a & 63) <= 0x30) { vic[a & 63] = v; return; }
    uint8_t old0 = ram[0], old1 = ram[1]; ram[0] = 0x2f; ram[1] = 0x37;
    [super writeMemory:v address:a]; ram[0] = old0; ram[1] = old1; return;
  }
  *[self ramPointer:a] = v;
}
- (uint8_t)videoRead:(uint16_t)a {
  if ([self isC64]) return [super videoRead:a];
  a = (((~[cia2 port:0 input:255]) & 3) << 14) | (a & 0x3fff);
  if (!(mmu[6] & 64) && (a & 0x7000) == 0x1000) return characters128[(a & 4095) + ((ram[1] & 64) ? 0 : 4096)];
  return (mmu[6] & 64) ? bank1[a] : ram[a];
}
- (void)renderRGBA:(uint8_t *)pixels {
  if (![self isC64] && (ram[1] & 2)) { uint8_t saved[1024]; memcpy(saved, color, 1024); memcpy(color, color1, 1024); [super renderRGBA:pixels]; memcpy(color, saved, 1024); }
  else [super renderRGBA:pixels];
}
- (BOOL)loadPRG:(NSData *)data start:(uint16_t *)start error:(NSError **)error {
  if ([self isC64]) return [super loadPRG:data start:start error:error];
  if ([data length] < 3) return fail(error, @"A PRG needs a two-byte address and program data.");
  const uint8_t *p = [data bytes]; unsigned a = p[0] | (p[1] << 8); NSUInteger n = [data length] - 2;
  if (n > 65536-a || (a == 0x1c01 && a+n > 0xff00)) return fail(error, @"Program exceeds available RAM.");
  memcpy(ram+a, p+2, n);
  if (a == 0x1c01) { unsigned end = a+n; ram[0x2b] = ram[0xac] = 1; ram[0x2c] = ram[0xad] = 0x1c; ram[0x1210] = end; ram[0x1211] = end >> 8; }
  if (start) *start = a;
  return YES;
}
@end

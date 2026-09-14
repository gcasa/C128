// SPDX-License-Identifier: GPL-3.0-or-later
#import "CPU6502Bus.h"
#import "CIA6526.h"
enum { C64Width = 384, C64Height = 272 };
@interface C64Bus : NSObject <CPU6502Bus> {
@public
  uint8_t ram[65536], basic[8192], kernal[8192], characters[4096];
  uint8_t color[1024], vic[64], sid[32];
  BOOL keys[8][8], hasROMs;
  CIA6526 *cia1, *cia2;
  NSUInteger raster, rasterCycle;
}
- (void)reset;
- (BOOL)loadROMDirectory:(NSString *)path error:(NSError **)error;
- (BOOL)loadPRG:(NSData *)data start:(uint16_t *)start error:(NSError **)error;
- (void)tick;
- (BOOL)irq;
- (uint8_t)videoRead:(uint16_t)address;
- (void)releaseKeys;
@end

@interface C64Bus (Video)
- (void)renderRGBA:(uint8_t *)pixels;
@end

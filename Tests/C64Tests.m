// SPDX-License-Identifier: GPL-3.0-or-later
#import "C64Machine.h"
#include <stdio.h>
#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); return 1; } } while (0)
int main(int argc, char *argv[]) {
#ifdef GNUSTEP
  extern char **environ; GSInitializeProcess(argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new]; {
    C64Machine *m = [C64Machine new]; C64Bus *b = m->memory;
    memset(b->basic, 0xba, 8192); memset(b->kernal, 0xce, 8192); memset(b->characters, 0xcc, 4096);
    b->ram[0xa000] = 0x11; b->ram[0xe000] = 0x22; b->ram[0xd000] = 0x33; b->vic[0] = 0x44;
    for (int bank = 0; bank < 8; bank++) {
      [b writeMemory:bank address:1];
      CHECK([b readMemory:0xa000] == ((bank & 3) == 3 ? 0xba : 0x11));
      CHECK([b readMemory:0xe000] == ((bank & 2) ? 0xce : 0x22));
      CHECK([b readMemory:0xd000] == (!(bank & 3) ? 0x33 : (bank & 4) ? 0x44 : 0xcc));
    }
    [b writeMemory:7 address:1]; [b writeMemory:0x55 address:0xa000];
    CHECK([b readMemory:0xa000] == 0xba && b->ram[0xa000] == 0x55);
    [b writeMemory:0 address:0]; [b writeMemory:0 address:1]; CHECK(([b readMemory:1] & 7) == 7);
    [b reset]; [b writeMemory:0xab address:0xd800]; CHECK([b readMemory:0xd800] == 0xfb);
    [b writeMemory:0x19 address:0xd060]; CHECK(b->vic[0x20] == 0x19);
    [b writeMemory:255 address:0xdc02]; [b writeMemory:~(1 << 1) address:0xdc00];
    b->keys[1][2] = YES; CHECK([b readMemory:0xdc01] == 0xfb);
    [b writeMemory:0 address:0xdc02]; [b writeMemory:255 address:0xdc03];
    [b writeMemory:~(1 << 2) address:0xdc01]; CHECK([b readMemory:0xdc00] == 0xfd);
    [b reset]; CIA6526 *cia = b->cia1;
    [cia write:2 reg:4]; [cia write:0 reg:5]; [cia write:0x81 reg:13]; [cia write:0x19 reg:14];
    [cia tick]; [cia tick]; CHECK(![cia irq]); [cia tick]; CHECK([cia irq]);
    CHECK([cia read:13] == 0x81); CHECK(![cia irq]); CHECK(!(cia->registers[14] & 1));
    [b reset]; [b writeMemory:1 address:0xd012]; [b writeMemory:1 address:0xd01a];
    for (int i = 0; i < 63; i++) [b tick];
    CHECK([b readMemory:0xd012] == 1 && [b irq]);
    [b writeMemory:1 address:0xd019]; CHECK(![b irq]);
    [b->cia2 write:3 reg:2]; [b->cia2 write:2 reg:0]; b->ram[0x5000] = 0x67;
    CHECK([b videoRead:0x1000] == 0x67); [b->cia2 write:3 reg:0]; CHECK([b videoRead:0x1000] == 0xcc);
    uint16_t start; NSError *error = nil;
    const uint8_t prg[] = {1,8,0,0};
    CHECK([b loadPRG:[NSData dataWithBytes:prg length:4] start:&start error:&error]);
    CHECK(start == 0x801 && b->ram[0x2d] == 3 && b->ram[0x2e] == 8);
    const uint8_t overflow[] = {255,255,1,2};
    CHECK(![b loadPRG:[NSData dataWithBytes:overflow length:4] start:NULL error:&error]);
    CHECK(![b loadPRG:[NSData data] start:NULL error:&error]);
    CHECK(![b loadROMDirectory:@"/nonexistent-c64-roms" error:&error]);
    // Render a known glyph through the VIC's own ROM view.
    [b reset]; b->vic[0x11] = 0x1b; b->vic[0x18] = 0x14;
    b->ram[0x400] = 0; b->characters[0] = 0x80; b->color[0] = 1;
    uint8_t *pixels = malloc(C64Width * C64Height * 4);
    [b renderRGBA:pixels]; NSUInteger i = (36 * C64Width + 32) * 4;
    CHECK(pixels[i] == 255 && pixels[i+4] == 0); free(pixels);
    // NMI ignores I and uses the mapped vector, with a seven-cycle entry.
    [b writeMemory:0 address:1]; b->ram[0xfffa] = 0; b->ram[0xfffb] = 0xc0;
    [m->cpu reset]; NSUInteger before = [m->cpu getCycleCount]; [m restore];
    CHECK([m->cpu getProgramCounter] == 0xc000 && [m->cpu getCycleCount] == before + 7);
    puts("PASS: banking, RAM under ROM, color RAM, mirrors, keyboard, CIA, raster IRQ, VIC bank, PRG validation, video, NMI");
    [m release];
  }
  [pool drain];
  return 0;
}

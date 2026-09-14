/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C64Bus.h"
static const uint8_t palette[16][3] = {
  { 0, 0, 0 },       { 255, 255, 255 }, { 136, 57, 50 },   { 103, 182, 189 },
  { 139, 63, 150 },  { 85, 160, 73 },   { 64, 49, 141 },   { 191, 206, 114 },
  { 139, 84, 41 },   { 87, 66, 0 },     { 184, 105, 98 },  { 80, 80, 80 },
  { 120, 120, 120 }, { 148, 224, 137 }, { 120, 105, 196 }, { 159, 159, 159 }
};
@implementation C64Bus (Video)

- (void)renderRGBA:(uint8_t *)pixels
{
  uint8_t indices[C64Width * C64Height];
  BOOL foreground[C64Width * C64Height];
  memset (indices, vic[0x20] & 15, sizeof indices);
  memset (foreground, 0, sizeof foreground);
  uint16_t screen = (vic[0x18] & 0xf0) << 6;
  uint16_t charset = (vic[0x18] & 14) << 10;
  BOOL bitmap = (vic[0x11] & 32) != 0, extended = (vic[0x11] & 64) != 0;
  BOOL multi = (vic[0x16] & 16) != 0;
  if (vic[0x11] & 16)
    {
      for (int y = 0; y < 200; y++)
        for (int x = 0; x < 320; x++)
          {
            int cell = (y / 8) * 40 + x / 8;
            uint8_t code = [self videoRead:screen + cell], ink = color[cell];
            uint8_t bits = [self
                videoRead:bitmap ? ((vic[0x18] & 8) << 10) + cell * 8 + (y & 7)
                                 : charset + (extended ? code & 63 : code) * 8
                                       + (y & 7)];
            uint8_t c = vic[0x21] & 15;
            BOOL fg = NO;
            if (multi && (bitmap || (ink & 8)) && !extended)
              {
                unsigned pair = (bits >> (6 - (x & 6))) & 3;
                uint8_t choices[4]
                    = { vic[0x21], bitmap ? code >> 4 : vic[0x22],
                        bitmap ? code & 15 : vic[0x23],
                        bitmap ? ink : ink & 7 };
                c = choices[pair] & 15;
                fg = pair >= 2;
              }
            else
              {
                fg = (bits & (128 >> (x & 7))) != 0;
                c = bitmap ? (fg ? code >> 4 : code & 15)
                           : (fg ? ink : vic[0x21 + (extended ? code >> 6 : 0)])
                                 & 15;
              }
            /* Invalid extended bitmap modes display black in this
             * approximation. */
            if (extended && (bitmap || multi))
              {
                c = 0;
                fg = NO;
              }
            int i = (y + 36) * C64Width + x + 32;
            indices[i] = c;
            foreground[i] = fg;
          }
      /* Draw lower-numbered sprites last so they have display priority. */
      for (int sprite = 7; sprite >= 0; sprite--)
        if (vic[0x15] & (1 << sprite))
          {
            int sx = vic[sprite * 2] + ((vic[0x10] & (1 << sprite)) ? 256 : 0)
                     - 24 + 32;
            int sy = vic[sprite * 2 + 1] - 50 + 36;
            int scaleX = (vic[0x1d] & (1 << sprite)) ? 2 : 1;
            int scaleY = (vic[0x17] & (1 << sprite)) ? 2 : 1;
            BOOL mc = (vic[0x1c] & (1 << sprite)) != 0;
            uint16_t base = [self videoRead:screen + 0x3f8 + sprite] * 64;
            for (int y = 0; y < 21; y++)
              for (int x = 0; x < 24; x++)
                {
                  uint8_t bits = [self videoRead:base + y * 3 + x / 8];
                  unsigned value = mc ? (bits >> (6 - (x & 6))) & 3
                                      : (bits >> (7 - (x & 7))) & 1;
                  if (!value)
                    continue;
                  uint8_t c = !mc || value == 2 ? vic[0x27 + sprite]
                                                : vic[value == 1 ? 0x25 : 0x26];
                  for (int dy = 0; dy < scaleY; dy++)
                    for (int dx = 0; dx < scaleX; dx++)
                      {
                        int px = sx + x * scaleX + dx,
                            py = sy + y * scaleY + dy;
                        if (px < 32 || px >= 352 || py < 36 || py >= 236)
                          continue;
                        int i = py * C64Width + px;
                        if (!(vic[0x1b] & (1 << sprite)) || !foreground[i])
                          indices[i] = c & 15;
                      }
                }
          }
    }
  for (NSUInteger i = 0; i < sizeof indices; i++)
    {
      memcpy (pixels + i * 4, palette[indices[i] & 15], 3);
      pixels[i * 4 + 3] = 255;
    }
}

@end

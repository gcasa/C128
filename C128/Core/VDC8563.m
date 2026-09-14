/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "VDC8563.h"
@implementation VDC8563

- (void)reset
{
  memset (ram, 0, sizeof ram);
  memset (registers, 0, sizeof registers);
  selected = 0;
  frames = 0;
}

- (uint8_t)read:(uint16_t)a
{
  if (!(a & 1))
    return 0xa0; /* ready, vertical blank; instruction-level approximation */
  if (selected == 31)
    {
      uint16_t p = (registers[18] << 8) | registers[19];
      uint8_t v = ram[p++];
      registers[18] = p >> 8;
      registers[19] = p;
      return v;
    }
  return registers[selected];
}

- (void)write:(uint8_t)v address:(uint16_t)a
{
  if (!(a & 1))
    {
      selected = v & 63;
      return;
    }
  registers[selected] = v;
  if (selected == 31 || selected == 30)
    {
      uint16_t p = (registers[18] << 8) | registers[19];
      uint16_t source = (registers[32] << 8) | registers[33];
      unsigned count = selected == 31 ? 1 : (v ? v : 256), i;
      for (i = 0; i < count; i++)
        ram[p++] = selected == 30 && (registers[24] & 128) ? ram[source++]
                                                           : registers[31];
      registers[18] = p >> 8;
      registers[19] = p;
      if (selected == 30 && (registers[24] & 128))
        {
          registers[32] = source >> 8;
          registers[33] = source;
        }
    }
}

- (void)renderRGBA:(uint8_t *)pixels
{
  unsigned y, x, height = (registers[9] & 31) + 1;
  uint16_t screen = (registers[12] << 8) | registers[13];
  uint16_t attrs = (registers[20] << 8) | registers[21];
  uint16_t charset = (registers[28] & 0xe0) << 8;
  uint16_t cursor = (registers[14] << 8) | registers[15];
  frames++;
  for (y = 0; y < VDCHeight; y++)
    for (x = 0; x < VDCWidth; x++)
      {
        unsigned cell = (y / height) * (registers[1] + registers[27]) + x / 8;
        uint8_t attr = ram[(uint16_t)(attrs + cell)],
                code = ram[(uint16_t)(screen + cell)];
        BOOL attributes = (registers[25] & 64) != 0;
        uint8_t bits
            = ram[(uint16_t)(charset + code * 16 + (y % height)
                             + (attributes && (attr & 128) ? 4096 : 0))];
        if (registers[25] & 128)
          bits = ram[(uint16_t)(screen + y * registers[1] + x / 8)];
        if (attributes && (attr & 32) && y % height == (registers[29] & 31))
          bits = 255;
        if (attributes && (attr & 64))
          bits ^= 255;
        if (attributes && (attr & 16) && (frames & 32))
          bits = 0;
        if ((uint16_t)(screen + cell) == cursor && (registers[10] & 96) != 32
            && y % height >= (registers[10] & 31)
            && y % height <= (registers[11] & 31)
            && (!(registers[10] & 64) || (frames & 16)))
          bits ^= 255;
        if (registers[24] & 64)
          bits ^= 255;
        unsigned c = (bits & (128 >> (x & 7)))
                         ? (attributes ? attr & 15 : registers[26] >> 4)
                         : registers[26] & 15;
        if (x / 8 >= registers[1] || y / height >= registers[6])
          c = registers[26] & 15;
        unsigned i = (y * VDCWidth + x) * 4, intensity = (c & 1) ? 85 : 0;
        pixels[i] = ((c & 8) ? 170 : 0) + intensity;
        pixels[i + 1] = ((c & 4) ? 170 : 0) + intensity;
        pixels[i + 2] = ((c & 2) ? 170 : 0) + intensity;
        pixels[i + 3] = 255;
      }
}

@end

/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C64Machine.h"
@implementation C64CPU

- (void)nmi
{
  [self push:pc >> 8];
  [self push:pc & 255];
  [self push:(s.sr & ~16) | 32];
  s.status.i = 1;
  pc = [self readMemory:0xfffa] | ([self readMemory:0xfffb] << 8);
  for (int i = 0; i < 7; i++)
    [self tick];
}

@end
@implementation C64Machine

- (id)init
{
  if ((self = [super init]))
    {
      memory = [C64Bus new];
      cpu = [[C64CPU alloc] initWithBus:memory];
    }
  return self;
}

- (void)dealloc
{
  [cpu release];
  [memory release];
  [super dealloc];
}

- (void)reset
{
  [memory reset];
  [cpu reset];
  previousNMI = NO;
}

- (void)restore
{
  [cpu nmi];
  for (int i = 0; i < 7; i++)
    [memory tick];
}

- (void)runCycles:(NSUInteger)count
{
  NSUInteger end = [cpu getCycleCount] + count;
  while ([cpu getCycleCount] < end)
    {
      NSUInteger before = [cpu getCycleCount];
      BOOL nmi = [memory->cia2 irq];
      if (nmi && !previousNMI)
        [cpu nmi];
      else if ([memory irq])
        [cpu interrupt];
      previousNMI = nmi;
      [cpu step];
      NSUInteger elapsed = [cpu getCycleCount] - before;
      for (NSUInteger i = 0; i < elapsed; i++)
        [memory tick];
    }
}

@end

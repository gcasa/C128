/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "C128Machine.h"
@implementation C128Machine

- (id)init
{
  if ((self = [super init]))
    {
      memory = [C128Bus new];
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
  while ([cpu getCycleCount] < end && !memory->unsupportedCPU)
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

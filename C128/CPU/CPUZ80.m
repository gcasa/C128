/* SPDX-License-Identifier: GPL-3.0-or-later */
#import "CPUZ80.h"
#include <string.h>

/* Decode using the Z80's x/y/z opcode fields. Timings in the base decoder
 * exclude DD/FD fetches; CB/ED timings include their prefix. */
enum
{
  C = 1,
  N = 2,
  P = 4,
  X = 8,
  H = 16,
  Y = 32,
  Z = 64,
  S = 128
};

static uint8_t
high (uint16_t v)
{
  return v >> 8;
}

static uint8_t
low (uint16_t v)
{
  return v;
}

static void
setHigh (uint16_t *v, uint8_t n)
{
  *v = (*v & 255) | ((uint16_t)n << 8);
}

static void
setLow (uint16_t *v, uint8_t n)
{
  *v = (*v & 0xff00) | n;
}

static uint8_t
sz (uint8_t v)
{
  return (v & (S | Y | X)) | (v ? 0 : Z);
}

static uint8_t
parity (uint8_t v)
{
  v ^= v >> 4;
  v ^= v >> 2;
  v ^= v >> 1;
  return (v & 1) ? 0 : P;
}

static uint8_t
szp (uint8_t v)
{
  return sz (v) | parity (v);
}

static void
refresh (CPUZ80State *s)
{
  s->r = (s->r & 128) | ((s->r + 1) & 127);
}

static uint16_t *
pair (CPUZ80State *s, unsigned p, unsigned index)
{
  switch (p)
    {
    case 0:
      return &s->bc;
    case 1:
      return &s->de;
    case 2:
      return index == 1 ? &s->ix : index == 2 ? &s->iy : &s->hl;
    default:
      return &s->sp;
    }
}

static BOOL
condition (CPUZ80State *s, unsigned c)
{
  uint8_t f = low (s->af);
  switch (c)
    {
    case 0:
      return !(f & Z);
    case 1:
      return (f & Z) != 0;
    case 2:
      return !(f & C);
    case 3:
      return (f & C) != 0;
    case 4:
      return !(f & P);
    case 5:
      return (f & P) != 0;
    case 6:
      return !(f & S);
    default:
      return (f & S) != 0;
    }
}

static uint8_t
add8 (CPUZ80State *s, uint8_t a, uint8_t b, unsigned carry, BOOL sub)
{
  unsigned result = sub ? (unsigned)a - b - carry : (unsigned)a + b + carry;
  uint8_t v = result;
  uint8_t f = sz (v) | ((a ^ b ^ v) & H) | ((result & 256) ? C : 0);
  if (sub)
    f |= N | (((a ^ b) & (a ^ v) & 128) ? P : 0);
  else
    f |= ((~(a ^ b) & (a ^ v) & 128) ? P : 0);
  setLow (&s->af, f);
  return v;
}

static void
alu (CPUZ80State *s, unsigned op, uint8_t v)
{
  uint8_t a = high (s->af), result = a, carry = low (s->af) & C;
  switch (op)
    {
    case 0:
      result = add8 (s, a, v, 0, NO);
      break;
    case 1:
      result = add8 (s, a, v, carry, NO);
      break;
    case 2:
      result = add8 (s, a, v, 0, YES);
      break;
    case 3:
      result = add8 (s, a, v, carry, YES);
      break;
    case 4:
      result = a & v;
      setLow (&s->af, szp (result) | H);
      break;
    case 5:
      result = a ^ v;
      setLow (&s->af, szp (result));
      break;
    case 6:
      result = a | v;
      setLow (&s->af, szp (result));
      break;
    case 7:
      add8 (s, a, v, 0, YES);
      setLow (&s->af, (low (s->af) & ~(X | Y)) | (v & (X | Y)));
      return;
    }
  setHigh (&s->af, result);
}

static uint8_t
incdec (CPUZ80State *s, uint8_t v, BOOL decrement)
{
  uint8_t result = v + (decrement ? -1 : 1);
  uint8_t f = (low (s->af) & C) | sz (result) | ((v ^ result) & H);
  f |= decrement ? N | (v == 128 ? P : 0) : (v == 127 ? P : 0);
  setLow (&s->af, f);
  return result;
}

@interface CPUZ80 (Execution)
- (uint8_t)fetchByte;
- (uint8_t)fetchOpcode;
- (uint16_t)fetchWord;
- (uint16_t)readWord:(uint16_t)address;
- (void)writeWord:(uint16_t)value at:(uint16_t)address;
- (void)pushWord:(uint16_t)value;
- (uint16_t)popWord;
- (uint8_t)readRegister:(unsigned)r
                  index:(unsigned)index
                address:(uint16_t)address;
- (void)writeRegister:(unsigned)r
                index:(unsigned)index
              address:(uint16_t)address
                value:(uint8_t)value;
- (NSUInteger)decode:(uint8_t)opcode index:(unsigned)index;
- (NSUInteger)decodeCB:(unsigned)index;
- (NSUInteger)decodeED;
- (NSUInteger)instruction:(uint8_t)opcode;
@end

@implementation CPUZ80

- (id)initWithBus:(id<CPUZ80Bus>)addressBus
{
  if (!addressBus)
    {
      [self release];
      [NSException raise:NSInvalidArgumentException
                  format:@"CPUZ80 requires a bus"];
      return nil;
    }
  if ((self = [super init]))
    {
      bus = [addressBus retain];
      [self reset];
    }
  return self;
}

- (void)dealloc
{
  [bus release];
  [super dealloc];
}

- (void)reset
{
  uint64_t cycles = registers.cycles;
  memset (&registers, 0, sizeof (registers));
  registers.af = registers.sp = 0xffff;
  registers.cycles = cycles;
}

- (CPUZ80State)state
{
  return registers;
}

- (void)setState:(CPUZ80State)state
{
  if (state.interruptMode > 2 || state.eiDelay > 2 || state.prefixIndex > 2)
    [NSException raise:NSInvalidArgumentException
                format:@"Invalid Z80 interrupt state"];
  registers = state;
}

- (uint16_t)getProgramCounter
{
  return registers.pc;
}

- (void)setProgramCounter:(uint16_t)address
{
  registers.pc = address;
}

- (uint64_t)getCycleCount
{
  return registers.cycles;
}

- (void)setInterruptLine:(BOOL)asserted
{
  registers.intLine = asserted;
}

- (void)setNMILine:(BOOL)asserted
{
  if (asserted && !registers.nmiLine)
    registers.nmiPending = YES;
  registers.nmiLine = asserted;
}

- (void)nmi
{
  registers.nmiPending = YES;
}

- (NSUInteger)step
{
  CPUZ80State *s = &registers;
  NSUInteger elapsed;
  flagsWritten = NO;
  if (s->nmiPending && !s->prefixIndex)
    {
      s->nmiPending = NO;
      s->halted = NO;
      s->iff1 = NO;
      refresh (s);
      [self pushWord:s->pc];
      s->pc = s->wz = 0x66;
      elapsed = 11;
    }
  else if (s->intLine && s->iff1 && !s->eiDelay && !s->prefixIndex)
    {
      s->halted = NO;
      s->iff1 = s->iff2 = NO;
      refresh (s);
      uint8_t vector = [bus acknowledgeInterrupt];
      if (s->interruptMode == 0)
        {
          elapsed = [self instruction:vector] + 2;
          if (s->eiDelay && !s->prefixIndex)
            s->eiDelay--;
        }
      else
        {
          [self pushWord:s->pc];
          s->pc = s->interruptMode == 1
                      ? 0x38
                      : [self readWord:((uint16_t)s->i << 8) | vector];
          s->wz = s->pc;
          elapsed = s->interruptMode == 1 ? 13 : 19;
        }
    }
  else if (s->halted)
    {
      [bus readMemory:s->pc];
      refresh (s);
      elapsed = 4;
    }
  else
    {
      elapsed = [self instruction:[self fetchOpcode]];
      if (s->eiDelay && !s->prefixIndex)
        s->eiDelay--;
    }
  if (!s->prefixIndex)
    s->q = flagsWritten ? low (s->af) : 0;
  s->cycles += elapsed;
  return elapsed;
}

@end

@implementation CPUZ80 (Execution)

- (uint8_t)fetchByte
{
  uint8_t v = [bus readMemory:registers.pc];
  registers.pc++;
  return v;
}

- (uint8_t)fetchOpcode
{
  refresh (&registers);
  return [self fetchByte];
}

- (uint16_t)fetchWord
{
  uint8_t l = [self fetchByte];
  return l | ((uint16_t)[self fetchByte] << 8);
}

- (uint16_t)readWord:(uint16_t)address
{
  uint8_t l = [bus readMemory:address];
  return l | ((uint16_t)[bus readMemory:(uint16_t)(address + 1)] << 8);
}

- (void)writeWord:(uint16_t)value at:(uint16_t)address
{
  [bus writeMemory:low (value) address:address];
  [bus writeMemory:high (value) address:(uint16_t)(address + 1)];
}

- (void)pushWord:(uint16_t)value
{
  [bus writeMemory:high (value) address:--registers.sp];
  [bus writeMemory:low (value) address:--registers.sp];
}

- (uint16_t)popWord
{
  uint8_t l = [bus readMemory:registers.sp++];
  return l | ((uint16_t)[bus readMemory:registers.sp++] << 8);
}

- (uint8_t)readRegister:(unsigned)r
                  index:(unsigned)index
                address:(uint16_t)address
{
  switch (r)
    {
    case 0:
      return high (registers.bc);
    case 1:
      return low (registers.bc);
    case 2:
      return high (registers.de);
    case 3:
      return low (registers.de);
    case 4:
      return high (*pair (&registers, 2, index));
    case 5:
      return low (*pair (&registers, 2, index));
    case 6:
      return [bus readMemory:address];
    default:
      return high (registers.af);
    }
}

- (void)writeRegister:(unsigned)r
                index:(unsigned)index
              address:(uint16_t)address
                value:(uint8_t)value
{
  switch (r)
    {
    case 0:
      setHigh (&registers.bc, value);
      break;
    case 1:
      setLow (&registers.bc, value);
      break;
    case 2:
      setHigh (&registers.de, value);
      break;
    case 3:
      setLow (&registers.de, value);
      break;
    case 4:
      setHigh (pair (&registers, 2, index), value);
      break;
    case 5:
      setLow (pair (&registers, 2, index), value);
      break;
    case 6:
      [bus writeMemory:value address:address];
      break;
    default:
      setHigh (&registers.af, value);
      break;
    }
}

- (NSUInteger)instruction:(uint8_t)opcode
{
  unsigned index = registers.prefixIndex;
  registers.prefixIndex = 0;
  NSUInteger prefixCycles = 0;
  while (opcode == 0xdd || opcode == 0xfd)
    {
      index = opcode == 0xdd ? 1 : 2;
      prefixCycles += 4;
      /* Yield a pathological prefix stream without accepting an interrupt or
       * losing the most recent index prefix. */
      if (prefixCycles == 65536 * 4)
        {
          registers.prefixIndex = index;
          return prefixCycles;
        }
      opcode = [self fetchOpcode];
    }
  if (opcode == 0xcb)
    return prefixCycles + [self decodeCB:index];
  if (opcode == 0xed)
    return prefixCycles + [self decodeED];
  return prefixCycles + [self decode:opcode index:index];
}

- (NSUInteger)decodeCB:(unsigned)index
{
  CPUZ80State *s = &registers;
  uint16_t address = s->hl;
  if (index)
    {
      int8_t d = (int8_t)[self fetchByte];
      address = *pair (s, 2, index) + d;
      s->wz = address;
    }
  uint8_t op = index ? [self fetchByte] : [self fetchOpcode];
  unsigned x = op >> 6, y = (op >> 3) & 7, z = op & 7;
  uint8_t v = [self readRegister:index ? 6 : z index:0 address:address];
  uint8_t result = v, carry = low (s->af) & C;
  if (x <= 1)
    flagsWritten = YES;
  if (x == 0)
    {
      switch (y)
        {
        case 0:
          result = (v << 1) | (v >> 7);
          carry = v >> 7;
          break;
        case 1:
          result = (v >> 1) | (v << 7);
          carry = v & 1;
          break;
        case 2:
          result = (v << 1) | carry;
          carry = v >> 7;
          break;
        case 3:
          result = (v >> 1) | (carry << 7);
          carry = v & 1;
          break;
        case 4:
          result = v << 1;
          carry = v >> 7;
          break;
        case 5:
          result = (v >> 1) | (v & 128);
          carry = v & 1;
          break;
        case 6:
          result = (v << 1) | 1;
          carry = v >> 7;
          break;
        case 7:
          result = v >> 1;
          carry = v & 1;
          break;
        }
      setLow (&s->af, szp (result) | carry);
    }
  else if (x == 1)
    {
      uint8_t xy = (index || z == 6) ? high (s->wz) : v;
      setLow (&s->af, carry | H | (xy & (X | Y))
                          | ((v & (1 << y)) ? (y == 7 ? S : 0) : Z | P));
      return index ? 16 : z == 6 ? 12 : 8;
    }
  else if (x == 2)
    result = v & ~(1 << y);
  else
    result = v | (1 << y);
  [self writeRegister:index ? 6 : z index:0 address:address value:result];
  if (index && z != 6)
    [self writeRegister:z index:0 address:address value:result];
  return index ? 19 : z == 6 ? 15 : 8;
}

- (NSUInteger)decode:(uint8_t)opcode index:(unsigned)index
{
  CPUZ80State *s = &registers;
  unsigned x = opcode >> 6, y = (opcode >> 3) & 7, z = opcode & 7, p = y >> 1,
           q = y & 1;
  uint16_t address = s->hl, word, *rp;
  uint8_t v, a = high (s->af), f = low (s->af);
  BOOL memoryOperand = (x == 1 && opcode != 0x76 && (y == 6 || z == 6))
                       || (x == 2 && z == 6)
                       || (x == 0 && y == 6 && z >= 4 && z <= 6);
  if (index && memoryOperand)
    {
      int8_t displacement = (int8_t)[self fetchByte];
      address = *pair (s, 2, index) + displacement;
      s->wz = address;
    }
  if (x == 1)
    {
      if (opcode == 0x76)
        {
          s->halted = YES;
          return 4;
        }
      /* LD H/L,(IX+d) and LD (IX+d),H/L use real H/L, not index halves. */
      unsigned registerIndex = memoryOperand ? 0 : index;
      v = [self readRegister:z index:registerIndex address:address];
      [self writeRegister:y index:registerIndex address:address value:v];
      return memoryOperand ? (index ? 15 : 7) : 4;
    }
  if (x == 2)
    {
      flagsWritten = YES;
      alu (s, y, [self readRegister:z index:index address:address]);
      return z == 6 ? (index ? 15 : 7) : 4;
    }
  if (x == 0)
    {
      switch (z)
        {
        case 0:
          if (y == 0)
            return 4;
          if (y == 1)
            {
              word = s->af;
              s->af = s->alternateAF;
              s->alternateAF = word;
              return 4;
            }
          {
            int8_t d = (int8_t)[self fetchByte];
            BOOL take;
            if (y == 2)
              {
                setHigh (&s->bc, high (s->bc) - 1);
                take = high (s->bc) != 0;
              }
            else
              take = y == 3 || condition (s, y - 4);
            if (take)
              {
                s->pc += d;
                s->wz = s->pc;
              }
            return (y == 2 ? 8 : 7) + (take ? 5 : 0);
          }
        case 1:
          rp = pair (s, p, index);
          if (!q)
            {
              *rp = [self fetchWord];
              return 10;
            }
          {
            flagsWritten = YES;
            uint16_t *dest = pair (s, 2, index), old = *dest;
            uint32_t result = (uint32_t)old + *rp;
            s->wz = old + 1;
            setLow (&s->af, (f & (S | Z | P)) | (high (result) & (X | Y))
                                | (((old ^ *rp ^ result) & 0x1000) ? H : 0)
                                | (result > 65535 ? C : 0));
            *dest = result;
            return 11;
          }
        case 2:
          if (p < 2)
            {
              word = *pair (s, p, 0);
              if (q)
                {
                  setHigh (&s->af, [bus readMemory:word]);
                  s->wz = word + 1;
                }
              else
                {
                  [bus writeMemory:a address:word];
                  s->wz = ((uint16_t)a << 8) | low (word + 1);
                }
              return 7;
            }
          word = [self fetchWord];
          s->wz = word + 1;
          if (p == 2)
            {
              if (q)
                *pair (s, 2, index) = [self readWord:word];
              else
                [self writeWord:*pair (s, 2, index) at:word];
              return 16;
            }
          if (q)
            setHigh (&s->af, [bus readMemory:word]);
          else
            {
              [bus writeMemory:a address:word];
              s->wz = ((uint16_t)a << 8) | low (word + 1);
            }
          return 13;
        case 3:
          rp = pair (s, p, index);
          *rp += q ? -1 : 1;
          return 6;
        case 4:
        case 5:
          flagsWritten = YES;
          v = incdec (s, [self readRegister:y index:index address:address],
                      z == 5);
          [self writeRegister:y index:index address:address value:v];
          return y == 6 ? (index ? 19 : 11) : 4;
        case 6:
          [self writeRegister:y
                        index:index
                      address:address
                        value:[self fetchByte]];
          return y == 6 ? (index ? 15 : 10) : 7;
        case 7:
          flagsWritten = YES;
          switch (y)
            {
            case 0:
              v = a >> 7;
              a = (a << 1) | v;
              f = (f & (S | Z | P)) | (a & (X | Y)) | v;
              break;
            case 1:
              v = a & 1;
              a = (a >> 1) | (v << 7);
              f = (f & (S | Z | P)) | (a & (X | Y)) | v;
              break;
            case 2:
              v = a >> 7;
              a = (a << 1) | (f & C);
              f = (f & (S | Z | P)) | (a & (X | Y)) | v;
              break;
            case 3:
              v = a & 1;
              a = (a >> 1) | ((f & C) << 7);
              f = (f & (S | Z | P)) | (a & (X | Y)) | v;
              break;
            case 4:
              {
                uint8_t correction = 0, old = a;
                BOOL carry = (f & C) != 0;
                if ((f & H) || ((a & 15) > 9))
                  correction |= 6;
                if (carry || (a > 0x99))
                  {
                    correction |= 0x60;
                    carry = YES;
                  }
                a += (f & N) ? -correction : correction;
                f = (f & N) | szp (a) | ((old ^ a) & H) | (carry ? C : 0);
                break;
              }
            case 5:
              a = ~a;
              f = (f & (S | Z | P | C)) | H | N | (a & (X | Y));
              break;
            case 6:
              f = (f & (S | Z | P)) | C | (((f ^ s->q) | a) & (X | Y));
              break;
            case 7:
              f = (f & (S | Z | P)) | (((f ^ s->q) | a) & (X | Y))
                  | ((f & C) ? H : C);
              break;
            }
          s->af = ((uint16_t)a << 8) | f;
          return 4;
        }
    }
  switch (z)
    {
    case 0:
      if (condition (s, y))
        {
          s->pc = s->wz = [self popWord];
          return 11;
        }
      return 5;
    case 1:
      if (!q)
        {
          *(p == 3 ? &s->af : pair (s, p, index)) = [self popWord];
          return 10;
        }
      switch (p)
        {
        case 0:
          s->pc = s->wz = [self popWord];
          return 10;
        case 1:
          word = s->bc;
          s->bc = s->alternateBC;
          s->alternateBC = word;
          word = s->de;
          s->de = s->alternateDE;
          s->alternateDE = word;
          word = s->hl;
          s->hl = s->alternateHL;
          s->alternateHL = word;
          return 4;
        case 2:
          s->pc = *pair (s, 2, index);
          return 4;
        default:
          s->sp = *pair (s, 2, index);
          return 6;
        }
    case 2:
      word = [self fetchWord];
      s->wz = word;
      if (condition (s, y))
        s->pc = word;
      return 10;
    case 3:
      switch (y)
        {
        case 0:
          s->pc = s->wz = [self fetchWord];
          return 10;
        case 2:
          v = [self fetchByte];
          word = ((uint16_t)a << 8) | v;
          [bus writePort:a address:word];
          s->wz = ((uint16_t)a << 8) | low (v + 1);
          return 11;
        case 3:
          v = [self fetchByte];
          word = ((uint16_t)a << 8) | v;
          setHigh (&s->af, [bus readPort:word]);
          s->wz = word + 1;
          return 11;
        case 4:
          rp = pair (s, 2, index);
          word = [self readWord:s->sp];
          /* EX (SP),rr writes the high byte before the low byte. */
          [bus writeMemory:high (*rp) address:(uint16_t)(s->sp + 1)];
          [bus writeMemory:low (*rp) address:s->sp];
          *rp = word;
          s->wz = word;
          return 19;
        case 5:
          word = s->de;
          s->de = s->hl;
          s->hl = word;
          return 4;
        case 6:
          s->iff1 = s->iff2 = NO;
          s->eiDelay = 0;
          return 4;
        case 7:
          s->iff1 = s->iff2 = YES;
          s->eiDelay = 2;
          return 4;
        default:
          return 4; /* CB is handled by the prefix dispatcher. */
        }
    case 4:
      word = [self fetchWord];
      s->wz = word;
      if (condition (s, y))
        {
          [self pushWord:s->pc];
          s->pc = word;
          return 17;
        }
      return 10;
    case 5:
      if (!q)
        {
          [self pushWord:p == 3 ? s->af : *pair (s, p, index)];
          return 11;
        }
      if (p == 0)
        {
          word = [self fetchWord];
          [self pushWord:s->pc];
          s->pc = s->wz = word;
          return 17;
        }
      return 4; /* DD/ED/FD are handled by the prefix dispatcher. */
    case 6:
      flagsWritten = YES;
      alu (s, y, [self fetchByte]);
      return 7;
    default:
      [self pushWord:s->pc];
      s->pc = s->wz = y * 8;
      return 11;
    }
}

- (NSUInteger)decodeED
{
  CPUZ80State *s = &registers;
  uint8_t opcode = [self fetchOpcode], a = high (s->af), f = low (s->af), v;
  unsigned x = opcode >> 6, y = (opcode >> 3) & 7, z = opcode & 7, p = y >> 1,
           q = y & 1;
  uint16_t word;
  if (x == 1)
    {
      switch (z)
        {
        case 0:
          flagsWritten = YES;
          s->wz = s->bc + 1;
          v = [bus readPort:s->bc];
          if (y != 6)
            [self writeRegister:y index:0 address:0 value:v];
          setLow (&s->af, (f & C) | szp (v));
          return 12;
        case 1:
          [bus writePort:y == 6 ? 0 : [self readRegister:y index:0 address:0]
                 address:s->bc];
          s->wz = s->bc + 1;
          return 12;
        case 2:
          {
            flagsWritten = YES;
            uint16_t left = s->hl, right = *pair (s, p, 0);
            uint32_t result = q ? (uint32_t)left + right + (f & C)
                                : (uint32_t)left - right - (f & C);
            uint16_t value = result;
            uint8_t flags = (high (value) & (S | X | Y)) | (value ? 0 : Z)
                            | (((left ^ right ^ value) & 0x1000) ? H : 0)
                            | ((result & 0x10000) ? C : 0);
            flags
                |= q ? ((~(left ^ right) & (left ^ value) & 0x8000) ? P : 0)
                     : N | (((left ^ right) & (left ^ value) & 0x8000) ? P : 0);
            s->hl = value;
            s->wz = left + 1;
            setLow (&s->af, flags);
            return 15;
          }
        case 3:
          word = [self fetchWord];
          s->wz = word + 1;
          if (q)
            *pair (s, p, 0) = [self readWord:word];
          else
            [self writeWord:*pair (s, p, 0) at:word];
          return 20;
        case 4:
          flagsWritten = YES;
          v = add8 (s, 0, a, 0, YES);
          setHigh (&s->af, v);
          return 8;
        case 5:
          s->pc = s->wz = [self popWord];
          s->iff1 = s->iff2;
          if (opcode == 0x4d)
            [bus didReturnFromInterrupt];
          return 14;
        case 6:
          {
            const uint8_t modes[] = { 0, 0, 1, 2, 0, 0, 1, 2 };
            s->interruptMode = modes[y];
            return 8;
          }
        case 7:
          switch (y)
            {
            case 0:
              s->i = a;
              return 9;
            case 1:
              s->r = a;
              return 9;
            case 2:
            case 3:
              flagsWritten = YES;
              v = y == 2 ? s->i : s->r;
              s->af = ((uint16_t)v << 8) | (f & C) | sz (v) | (s->iff2 ? P : 0);
              return 9;
            case 4:
            case 5:
              {
                flagsWritten = YES;
                v = [bus readMemory:s->hl];
                uint8_t result;
                if (y == 4)
                  {
                    result = (a << 4) | (v >> 4);
                    a = (a & 0xf0) | (v & 15);
                  }
                else
                  {
                    result = (v << 4) | (a & 15);
                    a = (a & 0xf0) | (v >> 4);
                  }
                [bus writeMemory:result address:s->hl];
                s->af = ((uint16_t)a << 8) | (f & C) | szp (a);
                s->wz = s->hl + 1;
                return 18;
              }
            default:
              return 8;
            }
        }
    }
  if (x == 2 && y >= 4 && z <= 3)
    {
      flagsWritten = YES;
      int direction = (y & 1) ? -1 : 1;
      BOOL repeat = (y & 2) != 0, again = NO;
      if (z == 0)
        {
          v = [bus readMemory:s->hl];
          [bus writeMemory:v address:s->de];
          s->hl += direction;
          s->de += direction;
          s->bc--;
          uint8_t sum = a + v;
          setLow (&s->af, (f & (S | Z | C)) | (s->bc ? P : 0) | (sum & X)
                              | ((sum & 2) << 4));
          again = s->bc != 0;
        }
      else if (z == 1)
        {
          v = [bus readMemory:s->hl];
          uint8_t result = a - v, half = (a ^ v ^ result) & H,
                  adjusted = result - (half ? 1 : 0);
          s->hl += direction;
          s->bc--;
          s->wz += direction;
          setLow (&s->af, (f & C) | N | (sz (result) & (S | Z)) | half
                              | (s->bc ? P : 0) | (adjusted & X)
                              | ((adjusted & 2) << 4));
          again = s->bc && result;
        }
      else
        {
          unsigned sum;
          if (z == 2)
            {
              v = [bus readPort:s->bc];
              [bus writeMemory:v address:s->hl];
              s->wz = s->bc + direction;
              setHigh (&s->bc, high (s->bc) - 1);
              s->hl += direction;
              sum = v + (uint8_t)(low (s->bc) + direction);
            }
          else
            {
              v = [bus readMemory:s->hl];
              setHigh (&s->bc, high (s->bc) - 1);
              s->hl += direction;
              [bus writePort:v address:s->bc];
              s->wz = s->bc + direction;
              sum = v + low (s->hl);
            }
          setLow (&s->af, sz (high (s->bc)) | ((v & 128) ? N : 0)
                              | (sum > 255 ? H | C : 0)
                              | parity ((sum & 7) ^ high (s->bc)));
          again = high (s->bc) != 0;
        }
      if (repeat && again)
        {
          s->pc -= 2;
          if (z < 2)
            s->wz = s->pc + 1;
          return 21;
        }
      return 16;
    }
  /* Unassigned ED opcodes are two-byte, eight-T-state NOPs. */
  return 8;
}

@end

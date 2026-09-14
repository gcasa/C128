/*
 * VIC20 - a Commodore VIC-20 emulator.
 * Copyright (C) 2018-2026 Gregory John Casamento
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#import "CPU6502+Instructions.h"

// http://nparker.llx.com/a2/opcodes.html

@implementation CPU6502 (Instructions)
// Instruction implementations...
/*
 *  add 1 to cycles if page boundery is crossed

 ** add 1 to cycles if branch occurs on same page
 add 2 to cycles if branch occurs to different page


 Legend to Flags:  + .... modified
 - .... not modified
 1 .... set
 0 .... cleared
 M6 .... memory bit 6
 M7 .... memory bit 7
 */

/*
 ADC  Add Memory to Accumulator with Carry

 A + M + C -> A, C                N Z C I D V
 + + + - - +

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     ADC #oper     69    2     2
 zeropage      ADC oper      65    2     3
 zeropage,X    ADC oper,X    75    2     4
 absolute      ADC oper      6D    3     4
 absolute,X    ADC oper,X    7D    3     4*
 absolute,Y    ADC oper,Y    79    3     4*
 (indirect,X)  ADC (oper,X)  61    2     6
 (indirect),Y  ADC (oper),Y  71    2     5*
 */
/* Implementation of ADC */
- (void)ADC_immediate
{
  pc++;
  uint8 operand = [self readMemory:pc];
  pc++;
  [self debugLogWithFormat:@"ADC #$%02X", operand];

  uint16 result = (uint16)a + (uint16)operand + (uint16)s.status.c;

  // Set overflow flag: (A^result) & (operand^result) & 0x80
  s.status.v = ((a ^ result) & (operand ^ result) & 0x80) ? 1 : 0;

  // Set carry flag if result > 255
  s.status.c = (result > 0xFF) ? 1 : 0;

  a = result & 0xFF;

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
}

/* Implementation of ADC */
- (void)ADC_zeropage
{
  pc++;
  uint8 address = [self readMemory:pc];
  pc++;
  uint8 operand = [self readMemory:address];
  [self debugLogWithFormat:@"ADC $%02X", address];

  uint16 result = (uint16)a + (uint16)operand + (uint16)s.status.c;

  // Set overflow flag: (A^result) & (operand^result) & 0x80
  s.status.v = ((a ^ result) & (operand ^ result) & 0x80) ? 1 : 0;

  // Set carry flag if result > 255
  s.status.c = (result > 0xFF) ? 1 : 0;

  a = result & 0xFF;

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
}

/* Implementation of ADC */
- (void)ADC_zeropageX
{
  pc++;
  uint8 address = [self readMemory:pc];
  pc++;
  uint8 operand =
      [self readMemory:(address + x) & 0xFF]; // Zero page wraps around
  [self debugLogWithFormat:@"ADC $%02X,X", address];

  uint16 result = (uint16)a + (uint16)operand + (uint16)s.status.c;

  // Set overflow flag: (A^result) & (operand^result) & 0x80
  s.status.v = ((a ^ result) & (operand ^ result) & 0x80) ? 1 : 0;

  // Set carry flag if result > 255
  s.status.c = (result > 0xFF) ? 1 : 0;

  a = result & 0xFF;

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
}

/* Implementation of ADC */
- (void)ADC_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"ADC $%04X", addr];
  uint8 val = [self readMemory:addr];
  a = a + val;
  s.status.c = (a & 0x80) != 0;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ADC */
- (void)ADC_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  [self debugLogWithFormat:@"ADC $%04X,X", addr];
  a = a + val;
  s.status.c = (a & 0x80) != 0;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ADC */
- (void)ADC_absoluteY
{
  [self debugLogWithFormat:@"ADC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  a = a + val;
  s.status.c = (a & 0x80) != 0;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ADC */
- (void)ADC_indirectX
{
  [self debugLogWithFormat:@"ADC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 p2 = param1 + x + 1;
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  a = a + val;
  s.status.c = (a & 0x80) != 0;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ADC */
- (void)ADC_indirectY
{
  pc++;
  uint8 zpAddr = [self readMemory:pc];
  pc++;

  // Read 16-bit address from zero page
  uint8 addrLo = [self readMemory:zpAddr];
  uint8 addrHi = [self readMemory:(zpAddr + 1) & 0xFF]; // Zero page wraps
  uint16 baseAddr = ((uint16)addrHi << 8) | addrLo;

  // Add Y to the address
  uint16 finalAddr = baseAddr + y;
  uint8 operand = [self readMemory:finalAddr];

  [self debugLogWithFormat:@"ADC ($%02X),Y", zpAddr];

  uint16 result = (uint16)a + (uint16)operand + (uint16)s.status.c;

  // Set overflow flag: (A^result) & (operand^result) & 0x80
  s.status.v = ((a ^ result) & (operand ^ result) & 0x80) ? 1 : 0;

  // Set carry flag if result > 255
  s.status.c = (result > 0xFF) ? 1 : 0;

  a = result & 0xFF;

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
}

/* Implementation of AND */
/*
 AND  AND Memory with Accumulator

 A AND M -> A                     N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     AND #oper     29    2     2
 zeropage      AND oper      25    2     3
 zeropage,X    AND oper,X    35    2     4
 absolute      AND oper      2D    3     4
 absolute,X    AND oper,X    3D    3     4*
 absolute,Y    AND oper,Y    39    3     4*
 (indirect,X)  AND (oper,X)  21    2     6
 (indirect),Y  AND (oper),Y  31    2     5*
 */
/* Implementation of AND */
- (void)AND_immediate
{
  pc++;
  uint8 operand = [self readMemory:pc];
  pc++;
  [self debugLogWithFormat:@"AND #$%02X", operand];

  a = a & operand;

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
  // Carry flag is not affected by AND
}

/* Implementation of AND */
- (void)AND_zeropage
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 val = [self readMemory:param1];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of AND */
- (void)AND_zeropageX
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 val = [self readMemory:param1 + x];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of AND */
- (void)AND_absolute
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of AND */
- (void)AND_absoluteX
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of AND */
- (void)AND_absoluteY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"AND $%04X,X", addr];
  uint8 val = [self readMemory:addr + y];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}
/* Implementation of AND */
- (void)AND_indirectX
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc] + x;
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 p2 = [self readMemory:param1 + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of AND */
- (void)AND_indirectY
{
  [self debugLogWithFormat:@"AND"];
  pc++;
  uint8 param1 = [self readMemory:pc] + y;
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 p2 = [self readMemory:param1 + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  a = a & val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/*
 ASL  Shift Left One Bit (Memory or Accumulator)

 C <- [76543210] <- 0             N Z C I D V
 + + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 accumulator   ASL A         0A    1     2
 zeropage      ASL oper      06    2     5
 zeropage,X    ASL oper,X    16    2     6
 absolute      ASL oper      0E    3     6
 absolute,X    ASL oper,X    1E    3     7
 */
/* Implementation of ASL */
- (void)ASL_accumulator
{
  [self debugLogWithFormat:@"ASL"];
  a = a << 1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ASL */
- (void)ASL_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ASL $%X", param1];
  uint8 val = [self readMemory:param1];
  uint8 r = val << 1;
  s.status.n = (r & 0x80) != 0;
  s.status.z = !(r);
  [self writeMemory:r loc:param1];
}

/* Implementation of ASL */
- (void)ASL_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ASL $%X,X", param1];
  uint8 val = [self readMemory:param1 + x];
  uint8 r = val << 1;
  s.status.n = (r & 0x80) != 0;
  s.status.z = !(r);
  [self writeMemory:r loc:param1];
}

/* Implementation of ASL */
- (void)ASL_absolute
{
  [self debugLogWithFormat:@"ASL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  uint8 r = val << 1;
  s.status.n = (r & 0x80) != 0;
  s.status.z = !(r);
  [self writeMemory:r loc:addr];
}

/* Implementation of ASL */
- (void)ASL_absoluteX
{
  [self debugLogWithFormat:@"ASL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  uint8 r = val << 1;
  s.status.n = (r & 0x80) != 0;
  s.status.z = !(r);
  [self writeMemory:r loc:addr];
}

/* Implementation of BCC */
- (void)BCC_relative
{
  [self debugLogWithFormat:@"BCC"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (!s.status.c)
    {
      pc += 1 + param1;
    }
}

/* Implementation of BCS */
- (void)BCS_relative
{
  [self debugLogWithFormat:@"BCS"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (s.status.c)
    {
      pc += 1 + param1;
    }
}

/* Implementation of BEQ */
- (void)BEQ_relative
{
  pc++;
  int8_t offset = (int8_t)[self readMemory:pc];
  pc++; // Move past the offset byte

  [self debugLogWithFormat:@"BEQ $%02X (offset: %d)", pc + offset, offset];

  if (s.status.z)
    {
      pc += offset; // Branch taken
                    // TODO: Add cycle penalty for page crossing
    }
  // If branch not taken, PC is already at next instruction
}

/*
 BIT  Test Bits in Memory with Accumulator

 bits 7 and 6 of operand are transfered to bit 7 and 6 of SR (N,V);
 the zeroflag is set to the result of operand AND accumulator.

 A AND M, M7 -> N, M6 -> V        N Z C I D V
 M7 + - - - M6

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      BIT oper      24    2     3
 absolute      BIT oper      2C    3     4
 */
/* Implementation of BIT */
- (void)BIT_zeropage
{
  [self debugLogWithFormat:@"BIT"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 m6 = val & 0x40; // bit 6
  uint8 m7 = val & 0x80; // bit 7
  a = a & val;
  s.status.z = !(a);
  s.status.n = m7;
  s.status.v = m6;
}

/* Implementation of BIT */
- (void)BIT_absolute
{
  [self debugLogWithFormat:@"BIT"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 m6 = val & 0x40; // bit 6
  uint8 m7 = val & 0x80; // bit 7
  a = a & val;
  s.status.z = !(a);
  s.status.n = m7;
  s.status.v = m6;
}

/*
 BMI  Branch on Result Minus

 branch on N = 1                  N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 relative      BMI oper      30    2     2**
 */
/* Implementation of BMI */
- (void)BMI_relative
{
  [self debugLogWithFormat:@"BMI"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (s.status.n == 1)
    {
      pc += 1 + param1;
    }
}

/*
 BNE  Branch on Result not Zero

 branch on Z = 0                  N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 relative      BNE oper      D0    2     2**
 */
/* Implementation of BNE */
- (void)BNE_relative
{
  [self debugLogWithFormat:@"BNE"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (!s.status.z)
    {
      pc += 1 + param1;
    }
}

/*
 BPL  Branch on Result Plus

 branch on N = 0                  N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 relative      BPL oper      10    2     2**
 */
/* Implementation of BPL */
- (void)BPL_relative
{
  [self debugLogWithFormat:@"BPL"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (s.status.n == 0)
    {
      pc += 1 + param1;
    }
}

/*
 BRK  Force Break

 interrupt,                       N Z C I D V
 push PC+2, push SR               - - - 1 - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       BRK           00    1     7
 */
/* Implementation of BRK */
- (void)BRK_implied
{
  [self debugLogWithFormat:@"BRK"];
}

/*
 BVC  Branch on Overflow Clear

 branch on V = 0                  N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 relative      BVC oper      50    2     2**
 */
/* Implementation of BVC */
- (void)BVC_relative
{
  [self debugLogWithFormat:@"BVC"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (s.status.v == 0)
    {
      pc += 1 + param1;
    }
}

/*
 BVS  Branch on Overflow Set

 branch on V = 1                  N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 relative      BVC oper      70    2     2**
 */
/* Implementation of BVS */
- (void)BVS_relative
{
  [self debugLogWithFormat:@"BVS"];
  pc++;
  int8_t param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (s.status.v == 1)
    {
      pc += 1 + param1;
    }
}

/*
 CLC  Clear Carry Flag

 0 -> C                           N Z C I D V
 - - 0 - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       CLC           18    1     2
 */
/* Implementation of CLC */
- (void)CLC_implied
{
  [self debugLogWithFormat:@"CLC"];
  s.status.c = 0;
}

/*
 CLD  Clear Decimal Mode

 0 -> D                           N Z C I D V
 - - - - 0 -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       CLD           D8    1     2
 */
/* Implementation of CLD */
- (void)CLD_implied
{
  [self debugLogWithFormat:@"CLD"];
  s.status.d = 0;
}

/*
 CLI  Clear Interrupt Disable Bit

 0 -> I                           N Z C I D V
 - - - 0 - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       CLI           58    1     2
 */
/* Implementation of CLI */
- (void)CLI_implied
{
  [self debugLogWithFormat:@"CLI"];
  s.status.i = 0;
}

/*
 CLV  Clear Overflow Flag

 0 -> V                           N Z C I D V
 - - - - - 0

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       CLV           B8    1     2
 */
/* Implementation of CLV */
- (void)CLV_implied
{
  [self debugLogWithFormat:@"CLV"];
  s.status.v = 0;
}

/* Implementation of CMP */
- (void)CMP_immediate
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (a == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CMP */
- (void)CMP_zeropage
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  if (a == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CMP */
- (void)CMP_zeropageX
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc] + x;
  [self debugLogWithFormat:@"param = %X", param1];
  if (a == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CMP */
- (void)CMP_absolute
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  uint8 result = a - val;
  s.status.z = (result == 0) ? 1 : 0;
  s.status.n = (result & 0x80) ? 1 : 0;
  s.status.c = (a >= val) ? 1 : 0;
}

/* Implementation of CMP */
- (void)CMP_absoluteX
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];

  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  uint8 result = a - val;
  s.status.z = (result == 0) ? 1 : 0;
  s.status.n = (result & 0x80) ? 1 : 0;
  s.status.c = (a >= val) ? 1 : 0;
}

/* Implementation of CMP */
- (void)CMP_absoluteY
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];

  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  if (a == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = (val & 0x80) != 0;
  s.status.c = (val & 0x80) != 0;
}

/* Implementation of CMP */
- (void)CMP_indirectX
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc] + x;
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 p2 = param1 + x + 1;
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  if (a == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = (val & 0x80) != 0;
  s.status.c = (val & 0x80) != 0;
}

/* Implementation of CMP */
- (void)CMP_indirectY
{
  [self debugLogWithFormat:@"CMP"];
  pc++;
  uint8 param1 = [self readMemory:pc] + y;
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 p2 = param1 + y + 1;
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  if (a == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = (val & 0x80) != 0;
  s.status.c = (val & 0x80) != 0;
}

/*
 CPX  Compare Memory and Index X

 X - M                            N Z C I D V
 + + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     CPX #oper     E0    2     2
 zeropage      CPX oper      E4    2     3
 absolute      CPX oper      EC    3     4
 */
/* Implementation of CPX */
- (void)CPX_immediate
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"CPX $%X", param1];
  if (x == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CPX */
- (void)CPX_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"CPX $%X", param1];
  if (x == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CPX */
- (void)CPX_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"CPX $%04X", addr];
  uint8 val = [self readMemory:addr];
  if (x == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = (val & 0x80) != 0;
  s.status.c = (val & 0x80) != 0;
}

/*
 CPY  Compare Memory and Index Y

 Y - M                            N Z C I D V
 + + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     CPY #oper     C0    2     2
 zeropage      CPY oper      C4    2     3
 absolute      CPY oper      CC    3     4
 */
/* Implementation of CPY */
- (void)CPY_immediate
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"CPY #%02X", param1];
  if (y == param1)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CPY */
- (void)CPY_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1];
  [self debugLogWithFormat:@"CPY $%02X", param1];
  if (y == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/* Implementation of CPY */
- (void)CPY_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  [self debugLogWithFormat:@"CPY $%04X", param1];
  if (y == val)
    {
      s.status.z = 0;
    }
  else
    {
      s.status.z = 1;
    }
  s.status.n = param1 & 0x80;
  s.status.c = param1 & 0x80;
}

/*
 DEC  Decrement Memory by One

 M - 1 -> M                       N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      DEC oper      C6    2     5
 zeropage,X    DEC oper,X    D6    2     6
 absolute      DEC oper      CE    3     3
 absolute,X    DEC oper,X    DE    3     7
 */
/* Implementation of DEC */
- (void)DEC_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"DEC $%02X", param1];
  uint8 val = [self readMemory:param1];
  val = val - 1;
  [self writeMemory:val loc:param1];
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of DEC */
- (void)DEC_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"DEC $%02X", param1];
  uint8 val = [self readMemory:param1 + x];
  val = val - 1;
  [self writeMemory:val loc:param1 + x];
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of DEC */
- (void)DEC_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"DEC $%04X", addr];
  uint8 val = [self readMemory:addr];
  val = val - 1;
  [self writeMemory:val loc:addr];
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of DEC */
- (void)DEC_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"DEC $%04X", addr];
  uint8 val = [self readMemory:addr + x];
  val = val - 1;
  [self writeMemory:val loc:addr + x];
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/*
 DEX  Decrement Index X by One

 X - 1 -> X                       N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       DEC           CA    1     2
 */
/* Implementation of DEX */
- (void)DEX_implied
{
  [self debugLogWithFormat:@"DEX"];
  x = x - 1;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/*
 DEY  Decrement Index Y by One

 Y - 1 -> Y                       N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       DEC           88    1     2
 */
/* Implementation of DEY */
- (void)DEY_implied
{
  [self debugLogWithFormat:@"DEY"];
  y = y - 1;
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/*
 EOR  Exclusive-OR Memory with Accumulator

 A EOR M -> A                     N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     EOR #oper     49    2     2
 zeropage      EOR oper      45    2     3
 zeropage,X    EOR oper,X    55    2     4
 absolute      EOR oper      4D    3     4
 absolute,X    EOR oper,X    5D    3     4*
 absolute,Y    EOR oper,Y    59    3     4*
 (indirect,X)  EOR (oper,X)  41    2     6
 (indirect),Y  EOR (oper),Y  51    2     5*
 */
/* Implementation of EOR */
- (void)EOR_immediate
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"EOR #%02X", param1];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1];
  [self debugLogWithFormat:@"EOR $%02X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1 + x];
  [self debugLogWithFormat:@"EOR $%02X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_absolute
{
  [self debugLogWithFormat:@"EOR"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  [self debugLogWithFormat:@"EOR $%02X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_absoluteX
{
  [self debugLogWithFormat:@"EOR"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  [self debugLogWithFormat:@"EOR $%02X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_absoluteY
{
  [self debugLogWithFormat:@"EOR"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  [self debugLogWithFormat:@"EOR $%02X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_indirectX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 p2 = [self readMemory:pc + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  [self debugLogWithFormat:@"EOR $%02X,X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of EOR */
- (void)EOR_indirectY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 p2 = [self readMemory:pc + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  [self debugLogWithFormat:@"EOR $%02X,X", val];
  a = a ^ param1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/*
 INC  Increment Memory by One

 M + 1 -> M                       N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      INC oper      E6    2     5
 zeropage,X    INC oper,X    F6    2     6
 absolute      INC oper      EE    3     6
 absolute,X    INC oper,X    FE    3     7
 */
/* Implementation of INC */
- (void)INC_zeropage
{
  [self debugLogWithFormat:@"INC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 val = [self readMemory:param1];
  val++;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of INC */
- (void)INC_zeropageX
{
  [self debugLogWithFormat:@"INC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 val = [self readMemory:param1 + x];
  val++;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of INC */
- (void)INC_absolute
{
  [self debugLogWithFormat:@"INC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  val++;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of INC */
- (void)INC_absoluteX
{
  [self debugLogWithFormat:@"INC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  val++;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of INX */
- (void)INX_implied
{
  [self debugLogWithFormat:@"INX"];
  uint8 val = x;
  val++;
  x = val;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/* Implementation of INY */
- (void)INY_implied
{
  [self debugLogWithFormat:@"INX"];
  uint8 val = y;
  val++;
  y = val;
  s.status.n = (val & 0x80) != 0;
  s.status.z = !(val);
}

/*
 JMP  Jump to New Location

 (PC+1) -> PCL                    N Z C I D V
 (PC+2) -> PCH                    - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 absolute      JMP oper      4C    3     3
 indirect      JMP (oper)    6C    3     5
 */
/* Implementation of JMP */
- (void)JMP_absolute
{
  pc++;
  uint8 addrLo = [self readMemory:pc];
  pc++;
  uint8 addrHi = [self readMemory:pc];

  uint16 jumpAddr = ((uint16)addrHi << 8) | addrLo;

  [self debugLogWithFormat:@"JMP $%04X", jumpAddr];

  pc = jumpAddr;
  // JMP does not affect any flags
}

/* Implementation of JMP */
- (void)JMP_indirect
{
  [self debugLogWithFormat:@"JMP"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"addr = %X", addr];
  uint8 p1 = [self readMemory:addr];
  uint8 p2 = [self readMemory:addr + 1];
  uint16 naddr = ((uint16)p2 << 8) + (uint16)p1; // indirect address...
  pc = naddr;                                    // Set new location.
}

/*
 JSR  Jump to New Location Saving Return Address

 push (PC+2),                     N Z C I D V
 (PC+1) -> PCL                    - - - - - -
 (PC+2) -> PCH

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 absolute      JSR oper      20    3     6
 */
/* Implementation of JSR */
- (void)JSR_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  pc--;

  [self push:(pc >> 8) & 0xff];
  [self push:(pc & 0xff)];
  [self debugLogWithFormat:@"JSR $%04X", addr];
  pc = addr; // Set new location.
}

/*
 LDA  Load Accumulator with Memory

 M -> A                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     LDA #oper     A9    2     2
 zeropage      LDA oper      A5    2     3
 zeropage,X    LDA oper,X    B5    2     4
 absolute      LDA oper      AD    3     4
 absolute,X    LDA oper,X    BD    3     4*
 absolute,Y    LDA oper,Y    B9    3     4*
 (indirect,X)  LDA (oper,X)  A1    2     6
 (indirect),Y  LDA (oper),Y  B1    2     5*
 */
/* Implementation of LDA */
/* Implementation of LDA */
- (void)LDA_immediate
{
  pc++;
  a = [self readMemory:pc];
  pc++;

  [self debugLogWithFormat:@"LDA #$%02X", a];

  // Update N and Z flags
  s.status.n = (a & 0x80) ? 1 : 0;
  s.status.z = (a == 0) ? 1 : 0;
}

/* Implementation of LDA */
- (void)LDA_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDA $%02X", param1];
  uint8 val = [self readMemory:param1];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDA $%02X,X", param1];
  uint8 val = [self readMemory:param1 + x];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDA $%04X", addr];
  uint8 val = [self readMemory:addr];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDA $%04X,X", addr + x];
  uint8 val = [self readMemory:addr + x];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_absoluteY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDA $%04X,Y", addr + y];
  uint8 val = [self readMemory:addr + y];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_indirectX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 p1 = [self readMemory:param1];
  uint8 p2 = [self readMemory:param1 + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)p1;
  [self debugLogWithFormat:@"LDA ($%04X,X)", addr + x];
  uint8 val = [self readMemory:addr];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of LDA */
- (void)LDA_indirectY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 p1 = [self readMemory:param1];
  uint8 p2 = [self readMemory:param1 + 1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)p1;
  [self debugLogWithFormat:@"LDA ($%04X),Y", addr + y];
  uint8 val = [self readMemory:addr];
  a = val;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/*
 LDX  Load Index X with Memory

 M -> X                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     LDX #oper     A2    2     2
 zeropage      LDX oper      A6    2     3
 zeropage,Y    LDX oper,Y    B6    2     4
 absolute      LDX oper      AE    3     4
 absolute,Y    LDX oper,Y    BE    3     4*
 */
/* Implementation of LDX */
- (void)LDX_immediate
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDX #%X", param1];
  x = param1;
  pc++;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/* Implementation of LDX */
- (void)LDX_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDX $%02X", param1];
  uint8 val = [self readMemory:param1];
  x = val;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/* Implementation of LDX */
- (void)LDX_zeropageY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDX $%02X,Y", param1];
  uint8 val = [self readMemory:param1 + y];
  x = val;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/* Implementation of LDX */
- (void)LDX_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDX $%04X", addr];
  uint8 val = [self readMemory:addr];
  x = val;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/* Implementation of LDX */
- (void)LDX_absoluteY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDX $%04X", addr];
  uint8 val = [self readMemory:addr];
  x = val;
  s.status.n = (x & 0x80) != 0;
  s.status.z = !(x);
}

/*
 LDY  Load Index Y with Memory

 M -> Y                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     LDY #oper     A0    2     2
 zeropage      LDY oper      A4    2     3
 zeropage,X    LDY oper,X    B4    2     4
 absolute      LDY oper      AC    3     4
 absolute,X    LDY oper,X    BC    3     4*
 */
/* Implementation of LDY */
- (void)LDY_immediate
{
  [self debugLogWithFormat:@"LDY"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/* Implementation of LDY */
- (void)LDY_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDY #%02X", param1];
  y = param1;
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/* Implementation of LDY */
- (void)LDY_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"LDY $%02X,X", param1];
  y = param1;
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/* Implementation of LDY */
- (void)LDY_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDY $%04X", addr];
  uint8 val = [self readMemory:addr];
  y = val;
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/* Implementation of LDY */
- (void)LDY_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LDY $%04X", addr];
  uint8 val = [self readMemory:addr];
  y = val;
  s.status.n = (y & 0x80) != 0;
  s.status.z = !(y);
}

/*
 LSR  Shift One Bit Right (Memory or Accumulator)

 0 -> [76543210] -> C             N Z C I D V
 - + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 accumulator   LSR A         4A    1     2
 zeropage      LSR oper      46    2     5
 zeropage,X    LSR oper,X    56    2     6
 absolute      LSR oper      4E    3     6
 absolute,X    LSR oper,X    5E    3     7
 */
/* Implementation of LSR */
- (void)LSR_accumulator
{
  [self debugLogWithFormat:@"LSR"];
  a = a >> 1;
  s.status.z = !(a);
  s.status.c = (a & 0x80) != 0;
}

/* Implementation of LSR */
- (void)LSR_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1];
  [self debugLogWithFormat:@"LSR $%02X", param1];
  uint8 r = val << 1;
  [self writeMemory:r loc:param1];
  s.status.z = !(r);
  s.status.c = (r & 0x80) != 0;
}

/* Implementation of LSR */
- (void)LSR_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  uint8 val = [self readMemory:param1 + x];
  [self debugLogWithFormat:@"LSR $%02X,X", param1];
  uint8 r = val << 1;
  [self writeMemory:r loc:param1];
  s.status.z = !(r);
  s.status.c = (r & 0x80) != 0;
}

/* Implementation of LSR */
- (void)LSR_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LSR $%04X", addr];
  uint8 val = [self readMemory:addr];
  uint8 r = val << 1;
  [self writeMemory:r loc:param1];
  s.status.z = !(r);
  s.status.c = (r & 0x80) != 0;
}

/* Implementation of LSR */
- (void)LSR_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"LSR $%04X", addr + x];
  uint8 val = [self readMemory:addr];
  uint8 r = val << 1;
  [self writeMemory:r loc:param1];
  s.status.z = !(r);
  s.status.c = (r & 0x80) != 0;
}

/*
 NOP  No Operation

 ---                              N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       NOP           EA    1     2
 */
/* Implementation of NOP */
- (void)NOP_implied
{
  [self debugLogWithFormat:@"NOP"]; // literally does nothing...
}

/*
 ORA  OR Memory with Accumulator

 A OR M -> A                      N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     ORA #oper     09    2     2
 zeropage      ORA oper      05    2     3
 zeropage,X    ORA oper,X    15    2     4
 absolute      ORA oper      0D    3     4
 absolute,X    ORA oper,X    1D    3     4*
 absolute,Y    ORA oper,Y    19    3     4*
 (indirect,X)  ORA (oper,X)  01    2     6
 (indirect),Y  ORA (oper),Y  11    2     5*
 */
/* Implementation of ORA */
- (void)ORA_immediate
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA #%02X", param1];
  uint8 r = a | param1;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA $%02X", param1];
  uint8 v = [self readMemory:param1];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA $%02X,X", param1];
  uint8 v = [self readMemory:param1 + x];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA $%04X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA $%04X,X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + x];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_absoluteY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"ORA $%04X,Y", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + y];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/* Implementation of ORA */
- (void)ORA_indirectX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 p2 = [self readMemory:pc + 1];
  [self debugLogWithFormat:@"ORA $%04X,Y", param1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + x];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

- (void)ORA_indirectY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 p2 = [self readMemory:pc + 1];
  [self debugLogWithFormat:@"ORA $%04X,Y", param1];
  uint16 addr = ((uint16)p2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + y];
  uint8 r = a | v;
  a = r;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
}

/*
 PHA  Push Accumulator on Stack

 push A                           N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       PHA           48    1     3
 */
/* Implementation of PHA */
- (void)PHA_implied
{
  [self debugLogWithFormat:@"PHA"];
  [self push:a];
}

/*
 PHP  Push Processor Status on Stack

 push SR                          N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       PHP           08    1     3
 */
/* Implementation of PHP */
- (void)PHP_implied
{
  [self debugLogWithFormat:@"PHP"];
  [self push:s.sr];
}

/*
 PLA  Pull Accumulator from Stack

 pull A                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       PLA           68    1     4
 */
/* Implementation of PLA */
- (void)PLA_implied
{
  [self debugLogWithFormat:@"PLA"];
  a = [self pop];
}

/*
 PLP  Pull Processor Status from Stack

 pull SR                          N Z C I D V
 from stack

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       PLP           28    1     4
 */
/* Implementation of PLP */
- (void)PLP_implied
{
  [self debugLogWithFormat:@"PLP"];
  s.sr = [self pop];
}

/*
 ROL  Rotate One Bit Left (Memory or Accumulator)

 C <- [76543210] <- C             N Z C I D V
 + + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 accumulator   ROL A         2A    1     2
 zeropage      ROL oper      26    2     5
 zeropage,X    ROL oper,X    36    2     6
 absolute      ROL oper      2E    3     6
 absolute,X    ROL oper,X    3E    3     7
 */
/* Implementation of ROL */
- (void)ROL_accumulator
{
  [self debugLogWithFormat:@"ROL"];
  a = a << 1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
  s.status.c = (a & 0x80) != 0;
}

/* Implementation of ROL */
- (void)ROL_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ROL $%02X", param1];
  uint8 v = [self readMemory:param1];
  v = v << 1;
  [self writeMemory:v loc:param1];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROL */
- (void)ROL_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ROL $%02X,X", param1];
  uint8 v = [self readMemory:param1];
  v = v << 1;
  [self writeMemory:v loc:param1 + x];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROL */
- (void)ROL_absolute
{
  [self debugLogWithFormat:@"ROL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr];
  v = v << 1;
  [self writeMemory:v loc:addr];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROL */
- (void)ROL_absoluteX
{
  [self debugLogWithFormat:@"ROL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + x];
  v = v << 1;
  [self writeMemory:v loc:addr + x];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/*
 ROR  Rotate One Bit Right (Memory or Accumulator)

 C -> [76543210] -> C             N Z C I D V
 + + + - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 accumulator   ROR A         6A    1     2
 zeropage      ROR oper      66    2     5
 zeropage,X    ROR oper,X    76    2     6
 absolute      ROR oper      6E    3     6
 absolute,X    ROR oper,X    7E    3     7
 */
/* Implementation of ROR */
- (void)ROR_accumulator
{
  [self debugLogWithFormat:@"ROR"];
  [self debugLogWithFormat:@"ROL"];
  a = a >> 1;
  s.status.n = (a & 0x80) != 0;
  s.status.z = !(a);
  s.status.c = (a & 0x80) != 0;
}

/* Implementation of ROR */
- (void)ROR_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ROL $%02X", param1];
  uint8 v = [self readMemory:param1];
  v = v >> 1;
  [self writeMemory:v loc:param1];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROR */
- (void)ROR_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"ROL $%02X,X", param1];
  uint8 v = [self readMemory:param1];
  v = v >> 1;
  [self writeMemory:v loc:param1 + x];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROR */
- (void)ROR_absolute
{
  [self debugLogWithFormat:@"ROL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr];
  v = v >> 1;
  [self writeMemory:v loc:addr];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of ROR */
- (void)ROR_absoluteX
{
  [self debugLogWithFormat:@"ROL"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 v = [self readMemory:addr + x];
  v = v << 1;
  [self writeMemory:v loc:addr + x];
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/*
 RTI  Return from Interrupt

 pull SR, pull PC                 N Z C I D V
 from stack

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       RTI           40    1     6
 */
/* Implementation of RTI */
- (void)RTI_implied
{
  [self debugLogWithFormat:@"RTI"];
  uint8_t lo, hi;

  s.sr = [self pop];

  lo = [self pop];
  hi = [self pop];

  pc = (hi << 8) | lo;
}

/*
 RTS  Return from Subroutine

 pull PC, PC+1 -> PC              N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       RTS           60    1     6
 */
/* Implementation of RTS */
- (void)RTS_implied
{
  [self debugLogWithFormat:@"RTS"];
  uint8_t lo, hi;

  lo = [self pop];
  hi = [self pop];

  pc = ((hi << 8) | lo) + 1;
}

/*
 SBC  Subtract Memory from Accumulator with Borrow

 A - M - C -> A                   N Z C I D V
 + + + - - +

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 immidiate     SBC #oper     E9    2     2
 zeropage      SBC oper      E5    2     3
 zeropage,X    SBC oper,X    F5    2     4
 absolute      SBC oper      ED    3     4
 absolute,X    SBC oper,X    FD    3     4*
 absolute,Y    SBC oper,Y    F9    3     4*
 (indirect,X)  SBC (oper,X)  E1    2     6
 (indirect),Y  SBC (oper),Y  F1    2     5*
 */
/* Implementation of SBC */
- (void)SBC_immediate
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  a = a - param1;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"SBC #%04X", param1];
  uint8 val = [self readMemory:param1];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"SBC #%04X,X", param1];
  uint8 val = [self readMemory:param1 + x];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_absolute
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_absoluteX
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_absoluteY
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  pc++;
  uint8 param2 = [self readMemory:pc + 1];
  [self debugLogWithFormat:@"param = %X", param2];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_indirectX
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 param2 = [self readMemory:pc + 1];

  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + x];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/* Implementation of SBC */
- (void)SBC_indirectY
{
  [self debugLogWithFormat:@"SBC"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
  uint8 param2 = [self readMemory:pc + 1];

  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  uint8 val = [self readMemory:addr + y];
  a = a - val;
  uint8 v = a;
  s.status.n = (v & 0x80) != 0;
  s.status.z = !(v);
  s.status.c = (v & 0x80) != 0;
}

/*
 SEC  Set Carry Flag

 1 -> C                           N Z C I D V
 - - 1 - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       SEC           38    1     2
 */
/* Implementation of SEC */
- (void)SEC_implied
{
  [self debugLogWithFormat:@"SEC"];
  s.status.c = 1;
}

/*
 SED  Set Decimal Flag

 1 -> D                           N Z C I D V
 - - - - 1 -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       SED           F8    1     2
 */
/* Implementation of SED */
- (void)SED_implied
{
  [self debugLogWithFormat:@"SED"];
  s.status.d = 1;
}

/*
 SEI  Set Interrupt Disable Status

 1 -> I                           N Z C I D V
 - - - 1 - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       SEI           78    1     2
 */
/* Implementation of SEI */
- (void)SEI_implied
{
  [self debugLogWithFormat:@"SEI"];
  s.status.i = 1;
}

/*
 STA  Store Accumulator in Memory

 A -> M                           N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      STA oper      85    2     3
 zeropage,X    STA oper,X    95    2     4
 absolute      STA oper      8D    3     4
 absolute,X    STA oper,X    9D    3     5
 absolute,Y    STA oper,Y    99    3     5
 (indirect,X)  STA (oper,X)  81    2     6
 (indirect),Y  STA (oper),Y  91    2     6
 */
/* Implementation of STA */
/* Implementation of STA */
- (void)STA_zeropage
{
  pc++;
  uint8 address = [self readMemory:pc];
  pc++;

  [self writeMemory:a address:address];
  [self debugLogWithFormat:@"STA $%02X", address];
  // STA does not affect any flags
}

/* Implementation of STA */
- (void)STA_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"STA #%02x,X", param1];
  [self writeMemory:a loc:param1 + x];
}

/* Implementation of STA */
- (void)STA_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  pc++;
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self writeMemory:a address:addr];
  [self debugLogWithFormat:@"STA $%04X", addr];
}

/* Implementation of STA */
- (void)STA_absoluteX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"STA $%04x,X", addr];
  [self writeMemory:a loc:addr + x];
}

/* Implementation of STA */
- (void)STA_absoluteY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"STA $%04x,Y", addr];
  [self writeMemory:a loc:addr + y];
}

/* Implementation of STA */
- (void)STA_indirectX
{
  [self debugLogWithFormat:@"STA"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
}

/* Implementation of STA */
- (void)STA_indirectY
{
  [self debugLogWithFormat:@"STA"];
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"param = %X", param1];
}

/*
 STX  Store Index X in Memory

 X -> M                           N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      STX oper      86    2     3
 zeropage,Y    STX oper,Y    96    2     4
 absolute      STX oper      8E    3     4
 */
/* Implementation of STX */
- (void)STX_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"STX $%02x", param1];
  [self writeMemory:x loc:param1];
}

/* Implementation of STX */
- (void)STX_zeropageY
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"STY $%02x,Y", param1];
  [self writeMemory:x loc:param1 + y];
}

/* Implementation of STX */
- (void)STX_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"STX $%04x", addr];
  [self writeMemory:x loc:addr];
}

/*
 STY  Sore Index Y in Memory

 Y -> M                           N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 zeropage      STY oper      84    2     3
 zeropage,X    STY oper,X    94    2     4
 absolute      STY oper      8C    3     4
 */
/* Implementation of STY */
- (void)STY_zeropage
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"STY $%02x", param1];
  [self writeMemory:y loc:param1];
}

/* Implementation of STY */
- (void)STY_zeropageX
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  [self debugLogWithFormat:@"STY $%02x,X", param1];
  [self writeMemory:x loc:param1 + x];
}

/* Implementation of STY */
- (void)STY_absolute
{
  pc++;
  uint8 param1 = [self readMemory:pc];
  pc++;
  uint8 param2 = [self readMemory:pc];
  uint16 addr = ((uint16)param2 << 8) + (uint16)param1;
  [self debugLogWithFormat:@"STY $%04x", addr];
  [self writeMemory:y loc:addr];
}

/*
 TAX  Transfer Accumulator to Index X

 A -> X                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TAX           AA    1     2
 */
/* Implementation of TAX */
- (void)TAX_implied
{
  [self debugLogWithFormat:@"TAX"];
  x = a;

  // Update N and Z flags based on the result
  s.status.n = (x & 0x80) ? 1 : 0; // Set N flag if bit 7 is set
  s.status.z = (x == 0) ? 1 : 0;   // Set Z flag if result is zero
}

/*
 TAY  Transfer Accumulator to Index Y

 A -> Y                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TAY           A8    1     2
 */
/* Implementation of TAY */
- (void)TAY_implied
{
  [self debugLogWithFormat:@"TAY"];
  y = a;

  // Update N and Z flags based on the result
  s.status.n = (y & 0x80) ? 1 : 0; // Set N flag if bit 7 is set
  s.status.z = (y == 0) ? 1 : 0;   // Set Z flag if result is zero
}

/*
 TSX  Transfer Stack Pointer to Index X

 SP -> X                          N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TSX           BA    1     2
 */
/* Implementation of TSX */
- (void)TSX_implied
{
  [self debugLogWithFormat:@"TSX"];
  x = sp;

  // Update N and Z flags based on the result
  s.status.n = (x & 0x80) ? 1 : 0; // Set N flag if bit 7 is set
  s.status.z = (x == 0) ? 1 : 0;   // Set Z flag if result is zero
}

/*
 TXA  Transfer Index X to Accumulator

 X -> A                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TXA           8A    1     2
 */
/* Implementation of TXA */
- (void)TXA_implied
{
  [self debugLogWithFormat:@"TXA"];
  a = x;

  // Update N and Z flags based on the result
  s.status.n = (a & 0x80) ? 1 : 0; // Set N flag if bit 7 is set
  s.status.z = (a == 0) ? 1 : 0;   // Set Z flag if result is zero
}

/*
 TXS  Transfer Index X to Stack Register

 X -> SP                          N Z C I D V
 - - - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TXS           9A    1     2
 */
/* Implementation of TXS */
- (void)TXS_implied
{
  [self debugLogWithFormat:@"TXS"];
  sp = x;
}

/*
 TYA  Transfer Index Y to Accumulator

 Y -> A                           N Z C I D V
 + + - - - -

 addressing    assembler    opc  bytes  cyles
 --------------------------------------------
 implied       TYA           98    1     2
 */
/* Implementation of TYA */
- (void)TYA_implied
{
  [self debugLogWithFormat:@"TYA"];
  a = y; // Transfer Y to A, not A to Y

  // Update N and Z flags based on the result
  s.status.n = (a & 0x80) ? 1 : 0; // Set N flag if bit 7 is set
  s.status.z = (a == 0) ? 1 : 0;   // Set Z flag if result is zero
}

/*
 * Canonical NMOS 6502 execution path.  The older per-addressing-mode methods
 * above are retained for source compatibility, but this routine is the one
 * used by CPU6502.  Keeping fetch/address formation here prevents the many
 * subtly different PC and zero-page wrapping rules from drifting apart.
 */
- (NSUInteger)executeOpcode:(uint8)opcode
{
  uint8 value = 0, old = 0;
  uint16 address = 0, base = 0;
  BOOL crossed = NO;
  NSUInteger used = 2;

#define FETCH8() ([self readMemory:pc++])
#define FETCH16()                                                             \
  ({                                                                          \
    uint8 _l = FETCH8 ();                                                     \
    uint8 _h = FETCH8 ();                                                     \
    (uint16) (_l | ((uint16)_h << 8));                                        \
  })
#define ZPX() ((uint8)(FETCH8 () + x))
#define ZPY() ((uint8)(FETCH8 () + y))
#define INDX()                                                                \
  ({                                                                          \
    uint8 _p = (uint8)(FETCH8 () + x);                                        \
    (uint16) ([self readMemory:_p]                                            \
              | ((uint16)[self readMemory:(uint8)(_p + 1)] << 8));            \
  })
#define INDY()                                                                \
  ({                                                                          \
    uint8 _p = FETCH8 ();                                                     \
    uint16 _b = (uint16)([self readMemory:_p]                                 \
                         | ((uint16)[self readMemory:(uint8)(_p + 1)] << 8)); \
    base = _b;                                                                \
    address = (uint16)(_b + y);                                               \
    crossed = ((_b ^ address) & 0xff00) != 0;                                 \
    address;                                                                  \
  })
#define ABSX()                                                                \
  ({                                                                          \
    uint16 _b = FETCH16 ();                                                   \
    base = _b;                                                                \
    address = (uint16)(_b + x);                                               \
    crossed = ((_b ^ address) & 0xff00) != 0;                                 \
    address;                                                                  \
  })
#define ABSY()                                                                \
  ({                                                                          \
    uint16 _b = FETCH16 ();                                                   \
    base = _b;                                                                \
    address = (uint16)(_b + y);                                               \
    crossed = ((_b ^ address) & 0xff00) != 0;                                 \
    address;                                                                  \
  })
#define NZ(v) [self updateNZFlags:(uint8)(v)]
#define COMPARE(r, m)                                                         \
  do                                                                          \
    {                                                                         \
      uint16 _d = (uint16)(r) - (uint16)(m);                                  \
      s.status.c = (r) >= (m);                                                \
      NZ ((uint8)_d);                                                         \
    }                                                                         \
  while (0)
#define BRANCH(cond)                                                          \
  do                                                                          \
    {                                                                         \
      int8_t _off = (int8_t)FETCH8 ();                                        \
      used = 2;                                                               \
      if (cond)                                                               \
        {                                                                     \
          uint16 _from = pc;                                                  \
          pc = (uint16)(pc + _off);                                           \
          used += 1 + (((_from ^ pc) & 0xff00) != 0);                         \
        }                                                                     \
    }                                                                         \
  while (0)
#define ADC_VALUE(m)                                                          \
  do                                                                          \
    {                                                                         \
      uint8 _m = (m), _a = a, _cin = s.status.c;                              \
      uint16 _binary = (uint16)_a + _m + _cin;                                \
      s.status.v = ((~(_a ^ _m) & (_a ^ (uint8)_binary) & 0x80) != 0);        \
      if (s.status.d)                                                         \
        {                                                                     \
          uint16 _lo = (_a & 0x0f) + (_m & 0x0f) + _cin;                      \
          uint16 _hi = (_a & 0xf0) + (_m & 0xf0);                             \
          if (_lo > 9)                                                        \
            {                                                                 \
              _lo += 6;                                                       \
              _hi += 0x10;                                                    \
            }                                                                 \
          if (_hi > 0x90)                                                     \
            _hi += 0x60;                                                      \
          s.status.c = _hi > 0xff;                                            \
          a = (uint8)((_hi & 0xf0) | (_lo & 0x0f));                           \
          s.status.n = ((uint8)_binary & 0x80) != 0;                          \
          s.status.z = ((uint8)_binary == 0);                                 \
        }                                                                     \
      else                                                                    \
        {                                                                     \
          s.status.c = _binary > 0xff;                                        \
          a = (uint8)_binary;                                                 \
          NZ (a);                                                             \
        }                                                                     \
    }                                                                         \
  while (0)
#define SBC_VALUE(m) ADC_VALUE ((uint8)((m) ^ 0xff))
#define RMW_SHIFT(expr)                                                       \
  do                                                                          \
    {                                                                         \
      old = [self readMemory:address];                                        \
      value = (expr);                                                         \
      [self writeMemory:value address:address];                               \
      NZ (value);                                                             \
    }                                                                         \
  while (0)

  pc++; /* consume opcode */
  switch (opcode)
    {
    /* ORA */
    case 0x09:
      value = FETCH8 ();
      used = 2;
      goto do_ora;
    case 0x05:
      address = FETCH8 ();
      used = 3;
      goto read_ora;
    case 0x15:
      address = ZPX ();
      used = 4;
      goto read_ora;
    case 0x0d:
      address = FETCH16 ();
      used = 4;
      goto read_ora;
    case 0x1d:
      address = ABSX ();
      used = 4 + crossed;
      goto read_ora;
    case 0x19:
      address = ABSY ();
      used = 4 + crossed;
      goto read_ora;
    case 0x01:
      address = INDX ();
      used = 6;
      goto read_ora;
    case 0x11:
      address = INDY ();
      used = 5 + crossed;
      goto read_ora;
    read_ora:
      value = [self readMemory:address];
    do_ora:
      a |= value;
      NZ (a);
      break;
    /* AND */
    case 0x29:
      value = FETCH8 ();
      used = 2;
      goto do_and;
    case 0x25:
      address = FETCH8 ();
      used = 3;
      goto read_and;
    case 0x35:
      address = ZPX ();
      used = 4;
      goto read_and;
    case 0x2d:
      address = FETCH16 ();
      used = 4;
      goto read_and;
    case 0x3d:
      address = ABSX ();
      used = 4 + crossed;
      goto read_and;
    case 0x39:
      address = ABSY ();
      used = 4 + crossed;
      goto read_and;
    case 0x21:
      address = INDX ();
      used = 6;
      goto read_and;
    case 0x31:
      address = INDY ();
      used = 5 + crossed;
      goto read_and;
    read_and:
      value = [self readMemory:address];
    do_and:
      a &= value;
      NZ (a);
      break;
    /* EOR */
    case 0x49:
      value = FETCH8 ();
      used = 2;
      goto do_eor;
    case 0x45:
      address = FETCH8 ();
      used = 3;
      goto read_eor;
    case 0x55:
      address = ZPX ();
      used = 4;
      goto read_eor;
    case 0x4d:
      address = FETCH16 ();
      used = 4;
      goto read_eor;
    case 0x5d:
      address = ABSX ();
      used = 4 + crossed;
      goto read_eor;
    case 0x59:
      address = ABSY ();
      used = 4 + crossed;
      goto read_eor;
    case 0x41:
      address = INDX ();
      used = 6;
      goto read_eor;
    case 0x51:
      address = INDY ();
      used = 5 + crossed;
      goto read_eor;
    read_eor:
      value = [self readMemory:address];
    do_eor:
      a ^= value;
      NZ (a);
      break;
    /* ADC */
    case 0x69:
      value = FETCH8 ();
      used = 2;
      goto do_adc;
    case 0x65:
      address = FETCH8 ();
      used = 3;
      goto read_adc;
    case 0x75:
      address = ZPX ();
      used = 4;
      goto read_adc;
    case 0x6d:
      address = FETCH16 ();
      used = 4;
      goto read_adc;
    case 0x7d:
      address = ABSX ();
      used = 4 + crossed;
      goto read_adc;
    case 0x79:
      address = ABSY ();
      used = 4 + crossed;
      goto read_adc;
    case 0x61:
      address = INDX ();
      used = 6;
      goto read_adc;
    case 0x71:
      address = INDY ();
      used = 5 + crossed;
      goto read_adc;
    read_adc:
      value = [self readMemory:address];
    do_adc:
      ADC_VALUE (value);
      break;
    /* SBC */
    case 0xe9:
    case 0xeb:
      value = FETCH8 ();
      used = 2;
      goto do_sbc;
    case 0xe5:
      address = FETCH8 ();
      used = 3;
      goto read_sbc;
    case 0xf5:
      address = ZPX ();
      used = 4;
      goto read_sbc;
    case 0xed:
      address = FETCH16 ();
      used = 4;
      goto read_sbc;
    case 0xfd:
      address = ABSX ();
      used = 4 + crossed;
      goto read_sbc;
    case 0xf9:
      address = ABSY ();
      used = 4 + crossed;
      goto read_sbc;
    case 0xe1:
      address = INDX ();
      used = 6;
      goto read_sbc;
    case 0xf1:
      address = INDY ();
      used = 5 + crossed;
      goto read_sbc;
    read_sbc:
      value = [self readMemory:address];
    do_sbc:
      SBC_VALUE (value);
      break;

    /* Loads */
    case 0xa9:
      value = FETCH8 ();
      used = 2;
      goto lda;
    case 0xa5:
      address = FETCH8 ();
      used = 3;
      goto lda_mem;
    case 0xb5:
      address = ZPX ();
      used = 4;
      goto lda_mem;
    case 0xad:
      address = FETCH16 ();
      used = 4;
      goto lda_mem;
    case 0xbd:
      address = ABSX ();
      used = 4 + crossed;
      goto lda_mem;
    case 0xb9:
      address = ABSY ();
      used = 4 + crossed;
      goto lda_mem;
    case 0xa1:
      address = INDX ();
      used = 6;
      goto lda_mem;
    case 0xb1:
      address = INDY ();
      used = 5 + crossed;
      goto lda_mem;
    lda_mem:
      value = [self readMemory:address];
    lda:
      a = value;
      NZ (a);
      break;
    case 0xa2:
      value = FETCH8 ();
      used = 2;
      goto ldx;
    case 0xa6:
      address = FETCH8 ();
      used = 3;
      goto ldx_mem;
    case 0xb6:
      address = ZPY ();
      used = 4;
      goto ldx_mem;
    case 0xae:
      address = FETCH16 ();
      used = 4;
      goto ldx_mem;
    case 0xbe:
      address = ABSY ();
      used = 4 + crossed;
      goto ldx_mem;
    ldx_mem:
      value = [self readMemory:address];
    ldx:
      x = value;
      NZ (x);
      break;
    case 0xa0:
      value = FETCH8 ();
      used = 2;
      goto ldy;
    case 0xa4:
      address = FETCH8 ();
      used = 3;
      goto ldy_mem;
    case 0xb4:
      address = ZPX ();
      used = 4;
      goto ldy_mem;
    case 0xac:
      address = FETCH16 ();
      used = 4;
      goto ldy_mem;
    case 0xbc:
      address = ABSX ();
      used = 4 + crossed;
      goto ldy_mem;
    ldy_mem:
      value = [self readMemory:address];
    ldy:
      y = value;
      NZ (y);
      break;

    /* Stores */
    case 0x85:
      address = FETCH8 ();
      used = 3;
      goto sta;
    case 0x95:
      address = ZPX ();
      used = 4;
      goto sta;
    case 0x8d:
      address = FETCH16 ();
      used = 4;
      goto sta;
    case 0x9d:
      address = (uint16)(FETCH16 () + x);
      used = 5;
      goto sta;
    case 0x99:
      address = (uint16)(FETCH16 () + y);
      used = 5;
      goto sta;
    case 0x81:
      address = INDX ();
      used = 6;
      goto sta;
    case 0x91:
      address = INDY ();
      used = 6;
      goto sta;
    sta:
      [self writeMemory:a address:address];
      break;
    case 0x86:
      address = FETCH8 ();
      used = 3;
      goto stx;
    case 0x96:
      address = ZPY ();
      used = 4;
      goto stx;
    case 0x8e:
      address = FETCH16 ();
      used = 4;
      goto stx;
    stx:
      [self writeMemory:x address:address];
      break;
    case 0x84:
      address = FETCH8 ();
      used = 3;
      goto sty;
    case 0x94:
      address = ZPX ();
      used = 4;
      goto sty;
    case 0x8c:
      address = FETCH16 ();
      used = 4;
      goto sty;
    sty:
      [self writeMemory:y address:address];
      break;

    /* Compare and BIT */
    case 0xc9:
      value = FETCH8 ();
      used = 2;
      goto cmp;
    case 0xc5:
      address = FETCH8 ();
      used = 3;
      goto cmpm;
    case 0xd5:
      address = ZPX ();
      used = 4;
      goto cmpm;
    case 0xcd:
      address = FETCH16 ();
      used = 4;
      goto cmpm;
    case 0xdd:
      address = ABSX ();
      used = 4 + crossed;
      goto cmpm;
    case 0xd9:
      address = ABSY ();
      used = 4 + crossed;
      goto cmpm;
    case 0xc1:
      address = INDX ();
      used = 6;
      goto cmpm;
    case 0xd1:
      address = INDY ();
      used = 5 + crossed;
      goto cmpm;
    cmpm:
      value = [self readMemory:address];
    cmp:
      COMPARE (a, value);
      break;
    case 0xe0:
      value = FETCH8 ();
      used = 2;
      goto cpx;
    case 0xe4:
      address = FETCH8 ();
      used = 3;
      goto cpxm;
    case 0xec:
      address = FETCH16 ();
      used = 4;
      goto cpxm;
    cpxm:
      value = [self readMemory:address];
    cpx:
      COMPARE (x, value);
      break;
    case 0xc0:
      value = FETCH8 ();
      used = 2;
      goto cpy;
    case 0xc4:
      address = FETCH8 ();
      used = 3;
      goto cpym;
    case 0xcc:
      address = FETCH16 ();
      used = 4;
      goto cpym;
    cpym:
      value = [self readMemory:address];
    cpy:
      COMPARE (y, value);
      break;
    case 0x24:
      address = FETCH8 ();
      used = 3;
      goto bit;
    case 0x2c:
      address = FETCH16 ();
      used = 4;
      goto bit;
    bit:
      value = [self readMemory:address];
      s.status.z = (a & value) == 0;
      s.status.n = (value & 0x80) != 0;
      s.status.v = (value & 0x40) != 0;
      break;

    /* Shifts and rotates */
    case 0x0a:
      s.status.c = (a & 0x80) != 0;
      a <<= 1;
      NZ (a);
      used = 2;
      break;
    case 0x06:
      address = FETCH8 ();
      used = 5;
      goto asl;
    case 0x16:
      address = ZPX ();
      used = 6;
      goto asl;
    case 0x0e:
      address = FETCH16 ();
      used = 6;
      goto asl;
    case 0x1e:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto asl;
    asl:
      old = [self readMemory:address];
      s.status.c = (old & 0x80) != 0;
      value = old << 1;
      [self writeMemory:value address:address];
      NZ (value);
      break;
    case 0x4a:
      s.status.c = a & 1;
      a >>= 1;
      NZ (a);
      used = 2;
      break;
    case 0x46:
      address = FETCH8 ();
      used = 5;
      goto lsr;
    case 0x56:
      address = ZPX ();
      used = 6;
      goto lsr;
    case 0x4e:
      address = FETCH16 ();
      used = 6;
      goto lsr;
    case 0x5e:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto lsr;
    lsr:
      old = [self readMemory:address];
      s.status.c = old & 1;
      value = old >> 1;
      [self writeMemory:value address:address];
      NZ (value);
      break;
    case 0x2a:
      {
        BOOL c = s.status.c;
        s.status.c = (a & 0x80) != 0;
        a = (a << 1) | c;
        NZ (a);
        used = 2;
        break;
      }
    case 0x26:
      address = FETCH8 ();
      used = 5;
      goto rol;
    case 0x36:
      address = ZPX ();
      used = 6;
      goto rol;
    case 0x2e:
      address = FETCH16 ();
      used = 6;
      goto rol;
    case 0x3e:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto rol;
    rol:
      old = [self readMemory:address];
      value = (old << 1) | s.status.c;
      s.status.c = (old & 0x80) != 0;
      [self writeMemory:value address:address];
      NZ (value);
      break;
    case 0x6a:
      {
        BOOL c = s.status.c;
        s.status.c = a & 1;
        a = (a >> 1) | (c ? 0x80 : 0);
        NZ (a);
        used = 2;
        break;
      }
    case 0x66:
      address = FETCH8 ();
      used = 5;
      goto ror;
    case 0x76:
      address = ZPX ();
      used = 6;
      goto ror;
    case 0x6e:
      address = FETCH16 ();
      used = 6;
      goto ror;
    case 0x7e:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto ror;
    ror:
      old = [self readMemory:address];
      value = (old >> 1) | (s.status.c ? 0x80 : 0);
      s.status.c = old & 1;
      [self writeMemory:value address:address];
      NZ (value);
      break;

    /* Increment/decrement */
    case 0xe6:
      address = FETCH8 ();
      used = 5;
      goto inc;
    case 0xf6:
      address = ZPX ();
      used = 6;
      goto inc;
    case 0xee:
      address = FETCH16 ();
      used = 6;
      goto inc;
    case 0xfe:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto inc;
    inc:
      value = [self readMemory:address] + 1;
      [self writeMemory:value address:address];
      NZ (value);
      break;
    case 0xc6:
      address = FETCH8 ();
      used = 5;
      goto dec;
    case 0xd6:
      address = ZPX ();
      used = 6;
      goto dec;
    case 0xce:
      address = FETCH16 ();
      used = 6;
      goto dec;
    case 0xde:
      address = (uint16)(FETCH16 () + x);
      used = 7;
      goto dec;
    dec:
      value = [self readMemory:address] - 1;
      [self writeMemory:value address:address];
      NZ (value);
      break;
    case 0xe8:
      x++;
      NZ (x);
      break;
    case 0xc8:
      y++;
      NZ (y);
      break;
    case 0xca:
      x--;
      NZ (x);
      break;
    case 0x88:
      y--;
      NZ (y);
      break;

    /* Branches */
    case 0x10:
      BRANCH (!s.status.n);
      break;
    case 0x30:
      BRANCH (s.status.n);
      break;
    case 0x50:
      BRANCH (!s.status.v);
      break;
    case 0x70:
      BRANCH (s.status.v);
      break;
    case 0x90:
      BRANCH (!s.status.c);
      break;
    case 0xb0:
      BRANCH (s.status.c);
      break;
    case 0xd0:
      BRANCH (!s.status.z);
      break;
    case 0xf0:
      BRANCH (s.status.z);
      break;

    /* Jumps, interrupts, and stack */
    case 0x4c:
      pc = FETCH16 ();
      used = 3;
      break;
    case 0x6c:
      {
        uint16 p = FETCH16 ();
        uint16 ph = (p & 0xff00) | ((p + 1) & 0xff);
        pc = (uint16)([self readMemory:p]
                      | ((uint16)[self readMemory:ph] << 8));
        used = 5;
        break;
      }
    case 0x20:
      address = FETCH16 ();
      base = pc - 1;
      [self push:base >> 8];
      [self push:base & 0xff];
      pc = address;
      used = 6;
      break;
    case 0x60:
      pc = (uint16)([self pop] | ((uint16)[self pop] << 8));
      pc++;
      used = 6;
      break;
    case 0x00:
      pc++;
      [self push:pc >> 8];
      [self push:pc & 0xff];
      [self push:s.sr | 0x30];
      s.status.i = 1;
      pc = (uint16)([self readMemory:IRQVECTOR]
                    | ((uint16)[self readMemory:IRQVECTOR + 1] << 8));
      used = 7;
      break;
    case 0x40:
      s.sr = ([self pop] & 0xef) | 0x20;
      pc = (uint16)([self pop] | ((uint16)[self pop] << 8));
      used = 6;
      break;
    case 0x48:
      [self push:a];
      used = 3;
      break;
    case 0x68:
      a = [self pop];
      NZ (a);
      used = 4;
      break;
    case 0x08:
      [self push:s.sr | 0x30];
      used = 3;
      break;
    case 0x28:
      s.sr = ([self pop] & 0xef) | 0x20;
      used = 4;
      break;

    /* Transfers and flags */
    case 0xaa:
      x = a;
      NZ (x);
      break;
    case 0xa8:
      y = a;
      NZ (y);
      break;
    case 0x8a:
      a = x;
      NZ (a);
      break;
    case 0x98:
      a = y;
      NZ (a);
      break;
    case 0xba:
      x = sp;
      NZ (x);
      break;
    case 0x9a:
      sp = x;
      break;
    case 0x18:
      s.status.c = 0;
      break;
    case 0x38:
      s.status.c = 1;
      break;
    case 0x58:
      s.status.i = 0;
      break;
    case 0x78:
      s.status.i = 1;
      break;
    case 0xb8:
      s.status.v = 0;
      break;
    case 0xd8:
      s.status.d = 0;
      break;
    case 0xf8:
      s.status.d = 1;
      break;
    case 0xea:
      break;

    default:
      /* Stable behavior for undocumented NOPs commonly used for padding. */
      switch (opcode)
        {
        case 0x04:
        case 0x44:
        case 0x64:
          FETCH8 ();
          used = 3;
          break;
        case 0x14:
        case 0x34:
        case 0x54:
        case 0x74:
        case 0xd4:
        case 0xf4:
          FETCH8 ();
          used = 4;
          break;
        case 0x0c:
          FETCH16 ();
          used = 4;
          break;
        case 0x1c:
        case 0x3c:
        case 0x5c:
        case 0x7c:
        case 0xdc:
        case 0xfc:
          address = ABSX ();
          used = 4 + crossed;
          break;
        case 0x80:
        case 0x82:
        case 0x89:
        case 0xc2:
        case 0xe2:
          FETCH8 ();
          used = 2;
          break;
        case 0x1a:
        case 0x3a:
        case 0x5a:
        case 0x7a:
        case 0xda:
        case 0xfa:
          used = 2;
          break;
        default:
          [self debugLogWithFormat:@"Undocumented opcode $%02X at $%04X",
                                   opcode, (uint16)(pc - 1)];
          used = 2;
          break;
        }
      break;
    }
  s.status.unused = 1;
#undef FETCH8
#undef FETCH16
#undef ZPX
#undef ZPY
#undef INDX
#undef INDY
#undef ABSX
#undef ABSY
#undef NZ
#undef COMPARE
#undef BRANCH
#undef ADC_VALUE
#undef SBC_VALUE
#undef RMW_SHIFT
  return used;
}

@end

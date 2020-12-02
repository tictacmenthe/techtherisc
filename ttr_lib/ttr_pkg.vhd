library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package ttr_pkg is

    -- GENERAL CONFIG -----------------------------------------------------------------------------
  constant C_NREG   : positive := 32; -- number of cpu registers (excluding PC)
  constant C_XLEN   : positive := 32; -- number of bits per register
  constant C_ILEN   : positive := 32; -- number of bits per instruction

  subtype R_REG is natural range integer(ceil(log2(real(C_NREG))))-1 downto 0;

  -- INSTRUCTION DECODER CONFIG -------------------------------------------------------------------
  -- Positions in instruction, constant ranges
  subtype R_FUNCT7 is natural range 31 downto 25;
  subtype R_RSRC2  is natural range 24 downto 20;
  subtype R_RSRC1  is natural range 19 downto 15;
  subtype R_FUNCT3 is natural range 14 downto 12;
  subtype R_RDEST  is natural range 11 downto  7;
  subtype R_OPCODE is natural range  6 downto  0;
  
  -- Bit Widths
  constant C_FUNCT3_W : natural := R_FUNCT3'high - R_FUNCT3'low + 1;
  constant C_FUNCT7_W : natural := R_FUNCT7'high - R_FUNCT7'low + 1;
  constant C_FUNCT_W  : natural := C_FUNCT7_W + C_FUNCT3_W;
  
  constant C_RSRC2_W  : natural := R_RSRC2'high - R_RSRC2'low + 1;
  constant C_RSRC1_W  : natural := R_RSRC1'high - R_RSRC1'low + 1;
  constant C_RDEST_W  : natural := R_RDEST'high - R_RDEST'low + 1;
  
  constant C_OPCODE_W : natural := R_OPCODE'high - R_OPCODE'low + 1;

  -- OP codes
  subtype opcode_t is std_logic_vector(C_OPCODE_W-1 downto 0);
  constant C_OPCODE_OPIMM   : opcode_t := "00" & "100" & "11";
  constant C_OPCODE_LUI     : opcode_t := "01" & "101" & "11";
  constant C_OPCODE_AUIPC   : opcode_t := "00" & "101" & "11";
  constant C_OPCODE_OP      : opcode_t := "01" & "100" & "11";
  constant C_OPCODE_JAL     : opcode_t := "11" & "011" & "11";
  constant C_OPCODE_JALR    : opcode_t := "11" & "001" & "11";
  constant C_OPCODE_BRANCH  : opcode_t := "11" & "000" & "11";
  constant C_OPCODE_LOAD    : opcode_t := "00" & "000" & "11";
  constant C_OPCODE_STORE   : opcode_t := "01" & "000" & "11";
  constant C_OPCODE_MISCMEM : opcode_t := "00" & "011" & "11";
  constant C_OPCODE_SYSTEM  : opcode_t := "11" & "100" & "11";

  -- Immediates positions section by section, right(0) to left(n)
  -- I_imm
  subtype R_IMM_I   is natural range 31 downto 20;
  constant C_IMM_I_W : natural := R_IMM_I'high - R_IMM_I'low + 1;
  
  -- I_imm shift amount
  subtype R_I_SHAMT is natural range 4 downto 0;
  constant C_I_SR_SIGNED : natural := 10; -- bit 10 of immediate for shift right determines if the sign bit is shifted

  -- S_imm
  subtype R_IMM_S_1 is natural range 31 downto 25;
  subtype R_IMM_S_0 is natural range 11 downto  7;
  -- B_imm
  subtype R_IMM_B_3 is natural range 31 downto 31;
  subtype R_IMM_B_2 is natural range  7 downto  7;
  subtype R_IMM_B_1 is natural range 30 downto 25;
  subtype R_IMM_B_0 is natural range 11 downto  8;
  -- U_imm
  subtype R_IMM_U   is natural range 31 downto 12;
  constant C_IMM_U_W : natural := R_IMM_U'high - R_IMM_U'low + 1;

  -- J_imm
  subtype R_IMM_J_3 is natural range 31 downto 31;
  subtype R_IMM_J_2 is natural range 19 downto 12;
  subtype R_IMM_J_1 is natural range 20 downto 20;
  subtype R_IMM_J_0 is natural range 30 downto 21;
  
  -- Funct3 codes
  subtype R_MEM_FUNC_SIZE is natural range 1 downto 0;
  subtype mem_size_t is std_logic_vector(R_MEM_FUNC_SIZE);
  constant C_MEM_SIZE_B : mem_size_t := "00";
  constant C_MEM_SIZE_H : mem_size_t := "01";
  constant C_MEM_SIZE_W : mem_size_t := "10";
  constant C_MEM_SIZE_I : mem_size_t := "11"; -- invalid, consider a Full Word
  constant C_MEM_LOAD   : std_logic := '0';
  constant C_MEM_STORE  : std_logic := '1';

  subtype funct3_t is std_logic_vector(C_FUNCT3_W-1 downto 0);
  constant C_FUNCT3_ADD_SUB  : funct3_t := "000";
  constant C_FUNCT_SUB_BIT   : natural  := 8;
  constant C_FUNCT3_SLT      : funct3_t := "010";
  constant C_FUNCT3_SLTU     : funct3_t := "011";
  constant C_FUNCT3_AND      : funct3_t := "111";
  constant C_FUNCT3_OR       : funct3_t := "110";
  constant C_FUNCT3_XOR      : funct3_t := "100";
  constant C_FUNCT3_SLL      : funct3_t := "001";
  constant C_FUNCT3_SR       : funct3_t := "101";
  constant C_FUNCT_SR_SIGNED : natural  := 8;
  constant C_FUNCT3_BEQ      : funct3_t := "000";
  constant C_FUNCT3_BNE      : funct3_t := "001";
  constant C_FUNCT3_BLT      : funct3_t := "100";
  constant C_FUNCT3_BLTU     : funct3_t := "110";
  constant C_FUNCT3_BGE      : funct3_t := "101";
  constant C_FUNCT3_BGEU     : funct3_t := "111";
  

  -- Subtypes for ports
  subtype reg_t     is std_logic_vector(C_XLEN-1 downto 0);       -- Register
  subtype reg_sel_t is integer range 0 to C_NREG-1;           -- Register selector
  subtype instr_t   is std_logic_vector(C_ILEN-1 downto 0);     -- Instruction
  subtype funct_t   is std_logic_vector(C_FUNCT_W-1 downto 0);  -- Function code
end ttr_pkg;
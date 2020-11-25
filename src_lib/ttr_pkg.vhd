library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package ttr_pkg is

    -- GENERAL CONFIG -----------------------------------------------------------------------------
  constant C_NREG   : positive := 32; -- number of cpu registers (excluding PC)
  constant C_XLEN   : positive := 32; -- number of bits per register
  constant C_ILEN   : positive := 32; -- number of bits per instruction

  subtype R_REG is natural range integer(ceil(log2(real(C_NREG))))-1 downto 0;

  subtype reg_t is std_logic_vector(C_XLEN-1 downto 0);
  subtype reg_sel_t is integer range 0 to C_NREG-1;


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
  constant C_OPCODE_OP_IMM  : opcode_t := "00" & "100" & "11";
  constant C_OPCODE_LUI     : opcode_t := "01" & "101" & "11";
  constant C_OPCODE_AUIPC   : opcode_t := "00" & "101" & "11";
  constant C_OPCODE_OP      : opcode_t := "01" & "100" & "11";
  constant C_OPCODE_JAL     : opcode_t := "11" & "011" & "11";
  constant C_OPCODE_JALR    : opcode_t := "11" & "001" & "11";
  constant C_OPCODE_BRANCH  : opcode_t := "11" & "000" & "11";
  constant C_OPCODE_LOAD    : opcode_t := "00" & "000" & "11";
  constant C_OPCODE_STORE   : opcode_t := "01" & "000" & "11";
  constant C_OPCODE_MISC_MEM: opcode_t := "00" & "011" & "11";
  constant C_OPCODE_SYSTEM  : opcode_t := "11" & "100" & "11";

  -- Immediates positions
  subtype R_IMM_I is natural range 31 downto 20;

  -- Funct3 codes
  subtype funct3_t is std_logic_vector(C_FUNCT3_W-1 downto 0);
  constant C_FUNCT3_ADDI  : funct3_t := "000";
  constant C_FUNCT3_SLTI  : funct3_t := "010";
  constant C_FUNCT3_SLTIU : funct3_t := "011";
  constant C_FUNCT3_ANDI  : funct3_t := "111";
  constant C_FUNCT3_ORI   : funct3_t := "110";
  constant C_FUNCT3_XORI  : funct3_t := "100";

  constant C_FUNCT3_SLLI  : funct3_t := "001";
  constant C_FUNCT3_SRLI  : funct3_t := "101";
  constant C_FUNCT3_SRAI  : funct3_t := "101"; -- bit 30 is 1 too
  
end ttr_pkg;
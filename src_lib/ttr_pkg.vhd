library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package ttr_pkg is
  constant C_NREG   : positive := 16; -- number of cpu registers (excluding PC)
  constant C_XLEN   : positive := 32; -- number of bits per register
  constant C_ILEN   : positive := 32; -- number of bits per instruction

  subtype reg_t is std_logic_vector(C_XLEN-1 downto 0);
  subtype reg_sel_t is integer range 0 to C_NREG-1;


  -- INSTRUCTION DECODER CONFIG
  constant C_FUNCT7_H : natural := 31;
  constant C_FUNCT7_L : natural := 25;
  constant C_RSRC2_H  : natural := 24;
  constant C_RSRC2_L  : natural := 20;
  constant C_RSRC1_H  : natural := 19;
  constant C_RSRC1_L  : natural := 15;
  constant C_FUNCT3_H : natural := 14;
  constant C_FUNCT3_L : natural := 12;
  constant C_RDEST_H  : natural := 11;
  constant C_RDEST_L  : natural := 7;
  constant C_OPCODE_H : natural := 6;
  constant C_OPCODE_L : natural := 0;
  
  constant C_FUNCT3_W : natural := C_FUNCT3_H-C_FUNCT3_L+1;
  constant C_FUNCT7_W : natural := C_FUNCT7_H-C_FUNCT7_L+1;
  constant C_FUNCT_W  : natural := C_FUNCT7_W + C_FUNCT3_W;
  
  constant C_RSRC2_W  : natural := C_RSRC2_H-C_RSRC2_L+1;
  constant C_RSRC1_W  : natural := C_RSRC1_H-C_RSRC1_L+1;
  constant C_RDEST_W  : natural := C_RDEST_H-C_RDEST_L+1;
  
  constant C_OPCODE_W : natural := C_OPCODE_H-C_OPCODE_L+1;

  -- OP-CODES
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

end ttr_pkg;
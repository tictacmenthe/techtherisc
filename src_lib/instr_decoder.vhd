library ieee;
use ieee.std_logic_1164.all;

library src_lib;
use src_lib.ttr_pkg.all;

entity instr_decoder is
  generic(
    G_ILEN : positive := 32; -- instruction bit width
    G_XLEN : positive := 32; -- register bit width
    G_NREG : positive := 32  -- number of registers (excluding PC)
  );
  port(
    clk           : in  std_logic;                            -- system clock
    rst           : in  std_logic;                            -- active high reset
    en            : in  std_logic;                            -- if '0', ignores all inputs and keeps outputs constant

    instruction   : in  std_logic_vector(G_ILEN-1 downto 0);  -- instruction to decode

    reg_src1_sel  : out integer range 0 to G_NREG-1;  -- source register 1 selection
    reg_src2_sel  : out integer range 0 to G_NREG-1;  -- source register 2 selection
    reg_dest_sel  : out integer range 0 to G_NREG-1;  -- destination register selection

    opcode        : out std_logic_vector(C_OPCODE_W-1 downto 0);  -- extracted opcode
    funct         : out std_logic_vector(C_FUNCT_W-1 downto 0);  -- extracted funct3
    immediate     : out std_logic_vector(G_XLEN-1 downto 0)    -- extracted immediate value
  );
end entity instr_decoder;

architecture rtl of instr_decoder is
  -- fixed position aliases
  alias opcode_i     : std_logic_vector(C_OPCODE_W-1 downto 0) is instruction(C_OPCODE_H downto C_OPCODE_L);
  alias reg_dest_i   : std_logic_vector(C_RDEST_W-1  downto 0) is instruction(C_RDEST_H  downto C_RDEST_L);
  alias reg_src2_i   : std_logic_vector(C_RSRC2_W-1  downto 0) is instruction(C_RSRC2_H  downto C_RSRC2_L);
  alias reg_src1_i   : std_logic_vector(C_RSRC1_W-1  downto 0) is instruction(C_RSRC1_H  downto C_RSRC1_L);
  alias reg_funct3_i : std_logic_vector(C_FUNCT3_W-1 downto 0) is instruction(C_FUNCT3_H downto C_FUNCT3_L);
  alias reg_funct7_i : std_logic_vector(C_FUNCT7_W-1 downto 0) is instruction(C_FUNCT7_H downto C_FUNCT7_L);
  -- aliases for immediate values, depending on type of instruction: I/S/B/U/J

begin
  p_sync_update: process(clk, rst)
  begin
    if rst = '1' then
      reg_src1_sel <= 0;
      reg_src2_sel <= 0;
      reg_dest_sel <= 0;
      opcode       <= (others=>'0');
      funct        <= (others=>'0');
      immediate    <= (others=>'0');
    elsif rising_edge(clk) then
      opcode <=opcode_i;
      case opcode_i is
        when others =>
          null;
      end case;
    end if;
  end process p_sync_update;
end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library src_lib;
use src_lib.ttr_pkg.all;
use src_lib.utility_pkg.all;

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
  -- internal constants
  constant C_FUNC7_ZERO : std_logic_vector(C_FUNCT7_W-1 downto 0) := (others=>'0');

  -- fixed position aliases
  alias opcode_i    : std_logic_vector(C_OPCODE_W-1 downto 0) is instruction(R_OPCODE);
  alias reg_dest_i  : std_logic_vector(C_RDEST_W-1  downto 0) is instruction(R_RDEST);
  alias reg_src2_i  : std_logic_vector(C_RSRC2_W-1  downto 0) is instruction(R_RSRC2);
  alias reg_src1_i  : std_logic_vector(C_RSRC1_W-1  downto 0) is instruction(R_RSRC1);
  alias funct3_i    : std_logic_vector(C_FUNCT3_W-1 downto 0) is instruction(R_FUNCT3);
  alias funct7_i    : std_logic_vector(C_FUNCT7_W-1 downto 0) is instruction(R_FUNCT7);
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
      opcode  <=  opcode_i;
      reg_src1_sel  <=  to_integer(unsigned(reg_src1_i(R_REG)));
      reg_src2_sel  <=  to_integer(unsigned(reg_src2_i(R_REG)));
      reg_dest_sel  <=  to_integer(unsigned(reg_dest_i(R_REG)));

      case opcode_i is
        when C_OPCODE_OPIMM =>
          funct     <=  C_FUNC7_ZERO & funct3_i;
          immediate <=  resize_slv(instruction(R_IMM_I), G_XLEN);

        when C_OPCODE_LUI|C_OPCODE_AUIPC  =>
          immediate <=  instruction(R_IMM_U) & x"000";

        when C_OPCODE_OP        => 
          funct     <=  funct7_i & funct3_i;

        when C_OPCODE_JAL       => 
          immediate <=  resize_slv(
                          instruction(R_IMM_J_3) & instruction(R_IMM_J_2) &
                          instruction(R_IMM_J_1) & instruction(R_IMM_J_0) & '0'
                        , G_XLEN);

        when C_OPCODE_JALR      => 
          funct     <= (others=>'0');
          immediate <= resize_slv(instruction(R_IMM_I), G_XLEN);

        when C_OPCODE_BRANCH    =>
          funct     <= C_FUNC7_ZERO & funct3_i;
          immediate <=  resize_slv(
                          instruction(R_IMM_B_3) & instruction(R_IMM_B_2) &
                          instruction(R_IMM_B_1) & instruction(R_IMM_B_0) & '0'
                        , G_XLEN);

        when C_OPCODE_LOAD      =>
          funct     <= C_FUNC7_ZERO & funct3_i;
          immediate <= resize_slv(instruction(R_IMM_I), G_XLEN);

        when C_OPCODE_STORE     => 
          funct     <= C_FUNC7_ZERO & funct3_i;
          immediate <= resize_slv(instruction(R_IMM_S_1) & instruction(R_IMM_S_0), G_XLEN);

        when C_OPCODE_MISCMEM  =>
          
        
        when C_OPCODE_SYSTEM   =>

        
        when others =>
          null;
      end case;
    end if;
  end process p_sync_update;
end architecture rtl;
library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library src_lib;
use src_lib.ttr_pkg.all;

--  A testbench has no ports.
entity instr_tb is
  generic(runner_cfg: string);
end instr_tb;

architecture testbench of instr_tb is
  -- Functions
  procedure do_pulse(constant pulse_width : time; signal target : inout std_logic) is
  begin
    wait for pulse_width;
    target <= not target;
    wait for pulse_width;
    target <= not target;
  end procedure do_pulse;

  procedure verify_reg(constant reg_slv : reg_t; constant expected : integer) is
    variable reg_int: integer := to_integer(unsigned(reg_slv)); 
  begin
    check(reg_int = expected, "Wrong comparison: got:" & integer'image(reg_int) & "/exp:" & integer'image(expected));
  end procedure verify_reg;

  -- Internal constants
  constant C_CLK_PERIOD   : time  := 100 ns;
  constant C_RST_WIDTH    : time  :=   1 us;
  constant C_RZERO        : reg_t := (others => '0');

  -- Internal signals
  signal tb_en_clk        : std_logic;

  signal clk, rst, en     : std_logic;
  signal reg_src1_sel, reg_src2_sel, reg_dest_sel : reg_sel_t;

  signal instruction    : std_logic_vector(C_ILEN-1 downto 0);
  signal opcode         : std_logic_vector(C_OPCODE_W-1 downto 0);
  signal funct          : std_logic_vector(C_FUNCT_W-1 downto 0);
  signal immediate      : std_logic_vector(C_XLEN-1 downto 0);
  signal immediate_int  : integer range -2**(C_XLEN-1) to 2**(C_XLEN-1)-1;
begin
  --  Component instantiation.
  i_dut: entity src_lib.instr_decoder
    generic map(
      G_ILEN => C_ILEN,
      G_XLEN => C_XLEN,
      G_NREG => C_NREG
    )
    port map (
      clk           => clk,
      rst           => rst,
      en            => en,
      instruction   => instruction,
      reg_src1_sel  => reg_src1_sel,
      reg_src2_sel  => reg_src2_sel,
      reg_dest_sel  => reg_dest_sel,
      opcode        => opcode,
      funct         => funct,
      immediate     => immediate
    );

  immediate_int <= to_integer(signed(immediate));

  -- clk generation process
  p_clk_rst: process
  begin
    if tb_en_clk = '1' then
      clk <= not clk;
      wait for C_CLK_PERIOD/2;
    else
      clk <= '0';
      wait until tb_en_clk = '1';
    end if;
  end process p_clk_rst;

  -- TB process
  p_tb_main: process
  begin
    test_runner_setup(runner, runner_cfg);
    info("Start of test");

    rst       <= '1';
    en        <= '0';

    instruction <= (others=>'0');

    rst       <= '1';
    tb_en_clk <= '0';
    do_pulse(C_RST_WIDTH, rst);
    rst       <= '0';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    
    en        <='1';
    wait for 1 us;
    wait until falling_edge(clk);

    instruction <= "000101101001" & "00001" & "000" & "00000" & C_OPCODE_OP_IMM;
    wait until falling_edge(clk);
    check(immediate_int = 16#169#, "Random immediate value failed");

    instruction <= "011111111111" & "01111" & "000" & "00010" & C_OPCODE_OP_IMM;
    wait until falling_edge(clk);
    check(immediate_int = 16#7FF#, "Maximum immediate value failed");

    instruction <= "100000000000" & "01111" & "000" & "00010" & C_OPCODE_OP_IMM;
    wait until falling_edge(clk);
    check(immediate_int = 16#FFFFF800#, "Minimum immediate value failed");

    instruction <= "111111111111" & "00011" & "000" & "00010" & C_OPCODE_OP_IMM;
    wait until falling_edge(clk);
    check(immediate_int = -1, "-1 immediate value failed");

    -- info(integer'image(to_integer(count_data)));
    -- check(to_integer(count_data) = 0, "count data not at expected value");
    wait for C_RST_WIDTH;
    info("End of test");
    test_runner_cleanup(runner);
  end process;
end testbench;

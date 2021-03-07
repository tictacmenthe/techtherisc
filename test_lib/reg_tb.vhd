library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library ttr_lib;
use ttr_lib.ttr_pkg.all;

--  A testbench has no ports.
entity reg_tb is
  generic(runner_cfg: string);
end reg_tb;

architecture testbench of reg_tb is
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
  signal reg_src1, reg_src2, reg_dest             : reg_t;
  signal write_en         : std_logic;

begin
  --  Component instantiation.
  i_dut: entity ttr_lib.ttr_registers
    generic map(
      G_XLEN => C_XLEN,
      G_NREG => C_NREG
    )
    port map (
      clk => clk,
      rst => rst,
      i_en => en,
      i_reg_src1_sel => reg_src1_sel,
      i_reg_src2_sel => reg_src2_sel,
      i_reg_dest_sel => reg_dest_sel,
      o_reg_src1 => reg_src1,
      o_reg_src2 => reg_src2,
      i_write_en => write_en,
      i_reg_dest => reg_dest
    );

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
    write_en  <= '0';

    reg_src1_sel <= 0;
    reg_src2_sel <= 0;
    reg_dest_sel <= 0;

    reg_dest  <= (others=>'0');

    rst       <= '1';
    tb_en_clk <= '0';
    do_pulse(C_RST_WIDTH, rst);
    rst       <= '0';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    
    en        <='1';
    wait for 1 us;
    wait until falling_edge(clk);

    -- 0 at reset
    for i in 0 to C_NREG-1 loop
      reg_src1_sel <= i;
      reg_src2_sel <= i;
      wait for C_CLK_PERIOD;
      verify_reg(reg_src1, 0);
      verify_reg(reg_src2, 0);
    end loop;

    -- write all registers once and read from rs1
    for i in 0 to C_NREG-1 loop
      reg_src1_sel <= i;
      reg_dest_sel <= i;
      write_en     <= '1';
      reg_dest     <= std_logic_vector(to_unsigned(i, C_XLEN));
      wait for C_CLK_PERIOD;
      verify_reg(reg_src1, i);
    end loop;
    
    -- write all registers once and read from rs2
    for i in 0 to C_NREG-1 loop
      reg_src2_sel <= i;
      reg_dest_sel <= i;
      write_en     <= '1';
      reg_dest     <= std_logic_vector(to_unsigned(i, C_XLEN));
      wait for C_CLK_PERIOD;
      verify_reg(reg_src2, i);
    end loop;
    write_en     <= '0';
    
    for i in 0 to C_NREG-1 loop
      reg_src1_sel <= i;
      reg_src2_sel <= C_NREG-1-i;
      wait for C_CLK_PERIOD;
      verify_reg(reg_src1, i);
      verify_reg(reg_src2, C_NREG-1-i);
    end loop;

    -- write all registers once reversed order
    for i in 0 to C_NREG-1 loop
      reg_dest_sel <= i;
      write_en     <= '1';
      reg_dest     <= std_logic_vector(to_unsigned(C_NREG-1-i, C_XLEN));
      wait for C_CLK_PERIOD;
    end loop;
    write_en     <= '0';
    
    -- check x0 is not written to
    reg_src1_sel <= 0;
    reg_src2_sel <= C_NREG-1;
    wait for C_CLK_PERIOD;
    verify_reg(reg_src1, 0);
    verify_reg(reg_src2, 0); -- last register should be 0 to since we wrote high to low values
    -- other regs
    for i in 1 to C_NREG-1 loop
      reg_src1_sel <= i;
      reg_src2_sel <= C_NREG-1-i;
      wait for C_CLK_PERIOD;
      verify_reg(reg_src1, C_NREG-1-i);
      -- verify_reg(reg_src2, i);
    end loop;

    -- info(integer'image(to_integer(count_data)));
    -- check(to_integer(count_data) = 0, "count data not at expected value");
    wait for C_RST_WIDTH;
    info("End of test");
    test_runner_cleanup(runner);
  end process;
end testbench;

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
  -- Waits for a duration, toggles the target signal, waits again, toggles again
  procedure do_pulse(constant pulse_width : time; signal target : inout std_logic) is
  begin
    wait for pulse_width;
    target <= not target;
    wait for pulse_width;
    target <= not target;
  end procedure do_pulse;  

  function to_int(in_slv : std_logic_vector) return integer is
    variable in_int: integer := to_integer(signed(in_slv)); 
  begin
    return in_int;
  end function to_int;
  -- Internal constants
  constant C_CLK_PERIOD   : time  := 100 ns;
  constant C_RST_WIDTH    : time  := 200 ns;
  constant C_RZERO        : reg_t := (others => '0');

  -- Internal signals
  signal tb_en_clk        : std_logic;

  signal clk, rst, en     : std_logic := '0';
  signal reg_src1_sel, reg_src2_sel, reg_dest_sel : reg_sel_t;

  signal instruction    : instr_t := (others=>'0');
  signal opcode         : opcode_t;
  signal funct          : funct_t;
  signal immediate      : reg_t := (others=>'0');
  signal op_valid       : std_logic;
  signal alu_op_valid   : std_logic;
  signal alu_f          : funct_t;
  signal mem_op_valid   : std_logic;
  signal mem_direction  : std_logic;
  signal mem_unsigned   : std_logic;
  signal mem_size       : mem_size_t;

  type dut_out_t is record
    rs1_sel       : natural;
    rs2_sel       : natural;
    rd_sel        : natural;
    alu_op_valid  : std_logic;
    alu_f         : funct_t;
    mem_op_valid  : std_logic;
    mem_size      : mem_size_t;
    mem_unsigned  : std_logic;
    opcode        : opcode_t;
    immediate     : reg_t;
  end record dut_out_t;

  type dut_case_r is record
    instr  : instr_t;
    result : dut_out_t;
  end record dut_case_r;
  
  type test_array_t is array(natural range <>) of dut_case_r;
  constant test_case : test_array_t := (
    (x"169" & "00001" & "000" & "00000" & C_OPCODE_OPIMM, (1, 0, 0, '1', "0000000000", '0', "XX", 'X', C_OPCODE_OPIMM, x"00000169")),
    (x"7FF" & "11111" & "000" & "01111" & C_OPCODE_OPIMM, (31, 0, 15, '1', "0000000000", '0', "XX", 'X', C_OPCODE_OPIMM, x"000007FF")),
    (x"800" & "00001" & "000" & "00001" & C_OPCODE_OPIMM, (1, 0, 1, '1', "0000000000", '0', "XX", 'X', C_OPCODE_OPIMM, x"FFFFF800")),
    (x"FFF" & "10001" & "000" & "10000" & C_OPCODE_OPIMM, (17, 0, 16, '1', "0000000000", '0', "XX", 'X', C_OPCODE_OPIMM, x"FFFFFFFF")),
    ("0000000" & "00010" & "00001" & "000" & "00100" & C_OPCODE_OP, (1, 2, 4, '1', "0000000000", '0', "XX", 'X', C_OPCODE_OP, x"XXXXXXXX"))
  );

begin
  --  Component instantiation.
  i_dut: entity src_lib.instr_decoder
    port map (
      clk             => clk,
      rst             => rst,

      i_en            => en,
      i_instruction   => instruction,
          
      o_reg_src1_sel  => reg_src1_sel,
      o_reg_src2_sel  => reg_src2_sel,
      o_reg_dest_sel  => reg_dest_sel,
      o_alu_op_valid  => alu_op_valid,
      o_alu_f         => alu_f,
      o_mem_op_valid  => mem_op_valid,
      o_mem_size      => mem_size,
      o_mem_unsigned  => mem_unsigned,
      o_mem_direction => mem_direction,
      o_opcode        => opcode,
      o_immediate     => immediate,
      o_valid         => op_valid
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
    rst <= '1';
    test_runner_setup(runner, runner_cfg);
    info("Start of test");
    en        <= '0';

    instruction <= (others=>'0');

    rst       <= '1';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    rst       <= '0';
    en        <= '1';

    wait until rising_edge(clk);

    for i in test_case'range loop
      instruction <= test_case(i).instr;
      wait until rising_edge(clk);
    end loop;
    
    instruction <= (others=>'0');
    wait until op_valid = '0' for C_CLK_PERIOD + 1 fs;
    check_equal(op_valid, '0');

    wait for C_RST_WIDTH;

    info("End of test");
    test_runner_cleanup(runner);
  end process;


  p_check_outputs: process(clk)
    variable count   : integer := 0;
    variable imm_got : reg_t := (others=>'0');
    variable imm_exp : reg_t := (others=>'0');
  begin
    if rising_edge(clk) then
      if op_valid = '1' then
        -- check each value if possible
        if count < test_case'length then
          check_equal(reg_src1_sel, test_case(count).result.rs1_sel);
          if opcode /= C_OPCODE_OPIMM then
            check_equal(reg_src2_sel, test_case(count).result.rs2_sel);
          end if;
          check_equal(reg_dest_sel, test_case(count).result.rd_sel);
          check_equal(alu_op_valid, test_case(count).result.alu_op_valid);
          check_equal(alu_f,        test_case(count).result.alu_f);
          check_equal(mem_op_valid, test_case(count).result.mem_op_valid);
          if opcode /= C_OPCODE_OPIMM and opcode /= C_OPCODE_OP then
            check_equal(mem_size,     test_case(count).result.mem_size);
            check_equal(mem_unsigned, test_case(count).result.mem_unsigned);
          end if;
          check_equal(opcode,       test_case(count).result.opcode);
          if opcode = C_OPCODE_OPIMM then
            check_equal(immediate,    test_case(count).result.immediate);
          end if;
          end if;
        count := count + 1;

      end if;
    end if;
  end process p_check_outputs;
end testbench;

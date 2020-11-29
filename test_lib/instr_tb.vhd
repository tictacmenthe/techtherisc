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

  signal clk            : std_logic := '1';
  signal rst            : std_logic := '1';
  signal en             : std_logic := '0';
  signal reg_src1_sel, reg_src2_sel, reg_dest_sel : reg_sel_t;

  constant C_INSTR_ZERO : instr_t := (others=>'0');
  signal instruction    : instr_t := C_INSTR_ZERO;
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
    mem_direction : std_logic;
    opcode        : opcode_t;
    immediate     : reg_t;
  end record dut_out_t;

  type dut_case_r is record
    instr  : instr_t;
    result : dut_out_t;
  end record dut_case_r;
  
  type test_array_t is array(natural range <>) of dut_case_r;
  constant test_case : test_array_t := (
    (x"169" & "00001" & "000" & "00000" & C_OPCODE_OPIMM,               ( 1,  0,  0, '1', "0000000000", '0', "--", '-', '-', C_OPCODE_OPIMM, x"00000169")),
    (x"7FF" & "11111" & "000" & "01111" & C_OPCODE_OPIMM,               (31,  0, 15, '1', "0000000000", '0', "--", '-', '-', C_OPCODE_OPIMM, x"000007FF")),
    (x"800" & "00001" & "000" & "00001" & C_OPCODE_OPIMM,               ( 1,  0,  1, '1', "0000000000", '0', "--", '-', '-', C_OPCODE_OPIMM, x"FFFFF800")),
    (x"FFF" & "10001" & "000" & "10000" & C_OPCODE_OPIMM,               (17,  0, 16, '1', "0000000000", '0', "--", '-', '-', C_OPCODE_OPIMM, x"FFFFFFFF")),
    ("0000000" & "00010" & "00001" & "000" & "00100" & C_OPCODE_OP,     ( 1,  2,  4, '1', "0000000000", '0', "--", '-', '-', C_OPCODE_OP,    x"--------")),
    ("0000000" & "10100" & "11111" & "111" & "00001" & C_OPCODE_OP,     (31, 20,  1, '1', "0000000111", '0', "--", '-', '-', C_OPCODE_OP,    x"--------")),
    ("1111111" & "00000" & "00001" & "000" & "11111" & C_OPCODE_OP,     ( 1,  0, 31, '1', "1111111000", '0', "--", '-', '-', C_OPCODE_OP,    x"--------")),
    ("1111111" & "00010" & "00000" & "111" & "00111" & C_OPCODE_OP,     ( 0,  2,  7, '1', "1111111111", '0', "--", '-', '-', C_OPCODE_OP,    x"--------")),
    (x"000" & "00000" & "000" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "00", '0', '0', C_OPCODE_LOAD,  x"00000000")),
    (x"001" & "00000" & "001" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "01", '0', '0', C_OPCODE_LOAD,  x"00000001")),
    (x"7FF" & "00000" & "010" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "10", '0', '0', C_OPCODE_LOAD,  x"000007FF")),
    (x"FFF" & "00000" & "100" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "00", '1', '0', C_OPCODE_LOAD,  x"FFFFFFFF")),
    (x"ABA" & "00000" & "101" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "01", '1', '0', C_OPCODE_LOAD,  x"FFFFFABA")),
    (x"FAC" & "00000" & "110" & "00111" & C_OPCODE_LOAD,                ( 0,  2,  7, '0', "----------", '1', "10", '1', '0', C_OPCODE_LOAD,  x"FFFFFFAC")),
    ("1010101" & "00010" & "00000" & "110" & "01010" & C_OPCODE_STORE,  ( 0,  2,  7, '0', "----------", '1', "10", '1', '1', C_OPCODE_STORE, x"FFFFFAAA")),
    ("0000101" & "11111" & "01010" & "110" & "01010" & C_OPCODE_STORE,  (10, 31,  7, '0', "----------", '1', "10", '1', '1', C_OPCODE_STORE, x"000000AA")),
    ("0111111" & "11111" & "01010" & "110" & "11111" & C_OPCODE_STORE,  (10, 31,  7, '0', "----------", '1', "10", '1', '1', C_OPCODE_STORE, x"000007FF"))
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
      clk <= '1';
      wait until tb_en_clk = '1';
    end if;
  end process p_clk_rst;
  
  -- TB process
  p_tb_main: process
  begin
    rst <= '1';
    test_runner_setup(runner, runner_cfg);
    -- show(get_logger(default_checker), display_handler, pass);
    info("Start of test");
    en        <= '0';

    instruction <= C_INSTR_ZERO;

    rst       <= '1';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    rst       <= '0';
    en        <= '1';

    wait until rising_edge(clk);

    for i in test_case'range loop
      instruction <= test_case(i).instr;
      info("Write number " & to_string(i));
      wait until rising_edge(clk);
    end loop;
    
    instruction <= C_INSTR_ZERO;
    info("Write null instruction");
    wait until rising_edge(clk);
  
    en        <= '0';
    wait for C_RST_WIDTH;
    info("Tested " & integer'image(test_case'length) & " cases.");

    info("End of test");
    test_runner_cleanup(runner);
  end process;

  p_check_outputs: process(clk)
    variable count   : integer := 0;
  begin
    if rising_edge(clk) then
      if op_valid = '1' then
        -- check each value if possible
        if count < test_case'length then
          info("Read output from decoder: " & to_string(count));
          check_equal(reg_src1_sel, test_case(count).result.rs1_sel, result("for rs1"));
          if opcode = C_OPCODE_OP or opcode = C_OPCODE_STORE then
            check_equal(reg_src2_sel, test_case(count).result.rs2_sel, result("for rs2"));
          end if;
          if opcode /= C_OPCODE_STORE then
            check_equal(reg_dest_sel, test_case(count).result.rd_sel, result("for rd"));
          end if;
          check_match(alu_op_valid,   test_case(count).result.alu_op_valid, result("for aluopvalid"));
          check_match(alu_f,          test_case(count).result.alu_f, result("for alu_f"));
          check_match(mem_op_valid,   test_case(count).result.mem_op_valid, result("for memopvalid"));
          check_match(mem_size,       test_case(count).result.mem_size, result("for mem_size"));
          check_match(mem_unsigned,   test_case(count).result.mem_unsigned, result("for mem_unsigned"));
          check_match(mem_direction,  test_case(count).result.mem_direction, result("for mem_dir"));
          check_match(opcode,         test_case(count).result.opcode, result("for opcode"));
          check_match(immediate,      test_case(count).result.immediate, result("for imm"));
        end if;
        count := count + 1;
      else
        check_equal(alu_op_valid, '0', result("for no alu op valid if no op valid"));
        check_equal(mem_op_valid, '0', result("for no mem op valid if no op valid"));
      end if;
    end if;
  end process p_check_outputs;
end testbench;

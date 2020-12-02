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
entity alu_tb is
  generic(runner_cfg: string);
end alu_tb;

architecture testbench of alu_tb is
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
  signal reg_src1_sel, reg_src2_sel         : reg_sel_t;
  signal reg_dest_sel_alu, reg_dest_sel_dec : reg_sel_t;

  signal opcode         : opcode_t;
  signal funct          : funct_t;
  signal immediate      : reg_t := (others=>'0');
  signal src1_data      : reg_t := (others=>'0');
  signal src2_data      : reg_t := (others=>'0');
  signal dest_result    : reg_t := (others=>'0');
  signal write_en       : std_logic;

  signal pc_current     : reg_t := (others=>'0');
  signal alu_f          : funct_t;

  type dut_in_t is record
    opcode        : opcode_t;
    alu_f         : funct_t;
    immediate     : reg_t;
    src1_data     : reg_t;
    src2_data     : reg_t;
    pc_current    : reg_t;
    reg_dest_sel  : natural;
  end record dut_in_t;

  type dut_out_t is record
    reg_dest_sel  : natural;
    dest_result   : reg_t;
  end record dut_out_t;

  type dut_case_r is record
    inputs  : dut_in_t;
    outputs : dut_out_t;
  end record dut_case_r;

  type test_array_t is array(natural range <>) of dut_case_r;
  -- Big fat array of test cases for ALU operations
  constant test_case : test_array_t := (
    -- ADDI: signed immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_ADD_SUB,  x"00000010", x"0000001F", x"00000000", x"00000000",  1), ( 1, x"0000002F")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_ADD_SUB,  x"00000001", x"FFFFFFFF", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_ADD_SUB,  x"00000001", x"FFFFFFFF", x"00000000", x"00000000", 15), (15, x"00000000")),
    -- SLTI : dest = 1 if signed rs1 strictly lower than signed immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"2A5A5A5A", x"1A5A5A5A", x"BABABABA", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"2A5A5A5A", x"1A5A5A5A", x"00000000", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"FA5A5A5A", x"1A5A5A5A", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"2A5A5A5A", x"1A5A5A5A", x"00000000", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"00000001", x"00000000", x"00000000", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"00000001", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"00000000", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLT,  x"7FFFFFFF", x"0FFFFFFF", x"00000000", x"00000000",  1), ( 1, x"00000001")),
    -- SLTIU : dest = 1 if unsigned rs1 strictly lower than unsigned (but sign extended immediate)
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLTU, x"00000000", x"00000000", x"00000000", x"00000000", 1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLTU, x"00000001", x"00000000", x"00000000", x"00000000", 1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLTU, x"00000001", x"00000001", x"00000000", x"00000000", 1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLTU, x"FFFFFFFF", x"00000000", x"00000000", x"00000000", 1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLTU, x"FA5A5A5A", x"1A5A5A5A", x"00000000", x"00000000", 1), ( 1, x"00000001")),
    -- ANDI : dest = rs1 and sign extended immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_AND,  x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_AND,  x"A5A5A5A5", x"00000000", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_AND,  x"A0A0A0A0", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A0A0A0A0")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_AND,  x"00000505", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"00000505")),
    -- ORI : dest = rs1 or sign extended immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_OR,   x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_OR,   x"A5A5A5A5", x"00000000", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_OR,   x"A0A0A0A0", x"05050505", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_OR,   x"00000505", x"A5A50000", x"00000000", x"00000000",  1), ( 1, x"A5A50505")),
    -- XORI : dest = rs1 xor sign extended immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_XOR,  x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_XOR,  x"A5A5A5A5", x"00000000", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_XOR,  x"FFFFFFFF", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"5A5A5A5A")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_XOR,  x"05050505", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A0A0A0A0")),
    -- SLLI : logical left shift by immediate
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLL,  x"00000001", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000002")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLL,  x"0000001F", x"00000001", x"00000000", x"00000000",  1), ( 1, x"80000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLL,  x"00000001", x"AAAAAAAA", x"00000000", x"00000000",  1), ( 1, x"55555554")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SLL,  x"00000002", x"55555555", x"00000000", x"00000000",  1), ( 1, x"55555554")),
    -- SRLI : logical right shift by immediate (as unsigned)
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000001", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000001", x"80000000", x"00000000", x"00000000",  1), ( 1, x"40000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"0000001F", x"80000000", x"00000000", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000001", x"AAAAAAAA", x"00000000", x"00000000",  1), ( 1, x"55555555")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000002", x"55555555", x"00000000", x"00000000",  1), ( 1, x"15555555")),
    -- SRAI : arthmetic right shift by immediate (as signed) if bit 10 of immediate is '1'
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000401", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000401", x"80000000", x"00000000", x"00000000",  1), ( 1, x"C0000000")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"0000041F", x"80000000", x"00000000", x"00000000",  1), ( 1, x"FFFFFFFF")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000401", x"AAAAAAAA", x"00000000", x"00000000",  1), ( 1, x"D5555555")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000402", x"55555555", x"00000000", x"00000000",  1), ( 1, x"15555555")),
    ((C_OPCODE_OPIMM, "0000000" & C_FUNCT3_SR,   x"00000402", x"D5555555", x"00000000", x"00000000",  1), ( 1, x"F5555555")),
    -- LUI : Load upper immediate 
    ((C_OPCODE_LUI,   "0000000000",              x"AAAAAAAA", x"00000000", x"00000000", x"00000000",  1), ( 1, x"AAAAA000")),
    ((C_OPCODE_LUI,   "0000000000",              x"55555555", x"00000000", x"00000000", x"00000000",  1), ( 1, x"55555000")),
    -- LUI : Load upper immediate
    ((C_OPCODE_AUIPC, "0000000000",              x"AAAAAAAA", x"00000000", x"00000000", x"00000000",  1), ( 1, x"AAAAA000")),
    ((C_OPCODE_AUIPC, "0000000000",              x"AAAAAAAA", x"00000000", x"00000000", x"00000AAA",  1), ( 1, x"AAAAAAAA")),
    ((C_OPCODE_AUIPC, "0000000000",              x"55555555", x"00000000", x"00000000", x"00000123",  1), ( 1, x"55555123")),
    ((C_OPCODE_AUIPC, "0000000000",              x"55555555", x"00000000", x"00000000", x"00000555",  1), ( 1, x"55555555")),
    ((C_OPCODE_AUIPC, "0000000000",              x"00000001", x"00000000", x"00000000", x"FFFFF123",  1), ( 1, x"00000123")),
    
    -- ADD signed registers
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_ADD_SUB, x"00000000", x"0000001F", x"00000010", x"00000000",  1), ( 1, x"0000002F")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_ADD_SUB, x"00000000", x"FFFFFFFF", x"00000001", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_ADD_SUB, x"00000000", x"FFFFFFFF", x"00000001", x"00000000", 15), (15, x"00000000")),
    -- SUB signed registers
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_ADD_SUB, x"00000000", x"0000001F", x"00000010", x"00000000",  1), ( 1, x"0000000F")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_ADD_SUB, x"00000000", x"FFFFFFFF", x"00000001", x"00000000",  1), ( 1, x"FFFFFFFE")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_ADD_SUB, x"00000000", x"00000001", x"FFFFFFFF", x"00000000",  1), ( 1, x"00000002")),

    -- SLTI : dest = 1 if signed rs1 strictly lower than signed immediate
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"1A5A5A5A", x"2A5A5A5A", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"1A5A5A5A", x"2A5A5A5A", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"1A5A5A5A", x"FA5A5A5A", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"1A5A5A5A", x"2A5A5A5A", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"00000000", x"00000001", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"00000001", x"00000001", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"00000001", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLT,  x"00000000", x"0FFFFFFF", x"7FFFFFFF", x"00000000",  1), ( 1, x"00000001")),
    -- SLTIU : dest = 1 if unsigned rs1 strictly lower than unsigned (but sign extended immediate)
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLTU, x"00000000", x"00000000", x"00000000", x"00000000", 1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLTU, x"00000000", x"00000000", x"00000001", x"00000000", 1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLTU, x"00000000", x"00000001", x"00000001", x"00000000", 1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLTU, x"00000000", x"00000000", x"FFFFFFFF", x"00000000", 1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLTU, x"00000000", x"1A5A5A5A", x"FA5A5A5A", x"00000000", 1), ( 1, x"00000001")),
    -- ANDI : dest = rs1 and sign extended immediate
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_AND,  x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_AND,  x"00000000", x"00000000", x"A5A5A5A5", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_AND,  x"00000000", x"A5A5A5A5", x"A0A0A0A0", x"00000000",  1), ( 1, x"A0A0A0A0")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_AND,  x"00000000", x"A5A5A5A5", x"00000505", x"00000000",  1), ( 1, x"00000505")),
    -- ORI : dest = rs1 or sign extended immediate
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_OR,   x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_OR,   x"00000000", x"00000000", x"A5A5A5A5", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_OR,   x"00000000", x"05050505", x"A0A0A0A0", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_OR,   x"00000000", x"A5A50000", x"00000505", x"00000000",  1), ( 1, x"A5A50505")),
    -- XORI : dest = rs1 xor sign extended immediate
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_XOR,  x"00000000", x"A5A5A5A5", x"00000000", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_XOR,  x"00000000", x"00000000", x"A5A5A5A5", x"00000000",  1), ( 1, x"A5A5A5A5")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_XOR,  x"00000000", x"A5A5A5A5", x"FFFFFFFF", x"00000000",  1), ( 1, x"5A5A5A5A")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_XOR,  x"00000000", x"A5A5A5A5", x"05050505", x"00000000",  1), ( 1, x"A0A0A0A0")),
    -- SLLI : logical left shift by immediate
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLL,  x"00000000", x"00000001", x"00000001", x"00000000",  1), ( 1, x"00000002")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLL,  x"00000000", x"00000001", x"0000001F", x"00000000",  1), ( 1, x"80000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLL,  x"00000000", x"AAAAAAAA", x"00000001", x"00000000",  1), ( 1, x"55555554")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SLL,  x"00000000", x"55555555", x"00000002", x"00000000",  1), ( 1, x"55555554")),
    -- SRLI : logical right shift by immediate (as unsigned)
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SR,   x"00000000", x"00000001", x"00000001", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SR,   x"00000000", x"80000000", x"00000001", x"00000000",  1), ( 1, x"40000000")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SR,   x"00000000", x"80000000", x"0000001F", x"00000000",  1), ( 1, x"00000001")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SR,   x"00000000", x"AAAAAAAA", x"00000001", x"00000000",  1), ( 1, x"55555555")),
    ((C_OPCODE_OP, "0000000" & C_FUNCT3_SR,   x"00000000", x"55555555", x"00000002", x"00000000",  1), ( 1, x"15555555")),
    -- SRAI : arthmetic right shift by immediate (as signed) if bit 10 of immediate is '1'
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"00000001", x"00000001", x"00000000",  1), ( 1, x"00000000")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"80000000", x"00000001", x"00000000",  1), ( 1, x"C0000000")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"80000000", x"0000001F", x"00000000",  1), ( 1, x"FFFFFFFF")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"AAAAAAAA", x"00000001", x"00000000",  1), ( 1, x"D5555555")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"55555555", x"00000002", x"00000000",  1), ( 1, x"15555555")),
    ((C_OPCODE_OP, "0100000" & C_FUNCT3_SR,   x"00000000", x"D5555555", x"00000002", x"00000000",  1), ( 1, x"F5555555"))
  );
begin
  --  Component instantiation.
  i_dut: entity ttr_lib.ttr_alu
    port map (
      clk             => clk,
      rst             => rst,

      i_en            => en,

      i_opcode        => opcode,
      i_alu_f         => alu_f,
      i_immediate     => immediate,

      i_pc_current    => pc_current,

      i_src1_data     => src1_data,
      i_src2_data     => src2_data,
      i_reg_dest_sel  => reg_dest_sel_dec,
      o_reg_dest_sel  => reg_dest_sel_alu,
      o_dest_result   => dest_result,
      o_write_en      => write_en
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

    opcode    <= (others=>'0');
    alu_f     <= (others=>'0');
    reg_dest_sel_dec<= 0;

    rst       <= '1';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    rst       <= '0';
    en        <= '1';

    wait until rising_edge(clk);

    for i in test_case'range loop
      opcode            <= test_case(i).inputs.opcode;
      alu_f             <= test_case(i).inputs.alu_f;
      immediate         <= test_case(i).inputs.immediate;
      src1_data         <= test_case(i).inputs.src1_data;
      src2_data         <= test_case(i).inputs.src2_data;
      pc_current        <= test_case(i).inputs.pc_current;
      reg_dest_sel_dec  <= test_case(i).inputs.reg_dest_sel;
      info("Write number " & to_string(i+1) & "/" & to_string(test_case'length));
      wait until rising_edge(clk);
    end loop;

    opcode    <= (others=>'0');
    alu_f     <= (others=>'0');
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
      if write_en = '1' then
        -- check each value if possible
        if count < test_case'length then
          info("Read output from ALU: " & to_string(count+1) & "/" & to_string(test_case'length));
          check_equal(dest_result, test_case(count).outputs.dest_result, result("for alu result"));
          check_equal(reg_dest_sel_alu, test_case(count).outputs.reg_dest_sel, result("for dest sel"));
        end if;
        count := count + 1;
      end if;
    end if;
  end process p_check_outputs;
end testbench;

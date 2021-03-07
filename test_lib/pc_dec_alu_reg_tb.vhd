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
entity pc_dec_alu_reg_tb is
  generic(runner_cfg: string);
end pc_dec_alu_reg_tb;

architecture testbench of pc_dec_alu_reg_tb is
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
  signal pc_en          : std_logic := '0';
  signal pc_en_complete : std_logic := '0';
  signal dec_en         : std_logic := '0';
  signal alu_en         : std_logic := '0';
  signal reg_en         : std_logic := '0';
  signal alu_op_valid   : std_logic := '0';
  signal mem_op_valid   : std_logic := '0';
  signal op_valid       : std_logic := '0';
  signal decoded_branch : std_logic := '0';

  -- Decode
  signal reg_src1_sel, reg_src2_sel         : reg_sel_t;
  signal reg_dest_sel_alu, reg_dest_sel_dec : reg_sel_t;
  signal opcode         : opcode_t;
  signal funct          : funct_t;
  signal immediate      : reg_t := (others=>'0');
  signal src1_data      : reg_t := (others=>'0');
  signal src2_data      : reg_t := (others=>'0');
  signal dest_result    : reg_t := (others=>'0');
  signal write_en       : std_logic;
  signal dest_write_en  : std_logic;
  signal alu_f          : funct_t;
  
  signal mem_size       : mem_size_t;
  signal mem_unsigned   : std_logic;
  signal mem_direction  : std_logic;
  
  signal pc_write_en    : std_logic;
  signal pc_current     : reg_t := (others=>'0');
  signal pc_4byte       : reg_t := (others=>'0'); -- PC divided by 4
  signal pc_new         : reg_t := (others=>'0');

  type instr_rom_t is array(0 to 31) of instr_t;
  constant instr_rom : instr_rom_t := (
    std_logic_vector'(x"001" & "00000" & C_FUNCT3_ADD_SUB & "00001" & C_OPCODE_OPIMM),
    std_logic_vector'(x"002" & "00000" & C_FUNCT3_ADD_SUB & "00010" & C_OPCODE_OPIMM),
    std_logic_vector'(x"003" & "00000" & C_FUNCT3_ADD_SUB & "00011" & C_OPCODE_OPIMM),
    std_logic_vector'(x"000" & "00001" & C_FUNCT3_ADD_SUB & "00010" & C_OPCODE_OPIMM),
    std_logic_vector'(x"7FF" & "11111" & C_FUNCT3_ADD_SUB & "01111" & C_OPCODE_OPIMM),
    std_logic_vector'(x"800" & "00001" & C_FUNCT3_ADD_SUB & "00001" & C_OPCODE_OPIMM),
    std_logic_vector'(x"FFF" & "10001" & C_FUNCT3_ADD_SUB & "10000" & C_OPCODE_OPIMM),
    others  =>  "00000000000000000000000000000000"
  );
begin
    
  --  PC UNIT
  i_dut_pc: entity ttr_lib.ttr_pcunit
    port map (
      clk         => clk,
      rst         => rst,
      i_en        => pc_en,

      i_write_en  => pc_write_en,
      i_pc_wr     => pc_new,
      
      o_pc        => pc_current
    );
    
    pc_4byte <= std_logic_vector(shift_right(unsigned(pc_current), 2)) when (pc_en = '1') else (others=>'0');
    
  --  Instruction Decoder
  i_dut_dec: entity ttr_lib.ttr_decoder
    port map (
      clk             => clk,
      rst             => rst,

      i_en            => dec_en,
      i_instruction   => instr_rom(to_integer(unsigned(pc_4byte))),
          
      o_reg_src1_sel  => reg_src1_sel,
      o_reg_src2_sel  => reg_src2_sel,
      o_reg_dest_sel  => reg_dest_sel_dec,
      o_alu_op_valid  => alu_op_valid,
      o_alu_f         => alu_f,
      o_mem_op_valid  => mem_op_valid,
      o_mem_size      => mem_size,
      o_mem_unsigned  => mem_unsigned,
      o_mem_direction => mem_direction,
      o_op_branch     => decoded_branch,
      o_opcode        => opcode,
      o_immediate     => immediate,
      o_valid         => op_valid
    );
  
    --  Registers
  i_dut: entity ttr_lib.ttr_registers
    generic map(
      G_XLEN => C_XLEN,
      G_NREG => C_NREG
    )
    port map (
      clk => clk,
      rst => rst,
      i_en => reg_en,
      i_reg_src1_sel => reg_src1_sel,
      i_reg_src2_sel => reg_src2_sel,
      i_reg_dest_sel => reg_dest_sel_alu,
      o_reg_src1 => src1_data,
      o_reg_src2 => src2_data,
      i_write_en => dest_write_en,
      i_reg_dest => dest_result
    );
  
    --  ALU
  i_dut_alu: entity ttr_lib.ttr_alu
    port map (
      clk             => clk,
      rst             => rst,

      i_en            => alu_en,

      i_opcode        => opcode,
      i_alu_f         => alu_f,
      i_immediate     => immediate,

      i_pc_current    => pc_current,

      i_src1_data     => src1_data,
      i_src2_data     => src2_data,
      i_reg_dest_sel  => reg_dest_sel_dec,
      o_reg_dest_sel  => reg_dest_sel_alu,
      o_dest_result   => dest_result,
      o_write_en      => dest_write_en
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
    pc_en   <= '0';
    dec_en  <= '0';
    alu_en  <= '0';
    reg_en  <= '0';


    rst       <= '1';
    tb_en_clk <= '1';
    do_pulse(C_RST_WIDTH, rst);
    rst     <= '0';
    pc_en   <= '1';
    dec_en  <= '1';
    alu_en  <= '0';
    reg_en  <= '0';
    
    wait until rising_edge(clk);
    alu_en <= '1';
    reg_en <= '1';

    for i in 0 to instr_rom'high-2 loop
      info("Write number " & to_string(i+1) & "/" & to_string(instr_rom'length));
      wait until rising_edge(clk);
    end loop;

    pc_en   <= '0';
    dec_en  <= '0';
    alu_en  <= '0';
    reg_en  <= '0';
    wait for C_RST_WIDTH;
    info("Tested " & integer'image(instr_rom'length) & " cases.");

    info("End of test");
    test_runner_cleanup(runner);
  end process;

  p_check_outputs: process(clk)
    variable count   : integer := 0;
  begin
    if rising_edge(clk) then
      if write_en = '1' then
        -- check each value if possible
        if count < instr_rom'length then
          info("Read output from ALU: " & to_string(count+1) & "/" & to_string(instr_rom'length));
        end if;
        count := count + 1;
      end if;
    end if;
  end process p_check_outputs;
end testbench;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library src_lib;
use src_lib.ttr_pkg.all;
use src_lib.utility_pkg.all;

entity instr_decoder is
  port(
    clk             : in  std_logic;  -- system clock
    rst             : in  std_logic;  -- active high reset
    
    i_en            : in  std_logic;  -- if '0', ignores all inputs and prevents outputs
    i_instruction   : in  instr_t;    -- instruction to decode
    
    -- Register selection
    o_reg_src1_sel  : out reg_sel_t;  -- source register 1 selection
    o_reg_src2_sel  : out reg_sel_t;  -- source register 2 selection
    o_reg_dest_sel  : out reg_sel_t;  -- destination register selection

    -- ALU
    o_alu_op_valid  : out std_logic;  -- an ALU operation needs to be executed
    o_alu_f         : out funct_t;    -- ALU function code
    
    -- MEMORY
    o_mem_op_valid  : out std_logic; 
    o_mem_size      : out mem_size_t; -- 0 = byte, 1 = half word, 2 = word
    o_mem_unsigned  : out std_logic;  -- 0 = sign extension on byte/half word loads
    o_mem_direction : out std_logic;  -- 0 = load, 1 = store

    o_opcode        : out opcode_t;   -- last valid opcode
    o_immediate     : out reg_t;      -- last extracted immediate value
    o_valid         : out std_logic   -- output data is available and valid. 1 cycle pulse
                                      -- no pulse on instructions not requiring external action (memory order)      
  );
end entity instr_decoder;

architecture rtl of instr_decoder is
  -- internal constants
  constant C_FUNC7_ZERO : std_logic_vector(C_FUNCT7_W-1 downto 0) := (others=>'0');

  -- fixed position aliases
  alias opcode_i    : std_logic_vector(C_OPCODE_W-1 downto 0) is i_instruction(R_OPCODE);
  alias reg_dest_i  : std_logic_vector(C_RDEST_W-1  downto 0) is i_instruction(R_RDEST);
  alias reg_src2_i  : std_logic_vector(C_RSRC2_W-1  downto 0) is i_instruction(R_RSRC2);
  alias reg_src1_i  : std_logic_vector(C_RSRC1_W-1  downto 0) is i_instruction(R_RSRC1);
  alias funct3_i    : std_logic_vector(C_FUNCT3_W-1 downto 0) is i_instruction(R_FUNCT3);
  alias funct7_i    : std_logic_vector(C_FUNCT7_W-1 downto 0) is i_instruction(R_FUNCT7);

begin
  -- Main synchronous process
  p_sync_update: process(clk, rst)
  begin
    if rst = '1' then
      o_valid         <= '0';
      
      o_opcode        <= (others=>'0');
      o_reg_src2_sel  <=  0;
      o_reg_dest_sel  <=  0;
      o_reg_src1_sel  <=  0;

      o_alu_op_valid  <= '0';
      o_alu_f         <= (others=>'0');
      o_immediate     <= (others=>'0');

      o_mem_op_valid  <= '0';
      o_mem_size      <= (others=>'0');
      o_mem_unsigned  <= '0';
      o_mem_direction <= C_MEM_LOAD;
    elsif rising_edge(clk) then

      if i_en = '1' then
        o_alu_op_valid  <= '0';
        o_mem_op_valid  <= '0';
        o_valid         <= '1'; --enabled by default
        o_opcode        <=  opcode_i;
        o_reg_src1_sel  <=  to_integer(unsigned(reg_src1_i(R_REG)));
        o_reg_src2_sel  <=  to_integer(unsigned(reg_src2_i(R_REG)));
        o_reg_dest_sel  <=  to_integer(unsigned(reg_dest_i(R_REG)));

        case opcode_i is
          when C_OPCODE_OPIMM =>
            o_alu_op_valid  <= '1';
            o_alu_f         <= C_FUNC7_ZERO & funct3_i;
            o_immediate     <=  resize_slv(i_instruction(R_IMM_I), C_XLEN);

          when C_OPCODE_LUI|C_OPCODE_AUIPC  =>
            o_alu_op_valid  <= '1';
            o_immediate <=  i_instruction(R_IMM_U) & x"000";

          when C_OPCODE_OP    =>
            o_alu_op_valid  <= '1'; 
            o_alu_f         <=  funct7_i & funct3_i;

          when C_OPCODE_JAL       => 
            o_immediate <=  resize_slv(
                            i_instruction(R_IMM_J_3) & i_instruction(R_IMM_J_2) &
                            i_instruction(R_IMM_J_1) & i_instruction(R_IMM_J_0) & '0'
                          , C_XLEN);

          when C_OPCODE_JALR      => 
            o_alu_f     <= (others=>'0');
            o_immediate <= resize_slv(i_instruction(R_IMM_I), C_XLEN);

          when C_OPCODE_BRANCH    =>
            o_alu_f     <= C_FUNC7_ZERO & funct3_i;
            o_immediate <=  resize_slv(
                            i_instruction(R_IMM_B_3) & i_instruction(R_IMM_B_2) &
                            i_instruction(R_IMM_B_1) & i_instruction(R_IMM_B_0) & '0'
                          , C_XLEN);

          when C_OPCODE_LOAD      =>
            o_mem_op_valid  <= '1';
            o_mem_direction <= '0';
            o_mem_unsigned  <= funct3_i(funct3_i'high);
            o_mem_size      <= funct3_i(R_MEM_FUNC_SIZE);
            o_immediate     <= resize_slv(i_instruction(R_IMM_I), C_XLEN);

          when C_OPCODE_STORE     => 
            o_mem_op_valid  <= '1';
            o_mem_direction <= '1';
            o_mem_size      <= funct3_i(R_MEM_FUNC_SIZE);
            o_immediate     <= resize_slv(i_instruction(R_IMM_S_1) & i_instruction(R_IMM_S_0), C_XLEN);

          when C_OPCODE_MISCMEM  => -- doesn't do anything here, since there is no ordering option
            o_valid   <= '0';

          when C_OPCODE_SYSTEM   => -- not implemented
            o_valid   <= '0';

          when others =>            -- invalid opcode
            o_valid   <= '0';
        end case;
      end if;
    end if;
  end process p_sync_update;
end architecture rtl;
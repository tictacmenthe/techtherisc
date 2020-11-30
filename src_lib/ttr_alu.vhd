library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library src_lib;
use src_lib.ttr_pkg.all;
use src_lib.utility_pkg.all;

entity ttr_alu is
  port(
    clk             : in  std_logic;  -- system clock
    rst             : in  std_logic;  -- active high reset
    
    i_en            : in  std_logic;  -- if '0', ignores all inputs and disables output

    -- Instruction to execute
    i_opcode        : in  opcode_t;   -- decoded opcode
    i_alu_f         : in  funct_t;    -- ALU function code
    i_immediate     : in  reg_t;      -- extracted immediate value
    
    -- Register data
    i_pc_to_write   : in  reg_t;      -- PC value to write if needed
    i_src1_data     : in  reg_t;      -- register src1 data
    i_src2_data     : in  reg_t;      -- register src2 data
    i_reg_dest_sel  : in  reg_sel_t;  -- destination register selection from decoder
    o_reg_dest_sel  : out reg_sel_t;  -- destination register selection to registers
    o_dest_result   : out reg_t;      -- destination register data to write
    o_write_en      : out std_logic   -- write enable on destination register
  );
end entity ttr_alu;

architecture rtl of ttr_alu is
  alias funct3_i    : std_logic_vector(C_FUNCT3_W-1 downto 0) is i_alu_f(C_FUNCT3_W-1 downto 0);
  alias funct7_i    : std_logic_vector(C_FUNCT7_W-1 downto 0) is i_alu_f(i_alu_f'high downto C_FUNCT3_W);
begin
  -- Main synchronous process
  p_sync_update: process(clk, rst)
  begin
    if rst = '1' then
      o_reg_dest_sel  <=  0;
      o_dest_result   <=  (others=>'0');
      o_write_en      <=  '0';
    elsif rising_edge(clk) then
      o_write_en    <= '0';

      if i_en = '1' then
        o_reg_dest_sel  <=  i_reg_dest_sel;

        case i_opcode is
          when C_OPCODE_OPIMM =>
            case funct3_i is
              when C_FUNCT3_OPIMM_ADDI =>
                o_write_en    <= '1';
                o_dest_result <= std_logic_vector(resize(signed(i_src1_data) + signed(i_immediate), C_XLEN));
              when others =>

            end case;
          when C_OPCODE_LUI|C_OPCODE_AUIPC  =>

          when C_OPCODE_OP    =>
          
          when C_OPCODE_JAL       => 
          
          when C_OPCODE_JALR      => 

          when C_OPCODE_BRANCH    =>

          when C_OPCODE_SYSTEM   =>

          when others =>            -- invalid opcode

        end case;
      end if;
    end if;
  end process p_sync_update;
end architecture rtl;
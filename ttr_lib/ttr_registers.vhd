library ieee;
use ieee.std_logic_1164.all;

entity ttr_registers is
  generic(
    G_XLEN : positive := 32; -- register bit width
    G_NREG : positive := 32  -- number of registers (excluding PC)
  );
  port(
    clk           : in  std_logic;                            -- system clock
    rst           : in  std_logic;                            -- active high reset
    i_en          : in  std_logic;                            -- if '0', ignores all inputs and keeps outputs constant

    i_reg_src1_sel: in  integer range 0 to G_NREG-1;  -- source register 1 selection
    i_reg_src2_sel: in  integer range 0 to G_NREG-1;  -- source register 2 selection
    i_reg_dest_sel: in  integer range 0 to G_NREG-1;  -- destination register selection

    o_reg_src1    : out std_logic_vector(G_XLEN-1 downto 0);  -- value output from source register 1
    o_reg_src2    : out std_logic_vector(G_XLEN-1 downto 0);  -- value output from source regsiter 2

    i_write_en    : in  std_logic;                            -- enable write to destination register
    i_reg_dest    : in  std_logic_vector(G_XLEN-1 downto 0)   -- value to write to destination register
  );
end entity ttr_registers;

architecture rtl of ttr_registers is
  type xregs_t is array(0 to G_NREG-1) of std_logic_vector(G_XLEN-1 downto 0);
  constant C_RZERO : std_logic_vector(G_XLEN-1 downto 0) := (others=>'0');
  signal xregs : xregs_t;
begin
  p_sync_update: process(clk, rst)
  begin
    if rst = '1' then
      xregs <= (others=>C_RZERO);
      o_reg_src1 <= C_RZERO;
      o_reg_src2 <= C_RZERO;
    elsif rising_edge(clk) then
      if i_en = '1' then
        o_reg_src1 <= xregs(i_reg_src1_sel);
        o_reg_src2 <= xregs(i_reg_src2_sel);
        if i_write_en = '1' and i_reg_dest_sel > 0 then
          xregs(i_reg_dest_sel) <= i_reg_dest;
          if i_reg_src1_sel = i_reg_dest_sel then
            o_reg_src1 <= i_reg_dest;
          end if;
          if i_reg_src2_sel = i_reg_dest_sel then
            o_reg_src2 <= i_reg_dest;
          end if;
        end if;
        xregs(0) <= C_RZERO;
      end if;
    end if;
  end process p_sync_update;
end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ttr_lib;
use ttr_lib.ttr_pkg.all;
use ttr_lib.utility_pkg.all;

entity ttr_pcunit is
  generic(
    G_XLEN : positive := 32 -- register bit width
  );
  port(
    clk           : in  std_logic;  -- system clock
    rst           : in  std_logic;  -- active high reset
    i_en          : in  std_logic;  -- if '0', ignores all inputs and keeps outputs constant

    i_write_en    : in  std_logic;  -- enable write to PC value
    i_pc_wr       : in  reg_t;      -- value to write to PC count
    
    o_pc          : out reg_t       -- value output of current PC
  );
end entity ttr_pcunit;

architecture rtl of ttr_pcunit is
  signal pc_i : reg_t;
begin
  
  o_pc <= pc_i;
  
  p_sync_update: process(clk, rst)
  begin
    if rst = '1' then
      pc_i  <=  (others=>'0');
    elsif rising_edge(clk) then
      if i_en = '1' then
        if i_write_en = '1' then
          pc_i  <=  i_pc_wr;
        else
          pc_i  <=  std_logic_vector(unsigned(pc_i) + 4);
        end if;
      end if;
    end if;
  end process p_sync_update;
end architecture rtl;

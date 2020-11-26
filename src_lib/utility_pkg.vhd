library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package utility_pkg is
  function resize_slv(old_slv: std_logic_vector; constant new_size: natural) return std_logic_vector;
end package utility_pkg;

package body utility_pkg is
  function resize_slv(old_slv: std_logic_vector; constant new_size: natural) return std_logic_vector
  is
    variable new_slv : std_logic_vector(new_size-1 downto 0):=std_logic_vector(resize(signed(old_slv), new_size));
  begin
    return new_slv;
  end function resize_slv;
end package body utility_pkg;
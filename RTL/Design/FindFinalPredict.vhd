library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

package findFinalPredict is
  function find_max_index(
    x : in bram_data_array(0 to 32)
  ) return std_logic_vector;

end package findFinalPredict;

package body findFinalPredict is

  function find_max_index(
    x : in bram_data_array(0 to 32)
  ) return std_logic_vector is
    variable max_val   : unsigned(7 downto 0) := (others => '0');
    variable max_index : std_logic_vector(7 downto 0) := (others => '0');
  begin
    --  Iterate over all 33 elements.
    for i in 0 to 32 loop
      if unsigned(x(i)) > max_val then
        max_val   := unsigned(x(i));
        max_index := std_logic_vector(to_unsigned(i, 8));
      end if;
    end loop;

    return max_index;
  end function find_max_index;

end package body findFinalPredict;
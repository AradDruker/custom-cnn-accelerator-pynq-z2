library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include the types package for custom type definitions
library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- Package declaration for finding kernel neighbors
-- Now ROWS and COLS are function parameters, making the function more generic.
package FindConv2Kernel is
	-- Function to compute 5x5 kernel addresses with parameterizable dimensions
	function find_conv_2_kernel (
			row_in : integer; -- Row index of the central pixel
			col_in : integer  -- Column index of the central pixel
		) return address_array_layer_2;
end FindConv2Kernel;

package body FindConv2Kernel is

	function find_conv_2_kernel (
			row_in : integer;
			col_in : integer
		) return address_array_layer_2 is
		--constant ROWS         : integer                      := 14;
		constant COLS         : integer                        := 14;
		variable neighbors    : address_array_layer_2(0 to 24) := (others => (others => '0'));
		variable neighbor_row : integer;
		variable neighbor_col : integer;
		variable addr         : integer;
	begin
		-- Loop through each pixel in the 5x5 kernel (relative to the central pixel)
		for i in -2 to 2 loop     -- Vertical offset (-2 to +2)
			for j in -2 to 2 loop -- Horizontal offset (-2 to +2)

				-- Calculate the row and column of the current neighbor
				neighbor_row := row_in + i;
				neighbor_col := col_in + j;

				-- Within bounds
				addr := neighbor_row * COLS + neighbor_col;

				-- Store the address in the output array
				neighbors((i + 2) * 5 + (j + 2)) := std_logic_vector(to_unsigned(addr, 8));
			end loop;
		end loop;

		return neighbors;
	end function;

end FindConv2Kernel;
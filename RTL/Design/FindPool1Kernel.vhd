library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Include the types package for custom type definitions
library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- Package declaration for finding 2x2 kernel neighbors
package FindPool1Kernel is
    -- Function to compute 2x2 kernel addresses with parameterizable dimensions
    function find_maxpool_kernel_neighbors (
            top_left_row : integer; -- Row index of the top-left pixel
            top_left_col : integer  -- Column index of the top-left pixel
        ) return address_array_layer_1;
end FindPool1Kernel;

-- Implementation of the package
package body FindPool1Kernel is

    function find_maxpool_kernel_neighbors (
            top_left_row : integer;
            top_left_col : integer
        ) return address_array_layer_1 is
        --constant ROWS         : integer := 28;
        constant COLS      : integer                       := 28;
        variable neighbors : address_array_layer_1(0 to 3) := (others => (others => '0'));
        variable addr      : integer;
    begin
        -- Loop through each pixel in the 2x2 kernel (relative to the top-left pixel)
        for i in 0 to 1 loop     -- Vertical offset (0 to 1)
            for j in 0 to 1 loop -- Horizontal offset (0 to 1)
                addr                 := (top_left_row + i) * COLS + (top_left_col + j);
                neighbors(i * 2 + j) := std_logic_vector(to_unsigned(addr, 10));
            end loop;
        end loop;

        return neighbors;
    end function;

end FindPool1Kernel;

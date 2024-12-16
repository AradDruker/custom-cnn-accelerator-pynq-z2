library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include the types package for custom type definitions
library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- Package declaration for finding kernel neighbors
-- Now ROWS and COLS are function parameters, making the function more generic.
package FindKernelNeighborsPkg is
    -- Function to compute 5x5 kernel addresses with parameterizable dimensions
    function find_kernel_neighbors (
            row_in : integer; -- Row index of the central pixel
            col_in : integer; -- Column index of the central pixel
            ROWS   : integer; -- Total number of rows in the image
            COLS   : integer  -- Total number of columns in the image
        ) return address_array_layer_1;
end FindKernelNeighborsPkg;

package body FindKernelNeighborsPkg is

    function find_kernel_neighbors (
            row_in : integer;
            col_in : integer;
            ROWS   : integer;
            COLS   : integer
        ) return address_array_layer_1 is
        constant PADDING_ADDR : integer                        := ROWS * COLS; -- Or any suitable out-of-bounds address
        variable neighbors    : address_array_layer_1(0 to 24) := (others => (others => '0'));
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

                -- Check if the neighbor is within the bounds of the image
                if (neighbor_row < 0) or (neighbor_row >= ROWS) or
                    (neighbor_col < 0) or (neighbor_col >= COLS) then
                    -- Neighbor is out-of-bounds
                    addr := PADDING_ADDR;
                else
                    -- Within bounds
                    addr := neighbor_row * COLS + neighbor_col;
                end if;

                -- Store the address in the output array
                neighbors((i + 2) * 5 + (j + 2)) := std_logic_vector(to_unsigned(addr, 10));
            end loop;
        end loop;

        return neighbors;
    end function;

end FindKernelNeighborsPkg;

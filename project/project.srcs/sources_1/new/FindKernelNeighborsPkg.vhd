library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Include the types package for custom type definitions
library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- Package declaration for finding kernel neighbors
-- This package provides a function to compute the addresses of all pixels
-- in a 5x5 kernel around a given central pixel in a 28x28 image.
package FindKernelNeighborsPkg is
    -- Function to compute 5x5 kernel addresses
    function find_kernel_neighbors (
            row_in : integer;   -- Row index of the central pixel (0 to 27)
            col_in : integer    -- Column index of the central pixel (0 to 27)
        ) return address_array_layer_1; -- Returns an array of addresses for the 5x5 kernel
end FindKernelNeighborsPkg;

-- Implementation of the package
package body FindKernelNeighborsPkg is

    -- Function definition
    function find_kernel_neighbors (
            row_in : integer; -- Central pixel's row index
            col_in : integer  -- Central pixel's column index
        ) return address_array_layer_1 is
        constant ROWS                       : integer                := 28;                          -- Number of rows in the image
        constant COLS                       : integer                := 28;                          -- Number of columns in the image
        constant PADDING_ADDR               : integer                := 784;                         -- Address used for out-of-bounds pixels
        variable neighbors                  : address_array_layer_1(0 to 24) := (others => (others => '0')); -- Output array
        variable neighbor_row, neighbor_col : integer;                                               -- Temporary variables for neighbor indices
        variable addr                       : integer;                                               -- Variable to hold calculated address
    begin
        -- Loop through each pixel in the 5x5 kernel (relative to the central pixel)
        for i in -2 to 2 loop     -- Vertical offset (-2 to +2)
            for j in -2 to 2 loop -- Horizontal offset (-2 to +2)

                -- Calculate the row and column of the current neighbor
                neighbor_row := row_in + i;
                neighbor_col := col_in + j;

                -- Check if the neighbor is within the bounds of the image
                if neighbor_row < 0 or neighbor_row >= ROWS or
                    neighbor_col < 0 or neighbor_col >= COLS then
                    -- Neighbor is out-of-bounds, assign padding address
                    addr := PADDING_ADDR;
                else
                    -- Neighbor is within bounds, compute its linear address
                    addr := neighbor_row * COLS + neighbor_col;
                end if;

                -- Store the calculated address in the output array
                neighbors((i + 2) * 5 + (j + 2)) := std_logic_vector(to_unsigned(addr, 10));
            end loop;
        end loop;

        -- Return the array of addresses for the 5x5 kernel
        return neighbors;
    end function;

end FindKernelNeighborsPkg;

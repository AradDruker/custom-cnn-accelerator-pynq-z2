library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Package declaration for custom types
-- This package defines reusable array types for addresses, kernels, and data.
package types_package is

    -- Address Array Type:
    -- Used to represent an array of addresses. Each address is a 10-bit vector.
    -- The range is flexible (defined when a variable of this type is declared).
    type address_array_layer_1 is array (natural range <>) of std_logic_vector(9 downto 0);
    type address_array_layer_2 is array (natural range <>) of std_logic_vector(7 downto 0);


    -- Kernel Array Type:
    -- Used to represent an array of signed 8-bit weights, typically for kernels in convolution operations.
    -- The range is flexible (defined when a variable of this type is declared).
    type kernel_array is array (natural range <>) of signed(7 downto 0);

    -- Data Array Type:
    -- Used to represent an array of unsigned 8-bit data values.
    -- Commonly used for pixel data or other unsigned numerical representations.
    -- The range is flexible (defined when a variable of this type is declared).
    type data_array is array (natural range <>) of unsigned(7 downto 0);
    type data_array_array is array (natural range <>) of data_array(0 to 3);

    --bram
    type wea_array is array (natural range <>) of std_logic_vector(0 downto 0);
    type bram_data_array is array (natural range <>) of std_logic_vector(7 downto 0);

    --rom
    type weights_array is array (natural range <>) of kernel_array(0 to 24);
    type bais_array is array (natural range <>) of signed(31 downto 0);


end package types_package;

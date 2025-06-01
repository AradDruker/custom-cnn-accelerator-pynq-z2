library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Package declaration for custom types
-- This package defines reusable array types for addresses, kernels, and data.
package types_package is

    -- Address Array Type:
    type address_array_layer_1 is array (natural range <>) of std_logic_vector(9 downto 0);
    type address_array_layer_2 is array (natural range <>) of std_logic_vector(7 downto 0);
    type address_array_layer_3 is array (natural range <>) of std_logic_vector(6 downto 0);
    type address_array_layer_4 is array (natural range <>) of std_logic_vector(4 downto 0);
    type address_array_layer_5 is array (natural range <>) of std_logic_vector(2 downto 0);

    type address_array_weights_conv2 is array (natural range <>) of std_logic_vector(7 downto 0);
    type address_array_weights_fc1 is array (natural range <>) of std_logic_vector(8 downto 0);
    type address_array_weights_fc2 is array (natural range <>) of std_logic_vector(5 downto 0);

    type finish_channel_array is array (natural range <>) of std_logic;

    type kernel_array is array (natural range <>) of signed(7 downto 0);
    type signed_data_array is array (natural range <>) of kernel_array(0 to 24);

    -- Data Array Type:
    type data_array is array (natural range <>) of unsigned(7 downto 0);
    type data_array_pool is array (natural range <>) of data_array(0 to 3);
    type data_array_conv2 is array (natural range <>) of data_array(0 to 24);

    type wea_array is array (natural range <>) of std_logic_vector(0 downto 0);
    type bram_data_array is array (natural range <>) of std_logic_vector(7 downto 0);
    type fc1_data_array is array (natural range <>) of bram_data_array(0 to 9);

    type weights_array is array (natural range <>) of kernel_array(0 to 24);
    type weights_array_conv_2 is array (natural range <>) of weights_array(0 to 5);
    type weights_array_fc_1 is array(natural range <>) of kernel_array(0 to 15);
    type weights_array_fc_2 is array(natural range <>) of kernel_array(0 to 119);
    type weights_array_fc_3 is array(natural range <>) of kernel_array(0 to 83);

    type bais_array is array (natural range <>) of signed(31 downto 0);

    --conv1 - relu_conv
    type address_array_delayed_layer_1 is array (natural range <>) of address_array_layer_1(0 to 24);
    type pixels_array is array (natural range <>) of data_array(0 to 24);
    type r_address_array_type is array (natural range <>) of address_array_layer_1(0 to 24);

    type scale_array is array (natural range <>) of integer range 0 to 511;

end package types_package;

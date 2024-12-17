library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module interfaces with two dual-port memory blocks: 
entity memory_controller is
    Port (
        clka : in std_logic; -- Clock signal

        -- Origin image memory block:
        -- Port A (Write port)
        wea_origin   : in std_logic_vector(0 downto 0);  -- Write enable signal for Port A
        addra_origin : in std_logic_vector(9 downto 0);  -- Address for Port A write operations
        dina_origin  : in std_logic_vector(7 downto 0);  -- Data input for Port A write operations
                                                         -- Port B (Read port)
        addrb_origin : in  std_logic_vector(9 downto 0); -- Address for Port B read operations
        doutb_origin : out std_logic_vector(7 downto 0); -- Data output for Port B read operations

        -- Predict image memory block layer_1:
        -- Port A (Write port)
        wea_layer_1   : in wea_array(0 to 5);              -- Write enable signal for Port A
        addra_layer_1 : in std_logic_vector(9 downto 0);   -- Address for Port A write operations
        dina_layer_1  : in bram_data_array(0 to 5);        -- Data input for Port A write operations
                                                           -- Port B (Read port)
        addrb_layer_1 : in  address_array_layer_1(0 to 5); -- Address for Port B read operations
        doutb_layer_1 : out bram_data_array(0 to 5);       -- Data output for Port B read operations

        wea_layer_2   : in wea_array(0 to 5);
        addra_layer_2 : in std_logic_vector(7 downto 0);
        dina_layer_2  : in bram_data_array(0 to 5);

        addrb_layer_2 : in  address_array_layer_2(0 to 5);
        doutb_layer_2 : out bram_data_array(0 to 5);

        wea_layer_3   : in wea_array(0 to 15);
        addra_layer_3 : in std_logic_vector(6 downto 0);
        dina_layer_3  : in bram_data_array(0 to 15);

        addrb_layer_3 : in  address_array_layer_3(0 to 15);
        doutb_layer_3 : out bram_data_array(0 to 15)
    );
end memory_controller;

-- Architecture definition
architecture Behavioral of memory_controller is

    -- Component declaration for the origin/predict image memory block
    component blk_mem_gen_3
        Port (
            clka  : in  std_logic;                    -- Clock signal
            wea   : in  std_logic_vector(0 downto 0); -- Write enable
            addra : in  std_logic_vector(9 downto 0); -- Write address
            dina  : in  std_logic_vector(7 downto 0); -- Write data
            clkb  : in  std_logic;                    -- Clock signal for read port
            addrb : in  std_logic_vector(9 downto 0); -- Read address
            doutb : out std_logic_vector(7 downto 0)  -- Read data
        );
    end component;

    component blk_mem_gen_4
        Port (
            clka  : in  std_logic;                    -- Clock signal
            wea   : in  std_logic_vector(0 downto 0); -- Write enable
            addra : in  std_logic_vector(7 downto 0); -- Write address
            dina  : in  std_logic_vector(7 downto 0); -- Write data
            clkb  : in  std_logic;                    -- Clock signal for read port
            addrb : in  std_logic_vector(7 downto 0); -- Read address
            doutb : out std_logic_vector(7 downto 0)  -- Read data
        );
    end component;

    component blk_mem_gen_13
        Port (
            clka  : in  std_logic;                    -- Clock signal
            wea   : in  std_logic_vector(0 downto 0); -- Write enable
            addra : in  std_logic_vector(6 downto 0); -- Write address
            dina  : in  std_logic_vector(7 downto 0); -- Write data
            clkb  : in  std_logic;                    -- Clock signal for read port
            addrb : in  std_logic_vector(6 downto 0); -- Read address
            doutb : out std_logic_vector(7 downto 0)  -- Read data
        );
    end component;

begin

        -- Instantiate the origin image memory block
        ram_origin_image : blk_mem_gen_3 port map(
            clka  => clka,         -- Clock signal for both ports
            wea   => wea_origin,   -- Write enable signal for Port A
            addra => addra_origin, -- Write address for Port A
            dina  => dina_origin,  -- Write data for Port A
            clkb  => clka,         -- Clock signal for Port B (shared with Port A)
            addrb => addrb_origin, -- Read address for Port B
            doutb => doutb_origin  -- Read data for Port B
        );

    -- Instantiate the predict image memory blocks
    ram_layer_1_output : for i in 0 to 5 generate
            instance : blk_mem_gen_3 port map(
                clka  => clka,             -- Clock signal for both ports
                wea   => wea_layer_1(i),   -- Write enable signal for Port A
                addra => addra_layer_1,    -- Write address for Port A
                dina  => dina_layer_1(i),  -- Write data for Port A
                clkb  => clka,             -- Clock signal for Port B (shared with Port A)
                addrb => addrb_layer_1(i), -- Read address for Port B
                doutb => doutb_layer_1(i)  -- Read data for Port B
            );
    end generate ram_layer_1_output;

    ram_layer_2_output : for i in 0 to 5 generate
            instance : blk_mem_gen_4 port map(
                clka  => clka,             -- Clock signal for both ports
                wea   => wea_layer_2(i),   -- Write enable signal for Port A
                addra => addra_layer_2,    -- Write address for Port A
                dina  => dina_layer_2(i),  -- Write data for Port A
                clkb  => clka,             -- Clock signal for Port B (shared with Port A)
                addrb => addrb_layer_2(i), -- Read address for Port B
                doutb => doutb_layer_2(i)  -- Read data for Port B
            );
    end generate ram_layer_2_output;

    ram_layer_3_output : for i in 0 to 15 generate
            instance : blk_mem_gen_13 port map(
                clka  => clka,             -- Clock signal for both ports
                wea   => wea_layer_3(i),   -- Write enable signal for Port A
                addra => addra_layer_3,    -- Write address for Port A
                dina  => dina_layer_3(i),  -- Write data for Port A
                clkb  => clka,             -- Clock signal for Port B (shared with Port A)
                addrb => addrb_layer_3(i), -- Read address for Port B
                doutb => doutb_layer_3(i)  -- Read data for Port B
            );
    end generate ram_layer_3_output;

end Behavioral;

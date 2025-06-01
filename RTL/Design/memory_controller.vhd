library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module interfaces with two dual-port memory blocks: 
--todo: remove addr arrays to save up some register
entity memory_controller is
    Port (
        clka : in std_logic; -- Clock signal

        wea_weights_conv2   : in  wea_array(0 to 95);
        addra_weights_conv2 : in  std_logic_vector(4 downto 0);
        dina_weights_conv2  : in  bram_data_array(0 to 95);
        douta_weights_conv2 : out bram_data_array(0 to 95);
        web_weights_conv2   : in  wea_array(0 to 95);
        addrb_weights_conv2 : in  std_logic_vector(4 downto 0);
        dinb_weights_conv2  : in  bram_data_array(0 to 95);
        doutb_weights_conv2 : out bram_data_array(0 to 95);

        wea_weights_fc1   : in  wea_array(0 to 63);
        addra_weights_fc1 : in  std_logic_vector(8 downto 0);
        dina_weights_fc1  : in  bram_data_array(0 to 63);
        addrb_weights_fc1 : in  std_logic_vector(8 downto 0);
        doutb_weights_fc1 : out bram_data_array(0 to 63);

        wea_weights_fc2   : in  wea_array(0 to 29);
        addra_weights_fc2 : in  std_logic_vector(5 downto 0);
        dina_weights_fc2  : in  bram_data_array(0 to 29);
        addrb_weights_fc2 : in  address_array_weights_fc2(0 to 29);
        doutb_weights_fc2 : out bram_data_array(0 to 29);

        -- Origin image memory block:
        -- Port A (Write port)
        wea_origin   : in  std_logic_vector(0 downto 0);
        addra_origin : in  std_logic_vector(9 downto 0);
        dina_origin  : in  std_logic_vector(7 downto 0);
        douta_origin : out std_logic_vector(7 downto 0);
        web_origin   : in  std_logic_vector(0 downto 0);
        addrb_origin : in  std_logic_vector(9 downto 0);
        dinb_origin  : in  std_logic_vector(7 downto 0);
        doutb_origin : out std_logic_vector(7 downto 0);

        wea_layer_1   : in  wea_array(0 to 5);
        addra_layer_1 : in  std_logic_vector(9 downto 0);
        dina_layer_1  : in  bram_data_array(0 to 5);
        douta_layer_1 : out bram_data_array(0 to 5);
        web_layer_1   : in  wea_array(0 to 5);
        addrb_layer_1 : in  std_logic_vector(9 downto 0);
        dinb_layer_1  : in  bram_data_array(0 to 5);
        doutb_layer_1 : out bram_data_array(0 to 5);

        wea_layer_2   : in  wea_array(0 to 5);
        addra_layer_2 : in  std_logic_vector(7 downto 0);
        dina_layer_2  : in  bram_data_array(0 to 5);
        douta_layer_2 : out bram_data_array(0 to 5);
        web_layer_2   : in  wea_array(0 to 5);
        addrb_layer_2 : in  std_logic_vector(7 downto 0);
        dinb_layer_2  : in  bram_data_array(0 to 5);
        doutb_layer_2 : out bram_data_array(0 to 5);

        wea_layer_3   : in  wea_array(0 to 15);
        addra_layer_3 : in  std_logic_vector(6 downto 0);
        dina_layer_3  : in  bram_data_array(0 to 15);
        addrb_layer_3 : in  std_logic_vector(6 downto 0);
        doutb_layer_3 : out bram_data_array(0 to 15);

        wea_layer_4   : in  wea_array(0 to 15);
        addra_layer_4 : in  std_logic_vector(4 downto 0);
        dina_layer_4  : in  bram_data_array(0 to 15);
        addrb_layer_4 : in  address_array_layer_4(0 to 15);
        doutb_layer_4 : out bram_data_array(0 to 15);

        wea_layer_5   : in  wea_array(0 to 7);
        addra_layer_5 : in  std_logic_vector(2 downto 0);
        dina_layer_5  : in  bram_data_array(0 to 7);
        addrb_layer_5 : in  address_array_layer_5(0 to 7);
        doutb_layer_5 : out bram_data_array(0 to 7)
    );
end memory_controller;

-- Architecture definition
architecture Behavioral of memory_controller is

    -- Component declaration for the origin/predict image memory block
    component blk_mem_gen_3 IS
        PORT (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(9 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            douta : out std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(9 downto 0);
            dinb  : in  std_logic_vector(7 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    END component;

    component blk_mem_gen_4
        PORT (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(7 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            douta : out std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(7 downto 0);
            dinb  : in  std_logic_vector(7 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    component blk_mem_gen_13
        PORT (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(6 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(6 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    component blk_mem_gen_14
        Port (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(4 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(4 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    component blk_mem_gen_1
        Port (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(8 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(8 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    component blk_mem_gen_2
        PORT (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(4 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            douta : out std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(4 downto 0);
            dinb  : in  std_logic_vector(7 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    component blk_mem_gen_0
        Port (
            clka  : in  std_logic;                    -- Clock signal
            wea   : in  std_logic_vector(0 downto 0); -- Write enable
            addra : in  std_logic_vector(5 downto 0); -- Write address
            dina  : in  std_logic_vector(7 downto 0); -- Write data
            clkb  : in  std_logic;                    -- Clock signal for read port
            addrb : in  std_logic_vector(5 downto 0); -- Read address
            doutb : out std_logic_vector(7 downto 0)  -- Read data
        );
    end component;

    component blk_mem_gen_5
        Port (
            clka  : in  std_logic;                    -- Clock signal
            wea   : in  std_logic_vector(0 downto 0); -- Write enable
            addra : in  std_logic_vector(2 downto 0); -- Write address
            dina  : in  std_logic_vector(7 downto 0); -- Write data
            clkb  : in  std_logic;                    -- Clock signal for read port
            addrb : in  std_logic_vector(2 downto 0); -- Read address
            doutb : out std_logic_vector(7 downto 0)  -- Read data
        );
    end component;

begin

    ram_weights_conv2 : for i in 0 to 95 generate
            instance : blk_mem_gen_2 port map(
                clka  => clka,
                wea   => wea_weights_conv2(i),
                addra => addra_weights_conv2,
                dina  => dina_weights_conv2(i),
                douta => douta_weights_conv2(i),
                clkb  => clka,
                web   => web_weights_conv2(i),
                addrb => addrb_weights_conv2,
                dinb  => dinb_weights_conv2(i),
                doutb => doutb_weights_conv2(i)
            );
    end generate ram_weights_conv2;

    ram_weights_fc1 : for i in 0 to 63 generate
            instance : blk_mem_gen_1 port map(
                clka  => clka,
                wea   => wea_weights_fc1(i),
                addra => addra_weights_fc1,
                dina  => dina_weights_fc1(i),
                clkb  => clka,
                addrb => addrb_weights_fc1,
                doutb => doutb_weights_fc1(i)
            );
    end generate ram_weights_fc1;

    ram_weights_fc2 : for i in 0 to 29 generate
            instance : blk_mem_gen_0 port map(
                clka  => clka,
                wea   => wea_weights_fc2(i),
                addra => addra_weights_fc2,
                dina  => dina_weights_fc2(i),
                clkb  => clka,
                addrb => addrb_weights_fc2(i),
                doutb => doutb_weights_fc2(i)
            );
    end generate ram_weights_fc2;

        -- Instantiate the origin image memory block
        ram_origin_image : blk_mem_gen_3 port map(
            clka  => clka,
            wea   => wea_origin,
            addra => addra_origin,
            dina  => dina_origin,
            douta => douta_origin,
            clkb  => clka,
            web   => web_origin,
            addrb => addrb_origin,
            dinb  => dinb_origin,
            doutb => doutb_origin
        );

    -- Instantiate the predict image memory blocks
    ram_layer_1_output : for i in 0 to 5 generate
            instance : blk_mem_gen_3 port map(
                clka  => clka,
                wea   => wea_layer_1(i),
                addra => addra_layer_1,
                dina  => dina_layer_1(i),
                douta => douta_layer_1(i),
                clkb  => clka,
                web   => web_layer_1(i),
                addrb => addrb_layer_1,
                dinb  => dinb_layer_1(i),
                doutb => doutb_layer_1(i)
            );
    end generate ram_layer_1_output;

    ram_layer_2_output : for i in 0 to 5 generate
            instance : blk_mem_gen_4 port map(
                clka  => clka,
                wea   => wea_layer_2(i),
                addra => addra_layer_2,
                dina  => dina_layer_2(i),
                douta => douta_layer_2(i),
                clkb  => clka,
                web   => web_layer_2(i),
                addrb => addrb_layer_2,
                dinb  => dinb_layer_2(i),
                doutb => doutb_layer_2(i)
            );
    end generate ram_layer_2_output;

    ram_layer_3_output : for i in 0 to 15 generate
            instance : blk_mem_gen_13 port map(
                clka  => clka,
                wea   => wea_layer_3(i),
                addra => addra_layer_3,
                dina  => dina_layer_3(i),
                clkb  => clka,
                addrb => addrb_layer_3,
                doutb => doutb_layer_3(i)
            );
    end generate ram_layer_3_output;

    ram_layer_4_output : for i in 0 to 15 generate
            instance : blk_mem_gen_14 port map(
                clka  => clka,             -- Clock signal for both ports
                wea   => wea_layer_4(i),   -- Write enable signal for Port A
                addra => addra_layer_4,    -- Write address for Port A
                dina  => dina_layer_4(i),  -- Write data for Port A
                clkb  => clka,             -- Clock signal for Port B (shared with Port A)
                addrb => addrb_layer_4(i), -- Read address for Port B
                doutb => doutb_layer_4(i)  -- Read data for Port B
            );
    end generate ram_layer_4_output;

    ram_layer_5_output : for i in 0 to 7 generate
            instance : blk_mem_gen_5 port map(
                clka  => clka,             -- Clock signal for both ports
                wea   => wea_layer_5(i),   -- Write enable signal for Port A
                addra => addra_layer_5,    -- Write address for Port A
                dina  => dina_layer_5(i),  -- Write data for Port A
                clkb  => clka,             -- Clock signal for Port B (shared with Port A)
                addrb => addrb_layer_5(i), -- Read address for Port B
                doutb => doutb_layer_5(i)  -- Read data for Port B
            );
    end generate ram_layer_5_output;

end Behavioral;

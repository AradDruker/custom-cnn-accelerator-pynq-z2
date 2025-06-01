library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;
use xil_defaultlib.FindConv1Kernel.all;

-- Entity declaration for layer_1
-- This module performs convolution operations by reading data from BRAM,
-- applying a kernel to the data, and writing the results to another BRAM.
entity layer_1 is
    Port (
        clka   : in  std_logic; -- Clock signal
        clkb   : in  std_logic;
        resetn : in  std_logic; -- Active-low reset signal
        start  : in  std_logic; -- Start signal to begin operation
        finish : out std_logic; -- finish signal for higher-level control

        weights : in weights_array(0 to 5); -- Kernel weights for convolution
        bias    : in bais_array(0 to 5);    -- Bias to be added after convolution

        -- Predict image (write to Port A of BRAM)
        wea_layer_1   : out wea_array(0 to 5);
        web_layer_1   : out wea_array(0 to 5);
        addra_layer_1 : out std_logic_vector(9 downto 0);
        addrb_layer_1 : out std_logic_vector(9 downto 0);
        dina_layer_1  : out bram_data_array(0 to 5);
        dinb_layer_1  : out bram_data_array(0 to 5);

        addra_origin     : out std_logic_vector(9 downto 0);
        douta_origin     : in  std_logic_vector(7 downto 0);
        addrb_origin     : out std_logic_vector(9 downto 0);
        doutb_origin     : in  std_logic_vector(7 downto 0);
        scale            : in  integer range 0 to 512;
        input_zero_point : in  integer range 0 to 255
    );
end layer_1;

-- Architecture definition
architecture Behavioral of layer_1 is

    component bram_reader_conv1 is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to initiate reading
            finish : out std_logic; -- Output signal indicating the operation is done

            r_address_array_a : in  address_array_layer_1(0 to 24); -- Input array of addresses to read from BRAM
            r_address_array_b : in  address_array_layer_1(0 to 24); -- Input array of addresses to read from BRAM
            r_address_a       : out std_logic_vector(9 downto 0);   -- Current address sent to BRAM
            r_address_b       : out std_logic_vector(9 downto 0);

            data_in_bram_a     : in  std_logic_vector(7 downto 0); -- Data read from BRAM
            data_in_bram_b     : in  std_logic_vector(7 downto 0);
            data_out_interface : out pixels_array(0 to 1) -- Processed data output array
        );
    end component;

    component channel_layer_1 is
        Port (
            clka   : in  std_logic; -- Clock signal
            clkb   : in  std_logic;
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- finish signal for higher-level control

            weights : in kernel_array(0 to 24); -- Kernel weights for convolution
            bias    : in signed(31 downto 0);   -- Bias to be added after convolution

            -- Predict image (write to Port A of BRAM)
            wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
            web          : out std_logic_vector(0 downto 0);
            dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM
            dinb_predict : out std_logic_vector(7 downto 0);

            image_slice             : in pixels_array(0 to 1);
            r_address_array_delayed : in address_array_delayed_layer_1(0 to 1);
            scale                   : in integer range 0 to 512;
            input_zero_point        : in integer range 0 to 255
        );
    end component;

    -- State machine definition
    type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, DONE);
    signal state : state_type := IDLE;

    -- Signals for bram_reader
    signal r_address_array         : r_address_array_type(0 to 1)          := (others => (others => ( others => '0')));
    signal r_address_array_delayed : address_array_delayed_layer_1(0 to 1) := (others => (others => ( others => '0')));

    signal data_out_interface : pixels_array(0 to 1) := (others => (others => ( others => '0')));
    signal data_compute       : pixels_array(0 to 1) := (others => (others => ( others => '0')));

    signal start_bram_reader  : std_logic := '0';
    signal finish_bram_reader : std_logic := '0';

    signal start_channel : std_logic := '0';

    signal finish_channel : finish_channel_array(0 to 5);

    signal finish_channel_latch     : std_logic_vector(5 downto 0) := (others => '0');
    signal finish_bram_reader_latch : std_logic                    := '0';

    signal flag_last : std_logic := '0';

    signal scale_pipeline : integer range 0 to 512;

begin

    scale_pipeline <= scale;

        -- Instantiation of bram_reader
        -- This module reads a 5x5 kernel from the origin image BRAM
        bram_reader_0 : bram_reader_conv1 port map(
            clka               => clka,
            resetn             => resetn,
            start              => start_bram_reader,
            finish             => finish_bram_reader,
            r_address_array_a  => r_address_array(0),
            r_address_array_b  => r_address_array(1),
            r_address_a        => addra_origin,
            r_address_b        => addrb_origin,
            data_in_bram_a     => douta_origin,
            data_in_bram_b     => doutb_origin,
            data_out_interface => data_out_interface
        );

    channel : for i in 0 to 5 generate
        instance : channel_layer_1
            port map(
                clka                    => clka,
                clkb                    => clkb,
                resetn                  => resetn,
                start                   => start_channel,
                finish                  => finish_channel(i),
                weights                 => weights(i),
                bias                    => bias(i),
                wea                     => wea_layer_1(i),
                web                     => web_layer_1(i),
                dina_predict            => dina_layer_1(i),
                dinb_predict            => dinb_layer_1(i),
                image_slice             => data_compute,
                r_address_array_delayed => r_address_array_delayed,
                scale                   => scale_pipeline,
                input_zero_point        => input_zero_point
            );
    end generate channel;


    process(clka, resetn)

        variable row : integer range 0 to 28 := 0;
        variable col : integer range 0 to 26 := 2;

    begin
        if resetn = '0' then
            state <= IDLE;

        elsif rising_edge(clka) then
            case state is
                when IDLE =>
                    finish                     <= '0';
                    finish_channel_latch       <= (others => '0');
                    addra_layer_1              <= (others => '0');
                    addrb_layer_1              <= (others => '0');
                    row                        := 0;
                    col                        := 2;
                    flag_last                  <= '0';
                    r_address_array(0)         <= find_conv_1_kernel(0, 0);
                    r_address_array(1)         <= find_conv_1_kernel(0, 1);
                    r_address_array_delayed(0) <= r_address_array(0);
                    r_address_array_delayed(1) <= r_address_array(1);

                    if start = '1' then
                        start_bram_reader <= '1';
                        state             <= FIRST_READ;
                    end if;

                when FIRST_READ =>
                    start_bram_reader <= '0';
                    if finish_bram_reader = '1' then
                        r_address_array(0)         <= find_conv_1_kernel(0, 2);
                        r_address_array(1)         <= find_conv_1_kernel(0, 3);
                        r_address_array_delayed(0) <= r_address_array(0);
                        r_address_array_delayed(1) <= r_address_array(1);
                        addra_layer_1              <= r_address_array(0)(12);
                        addrb_layer_1              <= r_address_array(1)(12);
                        data_compute               <= data_out_interface;
                        state                      <= READ_COMPUTE;
                    end if;

                when READ_COMPUTE =>
                    finish_bram_reader_latch <= '0';
                    finish_channel_latch     <= (others => '0');

                    start_channel     <= '1';
                    start_bram_reader <= '1';

                    -- Update row/col indices
                    if col < 26 then
                        col := col + 2;
                    else
                        if row < 27 then
                            col := 0;
                            row := row + 1;
                        else
                            flag_last <= '1';
                        end if;
                    end if;
                    state <= WAIT_READ_COMPUTE;

                when WAIT_READ_COMPUTE =>
                    -- Wait for next read operation to complete
                    start_bram_reader <= '0';
                    start_channel     <= '0';

                    if finish_bram_reader = '1' then
                        finish_bram_reader_latch <= '1';
                    end if;

                    for i in 0 to 5 loop
                        if finish_channel(i) = '1' then
                            finish_channel_latch(i) <= '1';
                        end if;
                    end loop;

                    if finish_bram_reader_latch = '1' and finish_channel_latch = "111111" then
                        r_address_array(0)         <= find_conv_1_kernel(row, col);
                        r_address_array(1)         <= find_conv_1_kernel(row, col + 1);
                        r_address_array_delayed(0) <= r_address_array(0);
                        r_address_array_delayed(1) <= r_address_array(1);
                        addra_layer_1              <= r_address_array(0)(12);
                        addrb_layer_1              <= r_address_array(1)(12);
                        data_compute               <= data_out_interface;
                        if flag_last = '1' then
                            start_channel        <= '1';
                            finish_channel_latch <= (others => '0');
                            state                <= LAST_COMPUTE;
                        else
                            state <= READ_COMPUTE;
                        end if;
                    end if;

                when LAST_COMPUTE =>
                    start_channel <= '0';
                    for i in 0 to 5 loop
                        if finish_channel(i) = '1' then
                            finish_channel_latch(i) <= '1';
                        end if;
                    end loop;

                    if finish_channel_latch = "111111" then
                        state <= DONE;
                    end if;

                when DONE =>
                    finish <= '1';
                    state  <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;

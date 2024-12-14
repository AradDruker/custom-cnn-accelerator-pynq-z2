library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;
use xil_defaultlib.FindKernelNeighborsPkg.all;

-- Entity declaration for layer_1
-- This module performs convolution operations by reading data from BRAM,
-- applying a kernel to the data, and writing the results to another BRAM.
entity layer_1 is
    Port (
        clka   : in  std_logic; -- Clock signal
        resetn : in  std_logic; -- Active-low reset signal
        start  : in  std_logic; -- Start signal to begin operation
        finish : out std_logic; -- finish signal for higher-level control

        weights : in weights_array(0 to 5); -- Kernel weights for convolution
        bias    : in bais_array(0 to 5);    -- Bias to be added after convolution

        -- Predict image (write to Port A of BRAM)
        wea_layer_1           : out wea_array(0 to 5);            -- Write enable signal for predict BRAM
        addra_layer_1 : out std_logic_vector(9 downto 0); -- Write address for predict BRAM
        dina_layer_1  : out bram_data_array(0 to 5);      -- Data to write into predict BRAM

        -- Origin image (read from Port B of BRAM)
        addrb_origin : out std_logic_vector(9 downto 0); -- Read address for origin BRAM
        doutb_origin : in  std_logic_vector(7 downto 0)  -- Data read from origin BRAM
    );
end layer_1;

-- Architecture definition
architecture Behavioral of layer_1 is

    -- Component declaration for bram_reader
    -- Reads a 5x5 neighborhood from the origin image BRAM based on the input address array
    component bram_reader is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal for the bram_reader
            finish : out std_logic; -- Finish signal indicating operation is complete

            r_address_array    : in  address_array_layer_1(0 to 24);       -- Input array of addresses for 5x5 neighborhood
            r_address          : out std_logic_vector(9 downto 0); -- Current address sent to BRAM
            data_in_bram       : in  std_logic_vector(7 downto 0); -- Data input from BRAM
            data_out_interface : out data_array(0 to 24)           -- Output array with 5x5 neighborhood data
        );
    end component;

    component channel_layer_1 is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- finish signal for higher-level control

            weights : in kernel_array(0 to 24); -- Kernel weights for convolution
            bias    : in signed(31 downto 0);   -- Bias to be added after convolution

            -- Predict image (write to Port A of BRAM)
            wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
            dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

            image_slice : in data_array(0 to 24)
        );
    end component;

    -- State machine definition
    type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, DONE);
    signal state : state_type := IDLE;

    -- Signals for bram_reader
    signal r_address_array    : address_array_layer_1(0 to 24) := (others => (others => '0'));
    signal data_out_interface : data_array(0 to 24)    := (others => (others => '0'));
    signal data_compute       : data_array(0 to 24)    := (others => (others => '0'));

    signal start_bram_reader  : std_logic := '0';
    signal finish_bram_reader : std_logic := '0';

    signal start_channel : std_logic := '0';

    type finish_channel_array is array (0 to 5) of std_logic;
    signal finish_channel : finish_channel_array;

    signal finish_channel_latch     : std_logic_vector(5 downto 0) := (others => '0');
    signal finish_bram_reader_latch : std_logic                    := '0';

    signal flag_last : std_logic := '0';

begin

        -- Instantiation of bram_reader
        -- This module reads a 5x5 kernel from the origin image BRAM
        bram_reader_0 : bram_reader port map(
            clka               => clka,
            resetn             => resetn,
            start              => start_bram_reader,
            finish             => finish_bram_reader,
            r_address_array    => r_address_array,
            r_address          => addrb_origin,      -- Connect to origin BRAM read address
            data_in_bram       => doutb_origin,      -- Data input from origin BRAM
            data_out_interface => data_out_interface -- Output data from bram_reader
        );

    channel : for i in 0 to 5 generate
            instance : channel_layer_1 port map(
                clka         => clka,
                resetn       => resetn,
                start        => start_channel,
                finish       => finish_channel(i),
                weights      => weights(i),
                bias         => bias(i),
                wea          => wea_layer_1(i),
                dina_predict => dina_layer_1(i),
                image_slice  => data_compute
            );
    end generate channel;

    process(clka, resetn)

        variable row : integer range 0 to 28 := 0;
        variable col : integer range 0 to 28 := 1;

    begin
        if resetn = '0' then
            finish               <= '0';
            finish_channel_latch <= (others => '0');
            addra_layer_1        <= (others => '0');
            row                  := 0;
            col                  := 1;
            flag_last            <= '0';
            state                <= IDLE;


        elsif rising_edge(clka) then
            case state is
                when IDLE =>
                    finish               <= '0';
                    finish_channel_latch <= (others => '0');
                    row                  := 0;
                    col                  := 1;
                    flag_last            <= '0';
                    r_address_array      <= find_kernel_neighbors(0, 0);
                    if start = '1' then
                        start_bram_reader <= '1';
                        state             <= FIRST_READ;
                    end if;

                when FIRST_READ =>
                    start_bram_reader <= '0';
                    if finish_bram_reader = '1' then
                        r_address_array <= find_kernel_neighbors(0, 1);
                        addra_layer_1   <= r_address_array(12); -- Write central pixel address
                        data_compute    <= data_out_interface;
                        state           <= READ_COMPUTE;
                    end if;

                when READ_COMPUTE =>
                    finish_bram_reader_latch <= '0';
                    finish_channel_latch     <= (others => '0');

                    start_channel     <= '1';
                    start_bram_reader <= '1';

                    -- Update row/col indices
                    if col < 27 then
                        col   := col + 1;
                        state <= WAIT_READ_COMPUTE;
                    else
                        if row < 27 then
                            col   := 0;
                            row   := row + 1;
                            state <= WAIT_READ_COMPUTE;
                        else
                            flag_last <= '1';
                            state     <= WAIT_READ_COMPUTE; -- End processing
                        end if;
                    end if;

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
                        r_address_array <= find_kernel_neighbors(row, col);
                        addra_layer_1   <= r_address_array(12); -- Write central pixel address
                        data_compute    <= data_out_interface;
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
                    finish    <= '1';
                    row       := 0;
                    col       := 1;
                    flag_last <= '0';
                    state     <= IDLE;


            end case;
        end if;
    end process;
end Behavioral;

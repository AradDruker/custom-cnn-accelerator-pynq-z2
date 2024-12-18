library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;


entity top is
    Port (
        clk    : in std_logic; -- 100Mhz
        resetn : in std_logic; -- Active-low reset signal

        -- CPU -> DMA -> RTL
        s_axis_tready : out std_logic;                    -- Ready signal for input stream
        s_axis_tlast  : in  std_logic;                    -- Last signal for input stream
        s_axis_tvalid : in  std_logic;                    -- Valid signal for input stream
        s_axis_tdata  : in  std_logic_vector(7 downto 0); -- Input data for writing to BRAM

        -- RTL -> DMA -> CPU
        m_axis_tready : in  std_logic;                   -- Ready signal for output stream
        m_axis_tlast  : out std_logic;                   -- Last signal for output stream
        m_axis_tvalid : out std_logic;                   -- Valid signal for output stream
        m_axis_tdata  : out std_logic_vector(7 downto 0) -- Output data from BRAM to DMA
    );
end top;

architecture Behavioral of top is
    -- Component instantiations
    component dma_interface is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete
            mode   : in  std_logic; -- Mode selector: '0' for write, '1' for send

            -- SEND state
            addrb_output : out std_logic_vector(6 downto 0); -- Address for RAM read operation for DMA -
            doutb_output : in  std_logic_vector(7 downto 0); -- Data read from RAM corresponding to addrb_output

            out_tready : in  std_logic;                    -- Ready signal for output stream
            out_tlast  : out std_logic;                    -- Last signal for output stream
            out_tvalid : out std_logic;                    -- Valid signal for output stream
            out_tdata  : out std_logic_vector(7 downto 0); -- Data output for sending via DMA

            -- WRITE STATE     
            wea   : out std_logic_vector(0 downto 0);  -- Write enable for RAM
            addra : out std_logic_vector(9 downto 0);  -- Address for RAM write operation
            dina  : out std_logic_vector(7 downto 0) ; -- Data to write into RAM

            in_tready : out std_logic;                   -- Ready signal for input stream
            in_tlast  : in  std_logic;                   -- Last signal for input stream
            in_tvalid : in  std_logic;                   -- Valid signal for input stream
            in_tdata  : in  std_logic_vector(7 downto 0) -- Data input for writing to RAM
        );
    end component;

    component rom_reader is
        Port (
            clk          : in  std_logic; -- Clock signal
            resetn       : in  std_logic; -- Active-low reset signal
            start_conv_1 : in  std_logic; -- Start signal to initiate read operation
            start_conv_2 : in  std_logic; -- Start signal to initiate read operation
            finish       : out std_logic; -- Signal indicating the operation is complete

            weights_conv_1 : out weights_array(0 to 5);
            bias_conv_1    : out bais_array(0 to 5);

            weights_conv_2 : out weights_array_conv_2(0 to 15);
            bias_conv_2    : out bais_array(0 to 15)
        );
    end component;

    component memory_controller is
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
    end component;

    component layer_1 is
        Port (
            clka : in std_logic;    -- Clock signal
                                    --clkb   : in  std_logic;
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- finish signal for higher-level control

            weights : in weights_array(0 to 5); -- Kernel weights for convolution
            bias    : in bais_array(0 to 5);    -- Bias to be added after convolution

            -- Predict image (write to Port A of BRAM)
            wea_layer_1   : out wea_array(0 to 5);            -- Write enable signal for predict BRAM
            addra_layer_1 : out std_logic_vector(9 downto 0); -- Write address for predict BRAM
            dina_layer_1  : out bram_data_array(0 to 5);      -- Data to write into predict BRAM

            -- Origin image (read from Port B of BRAM)
            addrb_origin : out std_logic_vector(9 downto 0); -- Read address for origin BRAM
            doutb_origin : in  std_logic_vector(7 downto 0)  -- Data read from origin BRAM
        );
    end component;

    component layer_2 is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete

            wea_layer_2   : out wea_array(0 to 5);            -- Write enable signal for predict BRAM
            addra_layer_2 : out std_logic_vector(7 downto 0); -- Write address for predict BRAM
            dina_layer_2  : out bram_data_array(0 to 5);      -- Data to write into predict BRAM

            addrb_layer_1 : out address_array_layer_1(0 to 5); -- Read address for origin BRAM
            doutb_layer_1 : in  bram_data_array(0 to 5)
        );
    end component;

    component layer_3 is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- finish signal for higher-level control

            weights : in weights_array_conv_2(0 to 15); -- Kernel weights for convolution
            bias    : in bais_array(0 to 15);    -- Bias to be added after convolution

            wea_layer_3   : out wea_array(0 to 15);
            addra_layer_3 : out std_logic_vector(6 downto 0);
            dina_layer_3  : out bram_data_array(0 to 15);

            addrb_layer_2 : out address_array_layer_2(0 to 5);
            doutb_layer_2 : in  bram_data_array(0 to 5)
        );
    end component;

    type state_type is (IDLE, WAIT_INPUT_READ, LAYER_1_PROC, LAYER_2_PROC, LAYER_3_PROC, SEND);
    signal state : state_type := IDLE;

    -- DMA Interface Signals
    -- These signals control the DMA interface and handle data transfer between CPU and BRAM
    signal mode_dma : std_logic; -- Mode for DMA interface: '0' for read, '1' for send

    -- BRAM Controller Signals
    -- These signals manage memory access for both origin and predict BRAMs
    -- Origin BRAM (Stores input data from CPU)
    signal wea_origin   : std_logic_vector(0 downto 0); -- Write enable signal for origin BRAM
    signal addra_origin : std_logic_vector(9 downto 0); -- Write address for origin BRAM
    signal dina_origin  : std_logic_vector(7 downto 0); -- Data input for origin BRAM write
    signal addrb_origin : std_logic_vector(9 downto 0); -- Read address for origin BRAM
    signal doutb_origin : std_logic_vector(7 downto 0); -- Data output from origin BRAM

    -- Predict BRAM (Stores processed data for output)
    signal wea_layer_1   : wea_array(0 to 5);
    signal addra_layer_1 : std_logic_vector(9 downto 0);
    signal dina_layer_1  : bram_data_array(0 to 5);
    signal addrb_layer_1 : address_array_layer_1(0 to 5);
    signal doutb_layer_1 : bram_data_array(0 to 5);

    signal wea_layer_2   : wea_array(0 to 5);
    signal addra_layer_2 : std_logic_vector(7 downto 0);
    signal dina_layer_2  : bram_data_array(0 to 5);
    signal addrb_layer_2 : address_array_layer_2(0 to 5);
    signal doutb_layer_2 : bram_data_array(0 to 5);

    signal wea_layer_3   : wea_array(0 to 15);
    signal addra_layer_3 : std_logic_vector(6 downto 0);
    signal dina_layer_3  : bram_data_array(0 to 15);
    signal addrb_layer_3 : address_array_layer_3(0 to 15);
    signal doutb_layer_3 : bram_data_array(0 to 15);

    -- ROM Reader Signals
    signal weights_conv_1 : weights_array(0 to 5);
    signal bias_conv_1    : bais_array(0 to 5);
    signal weights_conv_2 : weights_array_conv_2(0 to 15);
    signal bias_conv_2    : bais_array(0 to 15);

    -- IP Control Signals
    -- These signals control start and finish operations for various components
    signal start_dma_interface     : std_logic; -- Start signal for DMA interface
    signal start_rom_reader_conv_1 : std_logic; -- Start signal for ROM reader
    signal start_rom_reader_conv_2 : std_logic; -- Start signal for ROM reader
    signal start_layer_1           : std_logic; -- Start signal for Layer 1 processing
    signal start_layer_2           : std_logic;
    signal start_layer_3           : std_logic;

    signal finish_dma_interface : std_logic; -- Finish signal from DMA interface
    signal finish_rom_reader    : std_logic; -- Finish signal from ROM reader
    signal finish_layer_1       : std_logic; -- Finish signal from Layer 1 processing
    signal finish_layer_2       : std_logic;
    signal finish_layer_3       : std_logic;

    -- Latching Signals
    signal finish_dma_interface_latched : std_logic := '0'; -- Latched finish signal for DMA interface
    signal finish_rom_reader_latched    : std_logic := '0'; -- Latched finish signal for ROM reader

begin
        -- DMA interface: Manages data transfer between CPU and BRAM
        dma_interface_1 : dma_interface port map(
            clka   => clk,                  -- Clock
            resetn => resetn,               -- Reset
            start  => start_dma_interface,  -- Start signal for DMA interface
            finish => finish_dma_interface, -- Finish signal from DMA interface
            mode   => mode_dma,             -- DMA mode ('0' for read, '1' for send)

            -- BRAM connections for predict image  --debugging
            addrb_output => addrb_layer_3(0), -- Read address for predict BRAM
            doutb_output => doutb_layer_3(0), -- Data output from predict BRAM

            -- CPU -> DMA connections
            in_tready => s_axis_tready, -- Ready signal for input stream
            in_tlast  => s_axis_tlast,  -- Last signal for input stream
            in_tvalid => s_axis_tvalid, -- Valid signal for input stream
            in_tdata  => s_axis_tdata,  -- Input data for BRAM write

            -- DMA -> CPU connections
            out_tready => m_axis_tready, -- Ready signal for output stream
            out_tlast  => m_axis_tlast,  -- Last signal for output stream
            out_tvalid => m_axis_tvalid, -- Valid signal for output stream
            out_tdata  => m_axis_tdata,  -- Data output from BRAM

            -- BRAM write connections for origin image
            wea   => wea_origin,   -- Write enable for origin BRAM
            addra => addra_origin, -- Write address for origin BRAM
            dina  => dina_origin   -- Data input for origin BRAM write
        );

        -- ROM Reader: Loads weights and biases from ROM
        rom_reader_1 : rom_reader port map(
            clk          => clk,                     -- Clock
            resetn       => resetn,                  -- Reset
            start_conv_1 => start_rom_reader_conv_1, -- Start signal for ROM reader
            start_conv_2 => start_rom_reader_conv_2,
            finish       => finish_rom_reader, -- Finish signal from ROM reader

            -- Outputs for weights and biases
            weights_conv_1 => weights_conv_1, bias_conv_1 => bias_conv_1, -- Weights and bias for channel 1
            weights_conv_2 => weights_conv_2, bias_conv_2 => bias_conv_2  -- Weights and bias for channel 2
        );

        -- Memory Controller: Manages BRAM for origin and predict images
        memory_controller_1 : memory_controller port map(
            clka => clk, -- Clock

            -- Origin image BRAM connections
            wea_origin   => wea_origin,   -- Write enable for origin BRAM
            addra_origin => addra_origin, -- Write address for origin BRAM
            dina_origin  => dina_origin,  -- Data input for origin BRAM
            addrb_origin => addrb_origin, -- Read address for origin BRAM
            doutb_origin => doutb_origin, -- Data output from origin BRAM

            -- Predict image BRAM connections
            wea_layer_1   => wea_layer_1,   -- Write enable for predict BRAM
            addra_layer_1 => addra_layer_1, -- Write address for predict BRAM
            dina_layer_1  => dina_layer_1,  -- Data input for predict BRAM
            addrb_layer_1 => addrb_layer_1, -- Read address for predict BRAM
            doutb_layer_1 => doutb_layer_1, -- Data output from predict BRAM

            wea_layer_2   => wea_layer_2,   -- Write enable for predict BRAM
            addra_layer_2 => addra_layer_2, -- Write address for predict BRAM
            dina_layer_2  => dina_layer_2,  -- Data input for predict BRAM
            addrb_layer_2 => addrb_layer_2, -- Read address for predict BRAM
            doutb_layer_2 => doutb_layer_2, -- Data output from predict BRAM

            wea_layer_3   => wea_layer_3,   -- Write enable for predict BRAM
            addra_layer_3 => addra_layer_3, -- Write address for predict BRAM
            dina_layer_3  => dina_layer_3,  -- Data input for predict BRAM
            addrb_layer_3 => addrb_layer_3, -- Read address for predict BRAM
            doutb_layer_3 => doutb_layer_3  -- Data output from predict BRAM
        );

        -- Processing Layer 1: Performs convolution operation on the data
        layer_1_instance : layer_1 port map(
            clka   => clk,
            resetn => resetn,         -- Reset
            start  => start_layer_1,  -- Start signal for Layer 1
            finish => finish_layer_1, -- Finish signal from Layer 1

            -- Weights and biases for convolution
            weights => weights_conv_1, bias => bias_conv_1, -- Weights and bias for channel 1

            -- Predict image BRAM write connections
            wea_layer_1   => wea_layer_1,   -- Write enable for predict BRAM
            addra_layer_1 => addra_layer_1, -- Write address for predict BRAM
            dina_layer_1  => dina_layer_1,  -- Data input for predict BRAM

            -- Origin image BRAM read connections
            addrb_origin => addrb_origin, -- Read address for origin BRAM
            doutb_origin => doutb_origin  -- Data output from origin BRAM
        );

        -- Processing Layer 1: Performs convolution operation on the data
        layer_2_instance : layer_2 port map(
            clka   => clk,            -- Clock
            resetn => resetn,         -- Reset
            start  => start_layer_2,  -- Start signal for Layer 1
            finish => finish_layer_2, -- Finish signal from Layer 1

            wea_layer_2   => wea_layer_2,   -- Write enable for predict BRAM
            addra_layer_2 => addra_layer_2, -- Write address for predict BRAM
            dina_layer_2  => dina_layer_2,  -- Data input for predict BRAM
            addrb_layer_1 => addrb_layer_1, -- Read address for origin BRAM
            doutb_layer_1 => doutb_layer_1  -- Data output from origin BRAM
        );

        layer_3_instance : layer_3 port map(
            clka   => clk,            -- Clock
            resetn => resetn,         -- Reset
            start  => start_layer_3,  -- Start signal for Layer 1
            finish => finish_layer_3, -- Finish signal from Layer 1

            weights => weights_conv_2, bias => bias_conv_2, -- Weights and bias for channel 1

            wea_layer_3   => wea_layer_3,   -- Write enable for predict BRAM
            addra_layer_3 => addra_layer_3, -- Write address for predict BRAM
            dina_layer_3  => dina_layer_3,  -- Data input for predict BRAM
            addrb_layer_2 => addrb_layer_2, -- Read address for origin BRAM
            doutb_layer_2 => doutb_layer_2  -- Data output from origin BRAM
        );

    -- Control process for the top module
    process(clk, resetn)
    begin
        if resetn = '0' then
            -- Reset all control signals
            start_dma_interface          <= '0';
            start_rom_reader_conv_1      <= '0';
            start_rom_reader_conv_2      <= '0';
            start_layer_1                <= '0';
            start_layer_2                <= '0';
            start_layer_3                <= '0';
            finish_dma_interface_latched <= '0';
            finish_rom_reader_latched    <= '0';

        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    -- Initialize signals and start DMA and ROM reader
                    mode_dma                     <= '0'; -- Read mode
                    finish_dma_interface_latched <= '0';
                    finish_rom_reader_latched    <= '0';
                    start_dma_interface          <= '1';
                    start_rom_reader_conv_1      <= '1';
                    state                        <= WAIT_INPUT_READ;

                when WAIT_INPUT_READ =>
                    -- Wait for DMA and ROM reader to finish
                    start_dma_interface     <= '0';
                    start_rom_reader_conv_1 <= '0';

                    if finish_dma_interface = '1' then
                        finish_dma_interface_latched <= '1';
                    end if;

                    if finish_rom_reader = '1' then
                        finish_rom_reader_latched <= '1';
                    end if;

                    if finish_dma_interface_latched = '1' and finish_rom_reader_latched = '1' then
                        mode_dma                  <= '1'; -- Send mode
                        start_layer_1             <= '1'; -- Start Layer 1 computation
                        start_rom_reader_conv_2   <= '1';
                        finish_rom_reader_latched <= '0';
                        state                     <= LAYER_1_PROC;
                    end if;

                when LAYER_1_PROC =>
                    -- Wait for Layer 1 to finish computation
                    start_layer_1           <= '0';
                    start_rom_reader_conv_2 <= '0';

                    if finish_rom_reader = '1' then
                        finish_rom_reader_latched <= '1';
                    end if;
                    if finish_layer_1 = '1' then
                        start_layer_2 <= '1';
                        state         <= LAYER_2_PROC;
                    end if;

                when LAYER_2_PROC =>
                    start_layer_2 <= '0';

                    if finish_layer_2 = '1' and finish_rom_reader_latched = '1' then
                        start_layer_3 <= '1';
                        state         <= LAYER_3_PROC;
                    end if;

                when LAYER_3_PROC =>
                    start_layer_3 <= '0';

                    if finish_layer_3 = '1' then
                        start_dma_interface <= '1';
                        state               <= SEND;
                    end if;


                when SEND =>
                    -- Transition back to IDLE after sending data
                    start_dma_interface <= '0';
                    if finish_dma_interface = '1' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;

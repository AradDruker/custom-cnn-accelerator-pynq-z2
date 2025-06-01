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
        m_axis_tready : in  std_logic;                    -- Ready signal for output stream
        m_axis_tlast  : out std_logic;                    -- Last signal for output stream
        m_axis_tvalid : out std_logic;                    -- Valid signal for output stream
        m_axis_tdata  : out std_logic_vector(7 downto 0); -- Output data from BRAM to DMA

        ps_signal : in std_logic
    );
end top;

architecture Behavioral of top is

    component clk_wiz_0 is
        Port (
            clk_in1    : in  std_logic;
            resetn     : in  std_logic;
            clk_out_50 : out std_logic;
            locked     : out std_logic
        );
    end component;

    component dma_init is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete

            in_tready : out std_logic;                    -- Ready signal for input stream
            in_tlast  : in  std_logic;                    -- Last signal for input stream
            in_tvalid : in  std_logic;                    -- Valid signal for input stream
            in_tdata  : in  std_logic_vector(7 downto 0); -- Data input for writing to RAM

            weights_conv_1 : out weights_array(0 to 5);
            bias_conv_1    : out bais_array(0 to 5);

            wea_weights_conv2   : out wea_array(0 to 95);
            addra_weights_conv2 : out std_logic_vector(4 downto 0);
            dina_weights_conv2  : out bram_data_array(0 to 95);
            bias_conv_2         : out bais_array(0 to 15);

            wea_weights_fc1   : out wea_array(0 to 63);
            addra_weights_fc1 : out std_logic_vector(8 downto 0);
            dina_weights_fc1  : out bram_data_array(0 to 63);
            bias_fc_1         : out bais_array(0 to 63);

            wea_weights_fc2   : out wea_array(0 to 29);
            addra_weights_fc2 : out std_logic_vector(5 downto 0);
            dina_weights_fc2  : out bram_data_array(0 to 29);
            bias_fc_2         : out bais_array(0 to 29);

            scales            : out scale_array(0 to 3);
            input_zero_point  : out integer range 0 to 255;
            output_zero_point : out integer range 0 to 255
        );
    end component;

    component dma_predict is
        Port (
            clka   : in  std_logic; -- Clock signal
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete
            mode   : in  std_logic; -- Mode selector: '0' for write, '1' for send

            -- debugging
            --addrb_output : out std_logic_vector(6 downto 0);
            --doutb_output : in  std_logic_vector(7 downto 0);
            --final_predict : in bram_data_array(0 to 32);

            -- finished product
            final_predict : in std_logic_vector(7 downto 0);

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

    component memory_controller is
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
    end component;

    component layer_1 is
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

            addrb_layer_1 : out std_logic_vector(9 downto 0); -- Read address for origin BRAM
            doutb_layer_1 : in  bram_data_array(0 to 5)
        );
    end component;

    component layer_3 is
        Port (
            clka   : in  std_logic; -- Clock signal 
            clkb   : in  std_logic;
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- finish signal for higher-level control

            bias : in bais_array(0 to 15); -- Bias to be added after convolution

            addra_weights_conv2 : out std_logic_vector(4 downto 0);
            douta_weights_conv2 : in  bram_data_array(0 to 95);
            addrb_weights_conv2 : out std_logic_vector(4 downto 0);
            doutb_weights_conv2 : in  bram_data_array(0 to 95);

            wea_layer_3   : out wea_array(0 to 15);
            addra_layer_3 : out std_logic_vector(6 downto 0);
            dina_layer_3  : out bram_data_array(0 to 15);

            addra_layer_2 : out std_logic_vector(7 downto 0);
            douta_layer_2 : in  bram_data_array(0 to 5);
            addrb_layer_2 : out std_logic_vector(7 downto 0);
            doutb_layer_2 : in  bram_data_array(0 to 5);
            scale         : in  integer range 0 to 512

        );
    end component;

    component layer_4 is
        Port (
            clka   : in  std_logic;
            resetn : in  std_logic;
            start  : in  std_logic;
            finish : out std_logic;

            wea_layer_4   : out wea_array(0 to 15);
            addra_layer_4 : out std_logic_vector(4 downto 0);
            dina_layer_4  : out bram_data_array(0 to 15);

            addrb_layer_3 : out std_logic_vector(6 downto 0);
            doutb_layer_3 : in  bram_data_array(0 to 15)
        );
    end component;

    component layer_5 is
        Port (
            clka   : in  std_logic; -- Clock signal
            clkb   : in  std_logic;
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete

            bias : in bais_array(0 to 63); -- Bias to be added after convolution

            addrb_weights_fc1 : out std_logic_vector(8 downto 0);
            doutb_weights_fc1 : in  bram_data_array(0 to 63);

            wea_layer_5   : out wea_array(0 to 7);
            addra_layer_5 : out std_logic_vector(2 downto 0);
            dina_layer_5  : out bram_data_array(0 to 7);

            addrb_layer_4 : out address_array_layer_4(0 to 15);
            doutb_layer_4 : in  bram_data_array(0 to 15);
            scale         : in  integer range 0 to 512
        );
    end component;

    component layer_6 is
        Port (
            clka   : in  std_logic; -- Clock signal
            clkb   : in  std_logic;
            resetn : in  std_logic; -- Active-low reset signal
            start  : in  std_logic; -- Start signal to begin operation
            finish : out std_logic; -- Indicates when operation is complete

            bias : in bais_array(0 to 29); -- Bias to be added after convolution

            addrb_weights_fc2 : out address_array_weights_fc2(0 to 29);
            doutb_weights_fc2 : in  bram_data_array(0 to 29);

            addrb_layer_5     : out address_array_layer_5(0 to 7);
            doutb_layer_5     : in  bram_data_array(0 to 7);
            final_predict     : out std_logic_vector(7 downto 0);
            scale             : in  integer range 0 to 512;
            output_zero_point : in  integer range 0 to 255
        );
    end component;

    type state_type is (IDLE, INIT,
            WAIT_INPUT_READ, LAYER_1_PROC,
            LAYER_2_PROC, LAYER_3_PROC,
            LAYER_4_PROC, LAYER_5_PROC,
            LAYER_6_PROC, SEND);
    signal state : state_type := IDLE;

    -- DMA Interface Signals
    -- These signals control the DMA interface and handle data transfer between CPU and BRAM
    signal mode_dma : std_logic; -- Mode for DMA interface: '0' for read, '1' for send

    -- BRAM Controller Signals
    -- These signals manage memory access for both origin and predict BRAMs

    signal wea_weights_conv2   : wea_array(0 to 95);
    signal addra_weights_conv2 : std_logic_vector(4 downto 0);
    signal dina_weights_conv2  : bram_data_array(0 to 95);
    signal douta_weights_conv2 : bram_data_array(0 to 95);
    signal web_weights_conv2   : wea_array(0 to 95);
    signal addrb_weights_conv2 : std_logic_vector(4 downto 0);
    signal dinb_weights_conv2  : bram_data_array(0 to 95);
    signal doutb_weights_conv2 : bram_data_array(0 to 95);

    signal wea_weights_fc1   : wea_array(0 to 63);
    signal addra_weights_fc1 : std_logic_vector(8 downto 0);
    signal dina_weights_fc1  : bram_data_array(0 to 63);
    signal addrb_weights_fc1 : std_logic_vector(8 downto 0);
    signal doutb_weights_fc1 : bram_data_array(0 to 63);

    signal wea_weights_fc2   : wea_array(0 to 29);
    signal addra_weights_fc2 : std_logic_vector(5 downto 0);
    signal dina_weights_fc2  : bram_data_array(0 to 29);
    signal addrb_weights_fc2 : address_array_weights_fc2(0 to 29);
    signal doutb_weights_fc2 : bram_data_array(0 to 29);

    signal scales            : scale_array(0 to 3);
    signal input_zero_point  : integer range 0 to 255;
    signal output_zero_point : integer range 0 to 255;

    -- Origin BRAM (Stores input data from CPU)
    signal wea_origin   : std_logic_vector(0 downto 0);
    signal addra_origin : std_logic_vector(9 downto 0);
    signal dina_origin  : std_logic_vector(7 downto 0);
    signal douta_origin : std_logic_vector(7 downto 0);
    signal web_origin   : std_logic_vector(0 downto 0);
    signal dinb_origin  : std_logic_vector(7 downto 0);
    signal addrb_origin : std_logic_vector(9 downto 0);
    signal doutb_origin : std_logic_vector(7 downto 0);

    -- Predict BRAM (Stores processed data for output)
    signal wea_layer_1   : wea_array(0 to 5);
    signal addra_layer_1 : std_logic_vector(9 downto 0);
    signal dina_layer_1  : bram_data_array(0 to 5);
    signal douta_layer_1 : bram_data_array(0 to 5);
    signal web_layer_1   : wea_array(0 to 5);
    signal addrb_layer_1 : std_logic_vector(9 downto 0);
    signal dinb_layer_1  : bram_data_array(0 to 5);
    signal doutb_layer_1 : bram_data_array(0 to 5);

    signal wea_layer_2   : wea_array(0 to 5);
    signal addra_layer_2 : std_logic_vector(7 downto 0);
    signal dina_layer_2  : bram_data_array(0 to 5);
    signal douta_layer_2 : bram_data_array(0 to 5);
    signal web_layer_2   : wea_array(0 to 5);
    signal addrb_layer_2 : std_logic_vector(7 downto 0);
    signal dinb_layer_2  : bram_data_array(0 to 5);
    signal doutb_layer_2 : bram_data_array(0 to 5);

    signal wea_layer_3   : wea_array(0 to 15);
    signal addra_layer_3 : std_logic_vector(6 downto 0);
    signal dina_layer_3  : bram_data_array(0 to 15);
    signal addrb_layer_3 : std_logic_vector(6 downto 0);
    signal doutb_layer_3 : bram_data_array(0 to 15);

    signal wea_layer_4   : wea_array(0 to 15);
    signal addra_layer_4 : std_logic_vector(4 downto 0);
    signal dina_layer_4  : bram_data_array(0 to 15);
    signal addrb_layer_4 : address_array_layer_4(0 to 15);
    signal doutb_layer_4 : bram_data_array(0 to 15);

    signal wea_layer_5   : wea_array(0 to 7);
    signal addra_layer_5 : std_logic_vector(2 downto 0);
    signal dina_layer_5  : bram_data_array(0 to 7);
    signal addrb_layer_5 : address_array_layer_5(0 to 7);
    signal doutb_layer_5 : bram_data_array(0 to 7);

    -- init value Signals
    signal weights_conv_1 : weights_array(0 to 5);
    signal bias_conv_1    : bais_array(0 to 5);
    signal bias_conv_2    : bais_array(0 to 15);
    signal bias_fc_1      : bais_array(0 to 63);
    signal bias_fc_2      : bais_array(0 to 29);

    -- IP Control Signals
    -- These signals control start and finish operations for various components
    signal start_dma_init    : std_logic;
    signal start_dma_predict : std_logic; -- Start signal for DMA interface

    signal start_layer_1 : std_logic; -- Start signal for Layer 1 processing
    signal start_layer_2 : std_logic;
    signal start_layer_3 : std_logic;
    signal start_layer_4 : std_logic;
    signal start_layer_5 : std_logic;
    signal start_layer_6 : std_logic;

    signal finish_dma_init    : std_logic;
    signal finish_dma_predict : std_logic;

    signal finish_layer_1 : std_logic;
    signal finish_layer_2 : std_logic;
    signal finish_layer_3 : std_logic;
    signal finish_layer_4 : std_logic;
    signal finish_layer_5 : std_logic;
    signal finish_layer_6 : std_logic;

    -- Latching Signals
    signal finish_init_latched    : integer range 0 to 5 := 0;
    signal finish_predict_latched : std_logic            := '0';

    signal active_dma            : std_logic := '0'; -- Control signal: '0' selects dma_init, '1' selects dma_predict
    signal in_tready_dma_init    : std_logic;
    signal in_tready_dma_predict : std_logic;

    signal active_origin            : std_logic := '0';
    signal addra_origin_dma_predict : std_logic_vector(9 downto 0);
    signal addra_origin_layer_1     : std_logic_vector(9 downto 0);

    signal active_layer_1_bram : std_logic := '0';                  -- debugging
                                                                    --signal addrb_layer_1_dma_predict : std_logic_vector(9 downto 0);         -- debugging
    signal addrb_layer_1_to_layer_1 : std_logic_vector(9 downto 0); -- debugging
    signal addrb_layer_1_to_layer_2 : std_logic_vector(9 downto 0); -- debugging

    signal addra_weights_conv2_dma_init : std_logic_vector(4 downto 0);
    signal addra_weights_conv2_layer_3  : std_logic_vector(4 downto 0);

    signal active_layer_2_bram   : std_logic := '0'; -- debugging
    signal addra_layer_2_layer_3 : std_logic_vector(7 downto 0);
    signal addra_layer_2_layer_2 : std_logic_vector(7 downto 0);

    signal active_layer_3_bram          : std_logic := '0';             -- debugging
    signal addrb_layer_3_to_dma_predict : std_logic_vector(6 downto 0); -- debugging
    signal addrb_layer_3_to_layer_4     : std_logic_vector(6 downto 0); -- debugging

    signal final_predict : std_logic_vector(7 downto 0);
    --signal final_predict : bram_data_array(0 to 32); --debugging

    signal clkb   : std_logic;
    signal locked : std_logic;

begin

    -- MUX logic
    s_axis_tready <= in_tready_dma_init       when active_dma = '0' else in_tready_dma_predict;
    addra_origin  <= addra_origin_dma_predict when active_origin = '0' else addra_origin_layer_1;

    --addrb_layer_1 <= addrb_layer_1_dma_predict when active_layer_1_bram = "00" else -- debugging 
    --    addrb_layer_1_to_layer_1 when active_layer_1_bram = "01" else
    --    addrb_layer_1_to_layer_2 when active_layer_1_bram = "10";

    addrb_layer_1 <= addrb_layer_1_to_layer_1 when active_layer_1_bram = '0' else addrb_layer_1_to_layer_2;

    addrb_layer_3 <= addrb_layer_3_to_dma_predict when active_layer_3_bram = '0' else addrb_layer_3_to_layer_4; -- debugging

    addra_weights_conv2 <= addra_weights_conv2_dma_init when active_dma = '0' else addra_weights_conv2_layer_3;
    addra_layer_2       <= addra_layer_2_layer_2        when active_layer_2_bram = '0' else addra_layer_2_layer_3;

        clkb_0 : clk_wiz_0 port map(
            clk_in1    => clk,
            resetn     => resetn,
            clk_out_50 => clkb,
            locked     => locked
        );

        dma_init_0 : dma_init port map(
            clka   => clk,             -- Clock
            resetn => resetn,          -- Reset
            start  => start_dma_init,  -- Start signal for DMA interface
            finish => finish_dma_init, -- Finish signal from DMA interface

            -- CPU -> DMA connections
            in_tready => in_tready_dma_init, -- Ready signal for input stream
            in_tlast  => s_axis_tlast,       -- Last signal for input stream
            in_tvalid => s_axis_tvalid,      -- Valid signal for input stream
            in_tdata  => s_axis_tdata,       -- Input data for BRAM write

            weights_conv_1      => weights_conv_1,
            bias_conv_1         => bias_conv_1,
            wea_weights_conv2   => wea_weights_conv2,
            addra_weights_conv2 => addra_weights_conv2_dma_init,
            dina_weights_conv2  => dina_weights_conv2,
            bias_conv_2         => bias_conv_2,
            wea_weights_fc1     => wea_weights_fc1,
            addra_weights_fc1   => addra_weights_fc1,
            dina_weights_fc1    => dina_weights_fc1,
            bias_fc_1           => bias_fc_1,
            wea_weights_fc2     => wea_weights_fc2,
            addra_weights_fc2   => addra_weights_fc2,
            dina_weights_fc2    => dina_weights_fc2,
            bias_fc_2           => bias_fc_2,
            scales              => scales,
            input_zero_point    => input_zero_point,
            output_zero_point   => output_zero_point
        );

        -- DMA interface: Manages data transfer between CPU and BRAM
        dma_predict_1 : dma_predict port map(
            clka   => clk,
            resetn => resetn,
            start  => start_dma_predict,
            finish => finish_dma_predict,
            mode   => mode_dma,

            --addrb_output   => addrb_layer_3_to_dma_predict, -- debugging
            --doutb_output   => doutb_layer_3(15), -- debugging

            final_predict => final_predict, -- final product

            -- CPU -> DMA connections
            in_tready => in_tready_dma_predict,
            in_tlast  => s_axis_tlast,
            in_tvalid => s_axis_tvalid,
            in_tdata  => s_axis_tdata,

            -- DMA -> CPU connections
            out_tready => m_axis_tready,
            out_tlast  => m_axis_tlast,
            out_tvalid => m_axis_tvalid,
            out_tdata  => m_axis_tdata,

            -- BRAM write connections for origin image
            wea   => wea_origin,
            addra => addra_origin_dma_predict,
            dina  => dina_origin
        );

        -- Memory Controller: Manages BRAM for origin and predict images
        memory_controller_1 : memory_controller port map(
            clka => clk, -- Clock

            wea_weights_conv2   => wea_weights_conv2,
            addra_weights_conv2 => addra_weights_conv2,
            dina_weights_conv2  => dina_weights_conv2,
            douta_weights_conv2 => douta_weights_conv2,
            web_weights_conv2   => web_weights_conv2,
            addrb_weights_conv2 => addrb_weights_conv2,
            dinb_weights_conv2  => dinb_weights_conv2,
            doutb_weights_conv2 => doutb_weights_conv2,

            wea_weights_fc1   => wea_weights_fc1,
            addra_weights_fc1 => addra_weights_fc1,
            dina_weights_fc1  => dina_weights_fc1,
            addrb_weights_fc1 => addrb_weights_fc1,
            doutb_weights_fc1 => doutb_weights_fc1,

            wea_weights_fc2   => wea_weights_fc2,
            addra_weights_fc2 => addra_weights_fc2,
            dina_weights_fc2  => dina_weights_fc2,
            addrb_weights_fc2 => addrb_weights_fc2,
            doutb_weights_fc2 => doutb_weights_fc2,

            -- Origin image BRAM connections
            wea_origin   => wea_origin,
            addra_origin => addra_origin,
            dina_origin  => dina_origin,
            douta_origin => douta_origin,
            web_origin   => web_origin,
            addrb_origin => addrb_origin,
            dinb_origin  => dinb_origin,
            doutb_origin => doutb_origin,

            -- Predict image BRAM connections
            wea_layer_1   => wea_layer_1,
            addra_layer_1 => addra_layer_1,
            dina_layer_1  => dina_layer_1,
            douta_layer_1 => douta_layer_1,
            web_layer_1   => web_layer_1,
            addrb_layer_1 => addrb_layer_1,
            dinb_layer_1  => dinb_layer_1,
            doutb_layer_1 => doutb_layer_1,

            wea_layer_2   => wea_layer_2,
            addra_layer_2 => addra_layer_2,
            dina_layer_2  => dina_layer_2,
            douta_layer_2 => douta_layer_2,
            web_layer_2   => web_layer_2,
            addrb_layer_2 => addrb_layer_2,
            dinb_layer_2  => dinb_layer_2,
            doutb_layer_2 => doutb_layer_2,

            wea_layer_3   => wea_layer_3,
            addra_layer_3 => addra_layer_3,
            dina_layer_3  => dina_layer_3,
            addrb_layer_3 => addrb_layer_3,
            doutb_layer_3 => doutb_layer_3,

            wea_layer_4   => wea_layer_4,
            addra_layer_4 => addra_layer_4,
            dina_layer_4  => dina_layer_4,
            addrb_layer_4 => addrb_layer_4,
            doutb_layer_4 => doutb_layer_4,

            wea_layer_5   => wea_layer_5,
            addra_layer_5 => addra_layer_5,
            dina_layer_5  => dina_layer_5,
            addrb_layer_5 => addrb_layer_5,
            doutb_layer_5 => doutb_layer_5
        );

        -- Processing Layer 1: Performs convolution operation on the data
        layer_1_instance : layer_1 port map(
            clka   => clk,
            clkb   => clkb,
            resetn => resetn,         -- Reset
            start  => start_layer_1,  -- Start signal for Layer 1
            finish => finish_layer_1, -- Finish signal from Layer 1

            -- Weights and biases for convolution
            weights => weights_conv_1, bias => bias_conv_1, -- Weights and bias for channel 1

            -- Predict image BRAM write connections
            wea_layer_1   => wea_layer_1,   -- Write enable for predict BRAM
            addra_layer_1 => addra_layer_1, -- Write address for predict BRAM
            dina_layer_1  => dina_layer_1,  -- Data input for predict BRAM
            web_layer_1   => web_layer_1,
            addrb_layer_1 => addrb_layer_1_to_layer_1, -- debugging => need to be: addrb_layer_1 => addrb_layer_1
            dinb_layer_1  => dinb_layer_1,

            -- Origin image BRAM read connections
            addra_origin     => addra_origin_layer_1,
            douta_origin     => douta_origin,
            addrb_origin     => addrb_origin,
            doutb_origin     => doutb_origin,
            scale            => scales(0),
            input_zero_point => input_zero_point
        );

        -- Processing Layer 1: Performs convolution operation on the data
        layer_2_instance : layer_2 port map(
            clka   => clk,
            resetn => resetn,
            start  => start_layer_2,
            finish => finish_layer_2,

            wea_layer_2   => wea_layer_2,
            addra_layer_2 => addra_layer_2_layer_2,
            dina_layer_2  => dina_layer_2,
            addrb_layer_1 => addrb_layer_1_to_layer_2, -- debugging => need to be: addrb_layer_1 => addrb_layer_1
            doutb_layer_1 => doutb_layer_1
        );

        layer_3_instance : layer_3 port map(
            clka   => clk,
            clkb   => clkb,
            resetn => resetn,
            start  => start_layer_3,
            finish => finish_layer_3,

            bias => bias_conv_2,

            addra_weights_conv2 => addra_weights_conv2_layer_3,
            douta_weights_conv2 => douta_weights_conv2,
            addrb_weights_conv2 => addrb_weights_conv2,
            doutb_weights_conv2 => doutb_weights_conv2,

            wea_layer_3   => wea_layer_3,
            addra_layer_3 => addra_layer_3,
            dina_layer_3  => dina_layer_3,
            addra_layer_2 => addra_layer_2_layer_3,
            douta_layer_2 => douta_layer_2,
            addrb_layer_2 => addrb_layer_2,
            doutb_layer_2 => doutb_layer_2,
            scale         => scales(1)
        );

        layer_4_instance : layer_4 port map(
            clka   => clk,    -- Clock
            resetn => resetn, -- Reset
            start  => start_layer_4,
            finish => finish_layer_4,

            wea_layer_4   => wea_layer_4,
            addra_layer_4 => addra_layer_4,
            dina_layer_4  => dina_layer_4,
            addrb_layer_3 => addrb_layer_3_to_layer_4,
            doutb_layer_3 => doutb_layer_3
        );

        layer_5_instance : layer_5 port map(
            clka   => clk, -- Clock
            clkb   => clkb,
            resetn => resetn, -- Reset
            start  => start_layer_5,
            finish => finish_layer_5,

            bias => bias_fc_1,

            addrb_weights_fc1 => addrb_weights_fc1,
            doutb_weights_fc1 => doutb_weights_fc1,

            wea_layer_5   => wea_layer_5,
            addra_layer_5 => addra_layer_5,
            dina_layer_5  => dina_layer_5,
            addrb_layer_4 => addrb_layer_4,
            doutb_layer_4 => doutb_layer_4,
            scale         => scales(2)
        );

        layer_6_instance : layer_6 port map(
            clka   => clk, -- Clock
            clkb   => clkb,
            resetn => resetn, -- Reset
            start  => start_layer_6,
            finish => finish_layer_6,

            bias => bias_fc_2, -- Weights and bias for channel 1

            addrb_weights_fc2 => addrb_weights_fc2,
            doutb_weights_fc2 => doutb_weights_fc2,

            addrb_layer_5     => addrb_layer_5,
            doutb_layer_5     => doutb_layer_5,
            final_predict     => final_predict,
            scale             => scales(3),
            output_zero_point => output_zero_point
        );

    -- Control process for the top module
    process(clk, resetn)
    begin
        if resetn = '0' then
            -- Reset all control signals
            start_dma_init    <= '0';
            start_dma_predict <= '0';

            start_layer_1 <= '0';
            start_layer_2 <= '0';
            start_layer_3 <= '0';
            start_layer_4 <= '0';
            start_layer_5 <= '0';
            start_layer_6 <= '0';

            finish_init_latched    <= 0;
            finish_predict_latched <= '0';

        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    mode_dma <= '0'; -- Read mode

                    if ps_signal = '1' and finish_init_latched < 5 then
                        start_dma_init <= '1';
                        state          <= INIT;

                    elsif ps_signal = '0' and finish_init_latched > 4 then
                        active_dma        <= '1';
                        start_dma_predict <= '1';
                        state             <= WAIT_INPUT_READ;
                    end if;

                when INIT =>
                    start_dma_init <= '0';
                    if finish_dma_init = '1' then
                        finish_init_latched <= finish_init_latched + 1;
                        state               <= IDLE;
                    end if;

                when WAIT_INPUT_READ =>
                    start_dma_predict <= '0';

                    if finish_dma_predict = '1' then
                        finish_predict_latched <= '1';
                    end if;

                    if finish_predict_latched = '1' and locked = '1' then
                        --active_layer_1_bram <= "01"; -- debugging
                        active_origin       <= '1';
                        active_layer_3_bram <= '1';
                        mode_dma            <= '1'; -- Send mode
                        start_layer_1       <= '1';
                        state               <= LAYER_1_PROC;
                    end if;

                when LAYER_1_PROC =>
                    start_layer_1          <= '0';
                    finish_predict_latched <= '0';

                    if finish_layer_1 = '1' then
                        --active_layer_1_bram <= "10"; -- debugging
                        active_layer_1_bram <= '1';
                        active_origin       <= '0';
                        start_layer_2       <= '1';
                        state               <= LAYER_2_PROC;
                    end if;

                when LAYER_2_PROC =>
                    start_layer_2 <= '0';

                    if finish_layer_2 = '1' then
                        active_layer_2_bram <= '1';
                        --active_layer_1_bram <= "00"; -- debugging
                        active_layer_1_bram <= '0';
                        start_layer_3       <= '1';
                        state               <= LAYER_3_PROC;
                    end if;

                when LAYER_3_PROC =>
                    start_layer_3 <= '0';

                    if finish_layer_3 = '1' then
                        active_layer_2_bram <= '0';
                        start_layer_4       <= '1';
                        state               <= LAYER_4_PROC;
                    end if;

                when LAYER_4_PROC =>
                    start_layer_4 <= '0';

                    if finish_layer_4 = '1' then
                        active_layer_3_bram <= '0';
                        start_layer_5       <= '1';
                        state               <= LAYER_5_PROC;

                    end if;

                when LAYER_5_PROC =>
                    start_layer_5 <= '0';

                    if finish_layer_5 = '1' then
                        start_layer_6 <= '1';
                        state         <= LAYER_6_PROC;
                    end if;

                when LAYER_6_PROC =>
                    start_layer_6 <= '0';

                    if finish_layer_6 = '1' then
                        start_dma_predict <= '1';
                        state             <= SEND;
                    end if;

                when SEND =>
                    start_dma_predict <= '0';
                    if finish_dma_predict = '1' then
                        mode_dma <= '0';
                        state    <= IDLE;
                    end if;

            end case;
        end if;
    end process;
end Behavioral;


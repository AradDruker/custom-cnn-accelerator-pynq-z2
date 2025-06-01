library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity TB_dma_init is
--  Port ( );
end TB_dma_init;

architecture Behavioral of TB_dma_init is

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

	constant CLK_PERIOD : time      := 10 ns;
	signal clk          : std_logic := '0';
	signal resetn       : std_logic := '1';

	signal in_tready : std_logic;
	signal in_tlast  : std_logic := '0';
	signal in_tvalid : std_logic := '0';
	signal in_tdata  : std_logic_vector(7 downto 0);

	signal start  : std_logic;
	signal finish : std_logic;

	signal weights_conv_1 : weights_array(0 to 5);
	signal bias_conv_1    : bais_array(0 to 5);
	signal bias_conv_2    : bais_array(0 to 15);
	signal bias_fc_1      : bais_array(0 to 63);
	signal bias_fc_2      : bais_array(0 to 29);

	signal resetn_flag : integer := 0;
	signal start_flag  : integer := 0;

	signal counter_layer : integer := 0;

	signal counter_channel_conv1 : integer := 0;
	signal counter_index_conv1   : integer := 0;
	signal counter_bias_conv1    : integer := 0;

	signal counter_channel_conv2 : integer := 0;
	signal counter_index_conv2   : integer := 0;
	signal counter_bias_conv2    : integer := 0;

	signal counter_channel_fc1 : integer := 0;
	signal counter_index_fc1   : integer := 0;
	signal counter_bias_fc1    : integer := 0;

	signal counter_channel_fc2 : integer := 0;
	signal counter_index_fc2   : integer := 0;
	signal counter_bias_fc2    : integer := 0;

	signal counter_index_scales_zero_point  : integer := 0;
	signal counter_number   : integer := 0;

	signal wea_weights_conv2   : wea_array(0 to 95);
	signal addra_weights_conv2 : std_logic_vector(4 downto 0);
	signal dina_weights_conv2  : bram_data_array(0 to 95);

	signal wea_weights_fc1   : wea_array(0 to 63);
	signal addra_weights_fc1 : std_logic_vector(8 downto 0);
	signal dina_weights_fc1  : bram_data_array(0 to 63);

	signal wea_weights_fc2   : wea_array(0 to 29);
	signal addra_weights_fc2 : std_logic_vector(5 downto 0);
	signal dina_weights_fc2  : bram_data_array(0 to 29);

	signal scales            : scale_array(0 to 3);
    signal input_zero_point  : integer range 0 to 255;
    signal output_zero_point : integer range 0 to 255;


begin

		dma_init_0 : dma_init port map(
			clka   => clk,    -- Clock
			resetn => resetn, -- Reset
			start  => start,  -- Start signal for DMA interface
			finish => finish, -- Finish signal from DMA interface

			-- CPU -> DMA connections
			in_tready => in_tready, -- Ready signal for input stream
			in_tlast  => in_tlast,  -- Last signal for input stream
			in_tvalid => in_tvalid, -- Valid signal for input stream
			in_tdata  => in_tdata,  -- Input data for BRAM write

			weights_conv_1      => weights_conv_1,
			bias_conv_1         => bias_conv_1,
			wea_weights_conv2   => wea_weights_conv2,
			addra_weights_conv2 => addra_weights_conv2,
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

	clk_process : process
	begin
		while true loop
			-- Generate 100 MHz clock
			clk <= '0';
			wait for CLK_PERIOD / 2;
			clk <= '1';
			wait for CLK_PERIOD / 2;
		end loop;
	end process;

	resetn_process : process(clk)
	begin
		if rising_edge(clk) then
			if resetn_flag = 0 then
				resetn      <= '0';
				resetn_flag <= 1;
			else
				resetn <= '1';
			end if;
		end if;
	end process;

	start_process : process(clk)
	begin
		if rising_edge(clk) and resetn = '1' then
			if finish = '1' then
				start_flag <= 0;
				if counter_layer = 5 then
					start_flag <= 1;
				end if;

			elsif start_flag = 0 then
				start      <= '1';
				start_flag <= 1;
			else
				start <= '0';
			end if;
		end if;
	end process;

	main_process : process(clk)
	begin
		if resetn = '1' then
			if rising_edge(clk) then
				if in_tready = '1' then
					in_tvalid <= '1';
					if counter_channel_conv1 < 6 and counter_layer = 0 then
						if counter_index_conv1 < 25 then
							in_tdata            <= "00000010";
							counter_index_conv1 <= counter_index_conv1 + 1;
						elsif counter_index_conv1 = 25 and counter_bias_conv1 < 3 then
							in_tdata           <= "11111111";
							counter_bias_conv1 <= counter_bias_conv1 + 1;
						elsif counter_index_conv1 = 25 and counter_bias_conv1 = 3 and counter_channel_conv1 < 5 then
							in_tdata              <= "11111111";
							counter_channel_conv1 <= counter_channel_conv1 + 1;
							counter_index_conv1   <= 0;
							counter_bias_conv1    <= 0;
						elsif counter_index_conv1 = 25 and counter_bias_conv1 = 3 and counter_channel_conv1 = 5 then
							in_tdata      <= "11111111";
							in_tlast      <= '1';
							counter_layer <= counter_layer + 1;
						end if;

					elsif counter_channel_conv2 < 16 and counter_layer = 1 then
						if counter_index_conv2 < 150 then
							in_tlast            <= '0';
							in_tdata            <= "00000110";
							counter_index_conv2 <= counter_index_conv2 + 1;
						elsif counter_index_conv2 = 150 and counter_bias_conv2 < 3 then
							in_tdata           <= "11111000";
							counter_bias_conv2 <= counter_bias_conv2 + 1;
						elsif counter_index_conv2 = 150 and counter_bias_conv2 = 3 and counter_channel_conv2 < 15 then
							in_tdata              <= "11111000";
							counter_channel_conv2 <= counter_channel_conv2 + 1;
							counter_index_conv2   <= 0;
							counter_bias_conv2    <= 0;
						elsif counter_index_conv2 = 150 and counter_bias_conv2 = 3 and counter_channel_conv2 = 15 then
							in_tdata      <= "11111000";
							in_tlast      <= '1';
							counter_layer <= counter_layer + 1;
						end if;

					elsif counter_channel_fc1 < 64 and counter_layer = 2 then
						if counter_index_fc1 < 400 then
							in_tlast          <= '0';
							in_tdata          <= "00010010";
							counter_index_fc1 <= counter_index_fc1 + 1;
						elsif counter_index_fc1 = 400 and counter_bias_fc1 < 3 then
							in_tdata         <= "11111110";
							counter_bias_fc1 <= counter_bias_fc1 + 1;
						elsif counter_index_fc1 = 400 and counter_bias_fc1 = 3 and counter_channel_fc1 < 63 then
							in_tdata            <= "11111110";
							counter_channel_fc1 <= counter_channel_fc1 + 1;
							counter_index_fc1   <= 0;
							counter_bias_fc1    <= 0;
						elsif counter_index_fc1 = 400 and counter_bias_fc1 = 3 and counter_channel_fc1 = 63 then
							in_tdata      <= "11111110";
							in_tlast      <= '1';
							counter_layer <= counter_layer + 1;
						end if;

					elsif counter_channel_fc2 < 30 and counter_layer = 3 then
						if counter_index_fc2 < 64 then
							in_tlast          <= '0';
							in_tdata          <= "00000010";
							counter_index_fc2 <= counter_index_fc2 + 1;
						elsif counter_index_fc2 = 64 and counter_bias_fc2 < 3 then
							in_tdata         <= "11111111";
							counter_bias_fc2 <= counter_bias_fc2 + 1;
						elsif counter_index_fc2 = 64 and counter_bias_fc2 = 3 and counter_channel_fc2 < 29 then
							in_tdata            <= "11111111";
							counter_channel_fc2 <= counter_channel_fc2 + 1;
							counter_index_fc2   <= 0;
							counter_bias_fc2    <= 0;
						elsif counter_index_fc2 = 64 and counter_bias_fc2 = 3 and counter_channel_fc2 = 29 then
							in_tdata      <= "00000001";
							in_tlast      <= '1';
							counter_layer <= counter_layer + 1;
						end if;

					elsif counter_number < 6 and counter_layer = 4 then
						if counter_index_scales_zero_point < 3 and counter_number < 4 then
							in_tlast                        <= '0';
							in_tdata                        <= "00000001";
							counter_index_scales_zero_point <= counter_index_scales_zero_point + 1;
						elsif counter_index_scales_zero_point = 3 and counter_number < 4 then
							in_tlast                        <= '0';
							in_tdata                        <= "00000001";
							counter_index_scales_zero_point <= 0;
							counter_number                  <= counter_number + 1;
						elsif counter_number = 4 then
							in_tdata       <= "00000010";
							in_tlast       <= '0';
							counter_number <= counter_number + 1;
						elsif counter_number = 5 then
							in_tdata       <= "00000100";
							in_tlast       <= '1';
							counter_number <= counter_number + 1;
							counter_layer  <= counter_layer + 1;
						end if;

					end if;
				end if;
			end if;
		end if;
	end process;
end Behavioral;
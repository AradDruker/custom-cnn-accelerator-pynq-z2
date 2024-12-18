library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;
use xil_defaultlib.FindConv2Kernel.all;

-- Entity declaration for layer_3
-- This module performs convolution operations by reading data from BRAM,
-- applying a kernel to the data, and writing the results to another BRAM.
entity layer_3 is
	Port (
		clka   : in  std_logic; -- Clock signal 
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- finish signal for higher-level control

		weights : in weights_array_conv_2(0 to 15); -- Kernel weights for convolution
		bias    : in bais_array(0 to 15);           -- Bias to be added after convolution

		wea_layer_3   : out wea_array(0 to 15);
		addra_layer_3 : out std_logic_vector(6 downto 0);
		dina_layer_3  : out bram_data_array(0 to 15);

		addrb_layer_2 : out address_array_layer_2(0 to 5);
		doutb_layer_2 : in  bram_data_array(0 to 5)
	);
end layer_3;

-- Architecture definition
architecture Behavioral of layer_3 is

	component clk_wiz_0 is
		Port (
			clk_in1  : in  std_logic;
			resetn   : in  std_logic;
			clk_out1 : out std_logic;
			locked   : out std_logic
		);
	end component;

	-- Component declaration for bram_reader
	-- Reads a 5x5 neighborhood from the origin image BRAM based on the input address array
	component bram_reader_conv2 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to initiate reading
			finish : out std_logic; -- Output signal indicating the operation is done

			r_address_array : in  address_array_layer_2(0 to 24); -- Input array of addresses to read from BRAM
			r_address       : out address_array_layer_2(0 to 5);

			data_in_bram    : in  bram_data_array(0 to 5); -- Data read from BRAM
			data_out_bram_1 : out data_array(0 to 24);     -- Processed data output array
			data_out_bram_2 : out data_array(0 to 24);
			data_out_bram_3 : out data_array(0 to 24);
			data_out_bram_4 : out data_array(0 to 24);
			data_out_bram_5 : out data_array(0 to 24);
			data_out_bram_6 : out data_array(0 to 24)
		);
	end component;

	component channel_layer_3 is
		Port (
			clka   : in  std_logic; -- Clock signal
			clkb   : in  std_logic;
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- finish signal for higher-level control

			weights : in weights_array(0 to 5); -- Kernel weights for convolution
			bias    : in signed(31 downto 0);   -- Bias to be added after convolution

			-- Predict image (write to Port A of BRAM)
			wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
			dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

			image_slices : in data_array_conv2(0 to 5)
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, DONE);
	signal state : state_type := IDLE;

	-- Signals for bram_reader
	signal r_address_array    : address_array_layer_2(0 to 24) := (others => (others => '0'));
	signal data_out_interface : data_array_conv2(0 to 5);
	signal data_compute       : data_array_conv2(0 to 5);

	signal start_bram_reader  : std_logic := '0';
	signal finish_bram_reader : std_logic := '0';

	signal start_channel : std_logic := '0';

	type finish_channel_array is array (0 to 15) of std_logic;
	signal finish_channel : finish_channel_array;

	signal finish_channel_latch     : std_logic_vector(15 downto 0) := (others => '0');
	signal finish_bram_reader_latch : std_logic                     := '0';

	signal clkb   : std_logic;
	signal locked : std_logic;

	signal address_index : integer range 0 to 99 := 0;
	signal flag_last     : std_logic             := '0';

begin

		clkb_0 : clk_wiz_0 port map(
			clk_in1  => clka,
			resetn   => resetn,
			clk_out1 => clkb,
			locked   => locked
		);

		-- Instantiation of bram_reader
		-- This module reads a 5x5 kernel from the origin image BRAM
		bram_reader_0 : bram_reader_conv2 port map(
			clka            => clka,
			resetn          => resetn,
			start           => start_bram_reader,
			finish          => finish_bram_reader,
			r_address_array => r_address_array,
			r_address       => addrb_layer_2,
			data_in_bram    => doutb_layer_2,
			data_out_bram_1 => data_out_interface(0),
			data_out_bram_2 => data_out_interface(1),
			data_out_bram_3 => data_out_interface(2),
			data_out_bram_4 => data_out_interface(3),
			data_out_bram_5 => data_out_interface(4),
			data_out_bram_6 => data_out_interface(5)
		);

	--work in progress:
	channel : for i in 0 to 15 generate
			instance : channel_layer_3 port map(
				clka         => clka,
				clkb         => clkb,
				resetn       => resetn,
				start        => start_channel,
				finish       => finish_channel(i),
				weights      => weights(i),
				bias         => bias(i),
				wea          => wea_layer_3(i),
				dina_predict => dina_layer_3(i),
				image_slices => data_compute
			);
	end generate channel;

	process(clka, resetn)

		variable row : integer range 0 to 11 := 2;
		variable col : integer range 0 to 11 := 3;

	begin
		if resetn = '0' then
			finish                   <= '0';
			finish_channel_latch     <= (others => '0');
			finish_bram_reader_latch <= '0';
			addra_layer_3            <= (others => '0');
			row                      := 2;
			col                      := 3;
			flag_last                <= '0';
			address_index            <= 0;
			state                    <= IDLE;


		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish               <= '0';
					finish_channel_latch <= (others => '0');
					row                  := 2;
					col                  := 3;
					flag_last            <= '0';
					address_index        <= 0;
					r_address_array      <= find_conv_2_kernel(2, 2);
					if start = '1' and locked = '1' then
						start_bram_reader <= '1';
						state             <= FIRST_READ;
					end if;

				when FIRST_READ =>
					start_bram_reader <= '0';
					if finish_bram_reader = '1' then
						r_address_array <= find_conv_2_kernel(2, 3);
						addra_layer_3   <= std_logic_vector(to_unsigned(address_index,7));
						address_index   <= address_index + 1;
						data_compute    <= data_out_interface;
						state           <= READ_COMPUTE;
					end if;

				when READ_COMPUTE =>
					finish_bram_reader_latch <= '0';
					finish_channel_latch     <= (others => '0');

					start_channel     <= '1';
					start_bram_reader <= '1';

					-- Update row/col indices
					if col < 11 then
						col   := col + 1;
						state <= WAIT_READ_COMPUTE;
					else
						if row < 11 then
							col   := 2;
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

					for i in 0 to 15 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_bram_reader_latch = '1' and finish_channel_latch = x"FFFF" then
						r_address_array <= find_conv_2_kernel(row, col);
						addra_layer_3   <= std_logic_vector(to_unsigned(address_index,7));
						address_index   <= address_index + 1;
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
					for i in 0 to 15 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_channel_latch = x"FFFF" then
						state <= DONE;
					end if;

				when DONE =>
					finish    <= '1';
					row       := 2;
					col       := 3;
					flag_last <= '0';
					state     <= IDLE;
			end case;
		end if;
	end process;
end Behavioral;
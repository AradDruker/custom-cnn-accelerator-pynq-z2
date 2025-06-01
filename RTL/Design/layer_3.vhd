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
end layer_3;

-- Architecture definition
architecture Behavioral of layer_3 is

	component bram_reader_conv2 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to initiate reading
			finish : out std_logic; -- Output signal indicating the operation is done

			channel_in_counter         : in integer range 0 to 5;
			r_address_array_activation : in address_array_layer_2(0 to 24);

			r_address_activation_a     : out std_logic_vector(7 downto 0);
			r_address_activation_b     : out std_logic_vector(7 downto 0);
			data_in_bram_activation_a  : in  bram_data_array(0 to 5);
			data_in_bram_activation_b  : in  bram_data_array(0 to 5);
			data_out_bram_activation_1 : out data_array(0 to 24);
			data_out_bram_activation_2 : out data_array(0 to 24);

			r_address_weights_a     : out std_logic_vector(4 downto 0);
			r_address_weights_b     : out std_logic_vector(4 downto 0);
			data_in_bram_weights_a  : in  bram_data_array(0 to 95);
			data_in_bram_weights_b  : in  bram_data_array(0 to 95);
			data_out_bram_weights_1 : out weights_array(0 to 15);
			data_out_bram_weights_2 : out weights_array(0 to 15)
		);
	end component;

	component channel_layer_3 is
		Port (
			clka   : in  std_logic; -- Clock signal
			clkb   : in  std_logic;
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- finish signal for higher-level control

			weights_1 : in kernel_array(0 to 24);
			weights_2 : in kernel_array(0 to 24);

			image_slices_1 : in data_array(0 to 24);
			image_slices_2 : in data_array(0 to 24);

			bias : in signed(31 downto 0);

			wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
			dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

			scale              : in integer range 0 to 512;
			channel_in_counter : in integer range 0 to 5
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, DONE);
	signal state : state_type := IDLE;

	-- Signals for bram_reader
	signal r_address_array_activation : address_array_layer_2(0 to 24) := (others => (others => '0'));

	signal data_out_interface_1 : data_array(0 to 24);
	signal data_out_interface_2 : data_array(0 to 24);
	signal data_compute_1       : data_array(0 to 24);
	signal data_compute_2       : data_array(0 to 24);


	signal weights_out_interface_1 : weights_array(0 to 15);
	signal weights_out_interface_2 : weights_array(0 to 15);
	signal weights_compute_1       : weights_array(0 to 15);
	signal weights_compute_2       : weights_array(0 to 15);


	signal channel_in_counter_compute : integer range 0 to 5;
	signal channel_in_counter_read    : integer range 0 to 5;

	signal start_bram_reader  : std_logic := '0';
	signal finish_bram_reader : std_logic := '0';

	signal start_channel : std_logic := '0';

	signal finish_channel : finish_channel_array(0 to 15);

	signal finish_channel_latch     : std_logic_vector(15 downto 0) := (others => '0');
	signal finish_bram_reader_latch : std_logic                     := '0';

	signal address_index : integer range 0 to 100 := 0;
	signal flag_last     : std_logic              := '0';
	signal counter_last  : integer                := 0;

begin

		-- Instantiation of bram_reader
		-- This module reads a 5x5 kernel from the origin image BRAM
		bram_reader_0 : bram_reader_conv2 port map(
			clka                       => clka,
			resetn                     => resetn,
			start                      => start_bram_reader,
			finish                     => finish_bram_reader,
			channel_in_counter         => channel_in_counter_read,
			r_address_array_activation => r_address_array_activation,
			r_address_activation_a     => addra_layer_2,
			r_address_activation_b     => addrb_layer_2,
			r_address_weights_a        => addra_weights_conv2,
			r_address_weights_b        => addrb_weights_conv2,
			data_in_bram_weights_a     => douta_weights_conv2,
			data_in_bram_weights_b     => doutb_weights_conv2,
			data_out_bram_weights_1    => weights_out_interface_1,
			data_out_bram_weights_2    => weights_out_interface_2,
			data_in_bram_activation_a  => douta_layer_2,
			data_in_bram_activation_b  => doutb_layer_2,
			data_out_bram_activation_1 => data_out_interface_1,
			data_out_bram_activation_2 => data_out_interface_2
		);

	channel : for i in 0 to 15 generate
			instance : channel_layer_3 port map(
				clka               => clka,
				clkb               => clkb,
				resetn             => resetn,
				start              => start_channel,
				finish             => finish_channel(i),
				weights_1          => weights_compute_1(i),
				weights_2          => weights_compute_2(i),
				bias               => bias(i),
				wea                => wea_layer_3(i),
				dina_predict       => dina_layer_3(i),
				image_slices_1     => data_compute_1,
				image_slices_2     => data_compute_2,
				scale              => scale,
				channel_in_counter => channel_in_counter_compute
			);
	end generate channel;

	process(clka, resetn)

		variable row : integer range 0 to 11 := 2;
		variable col : integer range 0 to 11 := 2;

	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish                     <= '0';
					finish_channel_latch       <= (others => '0');
					finish_bram_reader_latch   <= '0';
					addra_layer_3              <= (others => '0');
					row                        := 2;
					col                        := 2;
					flag_last                  <= '0';
					address_index              <= 0;
					channel_in_counter_read    <= 0;
					channel_in_counter_compute <= 0;
					counter_last               <= 0;
					r_address_array_activation <= find_conv_2_kernel(2, 2);

					if start = '1' then
						start_bram_reader <= '1';
						state             <= FIRST_READ;
					end if;

				when FIRST_READ =>
					start_bram_reader <= '0';
					if finish_bram_reader = '1' then
						addra_layer_3           <= std_logic_vector(to_unsigned(address_index,7));
						address_index           <= address_index + 1;
						channel_in_counter_read <= channel_in_counter_read + 2;
						data_compute_1          <= data_out_interface_1;
						data_compute_2          <= data_out_interface_2;
						weights_compute_1       <= weights_out_interface_1;
						weights_compute_2       <= weights_out_interface_2;
						state                   <= READ_COMPUTE;
					end if;

				when READ_COMPUTE =>
					finish_bram_reader_latch <= '0';
					finish_channel_latch     <= (others => '0');

					start_channel     <= '1';
					start_bram_reader <= '1';

					if channel_in_counter_read = 4 then
						if col < 11 then
							col := col + 1;
						else
							if row < 11 then
								col := 2;
								row := row + 1;
							end if;
						end if;
					end if;

					if channel_in_counter_compute = 4 and address_index = 100 then
						flag_last <= '1';
					end if;

					state <= WAIT_READ_COMPUTE;

				when WAIT_READ_COMPUTE =>
					-- Wait for next read operation to complete
					start_bram_reader <= '0';
					start_channel     <= '0';

					if finish_bram_reader = '1' then
						if channel_in_counter_read < 4 then
							channel_in_counter_read <= channel_in_counter_read + 2;
						elsif channel_in_counter_read = 4 then
							channel_in_counter_read <= 0;
						end if;
						finish_bram_reader_latch <= '1';
					end if;

					for i in 0 to 15 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_bram_reader_latch = '1' and finish_channel_latch = x"FFFF" then
						if channel_in_counter_compute < 4 then
							channel_in_counter_compute <= channel_in_counter_compute + 2;
						elsif channel_in_counter_compute = 4 then
							addra_layer_3              <= std_logic_vector(to_unsigned(address_index,7));
							address_index              <= address_index + 1;
							channel_in_counter_compute <= 0;
						end if;
						r_address_array_activation <= find_conv_2_kernel(row, col);
						data_compute_1             <= data_out_interface_1;
						data_compute_2             <= data_out_interface_2;
						weights_compute_1          <= weights_out_interface_1;
						weights_compute_2          <= weights_out_interface_2;

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
					finish <= '1';
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;
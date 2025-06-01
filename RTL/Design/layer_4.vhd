library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;
use xil_defaultlib.FindPool2Kernel.all;

entity layer_4 is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- Indicates when operation is complete

		wea_layer_4   : out wea_array(0 to 15);
		addra_layer_4 : out std_logic_vector(4 downto 0);
		dina_layer_4  : out bram_data_array(0 to 15);

		addrb_layer_3 : out std_logic_vector(6 downto 0);
		doutb_layer_3 : in  bram_data_array(0 to 15)
	);
end layer_4;

architecture Behavioral of layer_4 is

	component bram_reader_pool2 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to initiate reading
			finish : out std_logic; -- Output signal indicating the operation is done

			r_address_array : in  address_array_layer_3(0 to 3); -- Input array of addresses to read from BRAM
			r_address       : out std_logic_vector(6 downto 0);  -- Current address sent to BRAM

			data_in_bram  : in  bram_data_array(0 to 15); -- Data read from BRAM
			data_out_bram : out data_array_pool(0 to 15)
		);
	end component;

	component channel_max_pooling is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- finish signal for higher-level control

			wea  : out std_logic_vector(0 downto 0);
			dina : out std_logic_vector(7 downto 0);

			sample : in data_array(0 to 3)
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, DONE);
	signal state : state_type := IDLE;

	signal r_address_array    : address_array_layer_3(0 to 3) := (others => (others => '0'));
	signal data_out_interface : data_array_pool(0 to 15);
	signal data_compute       : data_array_pool(0 to 15);

	signal start_bram_reader  : std_logic := '0';
	signal finish_bram_reader : std_logic := '0';

	signal start_channel : std_logic := '0';

	signal finish_channel : finish_channel_array(0 to 15);

	signal finish_channel_latch     : std_logic_vector(15 downto 0) := (others => '0');
	signal finish_bram_reader_latch : std_logic                     := '0';

	signal address_index : integer range 0 to 24 := 0;
	signal flag_last     : std_logic             := '0';

begin

		bram_reader_0 : bram_reader_pool2 port map(
			clka            => clka,
			resetn          => resetn,
			start           => start_bram_reader,
			finish          => finish_bram_reader,
			r_address_array => r_address_array,
			r_address       => addrb_layer_3,     -- Connect to origin BRAM read address
			data_in_bram    => doutb_layer_3,     -- Data input from origin BRAM
			data_out_bram   => data_out_interface -- Output data from bram_reader
		);

	channel : for i in 0 to 15 generate
			instance : channel_max_pooling port map(
				clka   => clka,
				resetn => resetn,
				start  => start_channel,
				finish => finish_channel(i),
				wea    => wea_layer_4(i),
				dina   => dina_layer_4(i),
				sample => data_compute(i)
			);
	end generate channel;

	process(clka, resetn)

		variable row : integer range 0 to 8 := 0;
		variable col : integer range 0 to 8 := 2;

	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish                   <= '0';
					finish_channel_latch     <= (others => '0');
					finish_bram_reader_latch <= '0';
					addra_layer_4            <= (others => '0');
					row                      := 0;
					col                      := 2;
					flag_last                <= '0';
					address_index            <= 0;
					r_address_array          <= find_maxpool_kernel_neighbors(0, 0);
					if start = '1' then
						start_bram_reader <= '1';
						state             <= FIRST_READ;
					end if;

				when FIRST_READ =>
					start_bram_reader <= '0';
					if finish_bram_reader = '1' then
						r_address_array <= find_maxpool_kernel_neighbors(0, 2);
						addra_layer_4   <= std_logic_vector(to_unsigned(address_index,5));
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
					if col < 8 then
						col   := col + 2;
						state <= WAIT_READ_COMPUTE;
					else
						if row < 8 then
							col   := 0;
							row   := row + 2;
							state <= WAIT_READ_COMPUTE;
						else
							flag_last <= '1';
							state     <= WAIT_READ_COMPUTE;
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
						r_address_array <= find_maxpool_kernel_neighbors(row, col);
						addra_layer_4   <= std_logic_vector(to_unsigned(address_index,5));
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
					row       := 0;
					col       := 2;
					flag_last <= '0';
					state     <= IDLE;

			end case;
		end if;
	end process;

end Behavioral;

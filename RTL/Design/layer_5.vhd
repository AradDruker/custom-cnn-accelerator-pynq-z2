library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity layer_5 is
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
end layer_5;

architecture Behavioral of layer_5 is

	component bram_reader_fc1 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to initiate reading
			finish : out std_logic; -- Output signal indicating the operation is done

			bram_counter         : in  integer range 0 to 15;
			r_address_index      : in  integer range 0 to 24;
			r_address_activation : out address_array_layer_4(0 to 15);
			r_address_weights    : out std_logic_vector(8 downto 0);

			data_in_bram_weights  : in  bram_data_array(0 to 63);
			data_out_bram_weights : out kernel_array(0 to 63);

			data_in_bram_activation  : in  bram_data_array(0 to 15); -- Data read from BRAM
			data_out_bram_activation : out unsigned(7 downto 0)
		);
	end component;

	component channel_layer_5 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- Indicates when operation is complete

			weight : in signed(7 downto 0);  -- Kernel weights for convolution
			bias   : in signed(31 downto 0); -- Bias to be added after convolution

			compute_output : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM
			data           : in  unsigned(7 downto 0);
			scale          : in  integer range 0 to 512
		);
	end component;

	type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, WRITE, DONE);
	signal state : state_type := IDLE;

	signal data_out_interface : unsigned(7 downto 0);
	signal data_compute       : unsigned(7 downto 0);

	signal weights_out_interface : kernel_array(0 to 63);
	signal weights_compute       : kernel_array(0 to 63);

	signal compute_output_temp : bram_data_array(0 to 31);
	signal compute_output      : bram_data_array(0 to 63);

	signal bram_counter    : integer range 0 to 15 := 0;
	signal r_address_index : integer range 0 to 24 := 0;

	signal start_bram_reader  : std_logic := '0';
	signal finish_bram_reader : std_logic := '0';

	signal start_channel : std_logic := '0';

	signal finish_channel : finish_channel_array(0 to 15);
	constant ALL_ONES_16  : std_logic_vector(15 downto 0) := (others => '1');

	signal finish_channel_latch     : std_logic_vector(15 downto 0) := (others => '0');
	signal finish_bram_reader_latch : std_logic                     := '0';

	signal flag_last : std_logic := '0';
	signal counter   : std_logic := '0';

	signal batch : integer range 0 to 3 := 0;

	signal start_latch : std_logic := '0';

	signal scale_pipeline : integer range 0 to 512;

begin

	scale_pipeline <= scale;

		bram_reader_0 : bram_reader_fc1 port map(
			clka                     => clka,
			resetn                   => resetn,
			start                    => start_bram_reader,
			finish                   => finish_bram_reader,
			bram_counter             => bram_counter,
			r_address_index          => r_address_index,
			r_address_activation     => addrb_layer_4,
			r_address_weights        => addrb_weights_fc1,
			data_in_bram_weights     => doutb_weights_fc1,
			data_out_bram_weights    => weights_out_interface,
			data_in_bram_activation  => doutb_layer_4,
			data_out_bram_activation => data_out_interface
		);

	channel : for i in 0 to 15 generate
			instance : channel_layer_5 port map(
				clka           => clkb,
				resetn         => resetn,
				start          => start_channel,
				finish         => finish_channel(i),
				weight         => weights_compute(i + batch * 16),
				bias           => bias(i + batch * 16),
				compute_output => compute_output_temp(i),
				data           => data_compute,
				scale          => scale_pipeline
			);
	end generate channel;

	process(clka, resetn)

		variable first_write_flag : std_logic            := '0';
		variable index            : integer range 0 to 8 := 0;

	begin
		if resetn = '0' then
			start_latch <= '0';
			state       <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish                   <= '0'; -- Reset the finish signal
					finish_channel_latch     <= (others => '0');
					finish_bram_reader_latch <= '0';
					flag_last                <= '0';
					addra_layer_5            <= (others => '0');
					first_write_flag         := '0';
					counter                  <= '0';
					r_address_index          <= 0;
					bram_counter             <= 0;
					index                    := 0;

					if start = '1' then
						start_bram_reader <= '1';
						start_latch       <= '1';
						state             <= FIRST_READ;

					elsif start = '0' and start_latch = '1' then
						start_bram_reader <= '1';
						if batch = 3 then
							start_latch <= '0';
						end if;
						state <= FIRST_READ;
					end if;

				when FIRST_READ =>
					start_bram_reader <= '0';
					if finish_bram_reader = '1' then
						r_address_index <= r_address_index + 1;
						data_compute    <= data_out_interface;
						weights_compute <= weights_out_interface;
						state           <= READ_COMPUTE;
					end if;

				when READ_COMPUTE =>
					finish_bram_reader_latch <= '0';
					finish_channel_latch     <= (others => '0');

					start_channel     <= '1';
					start_bram_reader <= '1';

					if bram_counter = 15 and r_address_index = 24 then
						flag_last <= '1';
					end if;

					state <= WAIT_READ_COMPUTE;

				when WAIT_READ_COMPUTE =>
					-- Wait for next read operation to complete
					start_bram_reader <= '0';

					if counter = '1' then
						start_channel <= '0';
					else
						counter <= '1';
					end if;

					if finish_bram_reader = '1' then
						finish_bram_reader_latch <= '1';
					end if;

					for i in 0 to 15 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_bram_reader_latch = '1' and finish_channel_latch = ALL_ONES_16 then
						counter <= '0';
						if bram_counter < 15 and r_address_index = 24 then
							bram_counter    <= bram_counter + 1;
							r_address_index <= 0;
						elsif r_address_index < 24 then
							r_address_index <= r_address_index + 1;
						end if;
						data_compute    <= data_out_interface;
						weights_compute <= weights_out_interface;
						if flag_last = '1' then
							start_channel        <= '1';
							finish_channel_latch <= (others => '0');
							state                <= LAST_COMPUTE;
						else
							state <= READ_COMPUTE;
						end if;
					end if;

				when LAST_COMPUTE =>

					if counter = '1' then
						start_channel <= '0';
					else
						counter <= '1';
					end if;

					for i in 0 to 15 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_channel_latch = ALL_ONES_16 then

						for i in 0 to 15 loop
							compute_output(i + batch * 16) <= compute_output_temp(i);
						end loop;

						if batch = 3 then
							state <= WRITE;
							batch <= 0;
						else
							batch <= batch + 1;
							state <= IDLE;
						end if;
					end if;

				when WRITE =>
					wea_layer_5 <= (others => "0");
					if first_write_flag = '0' then
						wea_layer_5 <= (others => "1");
						for i in 0 to 7 loop
							dina_layer_5(i) <= compute_output(i * 8 + index);
						end loop;
						first_write_flag := '1';
						index            := index + 1;

					elsif index < 8 then
						wea_layer_5 <= (others => "1");
						for i in 0 to 7 loop
							dina_layer_5(i) <= compute_output(i * 8 + index);
						end loop;
						addra_layer_5 <= std_logic_vector(unsigned(addra_layer_5) + 1);
						index         := index + 1;
					else
						state <= DONE;
					end if;

				when DONE =>
					finish           <= '1';
					flag_last        <= '0';
					first_write_flag := '0';
					counter          <= '0';
					state            <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;
use xil_defaultlib.FindFinalPredict.all;


--todo: integer range for signals.
entity layer_6 is
	Port (
		clka   : in  std_logic; -- Clock signal
		clkb   : in  std_logic;
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- Indicates when operation is complete

		bias : in bais_array(0 to 14); -- Bias to be added after convolution

		addrb_weights_fc2 : out address_array_weights_fc2(0 to 14);
		doutb_weights_fc2 : in  bram_data_array(0 to 14);

		addrb_layer_5     : out address_array_layer_5(0 to 7);
		doutb_layer_5     : in  bram_data_array(0 to 7);
		final_predict     : out std_logic_vector(7 downto 0);
		scale             : in  integer range 0 to 512;
		output_zero_point : in  integer range 0 to 255
	);
end layer_6;

architecture Behavioral of layer_6 is

	component bram_reader_fc2 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to initiate reading
			finish : out std_logic; -- Output signal indicating the operation is done

			bram_counter         : in  integer range 0 to 7;
			r_address_index      : in  integer range 0 to 7;
			r_address_activation : out address_array_layer_5(0 to 7);
			r_address_weights    : out address_array_weights_fc2(0 to 14);

			data_in_bram_weights  : in  bram_data_array(0 to 14);
			data_out_bram_weights : out kernel_array(0 to 14);

			data_in_bram_activation  : in  bram_data_array(0 to 7); -- Data read from BRAM
			data_out_bram_activation : out unsigned(7 downto 0)
		);
	end component;

	component channel_layer_6 is
		Port (
			clka   : in  std_logic; -- Clock signal
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- Indicates when operation is complete

			weight : in signed(7 downto 0);  -- Kernel weights for convolution
			bias   : in signed(31 downto 0); -- Bias to be added after convolution

			compute_output    : out std_logic_vector(7 downto 0);
			data              : in  unsigned(7 downto 0);
			scale             : in  integer range 0 to 512;
			output_zero_point : in  integer range 0 to 255
		);
	end component;

	type state_type is (IDLE, FIRST_READ, READ_COMPUTE, WAIT_READ_COMPUTE, LAST_COMPUTE, POST_PROCESS, DONE);
	signal state : state_type := IDLE;

	signal data_out_interface : unsigned(7 downto 0);
	signal data_compute       : unsigned(7 downto 0);

	signal weights_out_interface : kernel_array(0 to 14);
	signal weights_compute       : kernel_array(0 to 14);

	signal compute_output : bram_data_array(0 to 14);

	signal bram_counter    : integer range 0 to 7 := 0;
	signal r_address_index : integer range 0 to 7 := 0;

	signal start_bram_reader  : std_logic := '0';
	signal finish_bram_reader : std_logic := '0';

	signal start_channel : std_logic := '0';

	signal finish_channel : finish_channel_array(0 to 14);
	constant ALL_ONES_30  : std_logic_vector(14 downto 0) := (others => '1');

	signal finish_channel_latch     : std_logic_vector(14 downto 0) := (others => '0');
	signal finish_bram_reader_latch : std_logic                     := '0';

	signal flag_last : std_logic := '0';
	signal counter   : std_logic := '0';

	signal scale_pipeline : integer range 0 to 512;

begin

	scale_pipeline <= scale;

		bram_reader_0 : bram_reader_fc2 port map(
			clka                     => clka,
			resetn                   => resetn,
			start                    => start_bram_reader,
			finish                   => finish_bram_reader,
			bram_counter             => bram_counter,
			r_address_index          => r_address_index,
			r_address_activation     => addrb_layer_5,
			r_address_weights        => addrb_weights_fc2,
			data_in_bram_weights     => doutb_weights_fc2,
			data_out_bram_weights    => weights_out_interface,
			data_in_bram_activation  => doutb_layer_5,
			data_out_bram_activation => data_out_interface
		);

	channel : for i in 0 to 14 generate
			instance : channel_layer_6 port map(
				clka              => clkb,
				resetn            => resetn,
				start             => start_channel,
				finish            => finish_channel(i),
				weight            => weights_compute(i),
				bias              => bias(i),
				compute_output    => compute_output(i),
				data              => data_compute,
				scale             => scale_pipeline,
				output_zero_point => output_zero_point
			);
	end generate channel;

	process(clka, resetn)

		variable first_write_flag : std_logic                    := '0';
		variable index            : integer range 0 to 30        := 0;
		variable max_val          : unsigned(7 downto 0)         := (others => '0');
		variable max_index        : std_logic_vector(7 downto 0) := (others => '0');

	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish                   <= '0'; -- Reset the finish signal
					finish_channel_latch     <= (others => '0');
					finish_bram_reader_latch <= '0';
					flag_last                <= '0';
					first_write_flag         := '0';
					counter                  <= '0';
					max_val                  := (others => '0');
					r_address_index          <= 0;
					bram_counter             <= 0;

					if start = '1' then
						start_bram_reader <= '1';
						state             <= FIRST_READ;
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

					if bram_counter = 7 and r_address_index = 7 then
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

					for i in 0 to 14 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_bram_reader_latch = '1' and finish_channel_latch = ALL_ONES_30 then
						counter <= '0';
						if bram_counter < 7 and r_address_index = 7 then
							bram_counter    <= bram_counter + 1;
							r_address_index <= 0;
						elsif r_address_index < 7 then
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

					for i in 0 to 14 loop
						if finish_channel(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_channel_latch = ALL_ONES_30 then
						state <= POST_PROCESS;
					end if;

				when POST_PROCESS =>
					if index < 30 then
						if unsigned(compute_output(index)) > max_val then
							max_val   := unsigned(compute_output(index));
							max_index := std_logic_vector(to_unsigned(index, 8));
						end if;
						index := index + 1;
					elsif index = 30 then
						final_predict <= max_index;
						index         := 0;
						state         <= DONE;
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

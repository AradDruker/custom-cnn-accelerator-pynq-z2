library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity channel_layer_3 is
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
end channel_layer_3;

-- Architecture definition
architecture Behavioral of channel_layer_3 is

	component relu_conv2 is
		Port (
			clkb   : in  std_logic;
			resetn : in  std_logic;
			start  : in  std_logic;
			finish : out std_logic;

			weights_1 : in kernel_array(0 to 24);
			weights_2 : in kernel_array(0 to 24);

			pixels_1 : in data_array(0 to 24);
			pixels_2 : in data_array(0 to 24);

			bias               : in  signed(31 downto 0);
			compute_output     : out std_logic_vector(7 downto 0);
			scale              : in  integer range 0 to 512;
			channel_in_counter : in  integer range 0 to 5
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, COMPUTE, DONE);
	signal state : state_type := IDLE;

	signal compute_output : std_logic_vector(7 downto 0);

	signal start_relu_conv2  : std_logic := '0';
	signal finish_relu_conv2 : std_logic := '0';

	signal counter        : integer range 0 to 1 := 0;
	signal scale_pipeline : integer range 0 to 512;

begin

	scale_pipeline <= scale;

		relu_conv2_0 : relu_conv2 port map(
			clkb               => clkb,
			resetn             => resetn,
			start              => start_relu_conv2,
			finish             => finish_relu_conv2,
			weights_1          => weights_1,
			weights_2          => weights_2,
			bias               => bias,
			compute_output     => compute_output,
			pixels_1           => image_slices_1,
			pixels_2           => image_slices_2,
			scale              => scale_pipeline,
			channel_in_counter => channel_in_counter
		);

	-- Process for read and write operations
	process(clka, resetn)
	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish  <= '0';
					counter <= 0;
					wea     <= "0"; -- Disable writing initiall
					if start = '1' then
						start_relu_conv2 <= '1';
						state            <= COMPUTE;
					end if;

				when COMPUTE =>
					if counter = 1 then
						start_relu_conv2 <= '0';
					else
						counter <= counter + 1;
					end if;

					if finish_relu_conv2 = '1' and channel_in_counter = 4 then
						wea          <= "1";
						dina_predict <= compute_output;
						state        <= DONE;

					elsif finish_relu_conv2 = '1' then
						state <= DONE;
					end if;

				when DONE =>
					finish  <= '1';
					wea     <= "0"; -- Ensure no further writes
					counter <= 0;
					state   <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;
	
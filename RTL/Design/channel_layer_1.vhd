library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- Entity declaration for layer_1
-- This module performs convolution operations by reading data from BRAM,
-- applying a kernel to the data, and writing the results to another BRAM.
entity channel_layer_1 is
	Port (
		clka   : in  std_logic; -- Clock signal
		clkb   : in  std_logic;
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- finish signal for higher-level control

		weights : in kernel_array(0 to 24); -- Kernel weights for convolution
		bias    : in signed(31 downto 0);   -- Bias to be added after convolution

		-- Predict image (write to Port A of BRAM)
		wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
		web          : out std_logic_vector(0 downto 0);
		dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM
		dinb_predict : out std_logic_vector(7 downto 0);

		image_slice             : in pixels_array(0 to 1);
		r_address_array_delayed : in address_array_delayed_layer_1(0 to 1);
		scale                   : in integer range 0 to 512;
		input_zero_point        : in integer range 0 to 255
	);
end channel_layer_1;

-- Architecture definition
architecture Behavioral of channel_layer_1 is

	component relu_conv1 is
		Port (
			clkb   : in  std_logic;
			resetn : in  std_logic;
			start  : in  std_logic;
			finish : out std_logic;

			weights          : in  kernel_array(0 to 24);
			bias             : in  signed(31 downto 0);
			pixels           : in  data_array(0 to 24);
			compute_output   : out std_logic_vector(7 downto 0);
			r_address_array  : in  address_array_layer_1(0 to 24);
			scale            : in  integer range 0 to 512;
			input_zero_point : in  integer range 0 to 255
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, COMPUTE, DONE);
	signal state : state_type := IDLE;

	type compute_output_array is array (0 to 1) of std_logic_vector(7 downto 0);
	signal compute_output : compute_output_array;

	signal start_relu_conv1  : std_logic := '0';
	signal finish_relu_conv1 : finish_channel_array(0 to 1);

	signal finish_channel_latch : std_logic_vector(1 downto 0) := (others => '0');

	signal counter : integer range 0 to 1 := 0;
	signal flag    : std_logic            := '0';

begin

	relu_conv1_0 : for i in 0 to 1 generate
			instance : relu_conv1 port map(
				clkb            => clkb,
				resetn          => resetn,
				start           => start_relu_conv1,
				finish          => finish_relu_conv1(i),
				weights         => weights,
				bias            => bias,
				pixels          => image_slice(i),
				compute_output  => compute_output(i),
				r_address_array => r_address_array_delayed(i),
				scale           => scale,
				input_zero_point => input_zero_point
			);
	end generate relu_conv1_0;

	-- Process for read and write operations
	process(clka, resetn)
	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE                       =>
					finish_channel_latch <= (others => '0');
					finish               <= '0';
					counter              <= 0;

					if start = '1' then
						start_relu_conv1 <= '1';
						state            <= COMPUTE;
					end if;

				when COMPUTE =>
					if counter = 1 then
						start_relu_conv1 <= '0';
					else
						counter <= counter + 1;
					end if;


					for i in 0 to 1 loop
						if finish_relu_conv1(i) = '1' then
							finish_channel_latch(i) <= '1';
						end if;
					end loop;

					if finish_channel_latch = "11" then
						wea <= "0";
						web <= "0";
						if flag = '0' then
							wea          <= "1";
							web          <= "1";
							dina_predict <= compute_output(0);
							dinb_predict <= compute_output(1);
							flag         <= '1';
						else
							flag  <= '0';
							state <= DONE;
						end if;
					end if;

				when DONE =>
					finish <= '1';
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

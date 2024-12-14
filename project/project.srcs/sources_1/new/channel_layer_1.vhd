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
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- finish signal for higher-level control

		weights : in kernel_array(0 to 24); -- Kernel weights for convolution
		bias    : in signed(31 downto 0);   -- Bias to be added after convolution

		-- Predict image (write to Port A of BRAM)
		wea          : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
		dina_predict : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

		image_slice : in data_array(0 to 24)
	);
end channel_layer_1;

-- Architecture definition
architecture Behavioral of channel_layer_1 is

	component relu_conv_5x5 is
		Port (
			clka   : in  std_logic;
			resetn : in  std_logic;
			start  : in  std_logic;
			finish : out std_logic;

			weights        : in  kernel_array(0 to 24);
			bias           : in  signed(31 downto 0);
			pixels         : in  data_array(0 to 24);
			compute_output : out std_logic_vector(7 downto 0)
		);
	end component;

	-- State machine definition
	type state_type is (IDLE, COMPUTE, DONE);
	signal state : state_type := IDLE;

	signal compute_output : std_logic_vector(7 downto 0);

	signal start_relu_conv_5x5  : std_logic := '0';
	signal finish_relu_conv_5x5 : std_logic := '0';

	signal flag : std_logic := '0';

begin

		relu_conv_5x5_0 : relu_conv_5x5 port map(
			clka           => clka,
			resetn         => resetn,
			start          => start_relu_conv_5x5,
			finish         => finish_relu_conv_5x5,
			weights        => weights,
			bias           => bias,
			pixels         => image_slice,
			compute_output => compute_output
		);

	-- Process for read and write operations
	process(clka, resetn)

	begin
		if resetn = '0' then
			-- Reset all control signals
			finish <= '0';
			wea    <= "0";

			flag <= '0';

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish <= '0';
					flag   <= '0';
					wea    <= "0"; -- Disable writing initiall
					if start = '1' then
						start_relu_conv_5x5 <= '1';
						state               <= COMPUTE;
					end if;


				when COMPUTE =>
					if flag = '0' then
						flag <= '1';
					else
						start_relu_conv_5x5 <= '0';
					end if;

					if finish_relu_conv_5x5 = '1' then
						wea          <= "1";
						dina_predict <= compute_output;
						state        <= DONE;
					end if;

				when DONE =>
					finish <= '1';
					wea    <= "0"; -- Ensure no further writes
					flag   <= '0';
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

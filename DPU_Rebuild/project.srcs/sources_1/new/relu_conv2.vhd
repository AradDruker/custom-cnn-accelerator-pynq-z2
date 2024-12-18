library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.float_pkg.all;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity relu_conv2 is
	Port (
		clkb   : in  std_logic;
		resetn : in  std_logic;
		start  : in  std_logic;
		finish : out std_logic;

		weights        : in  weights_array(0 to 5);
		bias           : in  signed(31 downto 0);
		pixels         : in  data_array_conv2(0 to 5);
		compute_output : out std_logic_vector(7 downto 0)
	);
end relu_conv2;

architecture Behavioral of relu_conv2 is

	-- Signals
	type state_type is (IDLE, CONV, NORMALIZE_RELU, DONE);
	signal state : state_type := IDLE;

	signal flag                    : std_logic_vector(1 downto 0) := "00";
	signal index_kernel            : integer range 0 to 25        := 0;
	signal index_channel           : integer range 0 to 6         := 0;
	signal sum                     : signed(31 downto 0)          := (others => '0');
	signal float_sum               : float32;
	signal output_float_zero_point : float32;
	signal intermediate_value      : float32;

	signal pixels_signal : data_array_conv2(0 to 5);
	signal weights_signal   : weights_array(0 to 5);

	-- Normalize signals
	constant scale              : float32               := to_float(0.002469490747898817); --effective_scale/activation_scale
	constant output_zero_point  : unsigned(31 downto 0) := to_unsigned(0, 32);
	constant weights_zero_point : signed(7 downto 0)    := to_signed(0, 8);

begin
	process(clkb, resetn)
	begin
		if resetn = '0' then
			finish         <= '0';
			flag           <= "00";
			index_kernel   <= 0;
			index_channel  <= 0;
			sum            <= (others => '0');

		elsif rising_edge(clkb) then
			case state is
				when IDLE =>
					finish         <= '0';
					flag           <= "00";
					index_kernel   <= 0;
					index_channel  <= 0;
					sum            <= (others => '0');
					weights_signal <= weights;
					pixels_signal <= pixels;
					if start = '1' then
						state <= CONV;
					end if;

				when CONV =>
					if index_channel < 6 then
						if index_kernel < 25 then
							sum <= sum + to_signed(to_integer(pixels_signal(index_channel)(index_kernel)) * 
								to_integer(weights_signal(index_channel)(index_kernel) - weights_zero_point), sum'length);
							index_kernel <= index_kernel + 1;
						else
							-- Move to next channel and reset kernel index
							index_channel <= index_channel + 1;
							index_kernel  <= 0;
						end if;
					else
						sum   <= sum + bias;
						state <= NORMALIZE_RELU;
					end if;

				when NORMALIZE_RELU =>
					if flag = "00" then
						float_sum               <= to_float(sum, float_sum);
						output_float_zero_point <= to_float(output_zero_point, output_float_zero_point);
						flag                    <= "01";

					elsif flag = "01" then
						intermediate_value <= float_sum * scale;
						flag               <= "10";

					elsif flag = "10" then
						intermediate_value <= intermediate_value + output_float_zero_point;
						flag               <= "11";
					else
						compute_output <= std_logic_vector(to_unsigned(intermediate_value, 8));
						state          <= DONE;
					end if;

				when DONE =>
					finish <= '1';
					if start = '0' then
						state <= IDLE;
					end if;
			end case;
		end if;
	end process;
end Behavioral;

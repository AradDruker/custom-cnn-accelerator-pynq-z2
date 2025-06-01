library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity relu_conv2 is
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
end relu_conv2;

architecture Behavioral of relu_conv2 is

	-- Signals
	type state_type is (IDLE, CONV, NORMALIZE_RELU, DONE);
	signal state : state_type := IDLE;

	signal flag          : std_logic_vector(1 downto 0) := "00";
	signal index_kernel  : integer range 0 to 24        := 0;

	signal scaled_sum : integer;

	signal pixels_temp_1 : data_array(0 to 24);
	signal pixels_temp_2 : data_array(0 to 24);

	signal weights_temp_1 : kernel_array(0 to 24);
	signal weights_temp_2 : kernel_array(0 to 24);

begin
	process(clkb, resetn)
		variable sum_1     : signed(31 downto 0) := to_signed(0, 32);
		variable sum_2     : signed(31 downto 0) := to_signed(0, 32);
		variable sum_total : signed(31 downto 0) := to_signed(0, 32);
	begin
		if resetn = '0' then
			state <= IDLE;

		elsif rising_edge(clkb) then
			case state is
				when IDLE =>
					finish       <= '0';
					flag         <= "00";
					index_kernel <= 0;

					if start = '1' then
						pixels_temp_1  <= pixels_1;
						weights_temp_1 <= weights_1;
						pixels_temp_2  <= pixels_2;
						weights_temp_2 <= weights_2;
						state          <= CONV;
					end if;

				when CONV =>
					sum_1 := sum_1 + to_signed(to_integer(pixels_temp_1(index_kernel)) *
							to_integer(weights_temp_1(index_kernel)), sum_1'length);
					sum_2 := sum_2 + to_signed(to_integer(pixels_temp_2(index_kernel)) *
							to_integer(weights_temp_2(index_kernel)), sum_2'length);
					index_kernel <= index_kernel + 1;

					if index_kernel = 24 and channel_in_counter < 4 then
						state <= DONE;

					elsif index_kernel = 24 and channel_in_counter = 4 then
						sum_total := sum_1 + sum_2 + bias;
						state     <= NORMALIZE_RELU;
					end if;

				when NORMALIZE_RELU =>
					if flag = "00" then
						scaled_sum <= to_integer(sum_total) * scale;
						flag       <= "01";
					elsif flag = "01" then
						scaled_sum <= to_integer(shift_right(to_signed(scaled_sum, 32), 16)); -- Logical shift by 16 bits
						flag       <= "10";
					else
						if scaled_sum > 255 then
							compute_output <= (others => '1');
						elsif scaled_sum < 0 then
							compute_output <= (others => '0');
						else
							compute_output <= std_logic_vector(to_unsigned(scaled_sum, 8));
						end if;
						sum_1 := (others => '0');
						sum_2 := (others => '0');
						sum_total := (others => '0');
						state     <= DONE;
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
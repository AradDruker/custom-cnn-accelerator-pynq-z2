library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity channel_layer_5 is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- Indicates when operation is complete

		weight : in signed(7 downto 0);  -- Kernel weights for convolution
		bias   : in signed(31 downto 0); -- Bias to be added after convolution

		compute_output : out std_logic_vector(7 downto 0);
		data           : in  unsigned(7 downto 0);
		scale          : in  integer range 0 to 512
	);
end channel_layer_5;

architecture Behavioral of channel_layer_5 is

	type state_type is (IDLE, FC ,NORMALIZE_RELU, DONE);
	signal state : state_type := IDLE;

	signal index : integer range 0 to 400       := 0;
	signal flag  : std_logic_vector(1 downto 0) := "00";

	signal scaled_sum : integer := 0; 

	signal weight_temp: signed(7 downto 0);
	signal data_temp : unsigned(7 downto 0);

begin
	process(clka, resetn)
		variable sum : signed(31 downto 0) := to_signed(0, 32);
	begin
		if resetn = '0' then
			index  <= 0;
			state <= IDLE;

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish <= '0';
					flag <= "00";
					data_temp <= data;
					weight_temp <= weight;
					if start = '1' then
						index <= index + 1;
						state <= FC;
					end if;

				when FC =>
					sum := sum + to_signed(to_integer(data_temp) *
							to_integer(weight_temp), sum'length);
					if index < 400 then
						state <= DONE;

					elsif index = 400 then
						sum   := sum + bias;
						index <= 0;
						state <= NORMALIZE_RELU;
					end if;

				when NORMALIZE_RELU =>
					if flag = "00" then
						scaled_sum <= to_integer(sum) * scale;
						flag <= "01";
					elsif flag = "01" then
						scaled_sum <= to_integer(shift_right(to_signed(scaled_sum, 32), 16)); -- Logical shift by 16 bits
						flag <= "10";
                    else
                        if scaled_sum > 255 then
                            compute_output <= (others => '1');
                        elsif scaled_sum < 0 then
                            compute_output <= (others => '0');
                        else
                            compute_output <= std_logic_vector(to_unsigned(scaled_sum, 8));
                        end if;
                        sum := (others => '0');
                        state <= DONE;
                    end if;

				when DONE =>
					finish <= '1';
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;



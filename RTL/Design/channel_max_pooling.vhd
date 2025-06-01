library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity channel_max_pooling is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- finish signal for higher-level control

		wea  : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
		dina : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

		sample : in data_array(0 to 3)
	);
end channel_max_pooling;

architecture Behavioral of channel_max_pooling is

	type state_type is (IDLE, MAXPOOL, DONE);
	signal state : state_type := IDLE;

begin
	process(clka, resetn)

		variable current_max : unsigned(7 downto 0) := (others => '0'); -- Variable for max computation

	begin
		if resetn = '0' then
			state <= IDLE;
			
		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish      <= '0';
					wea         <= "0";
					current_max := to_unsigned(0,8);
					if start = '1' then
						state <= MAXPOOL;
					end if;

				when MAXPOOL =>
					for i in 0 to 3 loop
						if unsigned(sample(i)) > current_max then
							current_max := unsigned(sample(i));
						end if;
					end loop;
					wea   <= "1";
					dina  <= std_logic_vector(current_max);
					state <= DONE;

				when DONE =>
					finish <= '1';
					wea    <= "0";
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity channel_layer_2 is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- finish signal for higher-level control

		-- Predict image (write to Port A of BRAM)
		wea_layer_2  : out std_logic_vector(0 downto 0); -- Write enable signal for predict BRAM
		dina_layer_2 : out std_logic_vector(7 downto 0); -- Data to write into predict BRAM

		sample : in data_array(0 to 3)
	);
end channel_layer_2;

architecture Behavioral of channel_layer_2 is

	type state_type is (IDLE, MAXPOOL, DONE);
    signal state : state_type := IDLE;

begin
	process(clka, resetn, start)

	variable current_max : unsigned(7 downto 0) := (others => '0'); -- Variable for max computation
	
	begin
		if resetn = '0' then
			finish <= '0';
			current_max := to_unsigned(0,8);
			wea_layer_2 <= "0";

		elsif rising_edge(clka) then
			case state is
				when IDLE =>
					finish <= '0';
					wea_layer_2 <= "0";
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
	                wea_layer_2 <= "1";
                	dina_layer_2 <= std_logic_vector(current_max);
                	state <= DONE;

               	when DONE =>
               		finish <= '1';
               		wea_layer_2 <= "0";
               		state <= IDLE;

			end case;
		end if;
	end process;



end Behavioral;

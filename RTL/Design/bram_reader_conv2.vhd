library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads data from a BRAM using an address array, processes it, and outputs the data as array.
entity bram_reader_conv2 is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to initiate reading
		finish : out std_logic; -- Output signal indicating the operation is done

		channel_in_counter         : in integer range 0 to 5;
		r_address_array_activation : in address_array_layer_2(0 to 24);

		r_address_activation_a     : out std_logic_vector(7 downto 0);
		r_address_activation_b     : out std_logic_vector(7 downto 0);
		data_in_bram_activation_a  : in  bram_data_array(0 to 5);
		data_in_bram_activation_b  : in  bram_data_array(0 to 5);
		data_out_bram_activation_1 : out data_array(0 to 24);
		data_out_bram_activation_2 : out data_array(0 to 24);

		r_address_weights_a     : out std_logic_vector(4 downto 0);
		r_address_weights_b     : out std_logic_vector(4 downto 0);
		data_in_bram_weights_a  : in  bram_data_array(0 to 95);
		data_in_bram_weights_b  : in  bram_data_array(0 to 95);
		data_out_bram_weights_1 : out weights_array(0 to 15);
		data_out_bram_weights_2 : out weights_array(0 to 15)
	);
end bram_reader_conv2;

architecture Behavioral of bram_reader_conv2 is

	type state_type is (IDLE, READ, DONE);
	signal state : state_type := IDLE;

begin
	process(clka, resetn)
		-- Internal variables to manage indices and counters
		variable index   : integer range 0 to 24 := 0; -- Index to iterate through address array
		variable counter : integer range 0 to 2  := 0; -- Counter to add delay between reads
		variable flag    : std_logic             := '0';

	begin
		-- Reset condition: Initialize all outputs and variables
		if resetn = '0' then
			state <= IDLE;

		-- Main process logic triggered on the rising edge of the clock    
		elsif rising_edge(clka) then
			case state is
				-- Idle state: Wait for the start signal to begin
				when IDLE =>
					finish  <= '0';
					index   := 0;
					counter := 0;
					flag    := '0';

					if start = '1' then
						r_address_activation_a <= r_address_array_activation(index);
						r_address_activation_b <= r_address_array_activation(index + 1);

						r_address_weights_a <= std_logic_vector(to_unsigned((index),r_address_weights_a'length));
						r_address_weights_b <= std_logic_vector(to_unsigned((index + 1),r_address_weights_b'length));

						state <= READ;
					end if;

				when READ =>
					-- Read state: Perform data read and increment the index
					if counter = 2 then
						data_out_bram_activation_1(index) <= unsigned(data_in_bram_activation_a(channel_in_counter));
						data_out_bram_activation_2(index) <= unsigned(data_in_bram_activation_a(channel_in_counter + 1));
						if index < 24 then
							data_out_bram_activation_1(index + 1) <= unsigned(data_in_bram_activation_b(channel_in_counter));
							data_out_bram_activation_2(index + 1) <= unsigned(data_in_bram_activation_b(channel_in_counter + 1));
						end if;

						for i in 0 to 15 loop
							data_out_bram_weights_1(i)(index) <= signed(data_in_bram_weights_a(i * 6 + channel_in_counter));
							data_out_bram_weights_2(i)(index) <= signed(data_in_bram_weights_a(i * 6 + channel_in_counter + 1));
							if index < 24 then
								data_out_bram_weights_1(i)(index + 1) <= signed(data_in_bram_weights_b(i * 6 + channel_in_counter));
								data_out_bram_weights_2(i)(index + 1) <= signed(data_in_bram_weights_b(i * 6 + channel_in_counter + 1));
							end if;
						end loop;

						if index = 24 then
							state <= DONE;
						else
							index                  := index + 2;
							r_address_activation_a <= r_address_array_activation(index);
							r_address_weights_a    <= std_logic_vector(to_unsigned((index),r_address_weights_a'length));
							if index < 24 then
								r_address_activation_b <= r_address_array_activation(index + 1);
								r_address_weights_b    <= std_logic_vector(to_unsigned((index + 1),r_address_weights_b'length));
							end if;
							counter := 0;
						end if;
					else
						counter := counter + 1;
					end if;

				when DONE =>
					finish <= '1';
					state  <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads data from a BRAM using an address array, processes it, and outputs the data as array.
entity bram_reader_fc2 is
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
end bram_reader_fc2;

architecture Behavioral of bram_reader_fc2 is

	type state_type is (IDLE, READ, DONE);
	signal state : state_type := IDLE;

begin
	process(clka, resetn)
		-- Internal variables to manage indices and counters
		variable counter : integer range 0 to 2 := 0; -- Counter to add delay between reads

	begin
		-- Reset condition: Initialize all outputs and variables
		if resetn = '0' then
			state                <= IDLE;

		-- Main process logic triggered on the rising edge of the clock    
		elsif rising_edge(clka) then
			case state is
				-- Idle state: Wait for the start signal to begin
				when IDLE =>
					finish  <= '0';
					counter := 0;

					if start = '1' then
						r_address_activation(bram_counter) <= std_logic_vector(to_unsigned(r_address_index,r_address_activation(r_address_index)'length));

						for i in 0 to 14 loop
							r_address_weights(i) <= std_logic_vector(to_unsigned((r_address_index + bram_counter * 8),r_address_weights(i)'length)); -- Set initial address	   
						end loop;
						state <= READ; -- Transition to READ state
					end if;

				when READ =>
					-- Read state: Perform data read and increment the index
					if counter = 2 then
						data_out_bram_activation <= unsigned(data_in_bram_activation(bram_counter));
						for i in 0 to 14 loop
							data_out_bram_weights(i) <= signed(data_in_bram_weights(i));
						end loop;
						state <= DONE; -- Transition to DONE state
					else
						counter := counter + 1; -- Increment counter
					end if;

				when DONE =>
					-- Done state: Signal completion and return to IDLE
					finish  <= '1';
					counter := 0;
					state   <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

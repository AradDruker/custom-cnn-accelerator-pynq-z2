library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads data from a BRAM using an address array, processes it, and outputs the data as array.
entity bram_reader_2x2 is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to initiate reading
		finish : out std_logic; -- Output signal indicating the operation is done

		r_address_array : in  address_array_layer_1(0 to 3);        -- Input array of addresses to read from BRAM
		r_address       : out address_array_layer_1(0 to 5); -- Current address sent to BRAM

		data_in_bram    : in  bram_data_array(0 to 5); -- Data read from BRAM
		data_out_bram_1 : out data_array(0 to 3);      -- Processed data output array
		data_out_bram_2 : out data_array(0 to 3);      -- Processed data output array
		data_out_bram_3 : out data_array(0 to 3);      -- Processed data output array
		data_out_bram_4 : out data_array(0 to 3);      -- Processed data output array
		data_out_bram_5 : out data_array(0 to 3);      -- Processed data output array
		data_out_bram_6 : out data_array(0 to 3)       -- Processed data output array
	);
end bram_reader_2x2;

architecture Behavioral of bram_reader_2x2 is

	type state_type is (IDLE, READ, DONE);
	signal state : state_type := IDLE;

begin
	process(clka, resetn, start)

		-- Internal variables to manage indices and counters
		variable index   : integer range 0 to 3 := 0; -- Index to iterate through address array
		variable counter : integer range 0 to 2  := 0; -- Counter to add delay between reads

	begin
		-- Reset condition: Initialize all outputs and variables
		if resetn = '0' then
			finish    <= '0';
			index     := 0;
			counter   := 0;
			r_address <= (others => (others => '0'));
			state     <= IDLE;

		-- Main process logic triggered on the rising edge of the clock    
		elsif rising_edge(clka) then
			case state is
				-- Idle state: Wait for the start signal to begin
				when IDLE =>
					finish    <= '0';
					index     := 0;
					counter   := 0;
					r_address <= (others => (others => '0'));

					if start = '1' then
						for i in 0 to 5 loop
							r_address(i) <= r_address_array(index); -- Set initial address	   
						end loop;    
						state     <= READ; 
					end if;

				when READ =>
					-- Read state: Perform data read and increment the index
					if counter = 2 then                                      -- Delay for two clock cycles
						data_out_bram_1(index) <= unsigned(data_in_bram(0)); -- Store data
						data_out_bram_2(index) <= unsigned(data_in_bram(1));
						data_out_bram_3(index) <= unsigned(data_in_bram(2));
						data_out_bram_4(index) <= unsigned(data_in_bram(3));
						data_out_bram_5(index) <= unsigned(data_in_bram(4));
						data_out_bram_6(index) <= unsigned(data_in_bram(5));

						if index = 3 then  -- Check if all addresses are read
							state <= DONE; -- Transition to DONE state
						else
							index     := index + 1;              -- Move to next address
							for i in 0 to 5 loop
								r_address(i) <= r_address_array(index); -- Set initial address	   
							end loop; 
							counter   := 0;                      -- Reset counter
						end if;
					else
						counter := counter + 1; -- Increment counter
					end if;

				when DONE =>
					-- Done state: Signal completion and return to IDLE
					finish    <= '1';
					index     := 0;
					counter   := 0;
					r_address <= (others => (others => '0'));
					state     <= IDLE;

			end case;
		end if;
	end process;
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads data from a BRAM using an address array, processes it, and outputs the data as array.
entity bram_reader is
    Port (
        clka   : in  std_logic; -- Clock signal
        resetn : in  std_logic; -- Active-low reset signal
        start  : in  std_logic; -- Start signal to initiate reading
        finish : out std_logic; -- Output signal indicating the operation is done

        r_address_array : in  address_array_layer_1(0 to 24);       -- Input array of addresses to read from BRAM
        r_address       : out std_logic_vector(9 downto 0); -- Current address sent to BRAM

        data_in_bram       : in  std_logic_vector(7 downto 0); -- Data read from BRAM
        data_out_interface : out data_array(0 to 24)           -- Processed data output array
    );
end bram_reader;

architecture Behavioral of bram_reader is

    type state_type is (IDLE, READ, DONE);
    signal state : state_type := IDLE;

begin
    process(clka, resetn, start)

        constant padding_address : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(784, 10));
        -- Internal variables to manage indices and counters
        variable index   : integer range 0 to 24 := 0; -- Index to iterate through address array
        variable counter : integer range 0 to 2  := 0; -- Counter to add delay between reads

    begin
        -- Reset condition: Initialize all outputs and variables
        if resetn = '0' then
            finish    <= '0';
            index     := 0;
            counter   := 0;    
            r_address <= (others => '0');
            state     <= IDLE;

        -- Main process logic triggered on the rising edge of the clock    
        elsif rising_edge(clka) then
            case state is
                -- Idle state: Wait for the start signal to begin
                when IDLE =>
                    finish    <= '0';
                    index     := 0;
                    counter   := 0;
                    r_address <= (others => '0');

                    if start = '1' then
                        r_address <= r_address_array(index); -- Set initial address
                        state     <= READ;                   -- Transition to READ state
                    end if;

                when READ =>
                    -- Read state: Perform data read and increment the index
                    if counter = 2 then -- Delay for two clock cycles
                        if r_address_array(index) = padding_address then
                            data_out_interface(index) <= (others => '0');
                        else
                            data_out_interface(index) <= unsigned(data_in_bram); -- Store data
                        end if;

                        if index = 24 then -- Check if all addresses are read
                            state <= DONE; -- Transition to DONE state
                        else
                            index     := index + 1;              -- Move to next address
                            r_address <= r_address_array(index); -- Update address
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
                    r_address <= (others => '0');
                    state     <= IDLE;

            end case;
        end if;
    end process;
end Behavioral;

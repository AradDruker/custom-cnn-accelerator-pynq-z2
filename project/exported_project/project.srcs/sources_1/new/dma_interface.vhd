library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- This module handles data transfer between RAM and DMA, supporting both read and write modes.
entity dma_interface is
    Port (
        clka: in std_logic;                             -- Clock signal
        resetn: in std_logic;                           -- Active-low reset signal
        start: in std_logic;                            -- Start signal to begin operation
        finish: out std_logic;                          -- Indicates when operation is complete
        mode: in std_logic;                             -- Mode selector: '0' for write, '1' for send
        
        -- SEND state
        addrb_output: out std_logic_vector(7 downto 0); -- Address for RAM read operation for DMA -
        doutb_output: in std_logic_vector(7 downto 0);  -- Data read from RAM corresponding to addrb_output
        
        out_tready: in std_logic;                       -- Ready signal for output stream
        out_tlast: out std_logic;                       -- Last signal for output stream
        out_tvalid: out std_logic;                      -- Valid signal for output stream
        out_tdata: out std_logic_vector(7 downto 0);    -- Data output for sending via DMA

        -- WRITE STATE     
        wea: out std_logic_vector(0 downto 0);          -- Write enable for RAM
        addra: out std_logic_vector(9 downto 0);        -- Address for RAM write operation
        dina: out std_logic_vector(7 downto 0) ;        -- Data to write into RAM

        in_tready: out std_logic;                       -- Ready signal for input stream
        in_tlast: in std_logic;                         -- Last signal for input stream
        in_tvalid: in std_logic;                        -- Valid signal for input stream
        in_tdata: in std_logic_vector(7 downto 0)       -- Data input for writing to RAM
    );
end dma_interface;

architecture Behavioral of dma_interface is

    type state_type is (IDLE, WRITE, LAST_WRITE, SEND, DONE);
    signal state: state_type := IDLE;
    
    signal addra_internal: std_logic_vector(9 downto 0) := (others => '0'); -- Internal write address for RAM
    signal addrb_output_internal: std_logic_vector(7 downto 0) := (others => '0'); -- Internal read address for RAM
 
begin

    -- Map internal signals to entity ports
    addra <= addra_internal;
    addrb_output <= addrb_output_internal;

    process(clka, resetn, start, mode)
    
    -- Constant for the last address in RAM
    constant last_address_write: std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(783, 10));
    constant last_address_send: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(195, 8));
    -- Variables for iteration and delay
    variable counter: integer range 0 to 2 := 0;
    variable first_write_flag: std_logic := '0';       -- Indicates the first write operation
    
    begin
        -- Reset condition: Initialize signals and state
        if resetn = '0' then
            finish <= '0';
            out_tvalid <= '0';
            out_tlast <= '0';
            in_tready <= '0';
            addra_internal <= (others => '0');
            addrb_output_internal <= (others => '0');   
            first_write_flag := '0';  
            counter := 0;       
            wea <= "0";
            state <= IDLE;
            
        elsif rising_edge(clka) then
            case state is
                -- Idle state: Wait for the start signal and determine mode
                when IDLE =>
                    finish <= '0';
                    out_tvalid <= '0';
                    out_tlast <= '0';
                    in_tready <= '0';
                    addra_internal <= (others => '0');
                    addrb_output_internal <= (others => '0');   
                    first_write_flag := '0';   
                    counter := 0;      
                    wea <= "0";
                    
                    if start = '1' then
                        -- Write mode: Enable input stream and prepare to write
                        if mode = '0' then
                            wea <= "1";
                            state <= WRITE;  
                        -- Send mode: Prepare for DMA data transfer     
                        elsif mode = '1' then
                            state <= SEND;
                        end if;
                    end if;
                    
                when WRITE =>
                    in_tready <= '1';
                    -- Write state: Write data to RAM from input stream
                    if in_tvalid = '1' and first_write_flag = '0' then
                        dina <= in_tdata; -- Write input data to RAM
                        first_write_flag := '1';
                                                    
                    elsif in_tvalid = '1' and first_write_flag = '1' then
                        addra_internal <= std_logic_vector(to_unsigned(to_integer(unsigned(addra_internal)) + 1, addra'length));
                        dina <= in_tdata; -- Write input data to RAM
                        if in_tlast = '1' then
                            -- Transition to LAST_WRITE
                            state <= LAST_WRITE;          
                        end if;
                    end if;

                when LAST_WRITE =>  
                    addra_internal <= last_address_write;
                    dina <= in_tdata;
                    state <= DONE;

                when SEND =>
                    -- Send state: Send data from RAM via DMA
                    if out_tready = '1' then 
                        if counter = 2 then -- Add delay before sending next data
                            out_tvalid <= '1';
                            out_tdata <= doutb_output; -- Send current data
                            if addrb_output_internal = last_address_send then
                                out_tlast <= '1';
                                state <= DONE;
                            else
                                -- Increment address for next data
                                addrb_output_internal <= std_logic_vector(to_unsigned(to_integer(unsigned(addrb_output_internal)) + 1, 8));
                                counter := 0;
                            end if;
                        else
                            out_tvalid <= '0';
                            counter := counter + 1; -- Increment counter for delay                      
                        end if;
                    end if;
                    
                when DONE =>
                    -- Done state: Reset signals and return to IDLE
                    finish <= '1';
                    in_tready <= '0';
                    out_tlast <= '0';
                    out_tvalid <= '0';
                    addra_internal <= (others => '0');
                    addrb_output_internal <= (others => '0');  
                    first_write_flag := '0';  
                    counter := 0; 
                    wea <= "0";
                    state <= IDLE;   
                    
            end case;
        end if;
    end process;
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads weights and biases from multiple ROM blocks and outputs them for further processing.
entity rom_reader is
    Port (
        clk    : in  std_logic; -- Clock signal
        resetn : in  std_logic; -- Active-low reset signal
        start  : in  std_logic; -- Start signal to initiate read operation
        finish : out std_logic; -- Signal indicating the operation is complete

        -- Outputs for weights and biases
        weights_1 : out kernel_array(0 to 24); -- Weights from ROM_0 (Port A)
        bias_1    : out signed(31 downto 0);   -- Bias from ROM_0 (Port A)

        weights_2 : out kernel_array(0 to 24); -- Weights from ROM_0 (Port B)
        bias_2    : out signed(31 downto 0);   -- Bias from ROM_0 (Port B)

        weights_3 : out kernel_array(0 to 24); -- Weights from ROM_1 (Port A)
        bias_3    : out signed(31 downto 0);   -- Bias from ROM_1 (Port A)

        weights_4 : out kernel_array(0 to 24); -- Weights from ROM_1 (Port B)
        bias_4    : out signed(31 downto 0);   -- Bias from ROM_1 (Port B)

        weights_5 : out kernel_array(0 to 24); -- Weights from ROM_2 (Port A)
        bias_5    : out signed(31 downto 0);   -- Bias from ROM_2 (Port A)

        weights_6 : out kernel_array(0 to 24); -- Weights from ROM_2 (Port B)
        bias_6    : out signed(31 downto 0)    -- Bias from ROM_2 (Port B)
    );
end rom_reader;

-- Architecture definition
architecture Behavioral of rom_reader is

    -- Component declaration for ROM memory blocks
    component blk_mem_gen_0 IS
        Port (
            clka  : IN  std_logic;                      -- Clock signal for Port A
            addra : IN  std_logic_vector(0 downto 0);   -- Address for Port A
            douta : OUT std_logic_vector(231 downto 0); -- Data output from Port A
            clkb  : IN  std_logic;                      -- Clock signal for Port B
            addrb : IN  std_logic_vector(0 downto 0);   -- Address for Port B
            doutb : OUT std_logic_vector(231 downto 0)  -- Data output from Port B
        );
    END component;

    component blk_mem_gen_1 IS
        Port (
            clka  : IN  std_logic;
            addra : IN  std_logic_vector(0 downto 0);
            douta : OUT std_logic_vector(231 downto 0);
            clkb  : IN  std_logic;
            addrb : IN  std_logic_vector(0 downto 0);
            doutb : OUT std_logic_vector(231 downto 0)
        );
    END component;

    component blk_mem_gen_2 IS
        Port (
            clka  : IN  std_logic;
            addra : IN  std_logic_vector(0 downto 0);
            douta : OUT std_logic_vector(231 downto 0);
            clkb  : IN  std_logic;
            addrb : IN  std_logic_vector(0 downto 0);
            doutb : OUT std_logic_vector(231 downto 0)
        );
    END component;

    -- State machine definition
    type state_type is (IDLE, READ, DONE);
    signal state : state_type := IDLE;

    -- Signals for data from ROM blocks
    signal r_data_1, r_data_2 : std_logic_vector(231 downto 0);
    signal r_data_3, r_data_4 : std_logic_vector(231 downto 0);
    signal r_data_5, r_data_6 : std_logic_vector(231 downto 0);

    -- Signals for ROM addresses
    signal r_address_A : std_logic_vector(0 downto 0) := "0"; -- Address for Port A
    signal r_address_B : std_logic_vector(0 downto 0) := "1"; -- Address for Port B

begin

        -- ROM block instantiation for reading weights and biases
        ROM_0 : blk_mem_gen_0 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_1, doutb => r_data_2
        );

        ROM_1 : blk_mem_gen_1 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_3, doutb => r_data_4
        );

        ROM_2 : blk_mem_gen_2 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_5, doutb => r_data_6
        );

    -- Process for reading weights and biases
    process(clk, resetn, start)
    begin
        if resetn = '0' then
            finish <= '0'; -- Reset the finish signal

        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    finish <= '0'; -- Reset the finish signal
                    if start = '1' then
                        state <= READ; -- Transition to READ state
                    end if;

                when READ =>
                    -- Extract weights and biases from ROM data
                    for i in 0 to 24 loop
                        if (i * 8 + 7 <= 199) then
                            weights_1(i) <= signed(r_data_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_2(i) <= signed(r_data_2((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_3(i) <= signed(r_data_3((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_4(i) <= signed(r_data_4((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_5(i) <= signed(r_data_5((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_6(i) <= signed(r_data_6((231 - (i * 8)) downto (224 - (i * 8))));
                        end if;
                    end loop;

                    -- Extract biases from ROM data
                    bias_1 <= signed(r_data_1(31 downto 0));
                    bias_2 <= signed(r_data_2(31 downto 0));
                    bias_3 <= signed(r_data_3(31 downto 0));
                    bias_4 <= signed(r_data_4(31 downto 0));
                    bias_5 <= signed(r_data_5(31 downto 0));
                    bias_6 <= signed(r_data_6(31 downto 0));

                    state <= DONE; -- Transition to DONE state

                when DONE =>
                    finish <= '1';  -- Signal completion
                    state  <= IDLE; -- Return to IDLE state

            end case;
        end if;
    end process;

end Behavioral;

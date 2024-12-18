library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

-- This module reads weights and biases from multiple ROM blocks and outputs them for further processing.
entity rom_reader is
    Port (
        clk          : in  std_logic; -- Clock signal
        resetn       : in  std_logic; -- Active-low reset signal
        start_conv_1 : in  std_logic; -- Start signal to initiate read operation
        start_conv_2 : in  std_logic; -- Start signal to initiate read operation
        finish       : out std_logic; -- Signal indicating the operation is complete

        weights_conv_1 : out weights_array(0 to 5);
        bias_conv_1    : out bais_array(0 to 5);

        weights_conv_2 : out weights_array_conv_2(0 to 15);
        bias_conv_2    : out bais_array(0 to 15)
    );
end rom_reader;

-- Architecture definition
architecture Behavioral of rom_reader is

    -- Component declaration for ROM memory blocks
    component blk_mem_gen_0 IS
        Port (
            clka  : in  std_logic;                      -- Clock signal for Port A
            addra : in  std_logic_vector(0 downto 0);   -- Address for Port A
            douta : out std_logic_vector(231 downto 0); -- Data output from Port A
            clkb  : in  std_logic;                      -- Clock signal for Port B
            addrb : in  std_logic_vector(0 downto 0);   -- Address for Port B
            doutb : out std_logic_vector(231 downto 0)  -- Data output from Port B
        );
    end component;

    component blk_mem_gen_1 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_2 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_5 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_6 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_7 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_8 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_9 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_10 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_11 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_12 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(3 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    -- State machine definition
    type state_type is (IDLE, READ_CONV_1, READ_CONV_2, DONE);
    signal state : state_type := IDLE;

    -- Signals for data from ROM blocks
    signal r_data_1_conv1, r_data_2_conv1 : std_logic_vector(231 downto 0);
    signal r_data_3_conv1, r_data_4_conv1 : std_logic_vector(231 downto 0);
    signal r_data_5_conv1, r_data_6_conv1 : std_logic_vector(231 downto 0);

    signal r_data_1_conv2, r_data_2_conv2   : std_logic_vector(231 downto 0);
    signal r_data_3_conv2, r_data_4_conv2   : std_logic_vector(231 downto 0);
    signal r_data_5_conv2, r_data_6_conv2   : std_logic_vector(231 downto 0);
    signal r_data_7_conv2, r_data_8_conv2   : std_logic_vector(231 downto 0);
    signal r_data_9_conv2, r_data_10_conv2  : std_logic_vector(231 downto 0);
    signal r_data_11_conv2, r_data_12_conv2 : std_logic_vector(231 downto 0);
    signal r_data_13_conv2, r_data_14_conv2 : std_logic_vector(231 downto 0);
    signal r_data_15_conv2, r_data_16_conv2 : std_logic_vector(231 downto 0);

    -- Signals for ROM addresses
    signal r_address_A_conv1 : std_logic_vector(0 downto 0) := "0"; -- Address for Port A
    signal r_address_B_conv1 : std_logic_vector(0 downto 0) := "1"; -- Address for Port B

    signal r_address_A_conv2 : std_logic_vector(3 downto 0) := "0000"; -- Address for Port A
    signal r_address_B_conv2 : std_logic_vector(3 downto 0) := "0110"; -- Address for Port A

begin

        -- ROM blocks: CONV1
        ROM_1_conv_1 : blk_mem_gen_0 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv1, addrb => r_address_B_conv1,
            douta => r_data_1_conv1, doutb => r_data_2_conv1
        );
        ROM_2_conv_1 : blk_mem_gen_1 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv1, addrb => r_address_B_conv1,
            douta => r_data_3_conv1, doutb => r_data_4_conv1
        );
        ROM_3_conv_1 : blk_mem_gen_2 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv1, addrb => r_address_B_conv1,
            douta => r_data_5_conv1, doutb => r_data_6_conv1
        );

        -- ROM blocks: CONV2
        ROM_1_conv_2 : blk_mem_gen_5 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_1_conv2, doutb => r_data_2_conv2
        );
        ROM_2_conv_2 : blk_mem_gen_6 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_3_conv2, doutb => r_data_4_conv2
        );
        ROM_3_conv_2 : blk_mem_gen_7 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_5_conv2, doutb => r_data_6_conv2
        );
        ROM_4_conv_2 : blk_mem_gen_8 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_7_conv2, doutb => r_data_8_conv2
        );
        ROM_5_conv_2 : blk_mem_gen_9 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_9_conv2, doutb => r_data_10_conv2
        );
        ROM_6_conv_2 : blk_mem_gen_10 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_11_conv2, doutb => r_data_12_conv2
        );
        ROM_7_conv_2 : blk_mem_gen_11 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_13_conv2, doutb => r_data_14_conv2
        );
        ROM_8_conv_2 : blk_mem_gen_12 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A_conv2, addrb => r_address_B_conv2,
            douta => r_data_15_conv2, doutb => r_data_16_conv2
        );

    -- Process for reading weights and biases
    process(clk, resetn)

        variable index   : integer range 0 to 5 := 0; -- Index to iterate through address array
        variable counter : integer range 0 to 2 := 0;

    begin
        if resetn = '0' then
            finish            <= '0';
            index             := 0;
            counter           := 0;
            r_address_A_conv2 <= "0000"; -- Address for Port A
            r_address_B_conv2 <= "0110"; -- Address for Port A

        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    finish            <= '0';
                    index             := 0;
                    counter           := 0;
                    r_address_A_conv2 <= "0000"; -- Address for Port A
                    r_address_B_conv2 <= "0110"; -- Address for Port A
                    if start_conv_1 = '1' then
                        state <= READ_CONV_1; -- Transition to READ state
                    elsif start_conv_2 = '1' then
                        state <= READ_CONV_2; -- Transition to READ state
                    end if;

                when READ_CONV_1 =>
                    -- Extract weights and biases from ROM data
                    for i in 0 to 24 loop
                        if (i * 8 + 7 <= 199) then
                            weights_conv_1(0)(i) <= signed(r_data_1_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(1)(i) <= signed(r_data_2_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(2)(i) <= signed(r_data_3_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(3)(i) <= signed(r_data_4_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(4)(i) <= signed(r_data_5_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(5)(i) <= signed(r_data_6_conv1((231 - (i * 8)) downto (224 - (i * 8))));
                        end if;
                    end loop;

                    -- Extract biases from ROM data
                    bias_conv_1(0) <= signed(r_data_1_conv1(31 downto 0));
                    bias_conv_1(1) <= signed(r_data_2_conv1(31 downto 0));
                    bias_conv_1(2) <= signed(r_data_3_conv1(31 downto 0));
                    bias_conv_1(3) <= signed(r_data_4_conv1(31 downto 0));
                    bias_conv_1(4) <= signed(r_data_5_conv1(31 downto 0));
                    bias_conv_1(5) <= signed(r_data_6_conv1(31 downto 0));

                    state <= DONE; -- Transition to DONE state

                when READ_CONV_2 =>
                    if counter = 2 then
                        -- Extract weights and biases from ROM data
                        for i in 0 to 24 loop
                            if (i * 8 + 7 <= 199) then
                                weights_conv_2(0)(index)(i)  <= signed(r_data_1_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(1)(index)(i)  <= signed(r_data_2_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(2)(index)(i)  <= signed(r_data_3_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(3)(index)(i)  <= signed(r_data_4_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(4)(index)(i)  <= signed(r_data_5_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(5)(index)(i)  <= signed(r_data_6_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(6)(index)(i)  <= signed(r_data_7_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(7)(index)(i)  <= signed(r_data_8_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(8)(index)(i)  <= signed(r_data_9_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(9)(index)(i)  <= signed(r_data_10_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(10)(index)(i) <= signed(r_data_11_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(11)(index)(i) <= signed(r_data_12_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(12)(index)(i) <= signed(r_data_13_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(13)(index)(i) <= signed(r_data_14_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(14)(index)(i) <= signed(r_data_15_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                                weights_conv_2(15)(index)(i) <= signed(r_data_16_conv2((231 - (i * 8)) downto (224 - (i * 8))));
                            end if;
                        end loop;

                        -- Extract biases from ROM data
                        bias_conv_2(0)  <= signed(r_data_1_conv2(31 downto 0));
                        bias_conv_2(1)  <= signed(r_data_2_conv2(31 downto 0));
                        bias_conv_2(2)  <= signed(r_data_3_conv2(31 downto 0));
                        bias_conv_2(3)  <= signed(r_data_4_conv2(31 downto 0));
                        bias_conv_2(4)  <= signed(r_data_5_conv2(31 downto 0));
                        bias_conv_2(5)  <= signed(r_data_6_conv2(31 downto 0));
                        bias_conv_2(6)  <= signed(r_data_7_conv2(31 downto 0));
                        bias_conv_2(7)  <= signed(r_data_8_conv2(31 downto 0));
                        bias_conv_2(8)  <= signed(r_data_9_conv2(31 downto 0));
                        bias_conv_2(9)  <= signed(r_data_10_conv2(31 downto 0));
                        bias_conv_2(10) <= signed(r_data_11_conv2(31 downto 0));
                        bias_conv_2(11) <= signed(r_data_12_conv2(31 downto 0));
                        bias_conv_2(12) <= signed(r_data_13_conv2(31 downto 0));
                        bias_conv_2(13) <= signed(r_data_14_conv2(31 downto 0));
                        bias_conv_2(14) <= signed(r_data_15_conv2(31 downto 0));
                        bias_conv_2(15) <= signed(r_data_16_conv2(31 downto 0));

                        if index = 5 then  -- Check if all addresses are read
                            state <= DONE; -- Transition to DONE state
                        else
                            r_address_A_conv2 <= std_logic_vector(to_unsigned(to_integer(unsigned(r_address_A_conv2)) + 1, r_address_A_conv2'length));
                            r_address_B_conv2 <= std_logic_vector(to_unsigned(to_integer(unsigned(r_address_B_conv2)) + 1, r_address_B_conv2'length));
                            index             := index + 1; -- Move to next address
                            counter           := 0;         -- Reset counter
                        end if;
                    else
                        counter := counter + 1; -- Increment counter
                    end if;

                when DONE =>
                    finish <= '1';  -- Signal completion
                    state  <= IDLE; -- Return to IDLE state

            end case;
        end if;
    end process;

end Behavioral;

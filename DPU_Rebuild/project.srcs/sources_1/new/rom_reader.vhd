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

        weights_conv_2 : out weights_array(0 to 15);
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
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_6 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_7 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_8 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_9 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_10 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_11 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    component blk_mem_gen_12 IS
        Port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(0 downto 0);
            douta : out std_logic_vector(231 downto 0);
            clkb  : in  std_logic;
            addrb : in  std_logic_vector(0 downto 0);
            doutb : out std_logic_vector(231 downto 0)
        );
    end component;

    -- State machine definition
    type state_type is (IDLE, READ_CONV_1, READ_CONV_2, DONE);
    signal state : state_type := IDLE;

    -- Signals for data from ROM blocks
    signal r_data_1_conv_1, r_data_2_conv_1 : std_logic_vector(231 downto 0);
    signal r_data_3_conv_1, r_data_4_conv_1 : std_logic_vector(231 downto 0);
    signal r_data_5_conv_1, r_data_6_conv_1 : std_logic_vector(231 downto 0);

    signal r_data_1, r_data_2   : std_logic_vector(231 downto 0);
    signal r_data_3, r_data_4   : std_logic_vector(231 downto 0);
    signal r_data_5, r_data_6   : std_logic_vector(231 downto 0);
    signal r_data_7, r_data_8   : std_logic_vector(231 downto 0);
    signal r_data_9, r_data_10  : std_logic_vector(231 downto 0);
    signal r_data_11, r_data_12 : std_logic_vector(231 downto 0);
    signal r_data_13, r_data_14 : std_logic_vector(231 downto 0);
    signal r_data_15, r_data_16 : std_logic_vector(231 downto 0);

    -- Signals for ROM addresses
    signal r_address_A : std_logic_vector(0 downto 0) := "0"; -- Address for Port A
    signal r_address_B : std_logic_vector(0 downto 0) := "1"; -- Address for Port B

begin

        -- ROM blocks: CONV1
        ROM_1_conv_1 : blk_mem_gen_0 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_1_conv_1, doutb => r_data_2_conv_1
        );
        ROM_2_conv_1 : blk_mem_gen_1 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_3_conv_1, doutb => r_data_4_conv_1
        );
        ROM_3_conv_1 : blk_mem_gen_2 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_5_conv_1, doutb => r_data_6_conv_1
        );

        -- ROM blocks: CONV2
        ROM_1_conv_2 : blk_mem_gen_5 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_1, doutb => r_data_2
        );
        ROM_2_conv_2 : blk_mem_gen_6 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_3, doutb => r_data_4
        );
        ROM_3_conv_2 : blk_mem_gen_7 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_5, doutb => r_data_6
        );
        ROM_4_conv_2 : blk_mem_gen_8 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_7, doutb => r_data_8
        );
        ROM_5_conv_2 : blk_mem_gen_9 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_9, doutb => r_data_10
        );
        ROM_6_conv_2 : blk_mem_gen_10 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_11, doutb => r_data_12
        );
        ROM_7_conv_2 : blk_mem_gen_11 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_13, doutb => r_data_14
        );
        ROM_8_conv_2 : blk_mem_gen_12 port map(
            clka  => clk, clkb => clk,
            addra => r_address_A, addrb => r_address_B,
            douta => r_data_15, doutb => r_data_16
        );

    -- Process for reading weights and biases
    process(clk, resetn)
    begin
        if resetn = '0' then
            finish <= '0';

        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    finish <= '0';
                    if start_conv_1 = '1' then
                        state <= READ_CONV_1; -- Transition to READ state
                    elsif start_conv_2 = '1' then
                        state <= READ_CONV_2; -- Transition to READ state
                    end if;

                when READ_CONV_1 =>
                    -- Extract weights and biases from ROM data
                    for i in 0 to 24 loop
                        if (i * 8 + 7 <= 199) then
                            weights_conv_1(0)(i) <= signed(r_data_1_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(1)(i) <= signed(r_data_2_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(2)(i) <= signed(r_data_3_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(3)(i) <= signed(r_data_4_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(4)(i) <= signed(r_data_5_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_1(5)(i) <= signed(r_data_6_conv_1((231 - (i * 8)) downto (224 - (i * 8))));
                        end if;
                    end loop;

                    -- Extract biases from ROM data
                    bias_conv_1(0) <= signed(r_data_1_conv_1(31 downto 0));
                    bias_conv_1(1) <= signed(r_data_2_conv_1(31 downto 0));
                    bias_conv_1(2) <= signed(r_data_3_conv_1(31 downto 0));
                    bias_conv_1(3) <= signed(r_data_4_conv_1(31 downto 0));
                    bias_conv_1(4) <= signed(r_data_5_conv_1(31 downto 0));
                    bias_conv_1(5) <= signed(r_data_6_conv_1(31 downto 0));

                    state <= DONE; -- Transition to DONE state

                when READ_CONV_2 =>
                    -- Extract weights and biases from ROM data
                    for i in 0 to 24 loop
                        if (i * 8 + 7 <= 199) then
                            weights_conv_2(0)(i)  <= signed(r_data_1((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(1)(i)  <= signed(r_data_2((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(2)(i)  <= signed(r_data_3((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(3)(i)  <= signed(r_data_4((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(4)(i)  <= signed(r_data_5((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(5)(i)  <= signed(r_data_6((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(6)(i)  <= signed(r_data_7((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(7)(i)  <= signed(r_data_8((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(8)(i)  <= signed(r_data_9((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(9)(i)  <= signed(r_data_10((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(10)(i) <= signed(r_data_11((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(11)(i) <= signed(r_data_12((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(12)(i) <= signed(r_data_13((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(13)(i) <= signed(r_data_14((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(14)(i) <= signed(r_data_15((231 - (i * 8)) downto (224 - (i * 8))));
                            weights_conv_2(15)(i) <= signed(r_data_16((231 - (i * 8)) downto (224 - (i * 8))));
                        end if;
                    end loop;

                    -- Extract biases from ROM data
                    bias_conv_2(0)  <= signed(r_data_1(31 downto 0));
                    bias_conv_2(1)  <= signed(r_data_2(31 downto 0));
                    bias_conv_2(2)  <= signed(r_data_3(31 downto 0));
                    bias_conv_2(3)  <= signed(r_data_4(31 downto 0));
                    bias_conv_2(4)  <= signed(r_data_5(31 downto 0));
                    bias_conv_2(5)  <= signed(r_data_6(31 downto 0));
                    bias_conv_2(6)  <= signed(r_data_7(31 downto 0));
                    bias_conv_2(7)  <= signed(r_data_8(31 downto 0));
                    bias_conv_2(8)  <= signed(r_data_9(31 downto 0));
                    bias_conv_2(9)  <= signed(r_data_10(31 downto 0));
                    bias_conv_2(10) <= signed(r_data_11(31 downto 0));
                    bias_conv_2(11) <= signed(r_data_12(31 downto 0));
                    bias_conv_2(12) <= signed(r_data_13(31 downto 0));
                    bias_conv_2(13) <= signed(r_data_14(31 downto 0));
                    bias_conv_2(14) <= signed(r_data_15(31 downto 0));
                    bias_conv_2(15) <= signed(r_data_16(31 downto 0));

                    state <= DONE; -- Transition to DONE state  

                when DONE =>
                    finish <= '1';  -- Signal completion
                    state  <= IDLE; -- Return to IDLE state

            end case;
        end if;
    end process;

end Behavioral;

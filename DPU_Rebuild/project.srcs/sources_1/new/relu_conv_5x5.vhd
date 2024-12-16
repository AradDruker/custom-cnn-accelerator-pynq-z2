library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.float_pkg.all;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity relu_conv_5x5 is
    Port (
        clkb   : in  std_logic;
        resetn : in  std_logic;
        start  : in  std_logic;
        finish : out std_logic;

        weights         : in  kernel_array(0 to 24);
        bias            : in  signed(31 downto 0);
        pixels          : in  data_array(0 to 24);
        compute_output  : out std_logic_vector(7 downto 0);
        r_address_array : in  address_array_layer_1(0 to 24)
    );
end relu_conv_5x5;

architecture Behavioral of relu_conv_5x5 is

    -- Signals
    type state_type is (IDLE, PREPROCESS, CONV, NORMALIZE_RELU, DONE);
    signal state : state_type := IDLE;

    signal flag                    : std_logic_vector(1 downto 0) := "00";
    signal index                   : integer                      := 0;
    signal sum                     : signed(31 downto 0)          := (others => '0');
    signal float_sum               : float32;
    signal output_float_zero_point : float32;
    signal intermediate_value      : float32;

    signal processed_pixels : kernel_array(0 to 24);
    signal weights_signal   : kernel_array(0 to 24);

    -- Normalize signals
    constant scale              : float32               := to_float(0.0019096031845096618); --effective_scale/activation_scale
    constant output_zero_point  : unsigned(31 downto 0) := to_unsigned(0, 32);
    constant input_zero_point   : unsigned(7 downto 0)  := to_unsigned(127, 8);
    constant weights_zero_point : signed(7 downto 0)    := to_signed(0, 8);

    constant padding_address : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(784, 10));

begin
    process(clkb, resetn, start)
    begin
        if resetn = '0' then
            finish <= '0';
            flag   <= "00";
            index  <= 0;
            sum    <= (others => '0');

        elsif rising_edge(clkb) then
            case state is
                when IDLE =>
                    finish         <= '0';
                    flag           <= "00";
                    index          <= 0;
                    sum            <= (others => '0');
                    weights_signal <= weights;
                    if start = '1' and finish = '0' then
                        state <= PREPROCESS;
                    end if;

                when PREPROCESS =>
                    for i in 0 to 24 loop
                        if r_address_array(i) = padding_address then
                            processed_pixels(i) <= to_signed(0, 8);
                        else
                            processed_pixels(i) <= to_signed(to_integer(pixels(i)) - to_integer(input_zero_point), 8);
                        end if;
                    end loop;
                    state <= CONV;

                when CONV =>
                    -- Accumulate sum for the first 24 values
                    if index < 25 then
                        sum   <= sum + (processed_pixels(index) * (weights_signal(index) - weights_zero_point));
                        index <= index + 1;
                    else
                        -- Add bias after the loop
                        sum   <= sum + bias;
                        state <= NORMALIZE_RELU;
                    end if;

                when NORMALIZE_RELU =>
                    if flag = "00" then
                        float_sum               <= to_float(sum, float_sum);
                        output_float_zero_point <= to_float(output_zero_point, output_float_zero_point);
                        flag                    <= "01";

                    elsif flag = "01" then
                        intermediate_value <= float_sum * scale;
                        flag               <= "10";

                    elsif flag = "10" then
                        intermediate_value <= intermediate_value + output_float_zero_point;
                        flag               <= "11";
                    else
                        compute_output <= std_logic_vector(to_unsigned(intermediate_value, 8));
                        state          <= DONE;
                    end if;

                when DONE =>
                    finish <= '1';
                    if start = '0' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;

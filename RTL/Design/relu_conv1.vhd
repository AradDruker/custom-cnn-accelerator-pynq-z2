library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity relu_conv1 is
    Port (
        clkb   : in  std_logic;
        resetn : in  std_logic;
        start  : in  std_logic;
        finish : out std_logic;

        weights          : in  kernel_array(0 to 24);
        bias             : in  signed(31 downto 0);
        pixels           : in  data_array(0 to 24);
        compute_output   : out std_logic_vector(7 downto 0);
        r_address_array  : in  address_array_layer_1(0 to 24);
        scale            : in  integer range 0 to 512;
        input_zero_point : in  integer range 0 to 255
    );
end relu_conv1;

architecture Behavioral of relu_conv1 is

    -- Signals
    type state_type is (IDLE, PREPROCESS, CONV, NORMALIZE_RELU, DONE);
    signal state : state_type := IDLE;

    signal flag       : std_logic_vector(1 downto 0) := "00";
    signal index      : integer range 0 to 25        := 0;
    signal sum        : signed(31 downto 0)          := (others => '0');
    signal scaled_sum : integer                      := 0;

    signal processed_pixels : kernel_array(0 to 24);
    signal weights_signal   : kernel_array(0 to 24);

    constant padding_address : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(784, 10));

begin
    process(clkb, resetn)
    begin
        if resetn = '0' then
            state <= IDLE;

        elsif rising_edge(clkb) then
            case state is
                when IDLE =>
                    finish <= '0';
                    flag   <= "00";
                    index  <= 0;
                    sum    <= (others => '0');

                    weights_signal <= weights;
                    if start = '1' then
                        state <= PREPROCESS;
                    end if;

                when PREPROCESS =>
                    for i in 0 to 24 loop
                        if r_address_array(i) = padding_address then
                            processed_pixels(i) <= to_signed(0, 8);
                        else
                            processed_pixels(i) <= to_signed(to_integer(pixels(i)) - input_zero_point, 8);
                        end if;
                    end loop;
                    state <= CONV;

                when CONV =>
                    -- Accumulate sum for the first 24 values
                    if index < 25 then
                        sum   <= sum + (processed_pixels(index) * weights_signal(index));
                        index <= index + 1;
                    else
                        -- Add bias after the loop
                        sum   <= sum + bias;
                        state <= NORMALIZE_RELU;
                    end if;

                when NORMALIZE_RELU =>
                    if flag = "00" then
                        scaled_sum <= to_integer(sum) * scale;
                        flag       <= "01";
                    elsif flag = "01" then
                        scaled_sum <= to_integer(shift_right(to_signed(scaled_sum, 32), 16)); -- Logical shift by 16 bits
                        flag       <= "10";
                    else
                        if scaled_sum > 255 then
                            compute_output <= (others => '1');
                        elsif scaled_sum < 0 then
                            compute_output <= (others => '0');
                        else
                            compute_output <= std_logic_vector(to_unsigned(scaled_sum, 8));
                        end if;
                        state <= DONE;
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

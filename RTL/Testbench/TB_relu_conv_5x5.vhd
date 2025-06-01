library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity TB_relu_conv_5x5 is
--  Port ( );
end TB_relu_conv_5x5;

architecture Behavioral of TB_relu_conv_5x5 is

	component relu_conv_5x5 is
	    Port ( 
	        clka: in std_logic;
	        resetn: in std_logic;
	        start: in std_logic;
	        finish: out std_logic;

	        weights: in kernel_array(0 to 24); 
	        bias: in signed(31 downto 0);
	        pixels: in data_array(0 to 24);
	        compute_output: out std_logic_vector(7 downto 0)
	    );
	end component;

    signal clka: std_logic := '0';
    signal resetn: std_logic := '1';   
    signal start: std_logic := '0';
    signal finish: std_logic;

    signal weights : kernel_array(0 to 24) := (
    to_signed(-10, 8),
    to_signed(21, 8),
    to_signed(26, 8),
    to_signed(-106, 8),
    to_signed(-7, 8),
    to_signed(-40, 8),
    to_signed(28, 8),
    to_signed(43, 8),
    to_signed(18, 8),
    to_signed(-29, 8),
    to_signed(-73, 8),
    to_signed(5, 8),
    to_signed(54, 8),
    to_signed(38, 8),
    to_signed(32, 8),
    to_signed(-106, 8),
    to_signed(26, 8),
    to_signed(82, 8),
    to_signed(83, 8),
    to_signed(-125, 8),
    to_signed(-40, 8),
    to_signed(10, 8),
    to_signed(103, 8),
    to_signed(-25, 8),
    to_signed(-89, 8)
    );

    signal bias: signed(31 downto 0) := to_signed(-6850, 32);

    signal pixels: data_array(0 to 24) := (
        to_unsigned(0, 8), to_unsigned(0, 8),  to_unsigned(0, 8),   to_unsigned(0, 8),   to_unsigned(0, 8),    -- Row 1
        to_unsigned(0, 8), to_unsigned(0, 8),  to_unsigned(0, 8),   to_unsigned(0, 8),   to_unsigned(0, 8),    -- Row 2
        to_unsigned(0, 8), to_unsigned(0, 8),  to_unsigned(255, 8), to_unsigned(255, 8), to_unsigned(255, 8),  -- Row 3
        to_unsigned(0, 8), to_unsigned(0, 8),  to_unsigned(255, 8), to_unsigned(255, 8), to_unsigned(255, 8),  -- Row 4
        to_unsigned(0, 8), to_unsigned(0, 8),  to_unsigned(255, 8), to_unsigned(255, 8), to_unsigned(255, 8)   -- Row 5
    );

    constant CLK_PERIOD: time := 10 ns;
    signal compute_output: std_logic_vector(7 downto 0);

begin

U1: relu_conv_5x5 port map(
		clka => clka,
		resetn => resetn,
		start => start,
		finish => finish,
		weights => weights,
		bias => bias,
		pixels => pixels,
		compute_output => compute_output
	);

    clka_process: process
    begin
        while true loop
            clka <= '0';
            wait for CLK_PERIOD / 2;
            clka <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    main_process: process
    begin
        resetn <= '0'; wait for 20ns;
        resetn <= '1';

        start <= '1'; wait for 20ns;
        start <= '0';

        wait until finish = '1';    
        wait;
    end process;
end Behavioral;
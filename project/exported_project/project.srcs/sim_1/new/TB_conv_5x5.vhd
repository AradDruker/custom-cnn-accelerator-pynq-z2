library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_conv_5x5 is
--  Port ( );
end TB_conv_5x5;

architecture Behavioral of TB_conv_5x5 is

    component conv_5x5 is
        Port ( 
            clka: in  std_logic;
            resetn: in  std_logic;                            
            start: in std_logic;
            finish: out std_logic;
            image_input: in unsigned(199 downto 0);
            kernel_input: in unsigned(199 downto 0);
            final_output: out unsigned(15 downto 0) 
        );
    end component; 
    
    signal clka: std_logic := '0';
    signal resetn: std_logic := '1';
    signal start: std_logic := '0';
    signal finish: std_logic := '0';
    signal image_input: unsigned(199 downto 0);
    signal kernel_input: unsigned(199 downto 0);
    signal final_output: unsigned(15 downto 0);
    
    -- Clock period
    constant CLK_PERIOD: time := 10 ns;

begin

U1: conv_5x5 port map(
    clka => clka,
    resetn => resetn, 
    start => start, 
    finish => finish, 
    image_input => image_input, 
    kernel_input => kernel_input, 
    final_output => final_output
    );

    -- Clock Generation
    clk_process: process
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
        resetn <= '0'; wait for 100ns;
        resetn <= '1';
        
        image_input <= X"01" & X"01" &  X"01" &  X"01" &  X"01" & X"01" & X"01" &  X"01" &  X"01" &  X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01";
        kernel_input <= X"01" & X"01" &  X"01" &  X"01" &  X"01" & X"01" & X"01" &  X"01" &  X"01" &  X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01" & X"01";
    
        start <= '1'; wait for 50ns;
        start <= '0'; 
        wait;
    end process;
end Behavioral;

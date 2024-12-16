library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_rom_reader is
--  Port ( );
end TB_rom_reader;

architecture Behavioral of TB_rom_reader is

    component rom_reader is
        Port (
            clk: in  std_logic;
            resetn: in  std_logic;                            
            start: in std_logic;
            finish: out std_logic;
            rom_output_1: out std_logic_vector(207 downto 0);
            rom_output_2: out std_logic_vector(207 downto 0);
            rom_output_3: out std_logic_vector(207 downto 0);
            rom_output_4: out std_logic_vector(207 downto 0);
            rom_output_5: out std_logic_vector(207 downto 0);
            rom_output_6: out std_logic_vector(207 downto 0)
        );
    end component;
    
    signal clk: std_logic := '0';
    signal resetn: std_logic := '1';
    signal start: std_logic := '0';
    signal finish: std_logic := '0';
    signal rom_output_1: std_logic_vector(207 downto 0);
    signal rom_output_2: std_logic_vector(207 downto 0);
    signal rom_output_3: std_logic_vector(207 downto 0);
    signal rom_output_4: std_logic_vector(207 downto 0);
    signal rom_output_5: std_logic_vector(207 downto 0);
    signal rom_output_6: std_logic_vector(207 downto 0);
    
    -- Clock period
    constant CLK_PERIOD: time := 10 ns;

begin

U1: rom_reader port map(
    clk => clk,
    resetn => resetn, 
    start => start, 
    finish => finish, 
    rom_output_1 => rom_output_1,
    rom_output_2 => rom_output_2,
    rom_output_3 => rom_output_3,
    rom_output_4 => rom_output_4,
    rom_output_5 => rom_output_5,
    rom_output_6 => rom_output_6
    );
    
    -- Clock Generation
    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;
    
    
    main_process: process
    begin
        resetn <= '0'; wait for 100ns;
        resetn <= '1';
        
        start <= '1'; wait for 10ns;
        start <= '0'; 
        wait;
    end process;

end Behavioral;

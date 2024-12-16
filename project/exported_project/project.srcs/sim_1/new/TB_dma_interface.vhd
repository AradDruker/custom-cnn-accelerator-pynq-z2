library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_dma_interface is
--  Port ( );
end TB_dma_interface;

architecture Behavioral of TB_dma_interface is

    component dma_interface is
        Port (
            clka: in  std_logic;
            resetn: in  std_logic;                            
            start: in std_logic;
            finish: out std_logic;
            mode: in std_logic;
            data_in_pl: in std_logic_vector(15 downto 0);
            data_out_pl: out std_logic_vector(199 downto 0);
            
            in_tready: out std_logic;
            in_tlast: in std_logic; 
            in_tvalid: in std_logic; 
            in_tdata: in std_logic_vector(7 downto 0);
        
            out_tready: in std_logic;
            out_tlast: out std_logic; 
            out_tvalid: out std_logic; 
            out_tdata: out std_logic_vector(15 downto 0) -- to be changed when avgpool implented        
        );
    end component;

    signal clka: std_logic := '0';
    signal resetn: std_logic := '1';
    signal start: std_logic := '0';
    signal finish: std_logic := '0';
    
    signal in_tready: std_logic := '0';
    signal in_tlast: std_logic := '0';
    signal in_tvalid: std_logic := '0';
    signal in_tdata: std_logic_vector(7 downto 0) := "00000001";
    
    signal out_tready: std_logic := '0';
    signal out_tlast: std_logic := '0';
    signal out_tvalid: std_logic := '0';
    signal out_tdata: std_logic_vector(15 downto 0) := (others => '0');
    
    signal data_in_pl: std_logic_vector(15 downto 0) := x"FFFF";
    signal data_out_pl: std_logic_vector(199 downto 0);
    signal mode: std_logic;
    
    constant CLK_PERIOD: time := 10 ns;
    signal output: std_logic_vector(15 downto 0);

begin

U1: dma_interface port map(
    clka => clka,
    resetn => resetn,
    start => start,
    finish => finish,
    mode => mode,
    data_in_pl => data_in_pl,
    data_out_pl => data_out_pl,
    in_tready => in_tready,
    in_tlast => in_tlast,
    in_tvalid => in_tvalid,
    in_tdata => in_tdata,
    out_tready => out_tready,
    out_tlast => out_tlast,
    out_tvalid => out_tvalid,
    out_tdata => out_tdata                               
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
    
    READ: process
    begin
        resetn <= '0'; wait for 20ns;
        resetn <= '1';
        
        mode <= '0'; --read
        start <= '1';
        wait until in_tready = '1';
        in_tvalid <= '1';
        for counter in 0 to 783 loop
            in_tdata <= std_logic_vector(to_unsigned(to_integer(unsigned( in_tdata )) + 1, in_tdata'length));
            if counter = 783 then
                in_tlast <= '1';
            end if;
            wait until rising_edge(clka);
        end loop;
        wait;
    end process;
 
--    SEND: process
--    begin
--        resetn <= '0'; wait for 100ns;
--        resetn <= '1';
--        mode <= '1'; --read
--        start <= '1'; wait for 50ns;
--        out_tready <= '1'; wait for 10 ns;
--        if out_tvalid = '1' then
--            output <= out_tdata;
            
--        wait until out_tlast = '1';
--        end if;
    
--        wait;    

--    end process;
end Behavioral;

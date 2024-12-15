library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_top is
--  Port ( );
end TB_top;

architecture Behavioral of TB_top is

    component top is
        Port ( 
            clk: in std_logic;
            resetn: in std_logic;
            --input into rtl from from axi dma
            s_axis_tready: out std_logic;
            s_axis_tlast: in std_logic;
            s_axis_tvalid: in std_logic;
            s_axis_tdata: in std_logic_vector(7 downto 0);
            -- output axi
            m_axis_tready: in std_logic;
            m_axis_tlast: out std_logic;
            m_axis_tvalid: out std_logic;
            m_axis_tdata: out std_logic_vector(7 downto 0)
        );
    end component;

    signal clk: std_logic := '0';
    signal resetn: std_logic := '1';

    signal in_tready: std_logic := '0';
    signal in_tlast: std_logic := '0';
    signal in_tvalid: std_logic := '0';
    signal in_tdata: std_logic_vector(7 downto 0) := "11111110";
    
    signal out_tready: std_logic := '0';
    signal out_tlast: std_logic := '0';
    signal out_tvalid: std_logic := '0';
    signal out_tdata: std_logic_vector(7 downto 0);
    
    constant CLK_PERIOD: time := 10 ns;
    signal output: std_logic_vector(7 downto 0);

begin

U1: top port map(
        clk => clk,
        resetn => resetn,
        s_axis_tready => in_tready,
        s_axis_tlast => in_tlast,
        s_axis_tvalid => in_tvalid,
        s_axis_tdata => in_tdata,
        m_axis_tready => out_tready,
        m_axis_tlast => out_tlast,
        m_axis_tvalid => out_tvalid,
        m_axis_tdata => out_tdata    
    );
      
    clk_process: process
    begin
        while true loop
            -- Generate 100 MHz clock
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;
    
    main_process: process
    begin
        resetn <= '0'; wait for 20ns;
        resetn <= '1';
        wait until in_tready = '1';
        in_tvalid <= '1';
        for counter in 0 to 783 loop
            if counter = 783 then
                in_tlast <= '1';
            end if;
            wait until rising_edge(clk);
--            in_tdata <= std_logic_vector(to_unsigned(to_integer(unsigned(in_tdata)) + 1, in_tdata'length));
        end loop;
        
        in_tvalid <= '0';
        in_tlast <= '0';
        
        out_tready <= '1';
        wait until out_tvalid = '1' and out_tlast = '1';
        output <= out_tdata;
        
        wait;
    end process;
end Behavioral;

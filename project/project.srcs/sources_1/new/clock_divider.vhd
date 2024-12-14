library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clock_divider is
    Port (
        clka   : in std_logic;
        resetn : in std_logic;

        half_clka : out std_logic
    );
end clock_divider;

architecture Behavioral of clock_divider is

    signal internal_half_clka : std_logic := '0';

begin

    half_clka <= internal_half_clka;

    process(clka, resetn)
    begin
        if resetn = '0' then
            internal_half_clka <= '0';

        elsif rising_edge(clka) then
            internal_half_clka <= not internal_half_clka;
        end if;
    end process;

end Behavioral;

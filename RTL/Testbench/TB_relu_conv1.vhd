library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity TB_relu_conv1 is
--  Port ( );
end TB_relu_conv1;

architecture Behavioral of TB_relu_conv1 is

	component relu_conv1 is
		Port (
			clkb   : in  std_logic;
			resetn : in  std_logic;
			start  : in  std_logic;
			finish : out std_logic;

			weights         : in  kernel_array(0 to 24);
			bias            : in  signed(31 downto 0);
			pixels          : in  data_array(0 to 24);
			compute_output  : out std_logic_vector(7 downto 0);
			r_address_array : in  address_array_layer_1(0 to 24);
			scale           : in  integer
		);
	end component;

	signal clka   : std_logic := '0';
	signal resetn : std_logic := '1';
	signal start  : std_logic := '0';
	signal finish : std_logic;

	signal weights         : kernel_array(0 to 24) := (others => to_signed(100, 8));
	signal bias            : signed(31 downto 0)   := to_signed(5, 32);
	signal pixels          : data_array(0 to 24)   := (others => to_unsigned(254, 8));
	signal compute_output  : std_logic_vector(7 downto 0);
	signal r_address_array : address_array_layer_1(0 to 24);

	constant scale : integer := integer(0.0018913120729848742 * 2**16); -- Scale value in fixed-point (scaled by 256)

	constant CLK_PERIOD : time := 10 ns;

	signal resetn_flag : integer := 0;
	signal start_flag  : integer := 0;

begin

		U1 : relu_conv1 port map(
			clkb            => clka,
			resetn          => resetn,
			start           => start,
			finish          => finish,
			bias            => bias,
			weights         => weights,
			pixels          => pixels,
			compute_output  => compute_output,
			r_address_array => r_address_array,
			scale           => scale
		);

	clka_process : process
	begin
		while true loop
			clka <= '0';
			wait for CLK_PERIOD / 2;
			clka <= '1';
			wait for CLK_PERIOD / 2;
		end loop;
	end process;

	resetn_process : process(clka)
	begin
		if rising_edge(clka) then
			if resetn_flag = 0 then
				resetn      <= '0';
				resetn_flag <= 1;
			else
				resetn <= '1';
			end if;
		end if;
	end process;

	start_process : process(clka)
	begin
		if rising_edge(clka) and resetn = '1' then
			if start_flag = 0 then
				start      <= '1';
				start_flag <= 1;
			else
				start <= '0';
			end if;
		end if;
	end process;

end Behavioral;
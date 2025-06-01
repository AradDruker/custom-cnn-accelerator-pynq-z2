library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity TB_layer_3 is
--  Port ( );
end TB_layer_3;

architecture Behavioral of TB_layer_3 is

	component layer_3 is
		Port (
			clka   : in  std_logic; -- Clock signal 
			clkb   : in  std_logic;
			resetn : in  std_logic; -- Active-low reset signal
			start  : in  std_logic; -- Start signal to begin operation
			finish : out std_logic; -- finish signal for higher-level control

			bias : in bais_array(0 to 15); -- Bias to be added after convolution

			addra_weights_conv2 : out std_logic_vector(4 downto 0);
			douta_weights_conv2 : in  bram_data_array(0 to 95);
			addrb_weights_conv2 : out std_logic_vector(4 downto 0);
			doutb_weights_conv2 : in  bram_data_array(0 to 95);

			wea_layer_3   : out wea_array(0 to 15);
			addra_layer_3 : out std_logic_vector(6 downto 0);
			dina_layer_3  : out bram_data_array(0 to 15);

			addra_layer_2 : out std_logic_vector(7 downto 0);
			douta_layer_2 : in  bram_data_array(0 to 5);
			addrb_layer_2 : out std_logic_vector(7 downto 0);
			doutb_layer_2 : in  bram_data_array(0 to 5)
		);
	end component;

	signal clka   : std_logic := '0';
	signal clkb   : std_logic := '0';
	signal resetn : std_logic := '1';
	signal start  : std_logic := '0';
	signal finish : std_logic;

	signal bias : bais_array(0 to 15) := (others => to_signed(5, 32));

	constant CLK_PERIOD : time := 10 ns;

	signal resetn_flag : integer := 0;
	signal start_flag  : integer := 0;

	signal wea_layer_3   : wea_array(0 to 15);
	signal addra_layer_3 : std_logic_vector(6 downto 0);
	signal dina_layer_3  : bram_data_array(0 to 15);

	signal addra_layer_2 : std_logic_vector(7 downto 0);
	signal douta_layer_2 : bram_data_array(0 to 5) := (others => std_logic_vector(to_unsigned(1, 8)));

	signal addrb_layer_2 : std_logic_vector(7 downto 0);
	signal doutb_layer_2 : bram_data_array(0 to 5) := (others => std_logic_vector(to_unsigned(2, 8)));

	signal addra_weights_conv2 : std_logic_vector(4 downto 0);
	signal douta_weights_conv2 : bram_data_array(0 to 95) := (others => std_logic_vector(to_signed(3, 8)));

	signal addrb_weights_conv2 : std_logic_vector(4 downto 0);
	signal doutb_weights_conv2 : bram_data_array(0 to 95) := (others => std_logic_vector(to_signed(4, 8)));

begin

		U1 : layer_3 port map(
			clka                => clka,
			clkb                => clkb,
			resetn              => resetn,
			start               => start,
			finish              => finish,
			bias                => bias,
			addra_weights_conv2 => addra_weights_conv2,
			douta_weights_conv2 => douta_weights_conv2,
			addrb_weights_conv2 => addrb_weights_conv2,
			doutb_weights_conv2 => doutb_weights_conv2,
			wea_layer_3         => wea_layer_3,
			addra_layer_3       => addra_layer_3,
			dina_layer_3        => dina_layer_3,
			addra_layer_2       => addra_layer_2,
			douta_layer_2       => douta_layer_2,
			addrb_layer_2       => addrb_layer_2,
			doutb_layer_2       => doutb_layer_2
		);

	clka_process : process
	begin
		wait for 5ns;
		while true loop
			clka <= '0';
			wait for CLK_PERIOD / 2;
			clka <= '1';
			wait for CLK_PERIOD / 2;
		end loop;
	end process;

	clkb_process : process
	begin
		while true loop
			clkb <= '0';
			wait for CLK_PERIOD;
			clkb <= '1';
			wait for CLK_PERIOD;
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

	--addra_layer_2_process : process
	--begin
	--	wait until addra_layer_2'event;
	--	for i in 0 to 5 loop
	--		douta_layer_2(i) <= std_logic_vector(unsigned(douta_layer_2(i)) + 1);
	--	end loop;
	--end process;

	--addrb_layer_2_process : process
	--begin
	--	wait until addrb_layer_2'event;
	--	for i in 0 to 5 loop
	--		doutb_layer_2(i) <= std_logic_vector(unsigned(doutb_layer_2(i)) + 1);
	--	end loop;
	--end process;

	--addra_weights_conv2_process : process
	--begin
	--	wait until addra_weights_conv2'event;
	--	for i in 0 to 95 loop
	--		douta_weights_conv2(i) <= std_logic_vector(unsigned(douta_weights_conv2(i)) + 1);
	--	end loop;
	--end process;

	--addrb_weights_conv2_process : process
	--begin
	--	wait until addrb_weights_conv2'event;
	--	for i in 0 to 95 loop
	--		doutb_weights_conv2(i) <= std_logic_vector(unsigned(doutb_weights_conv2(i)) + 1);
	--	end loop;
	--end process;


end Behavioral;

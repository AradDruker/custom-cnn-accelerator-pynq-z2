library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity TB_layer_1 is
--  Port ( );
end TB_layer_1;

architecture Behavioral of TB_layer_1 is

	component layer_1 is
    Port (
        clka   : in  std_logic; -- Clock signal
        resetn : in  std_logic; -- Active-low reset signal
        start  : in  std_logic; -- Start signal to begin operation
        finish : out std_logic; -- finish signal for higher-level control

        weights : in weights_array(0 to 5); -- Kernel weights for convolution
        bias    : in bais_array(0 to 5);    -- Bias to be added after convolution

        -- Predict image (write to Port A of BRAM)
        wea_layer_1   : out wea_array(0 to 5);
        web_layer_1   : out wea_array(0 to 5);
        addra_layer_1 : out std_logic_vector(9 downto 0);
        addrb_layer_1 : out std_logic_vector(9 downto 0);
        dina_layer_1  : out bram_data_array(0 to 5);
        dinb_layer_1  : out bram_data_array(0 to 5);

        addra_origin : out std_logic_vector(9 downto 0);
        douta_origin : in  std_logic_vector(7 downto 0);
        addrb_origin : out std_logic_vector(9 downto 0);
        doutb_origin : in  std_logic_vector(7 downto 0);
        locked_debug : out std_logic
    );
	end component;

	signal clka         : std_logic := '0';
	signal resetn       : std_logic := '1';
	signal start        : std_logic := '0';
	signal finish       : std_logic;
	signal locked_debug : std_logic;

	constant CLK_PERIOD : time := 10 ns;

	signal resetn_flag : integer := 0;
	signal start_flag  : integer := 0;

	signal wea_layer_1   : wea_array(0 to 5);
	signal addra_layer_1 : std_logic_vector(9 downto 0);
	signal dina_layer_1  : bram_data_array(0 to 5);
	signal web_layer_1   : wea_array(0 to 5);
	signal addrb_layer_1 : std_logic_vector(9 downto 0);
	signal dinb_layer_1  : bram_data_array(0 to 5);

	signal addra_origin       : std_logic_vector(9 downto 0);
	signal addrb_origin       : std_logic_vector(9 downto 0);

	signal douta_origin : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(253, 8));
	signal doutb_origin : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(254, 8));

	signal weights : weights_array(0 to 5) := (others => (others => to_signed(5, 8)));
	signal bias : bais_array(0 to 5) := (others => to_signed(5, 32));

begin

        layer_1_instance : layer_1 port map(
            clka   => clka,
            resetn => resetn,         -- Reset
            start  => start,  -- Start signal for Layer 1
            finish => finish, -- Finish signal from Layer 1

            -- Weights and biases for convolution
            weights => weights, bias => bias, -- Weights and bias for channel 1

            -- Predict image BRAM write connections
            wea_layer_1   => wea_layer_1,   -- Write enable for predict BRAM
            addra_layer_1 => addra_layer_1, -- Write address for predict BRAM
            dina_layer_1  => dina_layer_1,  -- Data input for predict BRAM
            web_layer_1  => web_layer_1,
            addrb_layer_1  => addrb_layer_1, -- debugging => need to be: addrb_layer_1 => addrb_layer_1
            dinb_layer_1  => dinb_layer_1,

            -- Origin image BRAM read connections
            addra_origin => addra_origin,
            douta_origin => douta_origin,
            addrb_origin => addrb_origin,
            doutb_origin => doutb_origin,
            locked_debug => locked_debug
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
			if start_flag = 0 and locked_debug = '1' then
				start      <= '1';
				start_flag <= 1;
			else
				start <= '0';
			end if;
		end if;
	end process;

end Behavioral;

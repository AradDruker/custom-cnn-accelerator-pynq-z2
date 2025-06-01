library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TB_top is
--  Port ( );
end TB_top;

architecture Behavioral of TB_top is

    component top is
        Port (
            clk    : in std_logic;
            resetn : in std_logic;
            --input into rtl from from axi dma
            s_axis_tready : out std_logic;
            s_axis_tlast  : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tdata  : in  std_logic_vector(7 downto 0);
            -- output axi
            m_axis_tready : in  std_logic;
            m_axis_tlast  : out std_logic;
            m_axis_tvalid : out std_logic;
            m_axis_tdata  : out std_logic_vector(7 downto 0);

            ps_signal : in std_logic
        );
    end component;

    signal clk    : std_logic := '0';
    signal resetn : std_logic := '1';

    signal in_tready : std_logic;
    signal in_tlast  : std_logic                    := '0';
    signal in_tvalid : std_logic                    := '0';
    signal in_tdata  : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(1, 8));

    signal out_tready : std_logic := '0';
    signal out_tlast  : std_logic := '0';
    signal out_tvalid : std_logic := '0';
    signal out_tdata  : std_logic_vector(7 downto 0);

    signal ps_signal : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    signal resetn_flag : integer := 0;

    signal counter_layer : integer := 0;

    signal counter_channel_conv1 : integer := 0;
    signal counter_index_conv1   : integer := 0;
    signal counter_bias_conv1    : integer := 0;

    signal counter_channel_conv2 : integer := 0;
    signal counter_index_conv2   : integer := 0;
    signal counter_bias_conv2    : integer := 0;

    signal counter_channel_fc1 : integer := 0;
    signal counter_index_fc1   : integer := 0;
    signal counter_bias_fc1    : integer := 0;

    signal counter_channel_fc2 : integer := 0;
    signal counter_index_fc2   : integer := 0;
    signal counter_bias_fc2    : integer := 0;

    signal counter_index_scales_zero_point : integer := 0;
    signal counter_number : integer := 0;

    signal image_counter : integer := 0;

    signal cycle : integer := 0;

    signal final_output : std_logic_vector(7 downto 0);

begin

        U1 : top port map(
            clk           => clk,
            resetn        => resetn,
            s_axis_tready => in_tready,
            s_axis_tlast  => in_tlast,
            s_axis_tvalid => in_tvalid,
            s_axis_tdata  => in_tdata,
            m_axis_tready => out_tready,
            m_axis_tlast  => out_tlast,
            m_axis_tvalid => out_tvalid,
            m_axis_tdata  => out_tdata,
            ps_signal     => ps_signal
        );

    clk_process : process
    begin
        while true loop
            -- Generate 100 MHz clock
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    resetn_process : process(clk)
    begin
        if rising_edge(clk) then
            if resetn_flag = 0 then
                resetn      <= '0';
                resetn_flag <= 1;
            else
                resetn <= '1';
            end if;
        end if;
    end process;

    main_process : process(clk)
    begin
        if resetn = '1' then
            if rising_edge(clk) then

                in_tlast <= '0';
                if counter_layer = 0 then
                    ps_signal <= '1';
                end if;

                if in_tready = '1' and ps_signal = '1' then
                    in_tvalid <= '1';
                    if counter_channel_conv1 < 6 and counter_layer = 0 then
                        if counter_index_conv1 < 25 then
                            in_tdata            <= "00000010";
                            counter_index_conv1 <= counter_index_conv1 + 1;
                        elsif counter_index_conv1 = 25 and counter_bias_conv1 < 3 then
                            in_tdata           <= "11111111";
                            counter_bias_conv1 <= counter_bias_conv1 + 1;
                        elsif counter_index_conv1 = 25 and counter_bias_conv1 = 3 and counter_channel_conv1 < 5 then
                            in_tdata              <= "11111111";
                            counter_channel_conv1 <= counter_channel_conv1 + 1;
                            counter_index_conv1   <= 0;
                            counter_bias_conv1    <= 0;
                        elsif counter_index_conv1 = 25 and counter_bias_conv1 = 3 and counter_channel_conv1 = 5 then
                            in_tdata      <= "11111111";
                            in_tlast      <= '1';
                            counter_layer <= counter_layer + 1;
                        end if;

                    elsif counter_channel_conv2 < 16 and counter_layer = 1 then
                        if counter_index_conv2 < 150 then
                            in_tlast            <= '0';
                            in_tdata            <= "00000110";
                            counter_index_conv2 <= counter_index_conv2 + 1;
                        elsif counter_index_conv2 = 150 and counter_bias_conv2 < 3 then
                            in_tdata           <= "11111111";
                            counter_bias_conv2 <= counter_bias_conv2 + 1;
                        elsif counter_index_conv2 = 150 and counter_bias_conv2 = 3 and counter_channel_conv2 < 15 then
                            in_tdata              <= "11111111";
                            counter_channel_conv2 <= counter_channel_conv2 + 1;
                            counter_index_conv2   <= 0;
                            counter_bias_conv2    <= 0;
                        elsif counter_index_conv2 = 150 and counter_bias_conv2 = 3 and counter_channel_conv2 = 15 then
                            in_tdata      <= "11111111";
                            in_tlast      <= '1';
                            counter_layer <= counter_layer + 1;
                        end if;

                    elsif counter_channel_fc1 < 64 and counter_layer = 2 then
                        if counter_index_fc1< 400 then
                            in_tlast          <= '0';
                            in_tdata          <= "00010010";
                            counter_index_fc1 <= counter_index_fc1 + 1;
                        elsif counter_index_fc1 = 400 and counter_bias_fc1 < 3 then
                            in_tdata         <= "11111111";
                            counter_bias_fc1 <= counter_bias_fc1 + 1;
                        elsif counter_index_fc1 = 400 and counter_bias_fc1 = 3 and counter_channel_fc1 < 63 then
                            in_tdata            <= "11111111";
                            counter_channel_fc1 <= counter_channel_fc1 + 1;
                            counter_index_fc1   <= 0;
                            counter_bias_fc1    <= 0;
                        elsif counter_index_fc1 = 400 and counter_bias_fc1 = 3 and counter_channel_fc1 = 63 then
                            in_tdata      <= "11111111";
                            in_tlast      <= '1';
                            counter_layer <= counter_layer + 1;
                        end if;

                    elsif counter_channel_fc2 < 30 and counter_layer = 3 then
                        if counter_index_fc2 < 64 then
                            in_tlast          <= '0';
                            in_tdata          <= "00000010";
                            counter_index_fc2 <= counter_index_fc2 + 1;
                        elsif counter_index_fc2 = 64 and counter_bias_fc2 < 3 then
                            in_tdata         <= "11111111";
                            counter_bias_fc2 <= counter_bias_fc2 + 1;
                        elsif counter_index_fc2 = 64 and counter_bias_fc2 = 3 and counter_channel_fc2 < 29 then
                            in_tdata            <= "11111111";
                            counter_channel_fc2 <= counter_channel_fc2 + 1;
                            counter_index_fc2   <= 0;
                            counter_bias_fc2    <= 0;
                        elsif counter_index_fc2 = 64 and counter_bias_fc2 = 3 and counter_channel_fc2 = 29 then
                            in_tdata      <= "11111111";
                            in_tlast      <= '1';
                            counter_layer <= counter_layer + 1;
                        end if;

                    elsif counter_number < 6 and counter_layer = 4 then
                        if counter_index_scales_zero_point < 3 and counter_number < 4 then
                            in_tlast          <= '0';
                            in_tdata          <= "00000001";
                            counter_index_scales_zero_point <= counter_index_scales_zero_point + 1;
                        elsif counter_index_scales_zero_point = 3 and counter_number < 4 then
                            in_tlast          <= '0';
                            in_tdata          <= "00000001";
                            counter_index_scales_zero_point <= 0;
                            counter_number <= counter_number + 1;
                        elsif counter_number = 4 then
                            in_tdata      <= "00000010";
                            in_tlast      <= '0';
                            counter_number <= counter_number + 1;
                        elsif counter_number = 5 then
                            in_tdata      <= "00000100";
                            in_tlast      <= '1';
                            counter_number <= counter_number + 1;
                            counter_layer <= counter_layer + 1;
                        end if;

                    elsif counter_layer = 5 then
                        ps_signal <= '0';
                        in_tvalid <= '0';
                    end if;

                elsif in_tready = '1' and ps_signal = '0' then
                    in_tvalid <= '1';
                    if image_counter < 783 then
                        if cycle = 1 then
                            in_tdata <= "00000010";
                        else
                            in_tdata <= "00000110";
                        end if;
                        image_counter <= image_counter + 1;
                    elsif image_counter = 783 then
                        in_tdata <= "00000001";
                        in_tlast <= '1';
                    end if;
                end if;

            elsif in_tready = '0' and ps_signal = '0' then
                out_tready    <= '1';
                image_counter <= 0;
                cycle         <= cycle + 1;
                if out_tvalid = '1' then
                    if out_tlast = '1' then
                        final_output <= out_tdata;
                    end if;
                    final_output <= out_tdata;
                end if;
            end if;
        end if;
    end process;
end Behavioral;

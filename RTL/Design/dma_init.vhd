library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.types_package.all;

entity dma_init is
	Port (
		clka   : in  std_logic; -- Clock signal
		resetn : in  std_logic; -- Active-low reset signal
		start  : in  std_logic; -- Start signal to begin operation
		finish : out std_logic; -- Indicates when operation is complete

		in_tready : out std_logic;                    -- Ready signal for input stream
		in_tlast  : in  std_logic;                    -- Last signal for input stream
		in_tvalid : in  std_logic;                    -- Valid signal for input stream
		in_tdata  : in  std_logic_vector(7 downto 0); -- Data input for writing to RAM

		weights_conv_1 : out weights_array(0 to 5);
		bias_conv_1    : out bais_array(0 to 5);

		wea_weights_conv2   : out wea_array(0 to 95);
		addra_weights_conv2 : out std_logic_vector(4 downto 0);
		dina_weights_conv2  : out bram_data_array(0 to 95);
		bias_conv_2         : out bais_array(0 to 15);

		wea_weights_fc1   : out wea_array(0 to 63);
		addra_weights_fc1 : out std_logic_vector(8 downto 0);
		dina_weights_fc1  : out bram_data_array(0 to 63);
		bias_fc_1         : out bais_array(0 to 63);

		wea_weights_fc2   : out wea_array(0 to 14);
		addra_weights_fc2 : out std_logic_vector(5 downto 0);
		dina_weights_fc2  : out bram_data_array(0 to 14);
		bias_fc_2         : out bais_array(0 to 14);

		scales            : out scale_array(0 to 3);
		input_zero_point  : out integer range 0 to 255;
		output_zero_point : out integer range 0 to 255
	);
end dma_init;

architecture Behavioral of dma_init is

	type state_type is (IDLE, CONV_1, CONV_2, FC_1, FC_2, SCALES_ZERO_POINT, DONE);
	signal state : state_type := IDLE;

	type state_inside_type is (CONV_1, CONV_2, FC_1, FC_2, SCALES_ZERO_POINT);
	signal state_inside : state_inside_type := CONV_1;

	signal addra_weights_conv2_internal : std_logic_vector(4 downto 0) := (others => '0'); -- Internal write address for RAM
	signal addra_weights_fc1_internal   : std_logic_vector(8 downto 0) := (others => '0'); -- Internal write address for RAM
	signal addra_weights_fc2_internal   : std_logic_vector(5 downto 0) := (others => '0'); -- Internal write address for RAM

begin

	addra_weights_conv2 <= addra_weights_conv2_internal;
	addra_weights_fc1   <= addra_weights_fc1_internal;
	addra_weights_fc2   <= addra_weights_fc2_internal;

	process(clka, resetn)
		-- Variables for iteration and delay
		variable counter       : integer range 0 to 4   := 0;
		variable index         : integer range 0 to 400 := 0;
		variable channel       : integer range 0 to 64  := 0;
		variable input_channel : integer range 0 to 6   := 0;

		variable bias_temp              : std_logic_vector(31 downto 0);
		variable scales_temp            : std_logic_vector(31 downto 0);
		variable first_write_flag       : std_logic := '0';

	begin
		-- Reset condition: Initialize signals and state
		if resetn = '0' then
			state        <= IDLE;
			state_inside <= CONV_1;

		elsif rising_edge(clka) then
			case state is
				-- Idle state: Wait for the start signal and determine mode
				when IDLE =>
					finish                       <= '0';
					in_tready                    <= '0';
					counter                      := 0;
					index                        := 0;
					channel                      := 0;
					input_channel                := 0;
					addra_weights_conv2_internal <= (others => '0');
					addra_weights_fc1_internal   <= (others => '0');
					addra_weights_fc2_internal   <= (others => '0');

					if start = '1' then
						case state_inside is
							when CONV_1 =>
								state <= CONV_1;
							when CONV_2 =>
								state <= CONV_2;
							when FC_1 =>
								state <= FC_1;
							when FC_2 =>
								state <= FC_2;
							when SCALES_ZERO_POINT =>
								state <= SCALES_ZERO_POINT;
						end case;
					end if;

				when CONV_1 =>
					in_tready <= '1';
					if channel < 6 then
						if in_tvalid = '1' and index < 25 then
							weights_conv_1(channel)(index) <= signed(in_tdata);
							index                          := index + 1;
						elsif in_tvalid = '1' and index = 25 then
							bias_temp(31 - (counter * 8) downto 24 - (counter * 8)) := in_tdata;
							counter                                                 := counter + 1;
							if counter = 4 then
								bias_conv_1(channel) <= signed(bias_temp);
								counter              := 0;
								index                := 0;
								channel              := channel + 1;
								if in_tlast = '1' then
									state_inside <= CONV_2;
									state        <= DONE;
								end if;
							end if;
						end if;
					end if;

				when CONV_2 =>
					if channel < 16 then
						wea_weights_conv2 <= (others => "0");
						in_tready         <= '1';
						if in_tvalid = '1' and first_write_flag = '0' and input_channel < 6 then
							addra_weights_conv2_internal                    <= (others => '0');
							wea_weights_conv2(channel * 6 + input_channel)  <= "1";
							dina_weights_conv2(channel * 6 + input_channel) <= in_tdata; -- Write input data to RAM
							first_write_flag                                := '1';
							index                                           := index + 1;

						elsif in_tvalid = '1' and index < 25 and input_channel < 6 then
							wea_weights_conv2(channel * 6 + input_channel)  <= "1";
							dina_weights_conv2(channel * 6 + input_channel) <= in_tdata;
							addra_weights_conv2_internal                    <= std_logic_vector(unsigned(addra_weights_conv2_internal) + 1);
							index                                           := index + 1;
						elsif in_tvalid = '1' and input_channel = 6 then
							bias_temp(31 - (counter * 8) downto 24 - (counter * 8)) := in_tdata;
							counter                                                 := counter + 1;
							if counter = 4 then
								bias_conv_2(channel)         <= signed(bias_temp);
								counter                      := 0;
								input_channel                := 0;
								index                        := 0;
								channel                      := channel + 1;
								first_write_flag             := '0';
								addra_weights_conv2_internal <= (others => '0');
								if in_tlast = '1' then
									state_inside <= FC_1;
									state        <= DONE;
								end if;
							end if;
						end if;
					end if;

					if in_tvalid = '1' and index = 25 and input_channel < 6 then
						first_write_flag := '0';
						input_channel    := input_channel + 1;
						index            := 0;
					end if;

				when FC_1 =>
					if channel < 64 then
						wea_weights_fc1 <= (others => "0");
						in_tready       <= '1';
						if in_tvalid = '1' and first_write_flag = '0' then
							wea_weights_fc1(channel)  <= "1";
							dina_weights_fc1(channel) <= in_tdata;
							first_write_flag          := '1';
							index                     := index + 1;

						elsif in_tvalid = '1' and index < 400 then
							wea_weights_fc1(channel)   <= "1";
							dina_weights_fc1(channel)  <= in_tdata;
							addra_weights_fc1_internal <= std_logic_vector(unsigned(addra_weights_fc1_internal) + 1);
							index                      := index + 1;
						elsif in_tvalid = '1' and index = 400 then
							bias_temp(31 - (counter * 8) downto 24 - (counter * 8)) := in_tdata;
							counter                                                 := counter + 1;
							if counter = 4 then
								bias_fc_1(channel)         <= signed(bias_temp);
								counter                    := 0;
								index                      := 0;
								channel                    := channel + 1;
								first_write_flag           := '0';
								addra_weights_fc1_internal <= (others => '0');
								if in_tlast = '1' then
									state_inside <= FC_2;
									state        <= DONE;
								end if;
							end if;
						end if;
					end if;

				when FC_2 =>
					if channel < 30 then
						wea_weights_fc2 <= (others => "0");
						in_tready       <= '1';
						if in_tvalid = '1' and first_write_flag = '0' then
							wea_weights_fc2(channel)  <= "1";
							dina_weights_fc2(channel) <= in_tdata; -- Write input data to RAM
							first_write_flag          := '1';
							index                     := index + 1;

						elsif in_tvalid = '1' and index < 64 then
							wea_weights_fc2(channel)   <= "1";
							dina_weights_fc2(channel)  <= in_tdata;
							addra_weights_fc2_internal <= std_logic_vector(unsigned(addra_weights_fc2_internal) + 1);
							index                      := index + 1;
						elsif in_tvalid = '1' and index = 64 then
							bias_temp(31 - (counter * 8) downto 24 - (counter * 8)) := in_tdata;
							counter                                                 := counter + 1;
							if counter = 4 then
								bias_fc_2(channel)         <= signed(bias_temp);
								counter                    := 0;
								index                      := 0;
								channel                    := channel + 1;
								first_write_flag           := '0';
								addra_weights_fc2_internal <= (others => '0');
								if in_tlast = '1' then
									state_inside <= SCALES_ZERO_POINT;
									state        <= DONE;
								end if;
							end if;
						end if;
					end if;

				when SCALES_ZERO_POINT =>
					in_tready       <= '1';
					if in_tvalid = '1' and index < 4 then
						scales_temp(31 - (counter * 8) downto 24 - (counter * 8)) := in_tdata;
						counter                                                   := counter + 1;
						if counter = 4 then
							scales(index) <= to_integer(unsigned(scales_temp));
							counter       := 0;
							index         := index + 1;
						end if;

					elsif in_tvalid = '1' and index = 4 then
						if counter = 0 then
							input_zero_point <= to_integer(unsigned(in_tdata));
							counter := counter + 1;
						else
							output_zero_point <= to_integer(unsigned(in_tdata));
						end if;

						if in_tlast = '1' then
							index        := 0;
							counter       := 0;
							state_inside <= CONV_1;
							state        <= DONE;
						end if;
					end if;

				when DONE =>
					finish    <= '1';
					in_tready <= '0';

					if start = '0' then
						state <= IDLE;
					end if;

			end case;
		end if;
	end process;
end Behavioral;

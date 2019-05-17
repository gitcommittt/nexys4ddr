library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity sim_rx is
   port (
      rx_valid_i  : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_ok_i     : in  std_logic;
      --
      sim_data_o  : out std_logic_vector(127*8+7 downto 0);
      sim_len_o   : out std_logic_vector(15 downto 0)
   );
end sim_rx;

architecture simulation of sim_rx is

   signal sim_data : std_logic_vector(127*8+7 downto 0);
   signal sim_len  : std_logic_vector(15 downto 0);

begin

   ---------------------------
   -- Store data received
   ---------------------------

   sim_rx_proc : process
   begin
      sim_data <= (others => 'X');
      sim_len  <= (others => '0');

      byte_loop : while (true) loop
         wait until rx_valid_i = '1';

         sim_data(8*to_integer(sim_len)+7 downto 8*to_integer(sim_len)) <= rx_data_i;
         sim_len <= sim_len + 1;
         if rx_eof_i = '1' then
            assert rx_ok_i = '1';
            exit byte_loop;
         end if;
      end loop byte_loop;

      wait until rx_valid_i = '0';
   end process sim_rx_proc;

   -- Connect output signals
   sim_data_o <= sim_data;
   sim_len_o  <= sim_len;

end architecture simulation;


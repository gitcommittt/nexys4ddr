library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_eth is
end tb_eth;

architecture simulation of tb_eth is

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(64*8-1 downto 0);
      size  : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx    : t_sim;

   -- Output from wide2byte
   signal tx_empty  : std_logic;
   signal tx_rden   : std_logic;
   signal tx_data   : std_logic_vector(7 downto 0);
   signal tx_last   : std_logic;

   -- Signals conected to DUT
   signal eth_rstn  : std_logic;
   signal eth_rxd   : std_logic_vector(1 downto 0);
   signal eth_crsdv : std_logic;
   signal eth_txd   : std_logic_vector(1 downto 0);
   signal eth_txen  : std_logic;
   signal debug     : std_logic_vector(255 downto 0);

   -- Output from eth_rx
   signal rx_valid  : std_logic;
   signal rx_last   : std_logic;
   signal rx_data   : std_logic_vector(7 downto 0);
   signal rx_ok     : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx    : t_sim;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   --------------------------------------------------
   -- Generate clock and reset
   --------------------------------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns; -- 50 MHz
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;


   --------------------------------------------------
   -- Instantiate traffic generator
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_BYTES    => 64
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => sim_tx.valid,
      rx_data_i  => sim_tx.data,
      rx_last_i  => '1',
      rx_bytes_i => sim_tx.size,
      --
      tx_empty_o => tx_empty,
      tx_data_o  => tx_data,
      tx_last_o  => tx_last,
      tx_rden_i  => tx_rden
   ); -- i_wide2byte

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk,
      eth_rst_i  => rst,
      tx_data_i  => tx_data,
      tx_last_i  => tx_last,
      tx_empty_i => tx_empty,
      tx_rden_o  => tx_rden,
      tx_err_o   => open,
      --
      eth_txd_o  => eth_rxd,
      eth_txen_o => eth_crsdv
   ); -- i_eth_tx


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_eth : entity work.eth
   port map (
      clk_i        => clk,
      debug_o      => debug,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => open
   ); -- i_eth


   --------------------------------------------------
   -- Instantiate traffic receiver
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk,
      eth_rst_i   => rst,
      eth_rxd_i   => eth_txd,
      eth_rxerr_i => '0',
      eth_crsdv_i => eth_txen,
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_byte2wide : entity work.byte2wide
   generic map (
      G_BYTES    => 64
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => rx_valid,
      rx_data_i  => rx_data,
      rx_last_i  => rx_last,
      --
      tx_valid_o => sim_rx.valid,
      tx_data_o  => sim_rx.data,
      tx_last_o  => open,
      tx_bytes_o => sim_rx.size
   ); -- i_byte2wide


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Calculate the Internet Checksum according to RFC 1071.
      function checksum(inp : std_logic_vector) return std_logic_vector is
         variable res_v : std_logic_vector(19 downto 0) := (others => '0');
         variable val_v : std_logic_vector(15 downto 0);
      begin
         for i in 0 to inp'length/16-1 loop
            val_v := inp(i*16+15+inp'right downto i*16+inp'right);
            res_v := res_v + (X"0" & val_v);
         end loop;

         -- Handle wrap-around
         res_v := (X"0" & res_v(15 downto 0)) + (X"0000" & res_v(19 downto 16));
         return res_v(15 downto 0);
      end function checksum;

   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until clk = '1';

      -- Send one ARP request
      sim_tx.data <= (others => '0');
      sim_tx.data(64*8-1 downto 64*8-42*8) <= X"FFFFFFFFFFFF66778899AABB0806" &  -- MAC header
                                              X"0001080006040001" &              -- ARP header
                                              X"AABBCCDDEEFF" & X"C0A80001" &    -- SHA & SPA
                                              X"000000000000" & X"C0A8014D";     -- THA & TPA
      sim_tx.size  <= to_stdlogicvector(60, 6); -- Minimum frame size
      sim_tx.valid <= '1';
      wait until clk = '1';
      sim_tx.valid <= '0';

      -- Verify ARP response is correct
      wait until sim_rx.valid = '1';
      assert sim_rx.size = sim_tx.size + 4;
      assert sim_rx.data(64*8-1 downto 64*8-42*8) = X"66778899AABB0011223344550806" &  -- MAC header
                                                    X"0001080006040002" &              -- ARP header
                                                    X"001122334455" & X"C0A8014D" &    -- THA & TPA
                                                    X"AABBCCDDEEFF" & X"C0A80001";     -- SHA & SPA

      -- Wait a little while to ease debugging                                               
      wait for 200 ns;
    
      -- Send one ICMP request
      sim_tx.data <= (others => '0');
      sim_tx.data(64*8-1 downto 64*8-42*8) <= X"001122334455AABBCCDDEEFF0800" &              -- MAC header
                                              X"4500001C0000000040010000C0A80101C0A8014D" &  -- IP header
                                              X"0800000001020304";                           -- ICMP
      -- Wait one clock cycle.
      wait until clk = '1';
      -- Updated data with correct checksum
      sim_tx.data(64*8-42*8+17*8+7 downto 64*8-42*8+16*8) <= not checksum(sim_tx.data(64*8-42*8+27*8+7 downto 64*8-42*8+8*8));
      sim_tx.data(64*8-42*8+ 5*8+7 downto 64*8-42*8+ 4*8) <= not checksum(sim_tx.data(64*8-42*8+ 7*8+7 downto 64*8-42*8+0*8));

      sim_tx.size  <= to_stdlogicvector(60, 6);
      sim_tx.valid <= '1';
      wait until clk = '1';
      sim_tx.valid <= '0';

      -- Verify ICMP response is correct
      wait until sim_rx.valid = '1';
      assert sim_rx.size = sim_tx.size + 4;
      assert sim_rx.data(64*8-1 downto 64*8-42*8) = X"AABBCCDDEEFF0011223344550800" &              -- MAC header
                                                    X"4500001C0000000040010000C0A8014DC0A80101" &  -- IP header
                                                    X"0000000001020304";                           -- ICMP

      assert debug = sim_rx.data(64*8-42*8+32*8-1 downto 64*8-42*8);

      -- Wait a little while to ease debugging                                               
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;


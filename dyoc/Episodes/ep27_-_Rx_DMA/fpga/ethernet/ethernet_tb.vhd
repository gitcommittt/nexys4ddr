library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

-- This module is a test bench for the Ethernet module.

entity ethernet_tb is
end entity ethernet_tb;

architecture Structural of ethernet_tb is

   -- Connected to DUT
   signal user_clk          : std_logic;  -- 25 MHz
   signal user_wren         : std_logic;
   signal user_addr         : std_logic_vector(15 downto 0);
   signal user_data         : std_logic_vector( 7 downto 0);
   signal user_rxdma_enable : std_logic;
   signal user_rxdma_ptr    : std_logic_vector(15 downto 0);
   signal user_rxdma_size   : std_logic_vector(15 downto 0);
   signal user_rxcpu_ptr    : std_logic_vector(15 downto 0);
   signal user_rxbuf_ptr    : std_logic_vector(15 downto 0);
   signal user_rxbuf_size   : std_logic_vector(15 downto 0);
   signal user_cnt_good     : std_logic_vector(15 downto 0);
   signal user_cnt_error    : std_logic_vector( 7 downto 0);
   signal user_cnt_crc_bad  : std_logic_vector( 7 downto 0);
   signal user_cnt_overflow : std_logic_vector( 7 downto 0);
   --
   signal eth_clk           : std_logic;  -- 50 MHz
   signal eth_refclk        : std_logic;
   signal eth_rstn          : std_logic;
   signal eth_rxd           : std_logic_vector(1 downto 0);
   signal eth_crsdv         : std_logic;

   -- Controls the traffic input to Ethernet.
   signal sim_data  : std_logic_vector(128*8-1 downto 0);
   signal sim_len   : std_logic_vector( 15     downto 0);
   signal sim_start : std_logic := '0';
   signal sim_done  : std_logic;

   -- Used to clear the sim_ram between each test.
   signal sim_ram       : std_logic_vector(16383 downto 0);
   signal sim_ram_clear : std_logic;

   -- Control the execution of the test.
   signal sim_test_running : std_logic := '1';

begin

   -----------------------------
   -- Generate clock and reset
   -----------------------------

   -- Generate cpu clock @ 25 MHz
   proc_user_clk : process
   begin
      user_clk <= '1', '0' after 20 ns;
      wait for 40 ns;
      if sim_test_running = '0' then
         wait;
      end if;
   end process proc_user_clk;

   -- Generate eth clock @ 50 MHz
   proc_eth_clk : process
   begin
      eth_clk <= '1', '0' after 10 ns;
      wait for 20 ns;
      if sim_test_running = '0' then
         wait;
      end if;
   end process proc_eth_clk;


   ---------------------------------
   -- Instantiate sim_ram simulator
   ---------------------------------

   inst_ram_sim : entity work.ram_sim
   port map (
      clk_i   => user_clk,
      wren_i  => user_wren,
      addr_i  => user_addr,
      data_i  => user_data,
      clear_i => sim_ram_clear,
      ram_o   => sim_ram
   );


   ---------------------------------
   -- Instantiate PHY simulator
   ---------------------------------

   inst_phy_sim : entity work.phy_sim
   port map (
      sim_data_i   => sim_data,
      sim_len_i    => sim_len,
      sim_start_i  => sim_start,
      sim_done_o   => sim_done,
      --
      eth_refclk_i => eth_refclk,
      eth_rstn_i   => eth_rstn,
      eth_txd_o    => eth_rxd,
      eth_txen_o   => eth_crsdv
   );


   -------------------
   -- Instantiate DUT
   -------------------

   inst_ethernet : entity work.ethernet
   port map (
      user_clk_i          => user_clk,
      user_wren_o         => user_wren,
      user_addr_o         => user_addr,
      user_data_o         => user_data,
      user_rxdma_enable_i => user_rxdma_enable,
      user_rxdma_ptr_i    => user_rxdma_ptr,
      user_rxdma_size_i   => user_rxdma_size,
      user_rxcpu_ptr_i    => user_rxcpu_ptr,
      user_rxbuf_ptr_o    => user_rxbuf_ptr,
      user_rxbuf_size_o   => user_rxbuf_size,
      user_cnt_good_o     => user_cnt_good,
      user_cnt_error_o    => user_cnt_error,
      user_cnt_crc_bad_o  => user_cnt_crc_bad,
      user_cnt_overflow_o => user_cnt_overflow,
      --
      eth_clk_i           => eth_clk,
      eth_txd_o           => open,   -- We're ignoring transmit for now
      eth_txen_o          => open,   -- We're ignoring transmit for now
      eth_rxd_i           => eth_rxd,
      eth_rxerr_i         => '0',
      eth_crsdv_i         => eth_crsdv,
      eth_intn_i          => '0',
      eth_mdio_io         => open,
      eth_mdc_o           => open,
      eth_rstn_o          => eth_rstn,
      eth_refclk_o        => eth_refclk
   );
   

   --------------------
   -- Main test program
   --------------------

   proc_test : process
   begin
      -- Wait for reset
      sim_start         <= '0';
      user_rxdma_enable <= '0';
      user_rxdma_ptr    <= (others => '0');
      user_rxdma_size   <= (others => '0');
      user_rxcpu_ptr    <= (others => '0');
      wait until eth_rstn = '1';

      -- Clear sim_ram
      wait until user_clk = '0';
      sim_ram_clear <= '1';
      wait until user_clk = '1';
      sim_ram_clear <= '0';

      -----------------------------------------------
      -- Test 1 : Receive first frame while DMA is disabled
      -- Expected behaviour: Frame is discarded
      -----------------------------------------------

      -- Wait while test runs
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+32, 8));
      end loop;
      sim_len   <= X"0011";         -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';    -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait for 3 us;                -- Wait until data has been received in sim_ram.

      -- Verify statistics counters
      assert user_cnt_good     = 0;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;


      -----------------------------------------------
      -- Test 2 : Enable DMA
      -- Expected behaviour: DMA rx pointers updated
      -----------------------------------------------

      -- Configure DMA for 1700 bytes of receive buffer space
      user_rxdma_ptr  <= X"2000";
      user_rxdma_size <= std_logic_vector(to_unsigned(1700, 16));
      user_rxcpu_ptr  <= X"2000";
      wait until user_clk = '1';
      user_rxdma_enable <= '1';
      wait until user_clk = '1';

      assert user_rxbuf_ptr  = X"2000";
      assert user_rxbuf_size = 0;


      -----------------------------------------------
      -- Test 3 : Receive second frame
      -- Expected behaviour: Frame is written to memory
      --                     Write pointer is updated
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+32, 8));
      end loop;
      sim_len   <= X"0080"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait until user_rxbuf_size /= 0;  -- Wait until RxDMA is finished
      wait until user_clk = '1';

      -- Verify DMA write pointer
      assert user_rxbuf_ptr  = X"2000";
      assert user_rxbuf_size = X"82";

      -- Verify statistics counters
      assert user_cnt_good     = 1;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify memory contents.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+7 downto 130*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 4 : Receive third frame
      -- Expected behaviour: Frame is written to memory
      --                     Write pointer is now end of buffer
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+64, 8));
      end loop;
      sim_len   <= X"0070"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait until user_rxbuf_size /= X"82";  -- Wait until RxDMA is finished
      wait until user_clk = '1';

      -- Verify DMA write pointer
      assert user_rxbuf_ptr  = X"2000";
      assert user_rxbuf_size = X"F4";

      -- Verify statistics counters
      assert user_cnt_good     = 2;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify memory contents.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+15 downto 130*8) = X"0072";  -- Length includes 2-byte header.
      for i in 0 to 111 loop
         assert sim_ram((i+132)*8+7 downto (i+132)*8) = std_logic_vector(to_unsigned(i+64, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(244*8+7 downto 244*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 5 : Receive fourth frame
      -- Expected behaviour: Frame is held back
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+96, 8));
      end loop;
      sim_len   <= X"0060"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait for 10 us;            -- Wait some time while RxDMA processes data.

      -- Verify DMA write pointer is untouched.
      assert user_rxbuf_ptr  = X"2000";
      assert user_rxbuf_size = X"F4";

      -- Verify statistics counters
      assert user_cnt_good     = 3;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify previous frames are untouched.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+15 downto 130*8) = X"0072";  -- Length includes 2-byte header.
      for i in 0 to 111 loop
         assert sim_ram((i+132)*8+7 downto (i+132)*8) = std_logic_vector(to_unsigned(i+64, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(244*8+7 downto 244*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 6 : Release first frame
      -- Expected behaviour: Pointers updated, first frame still untouched.
      -----------------------------------------------

      -- Update CPU read pointer, to release first frame.
      user_rxcpu_ptr   <= X"2082";
      wait until user_rxbuf_size /= X"F4"; -- Wait until frame has been transferred to sim_ram.
      wait until user_clk = '1';

      -- Verify DMA pointers is updated
      assert user_rxbuf_ptr  = X"2082";
      assert user_rxbuf_size = X"72";

      wait for 10 us;            -- Wait some time while RxDMA processes data.

      -- Verify statistics counters
      assert user_cnt_good     = 3;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify first frame is untouched.

      -- TBD TBD TBD


      -----------------------------------------------
      -- Test 7 : Release second frame
      -- Expected behaviour: Pointers updated, first frame overwritten.
      -----------------------------------------------

      -- Update CPU read pointer, to release second frame.
      user_rxcpu_ptr   <= X"20F4";
      wait until user_rxbuf_size /= X"72";
      wait until user_clk = '1';

      -- Verify DMA pointers is updated. Buffer is not empty
      assert user_rxbuf_ptr  = X"20F4";
      assert user_rxbuf_size = X"00";

      -- Wait until frame has been transferred to memory.
      wait until user_rxbuf_size /= X"00";
      wait until user_clk = '1';

      -- Verify DMA pointers is updated again
      assert user_rxbuf_ptr  = X"2000";
      assert user_rxbuf_size = X"62";

      -- Verify statistics counters
      assert user_cnt_good     = 3;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify first frame is untouched.


      -----------------------------------------------
      -- END OF TEST
      -----------------------------------------------

      report "Test completed";
      sim_test_running <= '0';
      wait;

   end process proc_test;

end Structural;


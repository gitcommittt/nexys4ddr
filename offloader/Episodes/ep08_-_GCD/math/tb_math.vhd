library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_math is
end tb_math;

architecture simulation of tb_math is

   constant C_SIZE     : integer := 64;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal cmd          : t_sim;
   signal resp         : t_sim;
   signal debug        : std_logic_vector(255 downto 0);

   signal exp          : t_sim;

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
   -- Instantiate DUT
   --------------------------------------------------

   i_math : entity work.math
   generic map (
      G_SIZE     => C_SIZE
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      debug_o    => debug,
      rx_valid_i => cmd.valid,
      rx_data_i  => cmd.data,
      rx_last_i  => cmd.last,
      rx_bytes_i => cmd.bytes,
      tx_valid_o => resp.valid,
      tx_data_o  => resp.data,
      tx_last_o  => resp.last,
      tx_bytes_o => resp.bytes
   ); -- i_math


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify MULT processing
      procedure verify_mult(val1 : integer;
                            val2 : integer;
                            res  : integer) is
      begin

         report "Verify MULT: " & integer'image(val1) & 
         "*" & integer'image(val2) & "=" & integer'image(res);

         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 42*8)  <= X"0101" &
            to_stdlogicvector(val1, C_SIZE) & 
            to_stdlogicvector(val2, C_SIZE) &
            C_ZERO &
            C_ZERO;
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-C_SIZE)  <= 
            to_stdlogicvector(res,C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_mult;

      -- Verify GCD processing
      procedure verify_gcd(val1 : integer;
                           val2 : integer;
                           res  : integer) is
      begin

         report "Verify GCD: " & integer'image(val1) & 
         "*" & integer'image(val2) & "=" & integer'image(res);

         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 42*8)  <= X"0102" &
            to_stdlogicvector(val1, C_SIZE) & 
            to_stdlogicvector(val2, C_SIZE) &
            C_ZERO &
            C_ZERO;
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-C_SIZE)  <= 
            to_stdlogicvector(res,C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_gcd;

      -- Verify DIVMOD processing
      procedure verify_divmod(val_n : integer;
                              val_d : integer;
                              res_q : integer;
                              res_r : integer) is
      begin

         report "Verify DIVMOD: " & integer'image(val_n) & 
         "/" & integer'image(val_d) & "=" & integer'image(res_q) & ", " & integer'image(res_r);

         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 42*8)  <= X"0103" &
            to_stdlogicvector(val_n, C_SIZE) & 
            to_stdlogicvector(val_d, C_SIZE) &
            C_ZERO &
            C_ZERO;
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-2*C_SIZE)  <= 
            to_stdlogicvector(res_q, C_SIZE) &
            to_stdlogicvector(res_r, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_divmod;

      -- Verify AMM processing
      procedure verify_amm(val_a : integer;
                           val_x : integer;
                           val_b : integer;
                           val_n : integer;
                           res   : integer) is
      begin

         report "Verify AMM: " & integer'image(val_a) & 
         "*" & integer'image(val_x) & "+" & integer'image(val_b) & " mod " & integer'image(val_n) &
         "=" & integer'image(res);

         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 42*8)  <= X"0104" &
            to_stdlogicvector(val_a, C_SIZE) & 
            to_stdlogicvector(val_x, C_SIZE) &
            to_stdlogicvector(val_b, C_SIZE) &
            to_stdlogicvector(val_n, C_SIZE);
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-C_SIZE)  <= 
            to_stdlogicvector(res, C_SIZE);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_amm;

      -- Verify CF processing
      procedure verify_cf(val_n  : integer;
                          val_m  : integer;
                          val_y  : integer;
                          res1_x : integer;
                          res1_y : integer;
                          res2_x : integer;
                          res2_y : integer;
                          res3_x : integer;
                          res3_y : integer) is
      begin

         report "Verify CF: N=" & integer'image(val_n) & 
         ", M=" & integer'image(val_m) & 
         ", Y=" & integer'image(val_y) & 
         " -> (" & integer'image(res1_x) &
         ", " & integer'image(res1_y) &
         " -> (" & integer'image(res2_x) &
         ", " & integer'image(res2_y) &
         ") -> (" & integer'image(res3_x) &
         ", " & integer'image(res3_y) &
         ")";

         assert val_n - val_m*val_m = val_y;
         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 60*8-4*C_SIZE-16)  <= X"0105" &
            to_stdlogicvector(val_n, C_SIZE) & 
            to_stdlogicvector(val_m, C_SIZE) &
            to_stdlogicvector(val_y, C_SIZE) &
            C_ZERO;
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(18, 6);
         wait until clk = '1';
         cmd.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE/2)  <= 
            to_stdlogicvector(res1_x, C_SIZE) &
            to_stdlogicvector(res1_y, C_SIZE/2);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE/2)  <= 
            to_stdlogicvector(res2_x, C_SIZE) &
            to_stdlogicvector(res2_y, C_SIZE/2);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(60*8-1 downto 60*8-3*C_SIZE/2)  <= 
            to_stdlogicvector(res3_x, C_SIZE) &
            to_stdlogicvector(res3_y, C_SIZE/2);
         exp.last  <= '1';
         exp.bytes <= to_stdlogicvector(18, 6);

         -- Verify received response is correct
         wait until clk = '1' and resp.valid = '1';
         wait until clk = '0';
         assert resp.data  = exp.data;
         assert resp.last  = exp.last;
         assert resp.bytes = exp.bytes;
         wait until clk = '1' and resp.valid = '0';
         wait until clk = '0';
      end procedure verify_cf;

   begin
      -- Wait until reset is complete
      cmd.valid <= '0';
      wait until clk = '1' and rst = '0';

--       -- Verify MULT
--       for a in 0 to 3 loop 
--          for b in 0 to 3 loop 
--             verify_mult(a, b, a*b);
--          end loop;
--       end loop;
-- 
--       verify_mult(  7, 13,   91);
--       verify_mult(100, 10, 1000);
-- 
--       -- Verify GCD
--       verify_gcd(0, 0, 0);
--       verify_gcd(1, 0, 0);
--       verify_gcd(0, 1, 0);
--       verify_gcd(1, 1, 1);
--       verify_gcd(1, 2, 1);
--       verify_gcd(1, 3, 1);
--       verify_gcd(1, 4, 1);
--       verify_gcd(2, 1, 1);
--       verify_gcd(2, 2, 2);
--       verify_gcd(2, 3, 1);
--       verify_gcd(2, 4, 2);
--       verify_gcd(3, 1, 1);
--       verify_gcd(3, 2, 1);
--       verify_gcd(3, 3, 3);
--       verify_gcd(3, 4, 1);
--       verify_gcd(4, 1, 1);
--       verify_gcd(4, 2, 2);
--       verify_gcd(4, 3, 1);
--       verify_gcd(4, 4, 4);
--       verify_gcd(30, 35, 5);
--       verify_gcd(35, 30, 5);
--       verify_gcd(36, 30, 6);
--       verify_gcd(36, 32, 4);
--       verify_gcd(37, 30, 1);
--       verify_gcd(70, 30, 10);
--       verify_gcd(150, 30, 30);
--       verify_gcd(250, 30, 10);
--       verify_gcd(253, 30, 1);
--       verify_gcd(252, 30, 6);
--       
--       -- Verify DIVMOD
--       for n in 0 to 20 loop 
--          verify_divmod(n, 3, n/3, n mod 3);
--       end loop;
-- 
--       for d in 1 to 20 loop 
--          verify_divmod(10, d, 10/d, 10 mod d);
--       end loop;
-- 
--       verify_divmod(131*251+14, 131, 251, 14);
--       verify_divmod(131*251+14, 251, 131, 14);
-- 
--       -- Verify AMM
--       verify_amm(7, 13, 21, 30, 22); -- 7*13+21 mod 30 = 22
-- 
      -- Verify CF
      verify_cf(2059, 45, 34, 91, 45, 136, 35, 227, 54);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;


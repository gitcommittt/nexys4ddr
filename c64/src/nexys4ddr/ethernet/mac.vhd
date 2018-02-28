library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module connects to the LAN8720A Ethernet PHY. The PHY supports the RMII specification.
--
-- From the NEXYS 4 DDR schematic
-- RXD0/MODE0   : External pull UP
-- RXD1/MODE1   : External pull UP
-- CRS_DV/MODE2 : External pull UP
-- RXERR/PHYAD0 : External pull UP
-- MDIO         : External pull UP
-- LED2/NINTSEL : According to note on schematic, the PHY operates in REF_CLK in Mode (ETH_REFCLK = 50 MHz). External pull UP.
-- LED1/REGOFF  : Floating (LOW)
-- NRST         : External pull UP
--
-- This means:
-- MODE    => All capable. Auto-negotiation enabled.
-- PHYAD   => SMI address 1
-- REGOFF  => Internal 1.2 V regulator is ENABLED.
-- NINTSEL => nINT/REFCLKO is an active low interrupt output.
--            The REF_CLK is sourced externally and must be driven
--            on the XTAL1/CLKIN pin.
--
-- All signals are connected to BANK 16 of the FPGA, except: eth_rstn_o and eth_clkin_o are connected to BANK 35.
--
-- When transmitting, packets must be preceeded by an 8-byte preamble
-- in hex: 55 55 55 55 55 55 55 D5
-- Each byte is transmitted with LSB first.
-- Frames are appended with a 32-bit CRC, and then followed by 12 bytes of interpacket gap (idle).
--
-- Timing (from the data sheet):
-- On the transmit side: The MAC controller drives the transmit data onto the
-- TXD bus and asserts TXEN to indicate valid data.  The data is latched by the
-- transceivers RMII block on the rising edge of REF_CLK. The data is in the
-- form of 2-bit wide 50MHz data. 
-- SSD (/J/K/) is "Sent for rising TXEN".
--
-- On the receive side: The 2-bit data nibbles are sent to the RMII block.
-- These data nibbles are clocked to the controller at a rate of 50MHz. The
-- controller samples the data on the rising edge of XTAL1/CLKIN (REF_CLK). To
-- ensure that the setup and hold requirements are met, the nibbles are clocked
-- out of the transceiver on the falling edge of XTAL1/CLKIN (REF_CLK). 

entity mac is

   port (
      clk50_i      : in    std_logic;        -- Must be 50 MHz

      -- Pulling interface
      data_i       : in    std_logic_vector(7 downto 0);
      sof_i        : in    std_logic;
      eof_i        : in    std_logic;
      empty_i      : in    std_logic;
      rden_o       : out   std_logic;

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic         -- Connected to XTAL1/CLKIN. Must be driven to 50 MHz.
                                             -- All RMII signals are syunchronous to this clock.
   );
end mac;

architecture Structural of mac is

   signal eth_txen   : std_logic := '0';
   signal eth_mdc    : std_logic := '0';  -- Not used at the moment.
   signal eth_rstn   : std_logic := '0';  -- Assert reset by default.

   -- Minimum reset assert time is 25 ms. At 50 MHz (= 20 ns) this is approx 10^6 clock cycles.
   -- Here we have 21 bits, corresponding to approx 2*10^6 clock cycles, i.e. 40 ms.
--   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '1');   -- Set to all-ones, to start the count down.
--   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '0');   -- Set to all-ones, to start the count down.
   signal rst_cnt    : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(50, 21));   -- 1 us.

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PRE2_ST, PAYLOAD_ST, LAST_ST, CRC_ST, IFG_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   signal byte_cnt   : integer range 0 to 12000000;
   signal cur_byte   : std_logic_vector(7 downto 0) := X"00";
   signal twobit_cnt : std_logic_vector(1 downto 0) := "00";

   signal crc        : std_logic_vector(31 downto 0);
   signal crc_reg    : std_logic_vector(31 downto 0);
   signal crc_enable : std_logic;

begin

   -- Calculate CRC
   proc_crc : process (clk50_i)
      variable crc_v : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk50_i) then
         if crc_enable = '1' then   -- Consume two bits of data
            crc_v := crc;
            for i in 0 to 1 loop
               if cur_byte(i) = crc_v(31) then
                  crc_v :=  crc_v(30 downto 0) & '0';
               else
                  crc_v := (crc_v(30 downto 0) & '0') xor x"04C11DB7";
               end if;
            end loop;
            crc <= crc_v;
         else
            crc <= (others => '1');
         end if;
      end if;
   end process proc_crc;

   -- Generate PHY reset
   proc_eth_rstn : process (clk50_i)
   begin
      if rising_edge(clk50_i) then
         if rst_cnt /= 0 or eth_rstn = '0' then
            rst_cnt <= rst_cnt - 1;
         else
            eth_rstn <= '1';              -- Clear reset
         end if;
      end if;
   end process proc_eth_rstn;

   -- Generate MAC framing
   proc_mac : process (clk50_i)
   begin
      if rising_edge(clk50_i) then
         rden_o     <= '0';

         twobit_cnt <= twobit_cnt + 1;
         cur_byte   <= "00" & cur_byte(7 downto 2);

         if twobit_cnt = 0 then        -- Only change state on a byte boundary.
            case fsm_state is
               when IDLE_ST    =>
                  eth_txen <= '0';
                  if empty_i = '0' and eth_rstn = '1' and rst_cnt = 0 then
                     assert sof_i = '1' report "Missing SOF" severity failure;
                     byte_cnt  <= 7;
                     cur_byte  <= X"55";
                     fsm_state <= PRE1_ST;
                     eth_txen  <= '1';
                  end if;

               when PRE1_ST    =>
                  cur_byte  <= X"55";
                  if byte_cnt = 1 then
                     byte_cnt  <= 1;
                     cur_byte  <= X"D5";
                     fsm_state <= PRE2_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when PRE2_ST    =>
                  crc_enable <= '1';
                  cur_byte  <= data_i;
                  rden_o    <= '1';
                  fsm_state <= PAYLOAD_ST;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     fsm_state <= IFG_ST;
                     rden_o    <= '0';
                  end if;

               when PAYLOAD_ST =>
                  cur_byte <= data_i;
                  rden_o   <= '1';
                  if eof_i = '1' then
                     fsm_state <= LAST_ST;
                  end if;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     fsm_state <= IFG_ST;
                     rden_o    <= '0';
                  end if;

               when LAST_ST => 
                  byte_cnt   <= 4;
                  cur_byte   <= not (crc(24) & crc(25) & crc(26) & crc(27) &
                                     crc(28) & crc(29) & crc(30) & crc(31));      -- CRC is transmitted MSB first.
                  crc_reg    <= crc(23 downto 0) & X"00";
                  crc_enable <= '0';         -- This will reset the CRC.
                  fsm_state  <= CRC_ST;

               when CRC_ST =>
                  cur_byte <= not (crc_reg(24) & crc_reg(25) & crc_reg(26) & crc_reg(27) &
                                   crc_reg(28) & crc_reg(29) & crc_reg(30) & crc_reg(31));      -- CRC is transmitted MSB first.
                  crc_reg  <= crc_reg(23 downto 0) & X"00";
                  if byte_cnt = 1 then
                     byte_cnt  <= 11000000;           -- Only 11 octets, because the next state is always the idle state.
                     fsm_state <= IFG_ST;
                     eth_txen  <= '0';
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when IFG_ST =>
                  if byte_cnt = 1 then
                     fsm_state <= IDLE_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

            end case;
         end if;
      end if;
   end process proc_mac;


   -- Drive output signals
   eth_refclk_o <= clk50_i;
   eth_txd_o    <= cur_byte(1 downto 0);
   eth_txen_o   <= eth_txen;
   eth_rstn_o   <= eth_rstn;

end Structural;

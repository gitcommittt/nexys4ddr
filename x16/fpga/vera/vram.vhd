library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block contain the entire Video RAM.

-- At this early stage, I've only allocated 64 kB.
-- So only the area between 0x00000 - 0x0FFFF is valid.

entity vram is
   port (
      clk_i     : in  std_logic;
      -- Write port
      wr_addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      wr_en_i   : in  std_logic;
      wr_data_i : in  std_logic_vector( 7 downto 0);
      -- Read port
      rd_addr_i : in  std_logic_vector(16 downto 0);  -- 17 bit address allows for 128 kB
      rd_en_i   : in  std_logic;
      rd_data_o : out std_logic_vector( 7 downto 0)
   );
end vram;

architecture structural of vram is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 65535) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem_r : mem_t := (
      X"3C", X"66", X"6E", X"6E", X"60", X"62", X"3C", X"00",
      X"18", X"3C", X"66", X"7E", X"66", X"66", X"66", X"00",
      X"7C", X"66", X"66", X"7C", X"66", X"66", X"7C", X"00",
      X"3C", X"66", X"60", X"60", X"60", X"66", X"3C", X"00",
      X"78", X"6C", X"66", X"66", X"66", X"6C", X"78", X"00",
      X"7E", X"60", X"60", X"78", X"60", X"60", X"7E", X"00",
      X"7E", X"60", X"60", X"78", X"60", X"60", X"60", X"00",
      X"3C", X"66", X"60", X"6E", X"66", X"66", X"3C", X"00",
      X"66", X"66", X"66", X"7E", X"66", X"66", X"66", X"00",
      X"3C", X"18", X"18", X"18", X"18", X"18", X"3C", X"00",
      X"1E", X"0C", X"0C", X"0C", X"0C", X"6C", X"38", X"00",
      X"66", X"6C", X"78", X"70", X"78", X"6C", X"66", X"00",
      X"60", X"60", X"60", X"60", X"60", X"60", X"7E", X"00",
      X"63", X"77", X"7F", X"6B", X"63", X"63", X"63", X"00",
      X"66", X"76", X"7E", X"7E", X"6E", X"66", X"66", X"00",
      X"3C", X"66", X"66", X"66", X"66", X"66", X"3C", X"00",
      X"7C", X"66", X"66", X"7C", X"60", X"60", X"60", X"00",
      X"3C", X"66", X"66", X"66", X"66", X"3C", X"0E", X"00",
      X"7C", X"66", X"66", X"7C", X"78", X"6C", X"66", X"00",
      X"3C", X"66", X"60", X"3C", X"06", X"66", X"3C", X"00",
      X"7E", X"18", X"18", X"18", X"18", X"18", X"18", X"00",
      X"66", X"66", X"66", X"66", X"66", X"66", X"3C", X"00",
      X"66", X"66", X"66", X"66", X"66", X"3C", X"18", X"00",
      X"63", X"63", X"63", X"6B", X"7F", X"77", X"63", X"00",
      X"66", X"66", X"3C", X"18", X"3C", X"66", X"66", X"00",
      X"66", X"66", X"66", X"3C", X"18", X"18", X"18", X"00",
      X"7E", X"06", X"0C", X"18", X"30", X"60", X"7E", X"00",
      X"3C", X"30", X"30", X"30", X"30", X"30", X"3C", X"00",
      X"0C", X"12", X"30", X"7C", X"30", X"62", X"FC", X"00",
      X"3C", X"0C", X"0C", X"0C", X"0C", X"0C", X"3C", X"00",
      X"00", X"18", X"3C", X"7E", X"18", X"18", X"18", X"18",
      X"00", X"10", X"30", X"7F", X"7F", X"30", X"10", X"00",
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"18", X"18", X"18", X"18", X"00", X"00", X"18", X"00",
      X"66", X"66", X"66", X"00", X"00", X"00", X"00", X"00",
      X"66", X"66", X"FF", X"66", X"FF", X"66", X"66", X"00",
      X"18", X"3E", X"60", X"3C", X"06", X"7C", X"18", X"00",
      X"62", X"66", X"0C", X"18", X"30", X"66", X"46", X"00",
      X"3C", X"66", X"3C", X"38", X"67", X"66", X"3F", X"00",
      X"06", X"0C", X"18", X"00", X"00", X"00", X"00", X"00",
      X"0C", X"18", X"30", X"30", X"30", X"18", X"0C", X"00",
      X"30", X"18", X"0C", X"0C", X"0C", X"18", X"30", X"00",
      X"00", X"66", X"3C", X"FF", X"3C", X"66", X"00", X"00",
      X"00", X"18", X"18", X"7E", X"18", X"18", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"18", X"18", X"30",
      X"00", X"00", X"00", X"7E", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"18", X"18", X"00",
      X"00", X"03", X"06", X"0C", X"18", X"30", X"60", X"00",
      X"3C", X"66", X"6E", X"76", X"66", X"66", X"3C", X"00",
      X"18", X"18", X"38", X"18", X"18", X"18", X"7E", X"00",
      X"3C", X"66", X"06", X"0C", X"30", X"60", X"7E", X"00",
      X"3C", X"66", X"06", X"1C", X"06", X"66", X"3C", X"00",
      X"06", X"0E", X"1E", X"66", X"7F", X"06", X"06", X"00",
      X"7E", X"60", X"7C", X"06", X"06", X"66", X"3C", X"00",
      X"3C", X"66", X"60", X"7C", X"66", X"66", X"3C", X"00",
      X"7E", X"66", X"0C", X"18", X"18", X"18", X"18", X"00",
      X"3C", X"66", X"66", X"3C", X"66", X"66", X"3C", X"00",
      X"3C", X"66", X"66", X"3E", X"06", X"66", X"3C", X"00",
      X"00", X"00", X"18", X"00", X"00", X"18", X"00", X"00",
      X"00", X"00", X"18", X"00", X"00", X"18", X"18", X"30",
      X"0E", X"18", X"30", X"60", X"30", X"18", X"0E", X"00",
      X"00", X"00", X"7E", X"00", X"7E", X"00", X"00", X"00",
      X"70", X"18", X"0C", X"06", X"0C", X"18", X"70", X"00",
      X"3C", X"66", X"06", X"0C", X"18", X"00", X"18", X"00",
      X"00", X"00", X"00", X"FF", X"FF", X"00", X"00", X"00",
      X"08", X"1C", X"3E", X"7F", X"7F", X"1C", X"3E", X"00",
      X"18", X"18", X"18", X"18", X"18", X"18", X"18", X"18",
      X"00", X"00", X"00", X"FF", X"FF", X"00", X"00", X"00",
      X"00", X"00", X"FF", X"FF", X"00", X"00", X"00", X"00",
      X"00", X"FF", X"FF", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"FF", X"FF", X"00", X"00",
      X"30", X"30", X"30", X"30", X"30", X"30", X"30", X"30",
      X"0C", X"0C", X"0C", X"0C", X"0C", X"0C", X"0C", X"0C",
      X"00", X"00", X"00", X"E0", X"F0", X"38", X"18", X"18",
      X"18", X"18", X"1C", X"0F", X"07", X"00", X"00", X"00",
      X"18", X"18", X"38", X"F0", X"E0", X"00", X"00", X"00",
      X"C0", X"C0", X"C0", X"C0", X"C0", X"C0", X"FF", X"FF",
      X"C0", X"E0", X"70", X"38", X"1C", X"0E", X"07", X"03",
      X"03", X"07", X"0E", X"1C", X"38", X"70", X"E0", X"C0",
      X"FF", X"FF", X"C0", X"C0", X"C0", X"C0", X"C0", X"C0",
      X"FF", X"FF", X"03", X"03", X"03", X"03", X"03", X"03",
      X"00", X"3C", X"7E", X"7E", X"7E", X"7E", X"3C", X"00",
      X"00", X"00", X"00", X"00", X"00", X"FF", X"FF", X"00",
      X"36", X"7F", X"7F", X"7F", X"3E", X"1C", X"08", X"00",
      X"60", X"60", X"60", X"60", X"60", X"60", X"60", X"60",
      X"00", X"00", X"00", X"07", X"0F", X"1C", X"18", X"18",
      X"C3", X"E7", X"7E", X"3C", X"3C", X"7E", X"E7", X"C3",
      X"00", X"3C", X"7E", X"66", X"66", X"7E", X"3C", X"00",
      X"18", X"18", X"66", X"66", X"18", X"18", X"3C", X"00",
      X"06", X"06", X"06", X"06", X"06", X"06", X"06", X"06",
      X"08", X"1C", X"3E", X"7F", X"3E", X"1C", X"08", X"00",
      X"18", X"18", X"18", X"FF", X"FF", X"18", X"18", X"18",
      X"C0", X"C0", X"30", X"30", X"C0", X"C0", X"30", X"30",
      X"18", X"18", X"18", X"18", X"18", X"18", X"18", X"18",
      X"00", X"00", X"03", X"3E", X"76", X"36", X"36", X"00",
      X"FF", X"7F", X"3F", X"1F", X"0F", X"07", X"03", X"01",
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"F0", X"F0", X"F0", X"F0", X"F0", X"F0", X"F0", X"F0",
      X"00", X"00", X"00", X"00", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"FF",
      X"C0", X"C0", X"C0", X"C0", X"C0", X"C0", X"C0", X"C0",
      X"CC", X"CC", X"33", X"33", X"CC", X"CC", X"33", X"33",
      X"03", X"03", X"03", X"03", X"03", X"03", X"03", X"03",
      X"00", X"00", X"00", X"00", X"CC", X"CC", X"33", X"33",
      X"FF", X"FE", X"FC", X"F8", X"F0", X"E0", X"C0", X"80",
      X"03", X"03", X"03", X"03", X"03", X"03", X"03", X"03",
      X"18", X"18", X"18", X"1F", X"1F", X"18", X"18", X"18",
      X"00", X"00", X"00", X"00", X"0F", X"0F", X"0F", X"0F",
      X"18", X"18", X"18", X"1F", X"1F", X"00", X"00", X"00",
      X"00", X"00", X"00", X"F8", X"F8", X"18", X"18", X"18",
      X"00", X"00", X"00", X"00", X"00", X"00", X"FF", X"FF",
      X"00", X"00", X"00", X"1F", X"1F", X"18", X"18", X"18",
      X"18", X"18", X"18", X"FF", X"FF", X"00", X"00", X"00",
      X"00", X"00", X"00", X"FF", X"FF", X"18", X"18", X"18",
      X"18", X"18", X"18", X"F8", X"F8", X"18", X"18", X"18",
      X"C0", X"C0", X"C0", X"C0", X"C0", X"C0", X"C0", X"C0",
      X"E0", X"E0", X"E0", X"E0", X"E0", X"E0", X"E0", X"E0",
      X"07", X"07", X"07", X"07", X"07", X"07", X"07", X"07",
      X"FF", X"FF", X"00", X"00", X"00", X"00", X"00", X"00",
      X"FF", X"FF", X"FF", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"FF", X"FF", X"FF",
      X"03", X"03", X"03", X"03", X"03", X"03", X"FF", X"FF",
      X"00", X"00", X"00", X"00", X"F0", X"F0", X"F0", X"F0",
      X"0F", X"0F", X"0F", X"0F", X"00", X"00", X"00", X"00",
      X"18", X"18", X"18", X"F8", X"F8", X"00", X"00", X"00",
      X"F0", X"F0", X"F0", X"F0", X"00", X"00", X"00", X"00",
      X"F0", X"F0", X"F0", X"F0", X"0F", X"0F", X"0F", X"0F",
      X"C3", X"99", X"91", X"91", X"9F", X"9D", X"C3", X"FF",
      X"E7", X"C3", X"99", X"81", X"99", X"99", X"99", X"FF",
      X"83", X"99", X"99", X"83", X"99", X"99", X"83", X"FF",
      X"C3", X"99", X"9F", X"9F", X"9F", X"99", X"C3", X"FF",
      X"87", X"93", X"99", X"99", X"99", X"93", X"87", X"FF",
      X"81", X"9F", X"9F", X"87", X"9F", X"9F", X"81", X"FF",
      X"81", X"9F", X"9F", X"87", X"9F", X"9F", X"9F", X"FF",
      X"C3", X"99", X"9F", X"91", X"99", X"99", X"C3", X"FF",
      X"99", X"99", X"99", X"81", X"99", X"99", X"99", X"FF",
      X"C3", X"E7", X"E7", X"E7", X"E7", X"E7", X"C3", X"FF",
      X"E1", X"F3", X"F3", X"F3", X"F3", X"93", X"C7", X"FF",
      X"99", X"93", X"87", X"8F", X"87", X"93", X"99", X"FF",
      X"9F", X"9F", X"9F", X"9F", X"9F", X"9F", X"81", X"FF",
      X"9C", X"88", X"80", X"94", X"9C", X"9C", X"9C", X"FF",
      X"99", X"89", X"81", X"81", X"91", X"99", X"99", X"FF",
      X"C3", X"99", X"99", X"99", X"99", X"99", X"C3", X"FF",
      X"83", X"99", X"99", X"83", X"9F", X"9F", X"9F", X"FF",
      X"C3", X"99", X"99", X"99", X"99", X"C3", X"F1", X"FF",
      X"83", X"99", X"99", X"83", X"87", X"93", X"99", X"FF",
      X"C3", X"99", X"9F", X"C3", X"F9", X"99", X"C3", X"FF",
      X"81", X"E7", X"E7", X"E7", X"E7", X"E7", X"E7", X"FF",
      X"99", X"99", X"99", X"99", X"99", X"99", X"C3", X"FF",
      X"99", X"99", X"99", X"99", X"99", X"C3", X"E7", X"FF",
      X"9C", X"9C", X"9C", X"94", X"80", X"88", X"9C", X"FF",
      X"99", X"99", X"C3", X"E7", X"C3", X"99", X"99", X"FF",
      X"99", X"99", X"99", X"C3", X"E7", X"E7", X"E7", X"FF",
      X"81", X"F9", X"F3", X"E7", X"CF", X"9F", X"81", X"FF",
      X"C3", X"CF", X"CF", X"CF", X"CF", X"CF", X"C3", X"FF",
      X"F3", X"ED", X"CF", X"83", X"CF", X"9D", X"03", X"FF",
      X"C3", X"F3", X"F3", X"F3", X"F3", X"F3", X"C3", X"FF",
      X"FF", X"E7", X"C3", X"81", X"E7", X"E7", X"E7", X"E7",
      X"FF", X"EF", X"CF", X"80", X"80", X"CF", X"EF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"E7", X"E7", X"E7", X"E7", X"FF", X"FF", X"E7", X"FF",
      X"99", X"99", X"99", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"99", X"99", X"00", X"99", X"00", X"99", X"99", X"FF",
      X"E7", X"C1", X"9F", X"C3", X"F9", X"83", X"E7", X"FF",
      X"9D", X"99", X"F3", X"E7", X"CF", X"99", X"B9", X"FF",
      X"C3", X"99", X"C3", X"C7", X"98", X"99", X"C0", X"FF",
      X"F9", X"F3", X"E7", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"F3", X"E7", X"CF", X"CF", X"CF", X"E7", X"F3", X"FF",
      X"CF", X"E7", X"F3", X"F3", X"F3", X"E7", X"CF", X"FF",
      X"FF", X"99", X"C3", X"00", X"C3", X"99", X"FF", X"FF",
      X"FF", X"E7", X"E7", X"81", X"E7", X"E7", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"E7", X"E7", X"CF",
      X"FF", X"FF", X"FF", X"81", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"E7", X"E7", X"FF",
      X"FF", X"FC", X"F9", X"F3", X"E7", X"CF", X"9F", X"FF",
      X"C3", X"99", X"91", X"89", X"99", X"99", X"C3", X"FF",
      X"E7", X"E7", X"C7", X"E7", X"E7", X"E7", X"81", X"FF",
      X"C3", X"99", X"F9", X"F3", X"CF", X"9F", X"81", X"FF",
      X"C3", X"99", X"F9", X"E3", X"F9", X"99", X"C3", X"FF",
      X"F9", X"F1", X"E1", X"99", X"80", X"F9", X"F9", X"FF",
      X"81", X"9F", X"83", X"F9", X"F9", X"99", X"C3", X"FF",
      X"C3", X"99", X"9F", X"83", X"99", X"99", X"C3", X"FF",
      X"81", X"99", X"F3", X"E7", X"E7", X"E7", X"E7", X"FF",
      X"C3", X"99", X"99", X"C3", X"99", X"99", X"C3", X"FF",
      X"C3", X"99", X"99", X"C1", X"F9", X"99", X"C3", X"FF",
      X"FF", X"FF", X"E7", X"FF", X"FF", X"E7", X"FF", X"FF",
      X"FF", X"FF", X"E7", X"FF", X"FF", X"E7", X"E7", X"CF",
      X"F1", X"E7", X"CF", X"9F", X"CF", X"E7", X"F1", X"FF",
      X"FF", X"FF", X"81", X"FF", X"81", X"FF", X"FF", X"FF",
      X"8F", X"E7", X"F3", X"F9", X"F3", X"E7", X"8F", X"FF",
      X"C3", X"99", X"F9", X"F3", X"E7", X"FF", X"E7", X"FF",
      X"FF", X"FF", X"FF", X"00", X"00", X"FF", X"FF", X"FF",
      X"F7", X"E3", X"C1", X"80", X"80", X"E3", X"C1", X"FF",
      X"E7", X"E7", X"E7", X"E7", X"E7", X"E7", X"E7", X"E7",
      X"FF", X"FF", X"FF", X"00", X"00", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"00", X"00", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"00", X"00", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"00", X"00", X"FF", X"FF",
      X"CF", X"CF", X"CF", X"CF", X"CF", X"CF", X"CF", X"CF",
      X"F3", X"F3", X"F3", X"F3", X"F3", X"F3", X"F3", X"F3",
      X"FF", X"FF", X"FF", X"1F", X"0F", X"C7", X"E7", X"E7",
      X"E7", X"E7", X"E3", X"F0", X"F8", X"FF", X"FF", X"FF",
      X"E7", X"E7", X"C7", X"0F", X"1F", X"FF", X"FF", X"FF",
      X"3F", X"3F", X"3F", X"3F", X"3F", X"3F", X"00", X"00",
      X"3F", X"1F", X"8F", X"C7", X"E3", X"F1", X"F8", X"FC",
      X"FC", X"F8", X"F1", X"E3", X"C7", X"8F", X"1F", X"3F",
      X"00", X"00", X"3F", X"3F", X"3F", X"3F", X"3F", X"3F",
      X"00", X"00", X"FC", X"FC", X"FC", X"FC", X"FC", X"FC",
      X"FF", X"C3", X"81", X"81", X"81", X"81", X"C3", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"00", X"00", X"FF",
      X"C9", X"80", X"80", X"80", X"C1", X"E3", X"F7", X"FF",
      X"9F", X"9F", X"9F", X"9F", X"9F", X"9F", X"9F", X"9F",
      X"FF", X"FF", X"FF", X"F8", X"F0", X"E3", X"E7", X"E7",
      X"3C", X"18", X"81", X"C3", X"C3", X"81", X"18", X"3C",
      X"FF", X"C3", X"81", X"99", X"99", X"81", X"C3", X"FF",
      X"E7", X"E7", X"99", X"99", X"E7", X"E7", X"C3", X"FF",
      X"F9", X"F9", X"F9", X"F9", X"F9", X"F9", X"F9", X"F9",
      X"F7", X"E3", X"C1", X"80", X"C1", X"E3", X"F7", X"FF",
      X"E7", X"E7", X"E7", X"00", X"00", X"E7", X"E7", X"E7",
      X"3F", X"3F", X"CF", X"CF", X"3F", X"3F", X"CF", X"CF",
      X"E7", X"E7", X"E7", X"E7", X"E7", X"E7", X"E7", X"E7",
      X"FF", X"FF", X"FC", X"C1", X"89", X"C9", X"C9", X"FF",
      X"00", X"80", X"C0", X"E0", X"F0", X"F8", X"FC", X"FE",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"0F", X"0F", X"0F", X"0F", X"0F", X"0F", X"0F", X"0F",
      X"FF", X"FF", X"FF", X"FF", X"00", X"00", X"00", X"00",
      X"00", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"00",
      X"3F", X"3F", X"3F", X"3F", X"3F", X"3F", X"3F", X"3F",
      X"33", X"33", X"CC", X"CC", X"33", X"33", X"CC", X"CC",
      X"FC", X"FC", X"FC", X"FC", X"FC", X"FC", X"FC", X"FC",
      X"FF", X"FF", X"FF", X"FF", X"33", X"33", X"CC", X"CC",
      X"00", X"01", X"03", X"07", X"0F", X"1F", X"3F", X"7F",
      X"FC", X"FC", X"FC", X"FC", X"FC", X"FC", X"FC", X"FC",
      X"E7", X"E7", X"E7", X"E0", X"E0", X"E7", X"E7", X"E7",
      X"FF", X"FF", X"FF", X"FF", X"F0", X"F0", X"F0", X"F0",
      X"E7", X"E7", X"E7", X"E0", X"E0", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"07", X"07", X"E7", X"E7", X"E7",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"FF", X"00", X"00",
      X"FF", X"FF", X"FF", X"E0", X"E0", X"E7", X"E7", X"E7",
      X"E7", X"E7", X"E7", X"00", X"00", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"00", X"00", X"E7", X"E7", X"E7",
      X"E7", X"E7", X"E7", X"07", X"07", X"E7", X"E7", X"E7",
      X"3F", X"3F", X"3F", X"3F", X"3F", X"3F", X"3F", X"3F",
      X"1F", X"1F", X"1F", X"1F", X"1F", X"1F", X"1F", X"1F",
      X"F8", X"F8", X"F8", X"F8", X"F8", X"F8", X"F8", X"F8",
      X"00", X"00", X"FF", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"00", X"00", X"00", X"FF", X"FF", X"FF", X"FF", X"FF",
      X"FF", X"FF", X"FF", X"FF", X"FF", X"00", X"00", X"00",
      X"FC", X"FC", X"FC", X"FC", X"FC", X"FC", X"00", X"00",
      X"FF", X"FF", X"FF", X"FF", X"0F", X"0F", X"0F", X"0F",
      X"F0", X"F0", X"F0", X"F0", X"FF", X"FF", X"FF", X"FF",
      X"E7", X"E7", X"E7", X"07", X"07", X"FF", X"FF", X"FF",
      X"0F", X"0F", X"0F", X"0F", X"FF", X"FF", X"FF", X"FF",
      X"0F", X"0F", X"0F", X"0F", X"F0", X"F0", X"F0", X"F0",
   others => X"00");

begin

   -- Write process
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            mem_r(to_integer(wr_addr_i(15 downto 0))) <= wr_data_i;
         end if;
      end if;
   end process p_write;

   -- Read process.
   p_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rd_en_i = '1' then
            rd_data_o <= mem_r(to_integer(rd_addr_i(15 downto 0)));
         end if;
      end if;
   end process p_read;

end structural;


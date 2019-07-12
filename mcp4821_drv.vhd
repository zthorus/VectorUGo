--Driver for the MCP4821 DAC

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mcp4821_drv is
  port(
        clk_in    : in std_logic;
        d         : in std_logic_vector(7 downto 0);
		  d_valid   : in std_logic;
		  zero_trim : in std_logic_vector(3 downto 0);
		  sdi       : out std_logic;
		  ncs       : out std_logic;
		  nladc     : out std_logic;
		  clk       : out std_logic
		);
end mcp4821_drv;

architecture behavior of mcp4821_drv is
  signal r : std_logic_vector(14 downto 0);
begin
  clk <= not clk_in;
  process(clk_in)
    variable c : integer := 0;
  begin
    if rising_edge(clk_in) then
	   if ((c = 0) and (d_valid = '1')) then
        sdi <= '0';
		  r(14) <= '0';
		  r(13) <= '0';
		  r(12) <= '1';
		  r(11 downto 4) <= d; 
		  r(3 downto 0) <= zero_trim;
		  ncs <= '0';
		  nladc <= '1';
		  c := 1;
		else
		  if ((c >= 1) and (c < 16)) then
		    sdi <= r(14);
		    r(14) <= r(13);
		    r(13) <= r(12);
		    r(12) <= r(11);
		    r(11) <= r(10);
		    r(10) <= r(9);
		    r(9) <= r(8);
		    r(8) <= r(7);
		    r(7) <= r(6);
		    r(6) <= r(5);
		    r(5) <= r(4);
			 r(4) <= r(3);
			 r(3) <= r(2);
			 r(2) <= r(1);
			 r(1) <= r(0);
		    c:= c + 1;
		  else
		    if (c = 16) then
			   ncs <= '1';
	         c := 17;
			 else
			   nladc <= '0';
			   c := 0;
			 end if;
		  end if; -- if ((c >= 1) and (c < 16)) then
		end if; -- if (c = 0) then
	 end if; -- if riding_edge(clk) then
  end process;
 end behavior; 	 
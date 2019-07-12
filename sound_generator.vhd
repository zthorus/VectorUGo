-- sound generator for games

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sound_generator is
  port (clk : in std_logic;
        cmd : in std_logic_vector(1 downto 0);
        spkr : out std_logic
		 );
end sound_generator;

architecture behavior of sound_generator is
begin
  process(clk)
    variable state : integer range 0 to 7 := 0;
	 variable c1 : integer range 0 to 255;
	 variable c2 : integer range 0 to 255; 
	 variable s : std_logic := '0';
	 variable n : std_logic_vector(7 downto 0);
  begin 
    if (rising_edge(clk)) then
		if ((cmd = "01") and (state = 0)) then
		    state := 1;
			 c1 := 2;
			 c2 := 2;
			 s := '0';
		end if;
		if ((cmd = "10") and (state <= 1)) then
		  state := 2;
		  n := "11010101";
		  c1 := 0;
		  c2 := 0;
		end if;  
		if ((cmd = "11") and (state <= 2)) then
		  state := 3;
		  n := "11010101";
		  c1 := 0;
		  c2 := 0;
		end if;  
		if (state = 1) then
		  c2 := c2 - 1;
		  if (c2 = 0) then
		    c2 := c1;
			 c1 := c1 + 1;
			 s := not s;
			 if (c1 > 200) then
			   s := '0';
			   state := 0;
			 end if;
			 spkr <= s;
		  end if;
		end if;
		if (state = 2) then
		  c2 := c2 + 1;
		  if (c2 > (80 + c1)) then
		    s := n(0);
		    n := (n(3) xor n(5)) & n(7 downto 1);
			 c2 := 0;
		    c1 := c1 + 1;
		    if (c1 > 100) then
		      state := 0;
				s := '0';
		    end if;
			 spkr <= s;
		  end if;
		end if;
		if (state = 3) then
		  c2 := c2 + 1;
		  if (c2 > (120 + c1)) then
		    s := n(0);
		    n:= (n(3) xor n(5)) & n(7 downto 1);
			 c2 := 0;
		    c1 := c1 + 1;
		    if (c1 > 100) then
		      state := 0;
				s := '0';
		    end if;
			 spkr <= s;
		 end if;
		end if;
	 end if;
	end process;
end behavior;	
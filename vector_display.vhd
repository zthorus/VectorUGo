
-- Vector-display system, X and Y outputs sent to DACs
-- The table of vectors to be drawn is stored in a RAM 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vector_display is
  port (
    clk       : in std_logic;                     -- 10-MHz clock driving the system
    data      : in std_logic_vector(23 downto 0); -- data on vector from memory
	 nb_vec    : in std_logic_vector(9 downto 0);  -- number of vectors to be drawn
	 addr      : out std_logic_vector(9 downto 0); -- address of vector in table (memory)
	 vtab_rdy  : in std_logic;                     -- new vector table ready
	 rden      : out std_logic;                    -- read (vector table) enable; 
	 d_valid   : out std_logic;                    -- X and Y signals OK for DACs
	 x         : out std_logic_vector(7 downto 0); -- X signal
	 y         : out std_logic_vector(7 downto 0); -- Y signal
	 z         : out std_logic;                    -- Z signal (intensity)
	 vtab_rq   : out std_logic                     -- request for new vector table (all vectors have been drawn)
  );
end vector_display;


architecture behavior of vector_display is
begin
  process(clk)
    variable c     : integer;      -- counter (RAM access)
    variable nv    : integer;      -- number of drawn vectors
	 variable state : integer := 0; -- state of the FSM
	 variable l     : integer;         -- vector length (in on/off cycles)
	 variable v_a   : std_logic_vector(9 downto 0) := "0000000000"; -- address of vector
	 variable incr  : std_logic; -- true if xx or yy need to be incremented
  begin
    if rising_edge(clk) then
	   case state is
		  -- request for new table
	     when 0 => vtab_rq <= '1';
		            state := 1;
		  -- wait for new table ready. When ready, prepare to load 1st vector
		  when 1 => if (vtab_rdy = '1') then
		              vtab_rq <= '0';
						  v_a := "0000000000";
						  state := 2; 
						  nv := 0;
						end if;
		  -- read vector from RAM
	     when 2 => addr <= v_a;
		            rden <= '1';
						c := 0;
						state := 3;
		  -- wait a few cycles until data is ready
		  when 3 => c := c + 1;
		            if (c > 4) then
						  state := 4;
						  rden <= '0';
						end if;
		  -- get and issue the vector data (split the 24-bit data word)
		  when 4 => x <= data(23 downto 16);
						y <= data(15 downto 8);
						l := to_integer(unsigned(data(7 downto 1)));
						z <= not data(0); -- z = 1 => spot off 
						d_valid <= '1'; 
						state := 5;
						c := 0;
	     -- draw vector (wait until drawn)					
		  when 5 => c := c + 1;
		            if (c > l) then
						  d_valid <= '0';
						  nv := nv + 1 ;
						  if (nv >= to_integer(unsigned(nb_vec))) then
							 -- all vectors drawn => request new table 
							 state := 0;
						  else
							 -- otherwise, prepare to get next vector
							 v_a := v_a + 1;
							 state := 2;
						  end if;
						end if;
						
						
		  when others => state := 0;
		 end case;
	  end if;
   end process;
 end behavior;
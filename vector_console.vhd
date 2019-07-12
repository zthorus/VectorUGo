-- vector-display game console

-- 2019-04-16 : added sound_generator 


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vector_console is
  port(
        clk_in  : in std_logic;
		  joy_left  : in std_logic;
		  joy_right : in std_logic;
		  joy_up    : in std_logic;
		  joy_down  : in std_logic;
		  joy_fire  : in std_logic;
		  img_trim  : in std_logic;
		  sdi_x   : out std_logic;
		  sdi_y   : out std_logic;
		  z_axis  : out std_logic;
		  ncs_x   : out std_logic; -- used for both x and y actually
		  nladc_x : out std_logic; -- used for both x and y actually
		  clk_x   : out std_logic; -- used for both x and y actually
		  test1   : out std_logic;
		  test2   : out std_logic;
		  speaker : out std_logic
		);
end vector_console;

architecture behavior of vector_console is
  signal x_val : std_logic_vector(7 downto 0);   -- vector x-component from display to DAC driver
  signal y_val : std_logic_vector(7 downto 0);   -- vector y-component from display to DAC driver 
  signal trzx  : std_logic_vector(3 downto 0);   -- trimming x-offset for zero integration
  signal trzy  : std_logic_vector(3 downto 0);   -- trimming y-offset for zero integration
  signal d_rd  : std_logic_vector(23 downto 0);  -- data to be read from RAM
  signal d_wr  : std_logic_vector(23 downto 0);  -- data to be written into RAM
  signal d_l   : std_logic_vector(2 downto 0);   -- data to be read from ROM
  signal nv    : std_logic_vector(9 downto 0);   -- number of vectors to display
  signal a_rd  : std_logic_vector(9 downto 0);   -- address of RAM for data to be read 
  signal a_wr  : std_logic_vector(9 downto 0);   -- address of RAM for data to be written 
  signal a_l   : std_logic_vector(7 downto 0);   -- address of ROM (storing game´s landscape)
  signal dv    : std_logic;                      -- data-valid flag (from display to DAC drivers)
  signal rd    : std_logic;                      -- RAM read enable
  signal wr    : std_logic;                      -- RAM write enable
  signal treq  : std_logic;                      -- vector-table request (from display to game mgr)
  signal trdy  : std_logic;                      -- vector-table ready (from game mgr to display)
  signal clk_1 : std_logic;
  signal clk_2 : std_logic;
  signal scmd  : std_logic_vector(1 downto 0);
  
begin
  dac_x : entity work.mcp4821_drv port map(clk_1,x_val,dv,trzx,sdi_x,ncs_x,nladc_x,clk_x);
  dac_y : entity work.mcp4821_drv port map(clk_1,y_val,dv,trzy,sdi_y,open,open,open);
  disp  : entity work.vector_display port map(clk_2,d_rd,nv,a_rd,trdy,rd,dv,x_val,y_val,z_axis,treq);
  ram   : entity work.RAM_vec port map(clk_2,d_wr,a_rd,rd,a_wr,wr,d_rd);
  rom   : entity work.ROM_landscape port map(a_l,clk_2,d_l);
  game  : entity work.game1 port map(clk_2,joy_left,joy_right,joy_up,joy_down,joy_fire,img_trim,a_wr,d_wr,a_l,d_l,wr,nv,trzx,trzy,treq,trdy,scmd);
  snd   : entity work.sound_generator port map(clk_2,scmd,speaker);
  test1 <= rd;
  test2 <= wr;
		
  process(clk_in)
    variable c : integer := 0;
	 variable c2 : integer := 0;
  begin
    if rising_edge(clk_in) then
	   c:= c + 1;
		if (c > 2) then -- 2
		  clk_1 <= '0';
		else
		  clk_1 <= '1';
		end if;
		if (c > 4) then  -- 4
		  c := 0;
		end if;
	   c2 := c2 +1;
	   if (c2 > 36) then --36
		  clk_2 <= '0';
		else
		  clk_2 <= '1';
		end if;
		if (c2 > 72) then -- 72
		  c2 := 0;
		end if;
	 end if;
	 
  end process;
end behavior;
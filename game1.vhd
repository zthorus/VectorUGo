-- scramble game

-- 2019-04-24 : collision detection of bomb & bullet on ground (landscape)
-- 2019-04-16 : added sound
-- 2019-04-10 : strong spot homing (saturation/desaturation of integrators) after display of each sprite
-- 2019-04-10 : collision detection of player's sprite, fuel gauge
-- 2019-04-05 : modified for new integrators (based on OPA2604)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity game1 is
  port (
         clk_in      : in std_logic;
			joy_left    : in std_logic;
			joy_right   : in std_logic;
			joy_up      : in std_logic;
			joy_down    : in std_logic;
			joy_fire    : in std_logic;
			img_trim    : in std_logic;
			a           : out std_logic_vector(9 downto 0);
			d           : out std_logic_vector(23 downto 0);
			a_l         : out std_logic_vector(7 downto 0);
			d_l         : in std_logic_vector(2 downto 0);
			wren        : out std_logic;
			nv          : out std_logic_vector(9 downto 0);
			trim_zero_x : out std_logic_vector(3 downto 0);
		   trim_zero_y : out std_logic_vector(3 downto 0);
			vtab_rq     : in std_logic;
			vtab_rdy    : out std_logic;
			sound_cmd   : out std_logic_vector(1 downto 0)
		 );
end game1;

architecture behavior of game1 is

begin
  process(clk_in)
    variable zpt_x : integer range 0 to 255 := 157; -- value corresponding to 0 V at integrator's input (8 MSBs)
	 variable zpt_y : integer range 0 to 255 := 157;  --
	 variable trim_zx : integer range -32 to 31 := 12; -- value corresponding to 0 V at integrator's input (3 LSBs)
	 variable trim_zy : integer range -32 to 31 := 10;
    type vec_component is array(0 to 63) of integer range -128 to 127;
	 variable vx : vec_component;
	 variable vy : vec_component;
	 variable vz : std_logic_vector(0 to 63);
	 variable x_s : integer range 0 to 255 := 30;  -- coordinate (x) of player's sprite
	 variable y_s : integer range 0 to 255 := 40;  -- coordinate (y) of player's sprite
	 variable bullet : std_logic := '0';           -- state of bullet
	 variable bomb : std_logic := '0';             -- state of bomb 
	 variable mis1 : integer range 0 to 32 := 0;   -- state of missile #1
	 variable mis2 : integer range 0 to 32 := 0;   -- state of missile #2
	 variable mis3 : integer range 0 to 32 := 0;   -- state of missile #3
	 variable tank : integer range 0 to 32 := 0;   -- state of fuel tank
	 variable state : integer range 0 to 7 := 5;
	 variable nvecs  : integer range 0 to 255;
	 variable addr_l : integer range 0 to 255 := 0;
	 variable next_slope : std_logic_vector(2 downto 0); -- type of the next slope (landscape element) to appear on the right side
	 variable c : integer range 0 to 7;
	 variable c_div : integer range 0 to 7 := 0;
	 variable i : integer range 0 to 255;
	 variable lock : std_logic := '0';       -- joystick debouncing (for image trimming)
    variable xoc: integer range 0 to 255;
	 variable yoc: integer range 0 to 255;
	 type lint_component is array(0 to 13) of integer range 0 to 255;
	 variable yi : lint_component;                -- array of heights of landscape segments (origin from the left side)
	 variable xa : integer range 0 to 255;
	 variable xb : integer range 0 to 255;
	 variable ya : integer range -256 to 255;
	 variable crit : integer range -32768 to 32767; -- criterion for collision on ground
    variable hit : std_logic;	                    -- if 1, player has been hit
	 variable dead : std_logic := '0';	           -- if 1, player has been killed (explosion then reset game)
	 variable fuel : integer range 0 to 255 := 50; -- level of fuel gauge (MSBs)
	 variable c_fuel : integer range 0 to 15 := 0; -- level of fuel gauge (LSBs)
	 variable homing : integer range 0 to 7 := 0;  -- FSM for spot homing
	 variable xout : integer range -128 to 127;    -- X output to DAC
	 variable yout : integer range -128 to 127;    -- Y output to DAC
	 variable zout : std_logic;                    -- Z output to z-axis
	 variable addr_v : integer range 0 to 255;
	 
  begin
    if (rising_edge(clk_in)) then
	   if (state = 0) then
		  -- wait for vector-table request from display (end of frame)
		  if (vtab_rq = '1') then
		    if (c_div < 2) then 
		    -- re-use current vector-table
		      vtab_rdy <= '1';
			   c_div := c_div + 1;
		    else
		      -- refresh vector-table (manage animations)
			   vtab_rdy <= '1';
	         c_div := 0;
		      -- move player´s sprite (for next frame) from action on joystick
				-- or trim analog zero for x and y from action on joystick 
				if (dead = '1') then
				  -- player's sprite explosion
				  vx(2) := vx(2) + 1; vy(2) := vy(2) - 1;
		        vx(3) := vx(3) - 2; vy(3) := vy(3) + 2;
			     vx(4) := vx(4) + 2  ;
			     vx(5) := vx(5) - 2; vy(5) := vy(5) - 2; 
				else
		        if (joy_up = '0') then
		          if (img_trim = '0') then
				      if (lock = '0') then
				        lock := '1';
			           trim_zy := trim_zy + 1;
				        if (trim_zy > 15) then
				          zpt_y := zpt_y + 1;
  				          trim_zy := 0;
				        end if;
				      end if;
			       else	
				      if (y_s < 80) then 
		              y_s := y_s + 1;
				      end if;
			       end if; 
		        end if;
		        if (joy_down = '0') then
		          if (img_trim = '0') then
				      if (lock = '0') then
				        lock := '1';
		  	           trim_zy := trim_zy - 1;
			           if (trim_zy < 0 ) then
			             zpt_y := zpt_y - 1;
				          trim_zy := 15;
				        end if;
					   end if;
			       else	
		            if (y_s > 20) then 
		              y_s := y_s - 1;
		            end if;
			       end if;
		        end if;
		        if (joy_right = '0') then
		          if (img_trim = '0') then
				      if (lock = '0') then
				        lock := '1';
			           trim_zx := trim_zx + 1;
				        if (trim_zx > 15 ) then
				          zpt_x := zpt_x + 1;
				          trim_zx := 0;
				        end if;
				      end if;
			       else	
		            if (x_s < 60) then 
		              x_s := x_s + 1;
				      end if;  
		          end if;
		        end if;
		        if (joy_left = '0') then
		          if (img_trim = '0') then
				      if (lock = '0') then
				        lock := '1';
			           trim_zx := trim_zx - 1;
			  	        if (trim_zx < 0 ) then
				          zpt_x := zpt_x - 1;
				          trim_zx := 15;
				        end if;
				      end if;
			       else	
			         if (x_s > 10) then	
		              x_s := x_s - 1;
				      end if;
		          end if;
		        end if;
				end if;  
				if ((joy_left /= '0') and (joy_right /= '0') and (joy_up /= '0') and (joy_down /= '0')) then
				  lock := '0';
				end if;
		      -- animation
		      if (img_trim /= '0') then 
		        -- missiles & fuel tank
			     if (mis1 /= 0) then
			       vx(13) := vx(13) - 1;
					 if ((vx(13) < 70) and (mis1 = 1)) then -- 70
					   vy(13) := vy(13) +1;
					 end if;
				    if ((vx(13) < 2) or (vy(13) > 85)) then
				      mis1 := 0;
				    end if;
					 if (mis1 > 1) then
					   -- animate explosion
					   vx(13) := vx(13) +1; vy(13) := vy(13) -1;
					   vx(14) := vx(14) -2; vy(14) := vy(14) +2;
						vx(15) := vx(15) +2; 
						vx(16) := vx(16) -2; vy(16) := vy(16) -2;
						vx(17) := vx(17) +1; vy(17) := vy(17) -1;
						                     vy(18) := vy(18) +2;
						vx(19) := vx(19) +1; vy(19) := vy(19) -1; 
						mis1 := mis1 +1;
						if (mis1 > 8) then
						  mis1 := 0;
						end if;
				    end if;
			     end if;
			     if (mis2 /= 0) then
			       vx(21) := vx(21) - 1;
					 if ((vx(21) < 50) and (mis2 = 1)) then -- 50
					   vy(21) := vy(21) + 2;
					 end if;
				    if ((vx(21) < 2) or (vy(21) > 85)) then
				      mis2 := 0;
				    end if;
					 if (mis2 > 1) then
					   -- animate explosion
					   vx(21) := vx(21) +1; vy(21) := vy(21) -1;
					   vx(22) := vx(22) -2; vy(22) := vy(22) +2;
						vx(23) := vx(23) +2; 
						vx(24) := vx(24) -2; vy(24) := vy(24) -2;
						vx(25) := vx(25) +1; vy(25) := vy(25) -1;
						                     vy(26) := vy(26) +2;
						vx(27) := vx(27) +1; vy(27) := vy(27) -1; 
						mis2 := mis2 +1;
						if (mis2 > 8) then
						  mis2 := 0;
						end if;
				    end if;
			     end if;
			     if (mis3 /= 0) then
			       vx(29) := vx(29) - 1;
					 if ((vx(29) < 85) and (mis3 = 1)) then  
					   vy(29) := vy(29) +1;
					 end if;
				    if ((vx(29) < 2) or (vy(29) > 85)) then
				      mis3 := 0;
				    end if;
					 if (mis3 > 1) then
					   -- animate explosion
					   vx(29) := vx(29) +1; vy(29) := vy(29) -1;
					   vx(30) := vx(30) -2; vy(30) := vy(30) +2;
						vx(31) := vx(31) +2; 
						vx(32) := vx(32) -2; vy(32) := vy(32) -2;
						vx(33) := vx(33) +1; vy(33) := vy(33) -1;
						                     vy(34) := vy(34) +2;
						vx(35) := vx(35) +1; vy(35) := vy(35) -1; 
						mis3 := mis3 +1;
						if (mis3 > 8) then
						  mis3 := 0;
						end if;
					 end if;
			     end if;
			     if (tank /= 0) then
			       vx(37) := vx(37) - 1;
				    if (vx(37) < 2) then
				      tank := 0;
				    end if;
			       if (tank > 1) then
					   vx(38) := vx(38) -1; vy(38) := vy(38) +1;
						vx(39) := vx(39) +1; vy(39) := vy(39) -1;
					 	                     vy(40) := vy(40) +1;
						                     vy(41) := vy(41) -1;
						vx(42) := vx(42) +1; vy(42) := vy(42) +1;
						tank := tank +1;
						if (tank > 8) then
						  tank := 0;
						end if;
					 end if;
			     end if;
				  if ((mis1 > 1) or (mis2 > 1) or (mis2 > 1) or (tank > 1)) then
				    sound_cmd <= "00";
				  end if;
				  -- erase sprites if needed
				  if (mis1 = 0) then
				    vz(14 to 19) := "000000";
				  end if;
				  if (mis2 = 0) then
				    vz(22 to 27) := "000000";
				  end if;
				  if (mis3 = 0) then
				    vz(30 to 35) := "000000";
				  end if;
				  if (tank = 0) then
				    vz(38 to 42) := "00000";
				  end if;
		        -- landscape scrolling
		        vx(47) := vx(47) - 1;
		        if (vx(47) = 0) then
		          vx(47) := 6; -- 8
			       vy(47) := vy(47) + vy(48);
		          for n in 48 to 59 loop
			         vy(n) := vy(n + 1);
			       end loop;
				    -- integration 
			       xoc := 0;
			       yoc := 0;	
			  	    for n in 47 to 59 loop
				      xoc := xoc + vx(n);
				      yoc := yoc + vy(n);
			       end loop;
					 
				    xoc := xoc + 2;
					 -- add new element to landscape (on the right)
					 -- restore sprites (if they were exploded before)
				    case next_slope is
				      when "000" => vy(60) := 0; -- flat
				      when "001" => vy(60) := 8; -- slope up
				      when "010" => vy(60) := -8; -- slope down
				      when "011" => vy(60) := 0; -- flat (by default because value not used yet)
				      when "100" => vy(60) := 0;
				                    mis1 := 1;
				                    vx(13) := xoc; vy(13) := yoc + 2;
										  vx(14) := 0; vy(14) := -2;
		                          vx(15) := 4; vy(15) := 4; 
		                          vx(16) := -2; vy(16) := 6;
		                          vx(17) := -2; vy(17) := -6;
		                          vx(18) := 4; vy(18) := -4;
		                          vx(19) := 0; vy(19) := 2;
										  vz(14 to 19) := "111111";
				      when "101" => vy(60):= 0;
				                    mis2 := 1;
				                    vx(21) := xoc; vy(21) := yoc + 2;
										  vx(22) := 0; vy(22) := -2;
		                          vx(23) := 4; vy(23) := 4; 
		                          vx(24) := -2; vy(24) := 6;
		                          vx(25) := -2; vy(25) := -6;
		                          vx(26) := 4; vy(26) := -4;
		                          vx(27) := 0; vy(27) := 2;
							  		     vz(22 to 27) := "111111";
				      when "110" => vy(60):= 0;
				                    mis3 := 1;
				                    vx(29) := xoc; vy(29) := yoc + 2;
										  vx(30) := 0; vy(30) := -2;
		                          vx(31) := 4; vy(31) := 4; 
		                          vx(32) := -2; vy(32) := 6;
		                          vx(33) := -2; vy(33) := -6;
		                          vx(34) := 4; vy(34) := -4;
		                          vx(35) := 0; vy(35) := 2;
										  vz(30 to 35) := "111111";
				      when "111" => vy(60):= 0;
				                    tank := 1;
				                    vx(37) := xoc; vy(37) := yoc;
										  vx(38) := 0; vy(38) := 4;
		                          vx(39) := 4; vy(39) := 0;
		                          vx(40) := 0; vy(40) := -4;
		                          vx(41) := -4; vy(41) := 0;
		                          vx(42) := 4; vy(42) := 4;
										  vz(38 to 42) := "11111";
				    end case;
					  
			       addr_l := addr_l +1;
			       if (addr_l > 127) then
			         addr_l := 0;
				      vy(47) := 10;
						for n in 48 to 60 loop
			           vy(n) := 0;
		            end loop;
		          end if;
		        end if; -- if (vx(47) = 0) then
				  -- landscape integration (for player's sprite collision detection) 
				  yi(0) := vy(47);
				  for n in 1 to 13 loop
					 yi(n) := yi(n - 1) + vy(47 + n);
				  end loop;
					 
			     -- bullet & bomb
			     if ((joy_fire = '0') and (bullet = '0') and (bomb = '0')) then
			       vx(7) := x_s + 4; vy(7) := y_s;
				    vz(8) := '1'; -- make bullet visible
				    vx(10) := x_s + 8; vy(10) := y_s - 2;
				    vz(11) := '1'; -- make bomb visible
				    bullet :=  '1';
				    bomb := '1';
					 sound_cmd <= "01";
				  else
				    sound_cmd <= "00";
			     end if;
			     if (bullet = '1') then
			       vx(7) := vx(7) + 2;
				    if (vx(7) > 80) then
				      bullet := '0';
				    end if;
		        end if;
			     if (bomb = '1') then
			       vy(10) := vy(10) - 2;
				    if (vy(10) < 2) then
				      bomb := '0';
				      vz(11) := '0';
				    end if;
		        end if;
				  if (bullet = '0') then
				    vz(8) := '0';
				  end if;
				  if (bomb = '0') then
				    vz(11) := '0';
				  end if; 
			 
			     -- fuel consumption
			  	  c_fuel := c_fuel + 1;
				  if ((c_fuel > 8) and (fuel > 5)) then
				    c_fuel := 0;
				    fuel := fuel - 1;
				    vx(44) := fuel;
				    vx(45) := -fuel;
				  end if;
				  if ((fuel <= 5) and (y_s > 20)) then
				    y_s := y_s - 2;
				  end if;
		      end if; -- if (img_trim /= '0') then 
				
		      trim_zero_x <= std_logic_vector(to_unsigned(trim_zx,4));
		      trim_zero_y <= std_logic_vector(to_unsigned(trim_zy,4));
	
		      -- player's sprite position
		      vx(1) := x_s; vy(1) := y_s; 				
				
			   -- if player's sprite exploded, reset game
				if ((dead = '1') and (vx(2) > 14)) then
				  dead := '0';
				  x_s := 30;
			 	  y_s := 40;
				  fuel := 50;
				  c_fuel := 0;
				  mis1 := 0;
				  mis2 := 0;
				  mis3 := 0;
				  tank := 0;
				  bullet := '0';
				  bomb := '0';
				  addr_l := 0;
				  state := 5;
				else
		        -- otherwise prepare to write into RAM
		        state := 2;
		        c := 0;
		        nvecs := 79 ; -- 61; -- 63
		        nv <= std_logic_vector(to_unsigned(nvecs,10));
		        i := 0;
				  addr_v := 0;
				  homing := 0;
			   end if;
		    end if; -- if (c_div < 3) then
		  end if; -- if (vtab_rq = '1') then
		end if; -- if (state = 0) then
		
	   if (state = 2) then
		   -- write into RAM
		  if (c = 0) then
		    case homing is
			   -- manage FSM for spot homing
			   when 0 => if (vx(i) <= -100) then
				            -- first step  of homing
				            xout := -90; yout := -90;
								zout := '0';
								homing := 1;
							 else
							   -- display normal vector
							   xout := vx(i); yout := vy(i);
								zout := vz(i);
							 end if;
							 -- second step of homing (integrators will be saturated)
				when 1 => xout := -90; yout := -90;
				          zout := '0';
							 homing := 2;
							 -- third step of homing (de-saturation of integrators)
				when 2 => xout := 20; yout := 20;
				          zout := '0';
							 homing := 0;
				when others => homing := 0;
			 end case;				 
		    a <= std_logic_vector(to_unsigned(addr_v,10));
			 d(23 downto 16) <= std_logic_vector(to_unsigned(zpt_x - xout,8));
			 d(15 downto 8) <= std_logic_vector(to_unsigned(zpt_y - yout,8));
			 -- if input vector length = 1, actual lengths will be 9 clock-cycles
			 -- (time for vector_display to read next vector in RAM, etc...)
			 -- => adjust value of counter to have length multiple of 9 clock-cycles  
			 -- to simplify, all the vectors have a length of 2 * 9 clock-cycles (= counter set to 10)
			 --d(7 downto 1) <= "0001010";
			 -- test with 3 cycles => counter set to 19
			 d(7 downto 1) <= "0010011";
			 if (img_trim = '0') then
			   d(0) <= '1';
			 else
			   d(0) <= zout;
			 end if;
			 wren <= '1';
			 -- address next slope element of landscape to be read for ROM
			 a_l <= std_logic_vector(to_unsigned(addr_l,8));
			 c := c + 1;
		  else
		    if (c > 4) then
			   wren <= '0';
				c := 0;
				addr_v := addr_v + 1;
				if (homing = 0) then
				  -- get next vector
				  i:= i + 1;
				  if (i >= nvecs) then
				    vtab_rdy <= '1';
				    state := 3;
				  end if;
				end if;
				next_slope := d_l;
		    else
			   c := c + 1; 
		    end if;
		  end if;
		end if; -- if (state = 2) then
		if (state = 3) then
	     state := 0;
		  -- sprite collision detection state
		  -- use crappy algorithms currently (problem when compiling the right vector-crossing algorithm)
		  
		  -- collision of player's sprite (ship) with landscape
		  -- 1) find out the lanscape segment that is vertically aligned with back of the sprite (taking into acccount the landscape scrolling = v47)
		  
		  xa := x_s - vx(47) - 2;
		  -- dull algorithm because using "while" can problably not be synthesized
		  if (xa < 6) then
		    i:= 0; xb := 0;
		  end if;
		  if ((xa >= 6) and (xa < 12)) then
		    i:= 1; xb := 6;
		  end if;
		  if ((xa >= 12) and (xa < 18)) then
		    i:= 2; xb := 12;
		  end if;
		  if ((xa >= 18) and (xa < 24)) then
		    i:= 3; xb := 18;
		  end if;
		  if ((xa >= 24) and (xa < 30)) then
		    i:= 4; xb := 24;
		  end if;
		  if ((xa >= 30) and (xa < 36)) then
		    i:= 5; xb := 30;
		  end if;
		  if ((xa >= 36) and (xa < 42)) then
		    i:= 6; xb := 36;
		  end if;
		  if ((xa >= 42) and (xa < 48)) then
		    i:= 7; xb := 42;
		  end if;
		  if ((xa >= 48) and (xa < 56)) then
		    i:= 8; xb := 48;
		  end if;
		   if (xa >= 56) then
		    i:= 9; xb := 56;
		  end if;
		  
		  -- coordinates of back tip of ship w.r.t. back segment starting point
		  xa := xa - xb;
		  ya := y_s - 2 - yi(i);
		  hit := '0';
		  -- 2) test of sprite's vector (+6,+2) (bottom of the ship) with back segment
		  if (yi(i + 1) > yi(i)) then
		     -- segment = slope up (vector (+6,+8))
		    crit := ya + ya + ya - xa -18;
			 if (crit < 0) then
			   hit := '1';
			  end if;
		  end if;
		  if (yi(i + 1) < yi(i)) then
		    -- segment = slope down (vector (+6,-8))
			 crit := ya + ya + ya + xa + xa + xa + xa;
			  if (crit < 0) then
			    hit := '1';
			  end if;
		  end if;	 
		  if (yi(i + 1) = yi(i)) then
		    -- segment = flat
		    if (ya < 0) then
			   hit := '1';
			 end if;
		  end if;
		  -- 3) test of sprite's vector (+6,+2) with front landscape segment, only if it is slope up
		  if ((hit = '0') and (yi(i + 2) > yi(i + 1))) then
		    -- coordinates of front tip of ship w.r.t. front segment starting point
		    --xa := 6 - xa;
			 ya := y_s - yi(i + 1); -- := ya + 2;
		    crit := ya + ya + ya - xa - xa - xa - xa;
		    if (crit < 0) then
			    hit := '1';
			 end if;
		  end if;
		  
		  if (mis1 = 1) then
		    if ((vx(13) > (x_s - 4)) and (vx(13) < (x_s + 6)) and ((vy(13) + 8) > y_s) and ((vy(13) -2) < y_s)) then
			   hit := '1';
			 end if;	
		    if (bullet = '1') then
			   if ((vy(7) > (vy(13) -2)) and (vy(7) < (vy(13) +8)) and (vx(7) > vx(13)) and (vx(7) < (vx(13) +4))) then
				  mis1 := 2;	 
				  bullet := '0';
				end if;
			 end if;
			 if (bomb = '1') then
			   if ((vy(10) < (vy(13) + 8)) and (vy(10) > (vy(13) + 2)) and (vx(10) > vx(13)) and (vx(10) < (vx(13) +4))) then
		        mis1 := 2;
				  bomb := '0';
			   end if;
		    end if;
		  end if;
		  if (mis1 = 2) then
		    vx(13) := vx(13) + 4;
		    vx(14) := -4; vy(14) := 4;
		    vx(15) := 4; vy(15) := 0; 
		    vx(16) := -4; vy(16) := -4;
		    vx(17) := 2; vy(17) := -2;
		    vx(18) := 0; vy(18) := 8;
		    vx(19) := 2; vy(19) := -6;
		    vz(14 to 19) := "101010";
		  end if;
		  
		  if (mis2 = 1) then
		    if ((vx(21) > (x_s - 4)) and (vx(21) < (x_s + 6)) and ((vy(21) + 8) > y_s) and ((vy(21) -2) < y_s)) then
			   hit := '1';
			 end if;
		    if (bullet = '1') then
			   if ((vy(7) > (vy(21) -2)) and (vy(7) < (vy(21) +8)) and (vx(7) > vx(21)) and (vx(7) < (vx(21) +4))) then
				  mis2 := 2;
				  bullet := '0';
				end if;
			 end if;
			 if (bomb = '1') then
			   if ((vy(10) < (vy(21) + 8)) and (vy(10) > (vy(21) + 2)) and  (vx(10) > vx(21)) and (vx(10) < (vx(21) +4))) then
		        mis2 := 2;
				  bomb := '0';
			   end if;
		    end if;
		  end if;
		  if (mis2 = 2) then
		    vx(21) := vx(21) + 4;
		    vx(22) := -4; vy(22) := 4;
		    vx(23) := 4; vy(23) := 0; 
		    vx(24) := -4; vy(24) := -4;
		    vx(25) := 2; vy(25) := -2;
		    vx(26) := 0; vy(26) := 8;
		    vx(27) := 2; vy(27) := -6;
		    vz(22 to 27) := "101010";
		  end if;
		  
		  if (mis3 = 1) then
		    if ((vx(29) > (x_s - 4)) and (vx(29) < (x_s + 6)) and ((vy(29) + 8) > y_s) and ((vy(29) -2) < y_s)) then
			   hit := '1';
			 end if;
		    if (bullet = '1') then
			   if ((vy(7) > (vy(29) -2)) and (vy(7) < (vy(29) +8)) and (vx(7) > vx(29)) and (vx(7) < (vx(29) +4))) then
				  mis3 := 2;
				  bullet := '0';
				end if;
			 end if;
			 if (bomb = '1') then
			   if ((vy(10) < (vy(29) + 8)) and (vy(10) > (vy(29) + 2)) and (vx(10) > vx(29)) and (vx(10) < (vx(29) +4))) then
		        mis3 := 2;
				  bomb := '0';
			   end if;
		    end if;
		  end if;
		  if (mis3 = 2) then
		    vx(29) := vx(29) + 4;
		    vx(30) := -4; vy(30) := 4;
		    vx(31) := 4; vy(32) := 0; 
		    vx(32) := -4; vy(32) := -4;
		    vx(33) := 2; vy(33) := -2;
		    vx(34) := 0; vy(34) := 8;
		    vx(35) := 2; vy(35) := -6;
		    vz(30 to 35) := "101010";
		  end if;
		  
		  if ((hit = '1') and (dead = '0')) then
		    -- create player's sprite explosion 
			 vx(2) := 3; vy(2) := -3;
			 vx(3) := -6; vy(3) := 6;
			 vx(4) := 6 ; vy(4) := 0;
			 vx(5) := -6 ; vy(5) := -6; 
			 vz(2 to 5) := "0101";
			 dead := '1';
			 sound_cmd <= "11";
		  end if;
		  
		  if (tank = 1) then
		    if (bullet = '1') then
			   if ((vy(7) > vy(37)) and (vy(7) < (vy(37) +4)) and (vx(7) > vx(37)) and (vx(7) < (vx(37) +4))) then
				  tank := 2;
				  bullet := '0';
				end if;
			 end if;
			 if (bomb = '1') then
			   if ((vy(10) <= (vy(37) + 8)) and (vy(10) >= (vy(37) + 3)) and (vx(10) >= vx(37)) and (vx(10) <= (vx(37) +4))) then
		        tank := 2;
				  bomb := '0';
			   end if;
		    end if;
		  end if;
		  if (tank = 2) then
		    vx(37) := vx(37) +2;
		    vx(38) := -4; vy(38) := 4;
		    vx(39) := 4; vy(39) := -4;
		    vx(40) := 0; vy(40) := 6;
		    vx(41) := 0; vy(41) := -6;
		    vx(42) := 4; vy(42) := 4;
			 vz(38 to 42) := "10101";
			 fuel := fuel + 10;
			 if (fuel > 50) then
			   fuel := 50;
			 end if;	
		  end if;
		  
		  -- test if bomb or bullet hit ground
		  if (bomb = '1') then
		    xa := vx(10) - vx(47);
		    -- dull algorithm because using "while" can problably not be synthesized
		    if (xa < 6) then
		      i:= 0; xb := 0;
		    end if;
		    if ((xa >= 6) and (xa < 12)) then
		      i:= 1; xb := 6;
		    end if;
		    if ((xa >= 12) and (xa < 18)) then
		      i:= 2; xb := 12;
		    end if;
		    if ((xa >= 18) and (xa < 24)) then
		      i:= 3; xb := 18;
		    end if;
		    if ((xa >= 24) and (xa < 30)) then
		      i:= 4; xb := 24;
		    end if;
		    if ((xa >= 30) and (xa < 36)) then
		      i:= 5; xb := 30;
		    end if;
		    if ((xa >= 36) and (xa < 42)) then
		      i:= 6; xb := 36;
		    end if;
		    if ((xa >= 42) and (xa < 48)) then
		      i:= 7; xb := 42;
		    end if;
		    if ((xa >= 48) and (xa < 56)) then
		      i:= 8; xb := 48;
		    end if;
		    if (xa >= 56) then
		      i:= 9; xb := 56;
		    end if;
			 xa := xa - xb;
		    ya := vy(10) - 4 - yi(i);
			 -- flat 
			 if ((yi(i + 1) = yi(i)) and (ya < 0)) then
			   bomb := '0';
			 end if;
			 if (yi(i + 1) > yi(i)) then
			   -- slope up
			   crit := ya + ya + ya - xa - xa - xa - xa;
		      if (crit < 0) then
			     bomb := '0';
			   end if;
			 end if;
			 if (yi(i + 1) < yi(i)) then
			   -- slope down
			   crit := ya + ya + ya + xa + xa + xa + xa;
			   if (crit < 0) then
			     bomb := '0';
			   end if;
			 end if;
		  end if;
		  if (bullet = '1') then
		    xa := vx(7) - vx(47) + 4;
		    -- dull algorithm because using "while" can problably not be synthesized
		    if (xa < 6) then
		      i:= 0; xb := 0;
		    end if;
		    if ((xa >= 6) and (xa < 12)) then
		      i:= 1; xb := 6;
		    end if;
		    if ((xa >= 12) and (xa < 18)) then
		      i:= 2; xb := 12;
		    end if;
		    if ((xa >= 18) and (xa < 24)) then
		      i:= 3; xb := 18;
		    end if;
		    if ((xa >= 24) and (xa < 30)) then
		      i:= 4; xb := 24;
		    end if;
		    if ((xa >= 30) and (xa < 36)) then
		      i:= 5; xb := 30;
		    end if;
		    if ((xa >= 36) and (xa < 42)) then
		      i:= 6; xb := 36;
		    end if;
		    if ((xa >= 42) and (xa < 48)) then
		      i:= 7; xb := 42;
		    end if;
		    if ((xa >= 48) and (xa < 56)) then
		      i:= 8; xb := 48;
		    end if;
		    if (xa >= 56) then
		      i:= 9; xb := 56;
		    end if;
			 xa := xa - xb;
		    ya := vy(7) - yi(i);
			 if (yi(i + 1) > yi(i)) then
			   -- slope up
			   crit := ya + ya + ya - xa - xa - xa - xa;
		      if (crit < 0) then
			     bullet := '0';
			   end if;
			 end if;
		  end if;
			 
		  if ((mis1 = 2) or (mis2 = 2) or (mis3 = 2) or (tank = 2)) then
		    sound_cmd <= "10";
			end if;
		end if; --if (state = 3) 
		
		if (state = 5) then
		  -- initialization (constant vectors and initial values of variable vectors)
		  
		  -- v0 = spot homing
		  vx(0) := -100; vy(0) := -100;
		  -- player's sprite
		  -- v1 = player's sprite position (will be defined later)
		  vx(2) := -2; vy(2) := 2;
		  vx(3) := 6; vy(3) := -2;
		  vx(4) := -6; vy(4):= -2;
		  vx(5) := 2; vy(5) := 2;
		  -- v6 = spot homing from player's sprite (will be defined later)
		  vx(6) := -100; vy(6) := -100;
		  -- v7 = bullet position
		  vx(7) := 1; vy(7) := 1;
		  --player's bullet
		  vx(8) := 4; vy(8) := 0;
		  --  spot homing
		  vx(9) := -100; vy(9) := -100;
		  -- v10 = player's bomb position
		  vx(10) := 1; vy(10) := 4;
		  -- player's bomb
		  vx(11) := 0; vy(11) := -4;
		  -- spot homing
		  vx(12) := -100; vy(12) := -100;
		  -- v13 = missile #1 position
		  vx(13) := 90; vy(13) := 60; 
		  -- missile #1
		  vx(14) := 0; vy(14) := -2;
		  vx(15) := 4; vy(15) := 4;
		  vx(16) := -2; vy(16) := 6;
		  vx(17) := -2; vy(17) := -6;
		  vx(18) := 4; vy(18) := -4;
		  vx(19) := 0; vy(19) := 2;
		  -- spot homing
		  vx(20) := -100; vy(12) := -100;
		  -- v21 = missile #2 position
		  vx(21) := 90; vy(21) := 90;
		   -- missile #2
		  vx(22) := 0; vy(22) := -2;
		  vx(23) := 4; vy(23) := 4;
		  vx(24) := -2; vy(24) := 6;
		  vx(25) := -2; vy(25) := -6;
		  vx(26) := 4; vy(26) := -4;
		  vx(27) := 0; vy(27) := 2;
		  -- spot homing
		  vx(28) := -100; vy(28) := -100;
		  -- v29 = missile #3 position
		  vx(29) := 80; vy(29) := 90; 
		  -- missile #3
		  vx(30) := 0; vy(30) := -2;
		  vx(31) := 4; vy(31) := 4;
		  vx(32) := -2; vy(32) := 6;
		  vx(33) := -2; vy(33) := -6;
		  vx(34) := 4; vy(34) := -4;
		  vx(35) := 0; vy(35) := 2;
		  -- spot homing
		  vx(36) := -100; vy(36) := -100;
		  -- v37 = fuel tank position 
		  vx(37) := 80; vy(37) := 60;
		  -- fuel tank
		  vx(38) := 0; vy(38) := 4;
		  vx(39) := 4; vy(39) := 0;
		  vx(40) := 0; vy(40) := -4;
		  vx(41) := -4; vy(41) := 0;
		  vx(42) := 4; vy(42) := 4;
		  -- spot homing 
		  vx(43) := -100; vy(43) := -100;
		  -- fuel gauge (double stroke)
		  vx(44) := 50; vy(44) := 0;
		  vx(45) := -50; vy(45) := 0;
		  -- spot homing 
		  vx(46) := -100; vy(46) := -100;
		  
		  -- vector of landscape position (used for scrolling)
		  vx(47) := 6; vy(47) := 10;
		  -- landscape (flat at beginning)
		  for n in 48 to 60 loop
		    vx(n) := 6;
			 vy(n) := 0;
		  end loop;
		  -- the following is actually not used:
		  --  end-of-frame spot homing (saturating the integrators)
		  vx(61) := -90; vy(61) := -90; 
		  vx(62) := -90; vy(62) := -90;
		  vz(0 to 31) := "00111100000000000000000000000000";
		  vz(32 to 63):= "00000000000011001111111111111000";
		  state := 0;
		  sound_cmd <= "00";
		end if;
	 end if; -- if (rising_edge(clk_in)) then
  end process;
end behavior;
 
	 
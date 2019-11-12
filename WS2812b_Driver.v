module WS2812b_Driver(clk,sync,config_leds,reset,data,next_led,idle,dout);
/*
WS2812b addressable LED driver with friendly interface compatible with MCU usage
AUTHOR: LOCHE Jeremy 

inputs : 
	clk = high speed clock used to run the module -> Clock should be at least 3.2 MHz -> Default 50MHz is perfect
	sync = data send signal, when idle is asserted by the driver, apply '1' for at least 1 cycle of clk to start a DATA latch on the LEDs
	config_leds = use it to configure the number of LEDs of the driver, when idle is asserted by the driver, applying a '1' for at least 1 clk cycle will copy the content of data bus to the nb_led register
	data = 24 bits data bus for the LED data, the data is sent MSB first on dout bit 23 to bit 0

outputs:
	idle = idle is asserted when the module is ready to send or configure the LEDs
	next_led = next_led indicates that the module needs next LED data to send. The is asserted in the middle of latching procedure and data is then read just before latching the following LED.
	dout = actual driving signal for the LEDs.
*/


parameter CLK_FREQ=50000000;
parameter RESET_POLARITY=0; //0 when reset signal si active on 0 logic level 1 if you want reset on 1
parameter LED_ADDRESS_BUS_WIDTH=24;
parameter LED_DATA_BUS_WIDTH=24;


//State machine 
parameter IDLE=3'd0;
parameter INIT=3'd1;
parameter LOAD=3'd2;
parameter LATCH=3'd3;
parameter RESET=3'd4;

//Timing parameters for ws2812b

parameter LAT_FREQ = 800000; //Latch frequency of the LED is 800kHz
parameter CYC_PERIOD=(1.0*CLK_FREQ)/LAT_FREQ;  //equivalent of 1.2 us
parameter integer H1_CYC=(0.65)*CYC_PERIOD; //Number of clk cycles high for bit 1
parameter integer L1_CYC=(0.35)*CYC_PERIOD; //Number of clk cycles low for bit 1

parameter integer H0_CYC=(0.25)*CYC_PERIOD; //Number of clk cycles high for bit 0
parameter integer L0_CYC=(0.75)*CYC_PERIOD; //Number of clk cycles low for bit 0

parameter integer RESET_CYC=50*CYC_PERIOD; //Number of clk cycles for a reset pulse approx 60uS




input clk,sync,config_leds,reset;
input [LED_DATA_BUS_WIDTH-1:0] data;
output reg dout;
output next_led;
output idle;

wire _reset;

reg [2:0] state; //state of the driver
reg [LED_ADDRESS_BUS_WIDTH-1:0] address; //counter index of the current LED to latch
reg [LED_ADDRESS_BUS_WIDTH-1:0] nb_leds; //number of LED driven by the driver. To know when to stop and send reset pulse.
reg [LED_DATA_BUS_WIDTH-1:0] led_data; //a safe copy of the bus data line for the current led latch

reg [5:0] bit_address; //counter to address the current bit to latch on the  output
reg [31:0] clk_cnt; // a clock counter to manage the delays of latching

assign next_led = (state==LATCH && bit_address >= (LED_DATA_BUS_WIDTH/2)) ? 1 : 0;
assign idle = state == IDLE ? 1 : 0;

assign _reset= RESET_POLARITY ? !reset : reset;

always @(posedge(clk)) begin

	if(_reset==0) begin
	
	address<=0;
	nb_leds<=0;
	led_data<=0;
	clk_cnt<=0;
	dout<=0;
	state<=IDLE;
	
	end //end reset
	else begin
	
		case(state) 
			
			IDLE: begin
				
					if(sync) begin
						state<=INIT;
					end
					
					if(config_leds) begin
						nb_leds<=data;
					end
					
				end
			
			INIT: begin //reset led counter
					address<=0;
					state<=LOAD;
				end
				
			LOAD: begin //Load the led data to the copy register from the data bus
					led_data<=data; //Prepare to latch the data
					clk_cnt<=0;
					bit_address<=0;
					state<=LATCH;
				end
				
			LATCH: begin //Latch the LED bits to the dout
					
					//Count the cycles
					clk_cnt<=clk_cnt+1;
					
					if(bit_address < (LED_DATA_BUS_WIDTH) ) begin //latch the bit normally for each bits in the LED data
	
						if(led_data[LED_DATA_BUS_WIDTH-1-bit_address] == 1) begin //bit in LED data is 1 Latch 1
						
							if(clk_cnt < H1_CYC) dout<=1;
							else dout<=0;
							
							if(clk_cnt >= (H1_CYC + L1_CYC))begin //Finished latching this 1 bit do the next
								bit_address<=bit_address+1;
								clk_cnt<=0;
							end
						end
						else begin //Latch 0
						
							if(clk_cnt < H0_CYC) dout<=1;
							else dout<=0;
						
							if(clk_cnt >= (H0_CYC + L0_CYC)) begin //Finished latching this 0 bit do the next
								bit_address<=bit_address+1;
								clk_cnt<=0;
							end
						end
					end
					else begin //we have latched this whole LED data cause the bit is the last one
						//should either latch the next LED or send a reset pulse.
						
						if( address < (nb_leds-1) ) begin //still LEDs to latch, call load state to latch the following led
							state<=LOAD;
							address<=address+1; //Go to the next LED
						end
						else begin
							state<=RESET;
							clk_cnt<=0; //reset the clock counter for the reset pulse
						end
						
					end
					
				end //end LATCH
			
			RESET: begin
					clk_cnt<=clk_cnt+1;
					dout<=0;
					if(clk_cnt >= (RESET_CYC-1)) 
						state<=IDLE;
				end		
		endcase	
	end //end else reset
	
end

endmodule
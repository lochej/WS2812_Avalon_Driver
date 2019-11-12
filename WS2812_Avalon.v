module WS2812_Avalon(
	clk,
	reset,
	address,
	read, //register read data control signals
	readdata,
	write, //register write data control signals
	writedata, 
	waitrequest,
	led_dout
);
/*
WS2812b addressable LED driver with avalon memory mapped interface
AUTHOR: LOCHE Jeremy 

Exposed a conduit led_dout to connect to you LED strip
and memory registers to store your configuration and LED colors.
*/

parameter LED_MAX_NUMBER=200; //number of LED in the chain
parameter LED_ADDR_W=8; //number of bits in avalon to address each LED
parameter LED_DATA_W=24; //data width of LED data
parameter CLK_FREQUENCY=50000000;

//Addresses for registers
localparam STATUS_REG_ADDR=32'd0;
localparam CONTROL_REG_ADDR=32'd1;
localparam LED_NUMBER_REG_ADDR=32'd2;
localparam LED_DATA_REG_BASE_ADDR=32'd3;

//States for config state machine
localparam CONFIG_WAIT_REQUEST=1'b0;
localparam CONFIG_APPLYING_REQUEST=1'b1;
//localparam CONFIG_APPLIED_REQUEST=2'd2; //removed v1.0

//States for sync state machine
localparam SYNC_WAIT_REQUEST=1'b0;
localparam SYNC_APPLYING_REQUEST=1'b1;
//localparam SYNC_APPLIED_REQUEST=2'd2; //removed v1.0

//States for reset state machine
localparam RESET_WAIT_REQUEST=1'b0;
localparam RESET_APPLYING_REQUEST=1'b1;

//Avalon MM Slave signals
input clk;
input reset;
input [LED_ADDR_W-1:0] address;
input read; //register read data control signals
output [31:0] readdata;
input write; //register write data control signals
input [31:0] writedata; 
output waitrequest;

//WS2812b driver output
output led_dout;

//Avalon MM slave signal registers
reg _waitrequest;
reg [31:0] readdata;


//WS2812 driver control signals
reg led_sync; //driving signal for sync procedure on ws2812 driver
reg led_reset; //driving signal for reset procedure on ws2812 driver
reg led_config; //driving signal for config procedure on ws2812 driver
wire [LED_DATA_W-1:0] led_data; //data bus of the ws2812 driver
reg [LED_DATA_W-1:0] led_number;

wire led_idle; //idle signal from ws2812 driver
wire led_nextled; //nextled signal from ws2812 driver
wire [LED_DATA_W-1:0] led_color_data; //output of the led color ram selector
wire [LED_ADDR_W-1:0] led_currentid; //led color selector pointer for the register bank, set by the led counter

//WS2812 scheduler control signal
reg led_configrequest; //config process trigger
reg led_configstate; //remove reg v1.0

reg led_syncrequest; //sync process trigger
reg led_syncstate; //remove reg v1.0

reg led_resetrequest; //reset process trigger
reg led_resetstate; //remove reg v1.0

//WS2812 led data registers
reg [LED_DATA_W-1:0] led_ram [LED_MAX_NUMBER]; // led color data register bank

//assign led_color_data[LED_DATA_W-1:0] = led_ram[led_currentid][LED_DATA_W-1:0];
assign led_data = led_idle ? led_number : led_ram[led_currentid];


//Avalon MM slave waitrequest signal equation
assign waitrequest = read & _waitrequest; //put wait request

always @(posedge(clk) or posedge(reset)) begin //Write process

	if(reset) begin
		
		
		led_syncrequest<=0;
		led_configrequest<=0;
		led_resetrequest<=0;
		led_number<=0;
		//reset ram map
		
	end
	
	else begin
			
		if(led_configrequest==1) begin
			led_configrequest<=0;
		end
		if(led_syncrequest==1) begin
			led_syncrequest<=0;
		end
		
		if(led_resetrequest==1) begin
			led_resetrequest<=0;
		end
		
			
		if(write) begin
			
				case(address)
					//STATUS REG is not writable
					CONTROL_REG_ADDR: begin
						led_syncrequest<= writedata[1];
					
						led_resetrequest<= writedata[0];
					end
					
					LED_NUMBER_REG_ADDR: begin
						led_number[LED_DATA_W-1:0] <= writedata[LED_DATA_W-1:0];
						
						led_configrequest<=1;
					end
					
					default: begin
					
						if( (LED_DATA_REG_BASE_ADDR) <= address && (address < (LED_DATA_REG_BASE_ADDR + LED_MAX_NUMBER)) ) begin //want to write led colors
							led_ram[address - LED_DATA_REG_BASE_ADDR] <= writedata[LED_DATA_W-1:0];
						end
					end	
				endcase
		
		end
	end

end


always @(posedge(clk) or posedge(reset)) begin //Read process

	if (reset)	begin	
	
		readdata<=0;
		_waitrequest<=1;  //must assert waitrequest when reset
		
	end
	else if(read) begin
		
		_waitrequest<=0; //deassert waitrequest
		
		case(address)
			STATUS_REG_ADDR: begin
				readdata<= 32'd0 | led_idle;
			end
			
			CONTROL_REG_ADDR: begin
				readdata<= 32'd0 | (led_sync << 1) | led_reset; 
			end
			
			LED_NUMBER_REG_ADDR: begin
				readdata <= 32'd0 | led_number;
			end
			
			default: begin
			
				if( (LED_DATA_REG_BASE_ADDR) <= address && (address < (LED_DATA_REG_BASE_ADDR + LED_MAX_NUMBER)) ) begin //want to read led colors
					readdata <= led_ram[address - LED_DATA_REG_BASE_ADDR];//read pointed led data
				end
				
				else begin
					readdata <= 32'd0; //else read 0
				end
			end
		endcase
	end
	else if(!read) begin
		_waitrequest<=1;  //make sure to reenable wait request asap after read
	end
end



always @(posedge(clk) or posedge(reset)) begin //Config led process
	if(reset) begin
		led_configstate<=CONFIG_WAIT_REQUEST;
		led_config<=0;
	end
	else begin
		//check config process state machine
		case(led_configstate) 
			CONFIG_WAIT_REQUEST: begin //wait for the config request to be submitted
			
				if(led_configrequest) begin //A config request has been submitted
					led_config<=1;
					led_configstate<=CONFIG_APPLYING_REQUEST;
				end
	
			end
			CONFIG_APPLYING_REQUEST: begin //latch config pin
				led_config<=0;
				led_configstate<=CONFIG_WAIT_REQUEST;
			end
					
			default:
				led_configstate<=CONFIG_WAIT_REQUEST;
		endcase
	end
end

always @(posedge(clk) or posedge(reset)) begin //Sync led process
	
	if(reset) begin
		led_syncstate<=SYNC_WAIT_REQUEST;
		led_sync<=0;
	end
	else begin
		//check config process state machine
		case(led_syncstate) 
			SYNC_WAIT_REQUEST: begin //wait for the config request to be submitted

				if(led_syncrequest) begin //A config request has been submitted
					led_sync<=1;
					led_syncstate<=SYNC_APPLYING_REQUEST;
				end
		
			end
			SYNC_APPLYING_REQUEST: begin //latch config pin
				led_sync<=0;
				led_syncstate<=SYNC_WAIT_REQUEST; 
			end
			
			default:
				led_syncstate<=SYNC_WAIT_REQUEST;
		endcase
	
	end

end

always @(posedge(clk) or posedge(reset)) begin //Reset led process
	
	if(reset) begin
		led_resetstate<=RESET_WAIT_REQUEST;
		led_reset<=0;
	end
	else begin
		//check config process state machine
		case(led_resetstate) 
			RESET_WAIT_REQUEST: begin //wait for the config request to be submitted
			
				if(led_resetrequest) begin //A config request has been submitted
					led_reset<=0; //reset the driver by putting reset pin low
					led_resetstate<=RESET_APPLYING_REQUEST;
				end
		
			end
			RESET_APPLYING_REQUEST: begin //latch config pin
				led_reset<=1; //start the driver by putting reset high
				led_resetstate<=RESET_WAIT_REQUEST; 
			end
			
			default:
				led_resetstate<=RESET_WAIT_REQUEST;
			
		endcase
	end
end

//for each posedge of nextled, count up
//reset the counter when driver is idle so led_idle=1
DynCntModN #(.NBBITS(LED_ADDR_W),.POSEDG(1),.RESETLEVEL(1),.SETLEVEL(0)) led_address_counter(
	.Clk(led_nextled),
	.Q(led_currentid),
	.Mod(led_number),
	.aSet(1'b1),
	.aReset(led_idle)
); 

WS2812b_Driver #(.CLK_FREQ(CLK_FREQUENCY),.LED_DATA_BUS_WIDTH(LED_DATA_W),.LED_ADDRESS_BUS_WIDTH(LED_DATA_W)) led_driver(
	.clk(clk),
	.sync(led_sync),
	.data(led_data),
	.config_leds(led_config),
	.reset(led_reset),
	.dout(led_dout),
	.idle(led_idle),
	.next_led(led_nextled)
);

endmodule
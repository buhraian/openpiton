//`include "packet_defs.vh"
//`include "state_defs.vh"
//`include "noc_defs.vh"
//`include "soc_defs.vh"
//import beehive_topology::*;
module beehive_top (
	input                       clk          , // Clock
	input                       rst_n        , // Asynchronous reset active low
	input acc_pkg::acc_config_t acc_config   , // acclerator uncached configuration interface
	decoupled_vr_if.slave       consumer_data,
	decoupled_vr_if.master      producer_data
);
	
	//TODO: do we need configurable width?
	// nope. Can fix it at compilation time

	//can receive and send at same time

	//state machine needs to wait 4 cycles to capture all 256 bits
		// logic                                      loopback_val;
	// logic          [`MAC_INTERFACE_W-1:0]      loopback_data;
	// logic                                      loopback_startframe;
	// logic          [`MTU_SIZE_W-1:0]           loopback_frame_size;
	// logic                                      loopback_endframe;
	// logic          [`MAC_PADBYTES_W-1:0]       loopback_padbytes;
	// logic                                      loopback_rdy;

	logic                             loopback_val;
	logic [255:0]     				   loopback_data;
	logic                             loopback_startframe;
	logic [10:0]          			   loopback_frame_size;
	logic                             loopback_endframe;
	logic [4:0]      				   loopback_padbytes;
	logic                             loopback_rdy;
	
	udp_echo_top i_udp_echo_top (
		.clk                      (clk),
		.rst                      (~rst_n),
		//consumer side
		.mac_engine_rx_val        (loopback_val), //1
		.mac_engine_rx_data       (loopback_data), //MAC_INTERFACE_W is 256 bits
		.mac_engine_rx_startframe (loopback_startframe), //1
		.mac_engine_rx_frame_size (loopback_frame_size), //MTU_SIZE_W is `BSG_SAFE_CLOG2(`MTU_SIZE) where MTU_SIZE is 1500, 11 bits
		.mac_engine_rx_endframe   (loopback_endframe), //1
		.mac_engine_rx_padbytes   (loopback_padbytes), //BSG_SAFE_CLOG2(`MAC_INTERFACE_BYTES) where MAC_INTERFACE_BYTES is 256/8=32, 5 bits
		.engine_mac_rx_rdy        (loopback_rdy), //1
		//producer side
		.engine_mac_tx_val        (loopback_val), //1
		.mac_engine_tx_rdy        (loopback_rdy), //1
		.engine_mac_tx_startframe (loopback_startframe), //1
		.engine_mac_tx_frame_size (loopback_frame_size), //MTU_SIZE_W is `BSG_SAFE_CLOG2(`MTU_SIZE) where MTU_SIZE is 1500, 11 bits
		.engine_mac_tx_endframe   (loopback_endframe), //1
		.engine_mac_tx_data       (loopback_data), //256 bits
		.engine_mac_tx_padbytes   (loopback_padbytes),  //5 bits
		
		.consumer_data            (consumer_data),
		.producer_data            (producer_data)
	);

endmodule : beehive_top

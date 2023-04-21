// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2022 Tianrui Wei
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the authors nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*	important information:
	the module is stateless, meaning that it will generate transaction solely
	based on the information provided by fifo_info
	some of the information will be stored in this module
	some of the information will be stored in coherency manager
*/
`include "register.svh"
module consumer_load_transaction_generator
	import fifo_ctrl_pkg::*;
(
	input                                 clk                , // Clock
	input                                 rst_n              , // Asynchronous reset active low
	input  fifo_config_pkg::fifo_config_t fifo_config_r      , // registered input
	decoupled_vr_if.master                trans_info         , // transaction info. data field is address
	input                                 trans_ack          , // the ack for a previous transmission, this is for bumping the ack'ed head pointer
	output ptr_t                          consumer_head_ptr_o  // output to coherency manager
);

	`width_check(trans_info.data, head_ptr_addr_r, trans_data_check)	
	
	// the issued head pointer
	ptr_t head_ptr_issued_r, head_ptr_issued_n;

	addr_t addr_base;
	assign addr_base = fifo_config_r.addr_base;

	// the acked head ptr
	ptr_t head_ptr_acked_r, head_ptr_acked_n;

	logic fifo_empty;
	logic transaction_valid;
	logic transaction_handshake;

	
	// IO region

	assign trans_info.valid = transaction_valid & rst_n;
	assign trans_info.data = fifo_config_r.addr_base + ((head_ptr_issued_r >> 1) << 4 );
	assign transaction_handshake = transaction_valid & trans_info.ready;
	assign consumer_head_ptr_o = head_ptr_acked_r;
	
	// internal signal region
	assign transaction_valid = ~fifo_empty & rst_n;

	// check if fifo is empty, as we're trying to consume
	assign fifo_empty = fifo_ctrl_pkg::fifo_is_empty(fifo_config_r.fifo_ptr.tail, head_ptr_issued_r, fifo_config_r.fifo_length);



	always_ff @(posedge clk) begin : proc_head_ptr
		if(~rst_n) begin
			head_ptr_issued_r <= '0;
			head_ptr_acked_r <= '0;
		end else begin
			head_ptr_issued_r <= head_ptr_issued_n;
			head_ptr_acked_r <= head_ptr_acked_n;
		end
	end

	always_comb begin : proc_head_ptr_comb
		head_ptr_acked_n = head_ptr_acked_r;
		head_ptr_issued_n = head_ptr_issued_r;
		if (transaction_handshake) begin
			head_ptr_issued_n = fifo_ctrl_pkg::inc_ptr_two(head_ptr_issued_r, fifo_config_r.fifo_length);
		end
		if (trans_ack) begin
			head_ptr_acked_n = fifo_ctrl_pkg::inc_ptr_two(head_ptr_acked_r, fifo_config_r.fifo_length);
		end
	end	




endmodule : consumer_load_transaction_generator

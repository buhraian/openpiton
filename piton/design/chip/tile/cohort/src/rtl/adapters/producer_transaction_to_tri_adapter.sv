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

// this module translates producer_transaction_if into
// tri if.
// TODO: support outstanding memory operations
`include "register.svh"
module producer_transaction_to_tri_adapter #(parameter int unsigned DATABUS_WIDTH_P = 64) (
	input                                 clk          , // Clock
	input                                 rst_n        , // Asynchronous reset active low
	input  fifo_config_pkg::fifo_config_t fifo_config_r,
	decoupled_vr_if.slave                 trans        , // the transaction slave interface from producer
	decoupled_vr_if.slave                 acc_data     ,
	output                                trans_ack    , // denotes that a tri signal has written back
	tri_if.master                         tri_intf       // translate to tri interface
);
	import fifo_ctrl_pkg::size_t;
	import fifo_ctrl_pkg::addr_t;

	typedef logic [DATABUS_WIDTH_P-1:0] data_t;

	//TODO: align size requirement so that there wouldn't be any mass scale error
	//TODO: add threadid to support OoO memory operations

	
	size_t size_r, size_n;
	data_t data_r, data_n;
	addr_t addr_r, addr_n;

	typedef enum logic [1:0] {S_IDLE, S_REQ, S_RESP} state_t;

	state_t state, state_next;

	// address check to reduce signal width error
	`width_check(tri_intf.req_size, size_r, size_check)
	`width_check(tri_intf.req_data, data_r, data_check)
	`width_check(tri_intf.req_addr, addr_r, addr_check)

	assign trans.ready = state == S_IDLE && acc_data.valid;
	assign acc_data.ready = state == S_IDLE && trans.valid;

	assign tri_intf.req_valid = state == S_REQ;
	assign tri_intf.req_type =  tri_pkg::TRI_STORE_RQ;
	assign tri_intf.req_data = {data_r};
	assign tri_intf.req_size = 3'b100; // 64 bits. This is the only size TRI interface accepts
    assign tri_intf.req_addr = addr_r;
	assign tri_intf.req_amo_op = '0; // no atomic operations
	assign tri_intf.resp_ack = state == S_RESP & tri_intf.resp_val;
	
	// currently a very hacky solution, not sustaintable
	logic serdes_ctr, serdes_ctr_n;

	logic tri_resp;

	assign tri_resp = (state == S_RESP) & tri_intf.resp_val & tri_intf.resp_ack;

	always_ff @(posedge clk) begin: proc_ctr
		if (~rst_n) begin
			serdes_ctr <= '0;
		end else begin
			serdes_ctr <= serdes_ctr_n;
		end
	end

	always_comb begin
		serdes_ctr_n = serdes_ctr;
		if (tri_resp) begin
			serdes_ctr_n = serdes_ctr + 1;
		end
	end

	assign trans_ack = tri_resp;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			size_r <= '0;
			data_r <= '0;
			addr_r <= '0;
		end else begin
			state <= state_next;
			size_r <= size_n;
			data_r <= data_n;
			addr_r <= addr_n;
		end
	end
	
	always_comb begin : proc_state_next
		state_next = state;
		size_n = size_r;
		data_n = data_r;
		addr_n = addr_r;
		unique case (state)
			S_IDLE  : begin
				if ((trans.valid && trans.ready) && (acc_data.ready && acc_data.valid) ) begin
					state_next = S_REQ;
					size_n = fifo_config_r.element_size + 1; //TODO: check if this is correct
					data_n = acc_data.data;
					addr_n = trans.data;
				end
			end
			S_REQ   : begin
				if (tri_intf.req_valid && tri_intf.req_ack) begin
					state_next = S_RESP;
				end
			end
			S_RESP  : begin
				if (tri_intf.resp_val && tri_intf.resp_ack) begin
					state_next = S_IDLE;
				end
			end
		endcase
	end;

endmodule : producer_transaction_to_tri_adapter

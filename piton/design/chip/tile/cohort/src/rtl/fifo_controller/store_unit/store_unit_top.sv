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

module store_unit_top
	import tri_pkg::*;
(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input fifo_ctrl_pkg::transact_o_t transact_i,
	output fifo_ctrl_pkg::transact_i_t transact_o,
	output tri_pkg::tri_req_t tri_req,
	input tri_pkg::tri_resp_t tri_resp	
);
	// always store, ignore invalidation
	// pipe the input manually and use arbiter to split the queue before this
	// this is to maximize the threadid concurrency

	//TODO: aligh the size encoding between pmesh and tri interface
	//TODO: add back threadid
	typedef enum logic [1:0] {S_IDLE, S_REQ, S_RESP} state_t;
	state_t state, state_next;

	fifo_ctrl_pkg::transact_o_t transact_d, transact_q;

	assign transact_o.ready = state == S_IDLE;
	assign tri_req.req_valid = state == S_REQ;
	assign tri_req.req_type = TRI_STORE_RQ;
	//FIXME: fix the correct size conversion
	assign tri_req.req_size = 3'h1;
	assign tri_req.req_addr = transact_q.addr;
	assign tri_req.req_data = transact_q.data;
	assign tri_req.resp_ack = state == S_RESP;
	assign tri_req.req_amo_op = '0;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			transact_q <= '0;
		end else begin
			state <= state_next;
			transact_q <= transact_d;
		end
	end
	
	always_comb begin : proc_state_next
		state_next = state;
		transact_d = transact_q;
		case (state)
			S_IDLE  : begin 
				if (transact_i.valid && transact_o.ready) begin 
					state_next = S_REQ;
					transact_d = transact_i;
				end
			end
			S_REQ   : begin 
				if (tri_req.req_valid && tri_resp.req_ack) begin 
					state_next = S_IDLE; // Don't wait for ack for now
				end
			end
			S_RESP  : begin 
				if (tri_resp.resp_val && tri_req.resp_ack) begin 
					state_next = S_IDLE;
				end
			end
			default : ;
		endcase
	end

endmodule
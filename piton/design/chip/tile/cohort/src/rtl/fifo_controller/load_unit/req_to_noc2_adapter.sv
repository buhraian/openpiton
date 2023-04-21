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

module req_to_noc2_adapter
	import fifo_ctrl_pkg::*;
	import pmesh_pkg::pmesh_noc2_o_t;
	import pmesh_pkg::pmesh_noc2_i_t;
(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input ld_req_i_t ld_req_i,
	output ld_req_o_t ld_req_o,
	input pmesh_pkg::pmesh_noc2_i_t noc2_i,
	output pmesh_pkg::pmesh_noc2_o_t noc2_o
);
	typedef enum logic {S_IDLE, S_REQ} state_t;
	state_t state, state_next;
	addr_t addr_d, addr_q;
	size_t size_d, size_q;

	assign ld_req_o.ready = state == S_IDLE;
	assign noc2_o.valid = state == S_REQ;
	assign noc2_o.req_type = 6'd60;
	//TODO: add mshrid tracking to build a fetch queue
	assign noc2_o.mshrid = ld_req_i.mshrid;
	assign noc2_o.address = addr_q;
	assign noc2_o.size = size_q;
	//TODO: check for correct homeid
	assign noc2_o.homeid = '0;
	assign noc2_o.write_mask = '0;
	assign noc2_o.data_0 = '0;
	assign noc2_o.data_1 = '0;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			addr_q <= '0;
			size_q <= '0;
		end else begin
			state <= state_next;
			addr_q <= addr_d;
			size_q <= size_d;
		end
	end
	
	always_comb begin : proc_state_next
		state_next = state;
		addr_d = addr_q;
		size_d = size_q;
		unique case (state)
			S_IDLE  : begin 
				if (ld_req_i.valid) begin 
					state_next = S_REQ;
					addr_d = ld_req_i.addr;
					size_d = ld_req_i.size;
				end
			end
			S_REQ   : begin 
				if (noc2_i.ready) begin 
					state_next = S_IDLE;
				end
			end
		endcase
	end

endmodule : req_to_noc2_adapter

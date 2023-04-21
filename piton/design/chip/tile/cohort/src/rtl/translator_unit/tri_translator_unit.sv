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

module tri_translator_unit (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	tri_if.slave tri_req_vpn,
	tri_if.master tri_req_ppn,
	tlb_if.master tlb_req	
);

	// idle: nothing
	// req: request the translation
	// resp: the translation arrives

    import translator_pkg::pn_t;
	typedef enum logic [1:0] {S_IDLE, S_QUERY, S_PASSTHROUGH} state_t;

    pn_t req_addr_ppn_r, req_addr_ppn_n;
	

	state_t state, state_next;


	assign tri_req_ppn.req_type = tri_req_vpn.req_type;
	assign tri_req_ppn.req_amo_op = tri_req_vpn.req_amo_op;
	assign tri_req_ppn.req_size = tri_req_vpn.req_size;
	assign tri_req_ppn.req_data = tri_req_vpn.req_data;
	assign tri_req_ppn.resp_ack = tri_req_vpn.resp_ack;
	assign tri_req_ppn.req_addr = {req_addr_ppn_r, tri_req_vpn.req_addr[11:0]};
	assign tri_req_ppn.req_valid = state == S_PASSTHROUGH;
	assign tri_req_vpn.req_ack = state == S_PASSTHROUGH & tri_req_ppn.req_ack;
	assign tri_req_vpn.resp_val = tri_req_ppn.resp_val;
	assign tri_req_vpn.resp_type = tri_req_ppn.resp_type;
	assign tri_req_vpn.resp_data = tri_req_ppn.resp_data;
	assign tri_req_vpn.resp_inv_addr = tri_req_ppn.resp_inv_addr;
	assign tri_req_vpn.resp_inv_valid = tri_req_ppn.resp_inv_valid;

	assign tlb_req.vpn = tri_req_vpn.req_addr >> 12;
	assign tlb_req.valid = state == S_QUERY;


	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			req_addr_ppn_r <= '0;
		end else begin
			state <= state_next;
			req_addr_ppn_r <= req_addr_ppn_n;
		end
	end
	
	always_comb begin : proc_state_next
		state_next = state;
		req_addr_ppn_n = req_addr_ppn_r;
		case (state)
			S_IDLE  : begin
				if (tri_req_vpn.req_valid) begin
					state_next = S_QUERY;
				end
			end
			S_QUERY : begin
				if (tlb_req.ack) begin
					state_next = S_PASSTHROUGH;
					req_addr_ppn_n = tlb_req.ppn ; // the upper 12 bits
				end
			end
			S_PASSTHROUGH  : begin
				if (tri_req_ppn.req_valid & tri_req_ppn.req_ack) begin
					state_next = S_IDLE;
				end
			end
			default : ;
		endcase
	end	

endmodule : tri_translator_unit

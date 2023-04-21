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

module tlb_arbiter (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	tlb_if.slave tlb_req_source[1:0],
	tlb_if.master tlb_req_sink
);

	typedef enum logic {S_IDLE, S_ARBITING} state_t;

	// the index for selecting source
	logic tlb_sel_r, tlb_sel_n;

	state_t state, state_next;

	always_ff @(posedge clk or negedge rst_n) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			tlb_sel_r <= 1'b0;
		end else begin
			state <= state_next;
			tlb_sel_r <= tlb_sel_n;
		end
	end

	assign tlb_req_sink.valid = state == S_ARBITING;
	assign tlb_req_sink.vpn = tlb_sel_r == 1'b0 ? tlb_req_source[0].vpn : tlb_req_source[1].vpn;

	generate
		for (genvar i = 0; i < 2; i++) begin
			assign tlb_req_source[i].ppn = tlb_req_sink.ppn;
			assign tlb_req_source[i].ack = state == S_ARBITING & tlb_sel_r == i & tlb_req_sink.ack;
		end
	endgenerate
	
	always_comb begin : proc_state_next
		state_next = state;
		tlb_sel_n = tlb_sel_r;
		unique case (state)
			S_IDLE     : begin
				if (tlb_req_source[0].valid) begin
					tlb_sel_n = 1'b0;
					state_next = S_ARBITING;
				end
				else if (tlb_req_source[1].valid) begin
					tlb_sel_n = 1'b1;
					state_next = S_ARBITING;
				end
			end
			S_ARBITING : begin
				if (tlb_sel_r == 1'b0 & tlb_req_source[0].ack) begin
					state_next = S_IDLE;
				end
				else if (tlb_sel_r == 1'b1 & tlb_req_source[1].ack) begin
					state_next = S_IDLE;
				end
			end
		endcase
	end	

endmodule : tlb_arbiter

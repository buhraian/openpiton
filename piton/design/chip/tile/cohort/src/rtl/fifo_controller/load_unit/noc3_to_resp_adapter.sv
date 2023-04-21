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

module noc3_to_resp_adapter
	import pmesh_pkg::pmesh_noc3_in_t;
	import fifo_ctrl_pkg::*;
(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input pmesh_pkg::pmesh_noc3_in_t noc3_in,
	output ld_resp_o_t ld_resp_o
);

	typedef enum logic {S_IDLE, S_REQ} state_t;

	state_t state, state_next;
	cacheline_t data_d, data_q;
	mshrid_t mshrid_d, mshrid_q;

	assign ld_resp_o.data = data_q;
	assign ld_resp_o.mshrid = mshrid_q;
	assign ld_resp_o.valid = state == S_REQ;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			data_q <= '0;
			mshrid_q <= '0;
		end else begin
			state <= state_next;
			data_q <= data_d;
			mshrid_q <= mshrid_d;
		end
	end
	
	always_comb begin : proc_state_next
		state_next = state;
		data_d = data_q;
		mshrid_d = mshrid_q;
		unique case (state)
			S_IDLE  : begin 
				if (noc3_in.valid) begin
					state_next = S_REQ;
					data_d = noc3_in.resp_data;
					mshrid_d = noc3_in.mshrid;
				end
			end
			S_REQ   : begin 
					state_next = S_IDLE;
			end
		endcase
	end

endmodule

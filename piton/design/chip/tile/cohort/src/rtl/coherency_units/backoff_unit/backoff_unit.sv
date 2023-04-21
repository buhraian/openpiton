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

// calculates what the backoff cycles should be
// we could potentially enhance this based on heuristics
// of coherency latencies
// TODO: make backoff size relevant to cache coherency performance
//       currently the max trigger would be 100
module backoff_unit (
	input              clk            , // Clock
	input              rst_n          , // synchronous reset active low
	input logic [15:0] backoff_value  ,
	backoff_if.slave   backoff_if_inst
);

	import coherency_ctrl_pkg::*;

	typedef enum logic [1:0] {S_IDLE, S_BACKOFF, S_ACK} state_t;


	state_t state, state_next;

	// backoff counter
	backoff_t counter, counter_next;

	assign backoff_if_inst.ack = state == S_ACK;
	
	// what should the trigger value be for the backoff
	backoff_t counter_max, counter_max_next;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state       <= S_IDLE;
			counter     <= '0;
			counter_max <= 16'd10000;
		end else begin
			state       <= state_next;
			counter     <= counter_next;
			counter_max <= counter_max_next;
		end
	end

	always_comb begin : proc_state_next
		state_next       = state;
		counter_max_next = counter_max;
		counter_next     = counter;
		unique case (state)
			S_IDLE : begin
				if (backoff_if_inst.valid) begin
					state_next       = S_BACKOFF;
					counter_max_next = backoff_value;
				end
			end
			S_BACKOFF : begin
				if (backoff_if_inst.interrupt) begin
					counter_next = '0;
					state_next = S_IDLE;
				end
				else if (counter == counter_max) begin
					state_next = S_ACK;
				end
				else begin
					counter_next = counter + 1;
				end
			end
			S_ACK : begin
				state_next   = S_IDLE;
				counter_next = '0;
			end

		endcase
	end	

endmodule : backoff_unit

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

/* this is a write only coherency manager
   when the queue operation begins, there'll be a reset signal that reset it to 0
   after that it will be incremented **and ignore all invalidation requests**
   it will regularly write its value back to dram for software to see
   basically software only reads this part
   Jon: library already does this to avoid false sharing 

   note that it only retains value for ptr_t width

   *_r: registered input
*/
module wo_coherency_manager
	import fifo_ctrl_pkg::ptr_t;
(
	input                   clk            , // Clock
	input                   rst_n          , // Asynchronous reset active low
	input                   monitor_on     ,
	`ifdef COHORT_PERF
	perf_if.slave           perf           ,
	`endif
	input  dcp_pkg::paddr_t base_addr_r    , // registered input
	input  logic [15:0]     backoff_value  ,
	output                  element_fetched,
	tri_if.master           tri_l2         , // handle all requests through here
	input  ptr_t            src_ptr_r      , // the actual value we're trying to write
	input  ptr_t            ref_ptr_r        // need to write them back
);
	
	import tri_pkg::*;

	assign element_fetched = 1'b1;

	typedef enum logic [1:0] {S_IDLE, S_BACKOFF, S_REQ, S_RESP} state_t;

	state_t state, state_next;

	backoff_if backoff_if_inst();
	
	assign backoff_if_inst.valid = (state == S_IDLE) & (src_ptr_r != ref_ptr_r);
	assign backoff_if_inst.interrupt = 1'b0;

	backoff_unit i_backoff_unit (
		.clk            (clk                  ),
		.rst_n          (rst_n                ),
		.backoff_value  (backoff_value        ),
		.backoff_if_inst(backoff_if_inst.slave)
	);

	assign tri_l2.req_amo_op = '0;
	assign tri_l2.req_valid = state == S_REQ;
	assign tri_l2.req_type = TRI_STORE_RQ;
	assign tri_l2.req_size = 3'b011; // always 128 bits ( 16 bytes )
	assign tri_l2.req_data = src_ptr_r; // zero extend the source pointer
	assign tri_l2.req_addr = base_addr_r;


	assign tri_l2.resp_ack = 1'b1;

	// we synchronize the pointers neverthless

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
		end else begin
			state <= state_next;
		end
	end

	always_comb begin : proc_state_next
		state_next = state;
		unique case (state)
			S_IDLE : begin
				if (!monitor_on) begin
					state_next = S_IDLE;
				end
				else if (src_ptr_r != ref_ptr_r) begin
					state_next = S_BACKOFF;
				end
			end
			S_BACKOFF : begin
				if (backoff_if_inst.ack) begin
					state_next = S_REQ;
				end
			end
			S_REQ : begin
				if (tri_l2.req_ack) begin
					state_next = S_RESP;
				end
			end
			S_RESP : begin
				if (tri_l2.resp_val && tri_l2.resp_type == TRI_ST_ACK) begin
					state_next = S_IDLE; // don't go to backoff directly, it's one cycle anyway
				end
			end
		endcase
	end

	`ifdef COHORT_PERF
	logic [63:0] counter_r [4:0];

	genvar i;
	generate
		for (i = 0; i < 5; i++) begin
			assign perf.counter_r[i] = counter_r[i];
		end
	endgenerate

	generic_perf_counter idle_perf_counter (
		.clk               (clk                ),
		.rst_n             (rst_n              ),
		.toggle_trigger    (perf.toggle_trigger),
		.inc_condition     (state == S_IDLE    ),
		.clear_trigger     (perf.clear_trigger ),
		.perf_counter_value(counter_r[0]       )
	);
	generic_perf_counter backoff_perf_counter (
		.clk               (clk                ),
		.rst_n             (rst_n              ),
		.toggle_trigger    (perf.toggle_trigger),
		.inc_condition     (state == S_BACKOFF ),
		.clear_trigger     (perf.clear_trigger ),
		.perf_counter_value(counter_r[1]       )
	);
	generic_perf_counter req_perf_counter (
		.clk               (clk                ),
		.rst_n             (rst_n              ),
		.toggle_trigger    (perf.toggle_trigger),
		.inc_condition     (state == S_REQ     ),
		.clear_trigger     (perf.clear_trigger ),
		.perf_counter_value(counter_r[2]       )
	);
	generic_perf_counter resp_perf_counter (
		.clk               (clk                ),
		.rst_n             (rst_n              ),
		.toggle_trigger    (perf.toggle_trigger),
		.inc_condition     (state == S_RESP    ),
		.clear_trigger     (perf.clear_trigger ),
		.perf_counter_value(counter_r[3]       )
	);
	generic_perf_counter transaction_perf_counter (
		.clk               (clk                            ),
		.rst_n             (rst_n                          ),
		.toggle_trigger    (perf.toggle_trigger            ),
		.inc_condition     (state == S_REQ & tri_l2.req_ack),
		.clear_trigger     (perf.clear_trigger             ),
		.perf_counter_value(counter_r[4]                   )
	);
	`endif
endmodule : wo_coherency_manager

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

// coherency manager gets input from communication interface
// and outputs an array of register interface
// it also has an tri interface to communicate with llc.
// it serves the purpose of issuing load requests and getting invalidations

`include "dcp.h"

module ro_coherency_manager #(
	parameter int unsigned reg_number = 1  ,
	parameter int unsigned reg_width  = 128
) (
	input                        clk            , // Clock
	input                        rst_n          , // Asynchronous reset active low
	input                        monitor_on     , // whether I'm watching the address or not
	input  dcp_pkg::paddr_t      base_addr_r    ,
	input  logic [         15:0] backoff_value  ,
	output                       element_fetched,
	tri_if.master                tri_l2         ,
	`ifdef COHORT_PERF
	perf_if.slave                perf           ,
	cohort_dbg_if.master         debug          ,
	`endif
	output logic [reg_width-1:0] reg_file_o
);
	import tri_pkg::*;
	import dcp_pkg::paddr_t;

	typedef enum logic [1:0] {S_IDLE, S_BACKOFF, S_ELEVATE, S_WRITEBACK} state_t;

    logic monitor_on_r;

    logic fetched_r;

	// the interface for backoff connections
	backoff_if backoff_if_inst();


	// the regfile of coherence manager
	logic [reg_width-1:0] reg_file;



	// for FSM
	state_t state_r, state_n;

	// should be at most one hot encoding
	// compares which part of the address hit must hold to be true
	logic  reg_compare;

	// decimal encoding, calculates how many bits are required
	wire [15:0] resp_inv_addr = tri_l2.resp_inv_addr;
    
    assign element_fetched = fetched_r;

	// handle the com interface
	// assignments
	assign tri_l2.req_valid = state_r == S_ELEVATE;
	assign tri_l2.req_type = TRI_LOAD_RQ;
	assign tri_l2.req_size = 3'b011; // 128 / 8 = 16 ( bytes ), 16 = 2 ^ (5-1). Size = 5
	assign tri_l2.req_addr = base_addr_r;
	assign tri_l2.req_data = '0;
	assign tri_l2.req_amo_op = '0;

	// always ready to receive response
	assign tri_l2.resp_ack = 1'b1;

	always_ff @(posedge clk) begin : proc_assign_regfile
		if (!rst_n) begin
			reg_file <= '0;
            monitor_on_r <= 1'b0;
            fetched_r <= 1'b0;
		end
		else begin
			if (!monitor_on_r) begin
				reg_file <= '0;
				fetched_r <= 1'b0; // zero if not fetched
			end
			else if (tri_l2.resp_val && tri_l2.resp_type == TRI_LOAD_RET && state_r == S_WRITEBACK) begin
				reg_file <= tri_l2.resp_data;
				fetched_r <= 1'b1;
			end
			else begin
				reg_file <= reg_file;
				fetched_r <= fetched_r;
			end
            monitor_on_r <= monitor_on;
		end
	end : proc_assign_regfile

	// regfile output assignment
	assign reg_file_o = reg_file;

    wire [7:0] base_addr_inv_r = ((base_addr_r[11:($clog2(reg_width / 8))]));

	always_comb begin
		reg_compare = resp_inv_addr[7:0] == base_addr_inv_r;
	end

	
	backoff_unit i_backoff_unit (
		.clk            (clk                  ),
		.rst_n          (rst_n                ),
		.backoff_value  (backoff_value        ),
		.backoff_if_inst(backoff_if_inst.slave)
	);

	assign backoff_if_inst.valid = state_r == S_BACKOFF;
	assign backoff_if_inst.interrupt = 1'b0;

	always_ff @(posedge clk) begin : proc_state_r
		if(~rst_n) begin
			state_r <= S_IDLE;
		end else begin
			state_r <= state_n;
		end
	end : proc_state_r

	always_comb begin : proc_state_n
		state_n = state_r;
		unique case(state_r)
			S_IDLE : begin
				if (!monitor_on) begin
					state_n = S_IDLE;
				end // if monitor is not on, stop polling
                else if (!monitor_on_r) begin
                    state_n = S_BACKOFF; // if monitor is on, but isn't on last cycle, starts polling
                end
				else if (tri_l2.resp_inv_valid && |reg_compare) begin
					state_n = S_BACKOFF;
				end
			end
			S_BACKOFF : begin
				// wait until backoff unit is over
				if (backoff_if_inst.ack) begin
					state_n = S_ELEVATE;
				end
			end
			S_ELEVATE   : state_n = tri_l2.req_ack ? S_WRITEBACK : S_ELEVATE;
			S_WRITEBACK : begin
				if (tri_l2.resp_val && tri_l2.resp_type == TRI_LOAD_RET) begin
					state_n = S_IDLE;
				end
			end
		endcase // state_r
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
		.inc_condition     (state_r == S_IDLE  ),
		.clear_trigger     (perf.clear_trigger ),
		.perf_counter_value(counter_r[0]       )
	);
	generic_perf_counter backoff_perf_counter (
		.clk               (clk                 ),
		.rst_n             (rst_n               ),
		.toggle_trigger    (perf.toggle_trigger ),
		.inc_condition     (state_r == S_BACKOFF),
		.clear_trigger     (perf.clear_trigger  ),
		.perf_counter_value(counter_r[1]        )
	);
	generic_perf_counter elevate_perf_counter (
		.clk               (clk                 ),
		.rst_n             (rst_n               ),
		.toggle_trigger    (perf.toggle_trigger ),
		.inc_condition     (state_r == S_ELEVATE),
		.clear_trigger     (perf.clear_trigger  ),
		.perf_counter_value(counter_r[2]        )
	);
	generic_perf_counter writeback_perf_counter (
		.clk               (clk                   ),
		.rst_n             (rst_n                 ),
		.toggle_trigger    (perf.toggle_trigger   ),
		.inc_condition     (state_r == S_WRITEBACK),
		.clear_trigger     (perf.clear_trigger    ),
		.perf_counter_value(counter_r[3]          )
	);
	generic_perf_counter transaction_perf_counter (
		.clk               (clk                                  ),
		.rst_n             (rst_n                                ),
		.toggle_trigger    (perf.toggle_trigger                  ),
		.inc_condition     (state_r == S_ELEVATE & tri_l2.req_ack),
		.clear_trigger     (perf.clear_trigger                   ),
		.perf_counter_value(counter_r[4]                         )
	);

	generate
		for (genvar i = 0; i < reg_width / 32; i++) begin : generate_for_lable_ro
			assign debug.dbg_data[i] = reg_file[i*32 +: 32];
		end : generate_for_lable_ro
	endgenerate
	`endif

endmodule : ro_coherency_manager

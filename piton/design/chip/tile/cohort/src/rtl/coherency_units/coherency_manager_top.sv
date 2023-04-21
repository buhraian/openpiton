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

// coherency manager top instantiates an array of coherency managers
// it's basically a top level for instantiating modules

`include "dcp.h"
module coherency_manager_top #(
	parameter int unsigned reg_width     = 128,
	parameter int unsigned source_num    = 7  ,
	parameter int unsigned regfile_numer = 5
) (
	input                        clk                           , // Clock
	input                        rst_n                         , // Asynchronous reset active low
	input                        monitor_on                    ,
	`ifdef COHORT_PERF
	perf_if.slave                perf                          ,
	cohort_dbg_if.master         debug                         ,
	`endif
	input        [         63:0] base_addr_r [source_num-1:0]  ,
	input  logic [         15:0] backoff_value                 ,
	output                       element_fetched               , // whether elements have been fetched yet
	tri_if.master                tri_l2                        ,
	output       [reg_width-1:0] reg_file_o [regfile_numer-1:0],
	input  fifo_ctrl_pkg::ptr_t  producer_tail_ptr_i           ,
	input  fifo_ctrl_pkg::ptr_t  consumer_head_ptr_i
);

	localparam int unsigned NumDebugInterfaces = 5;
	localparam int unsigned WidthDebugInterfaces = reg_width / 32;
	localparam int unsigned PerfCountNum = 5;
	

	logic [6:0] fetched;

	`ifdef COHORT_PERF
	perf_if  #(.perf_reg_num(5)) coh_perf [source_num-1:0]   (
		.clk(clk),
		.rst_n(rst_n)
	);

	cohort_dbg_if #(.RegNum(WidthDebugInterfaces)) coh_debug [NumDebugInterfaces - 1 : 0] (
		.clk(clk),
		.rst_n(rst_n)
	);
	`endif

	assign element_fetched = &fetched; // every element is fetched

	// always check cohort design sheet
	coherency_configure_if coherency_configure_source[source_num] (
		.clk  (clk  ),
		.rst_n(rst_n)
	);

	tri_if tri_source [source_num - 1 : 0] (
		.clk(clk),
		.rst_n(rst_n)
	);

	logic [reg_width-1:0] consumer_tail_ptr;
	assign reg_file_o[0] = consumer_tail_ptr;

	// consumer tail pointer coherency manager
	ro_coherency_manager #(
		.reg_number(1        ),
		.reg_width (reg_width)
	) c_tail_coh_mgr (
		.clk            (clk              ),
		.rst_n          (rst_n            ),
		.monitor_on     (monitor_on       ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[0]      ),
		.debug          (coh_debug[0]     ),
		`endif
		.element_fetched(fetched [0]      ),
		.base_addr_r    (base_addr_r[0]   ),
		.backoff_value  (backoff_value    ),
		.tri_l2         (tri_source[0]    ),
		.reg_file_o     (consumer_tail_ptr)
	);


	// consumer fifo info coherency manager
	ro_coherency_manager #(
		.reg_number(1        ),
		.reg_width (reg_width)
	) c_fifo_coh_mgr (
		.clk            (clk           ),
		.rst_n          (rst_n         ),
		.monitor_on     (monitor_on    ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[1]   ),
		.debug          (coh_debug[1]  ),
		`endif
		.element_fetched(fetched [1]   ),
		.base_addr_r    (base_addr_r[1]),
		.backoff_value  (backoff_value ),
		.tri_l2         (tri_source[1] ),
		.reg_file_o     (reg_file_o[1] )
	);


	// consumer head
	wo_coherency_manager c_head_coh_mgr (
		.clk            (clk                ),
		.rst_n          (rst_n              ),
		.monitor_on     (monitor_on         ),
		.base_addr_r    (base_addr_r[2]     ),
		.backoff_value  (backoff_value      ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[2]        ),
		`endif
		.element_fetched(fetched [2]        ),
		.tri_l2         (tri_source[2]      ),
		.src_ptr_r      (consumer_head_ptr_i),
		.ref_ptr_r      (consumer_tail_ptr  )
	);

	logic [reg_width-1:0] producer_head_ptr;
	assign reg_file_o[2] = producer_head_ptr;


	// producer head
	ro_coherency_manager #(
		.reg_number(1        ),
		.reg_width (reg_width)
	) p_head_coh_mgr (
		.clk            (clk              ),
		.rst_n          (rst_n            ),
		.monitor_on     (monitor_on       ),
		.backoff_value  (backoff_value    ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[3]      ),
		.debug          (coh_debug[2]     ),
		`endif
		.base_addr_r    (base_addr_r[3]   ),
		.element_fetched(fetched [3]      ),
		.tri_l2         (tri_source[3]    ),
		.reg_file_o     (producer_head_ptr)
	);

	// producer fifo structure
	ro_coherency_manager #(
		.reg_number(1        ),
		.reg_width (reg_width)
	) p_fifo_coh_mgr (
		.clk            (clk           ),
		.rst_n          (rst_n         ),
		.monitor_on     (monitor_on    ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[4]   ),
		.debug          (coh_debug[3]  ),
		`endif
		.element_fetched(fetched [4]   ),
		.base_addr_r    (base_addr_r[4]),
		.backoff_value  (backoff_value ),
		.tri_l2         (tri_source[4] ),
		.reg_file_o     (reg_file_o[3] )
	);


	// producer tail
	wo_coherency_manager p_tail_coh_mgr (
		.clk            (clk                ),
		.rst_n          (rst_n              ),
		.monitor_on     (monitor_on         ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[5]        ),
		`endif
		.element_fetched(fetched [5]        ),
		.base_addr_r    (base_addr_r[5]     ),
		.backoff_value  (backoff_value      ),
		.tri_l2         (tri_source[5]      ),
		.src_ptr_r      (producer_tail_ptr_i),
		.ref_ptr_r      (producer_head_ptr  )
	);

	// accelerator data

	ro_coherency_manager #(
		.reg_number(1        ),
		.reg_width (reg_width)
	) acc_coh_mgr (
		.clk            (clk           ),
		.rst_n          (rst_n         ),
		.monitor_on     (monitor_on    ),
		`ifdef COHORT_PERF
		.perf           (coh_perf[6]   ),
		.debug          (coh_debug[4]  ),
		`endif
		.element_fetched(fetched [6]   ),
		.base_addr_r    (base_addr_r[6]),
		.backoff_value  (backoff_value ),
		.tri_l2         (tri_source[6] ),
		.reg_file_o     (reg_file_o[4] )
	);

	mshr_tri_unit #(.source_num(source_num)) i_mshr_tri_unit (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.tri_source(tri_source),
		.tri_sink  (tri_l2    )
	);

	`ifdef COHORT_PERF
	genvar i, j, k;

	generate
		for (i = 0; i < source_num; i++) begin
			assign coh_perf[i].clear_trigger = perf.clear_trigger;
			assign coh_perf[i].toggle_trigger = perf.toggle_trigger;
			assign perf.counter_r[5*i +: 5] = coh_perf[i].counter_r[0 +: 5];
		end

		for (j = 0; j < NumDebugInterfaces; j++) begin
				assign debug.dbg_data[j * WidthDebugInterfaces + 0] = coh_debug[j].dbg_data[0];
				assign debug.dbg_data[j * WidthDebugInterfaces + 1] = coh_debug[j].dbg_data[1];
				assign debug.dbg_data[j * WidthDebugInterfaces + 2] = coh_debug[j].dbg_data[2];
				assign debug.dbg_data[j * WidthDebugInterfaces + 3] = coh_debug[j].dbg_data[3];
		end
	endgenerate
	`endif


endmodule

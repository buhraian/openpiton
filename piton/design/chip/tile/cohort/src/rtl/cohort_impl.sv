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

`include "dcp.h"

module cohort_impl (
    input logic clk,
    input logic rst_n,
    config_if.slave conf,
    mem_req_if.master load_req,
    atomic_resp_if.slave atomic_resp,
    tlb_if.master tlb_req,
    tri_if.master tri_l2
    //TODO: add scratchpad interface
);
    
    tri_if tri_l2_untranslated(
        .clk  (clk),
        .rst_n(rst_n)
    );

    mem_req_if load_req_untranslated (
        .clk  (clk  ),
        .rst_n(rst_n)
    );


    localparam int unsigned uncached_regfile_num = 8;

    // our available mshr id range is 128-143
    // give 128-131 to mem_controller
    // give 132-143 to memory parser
    
    fifo_config_pkg::fifo_config_t consumer_config, producer_config;
    acc_pkg::acc_config_t acc_config;

    config_if config_if_inst (
        .clk  (clk  ),
        .rst_n(rst_n)
    );

    tri_if tri_source[1:0] (
        .clk(clk),
        .rst_n(rst_n)
    );
    atomic_resp_if atomic_resp_if_inst (
        .clk  (clk  ),
        .rst_n(rst_n)
    );
    coherency_configure_if coherency_configure_if_inst (
        .clk  (clk  ),
        .rst_n(rst_n)
    );

    
    logic [63:0] uncached_reg[uncached_regfile_num - 1:0];

	`ifdef COHORT_PERF
    logic [63:0] performance_counters[35 + 20 -1:0];
    perf_if #(.perf_reg_num(35)) coherency_perf (
        .clk  (clk  ),
        .rst_n(rst_n)
    );
    cohort_dbg_if #(.RegNum((128/32)*5)) impl_debug (
        .clk  (clk  ),
        .rst_n(rst_n)
    );

    assign coherency_perf.clear_trigger = uncached_reg[uncached_regfile_num - 1][2];
    assign coherency_perf.toggle_trigger = uncached_reg[uncached_regfile_num - 1][3];

	`endif

    logic monitor_on;
    logic manual_reset;

    logic [15:0] backoff_value;

    logic [15:0] serialization_ratio;

    logic [15:0] deserialization_ratio;

    logic [13:0] wait_cycles;

    // 0: reset
    // 1: toggle monitor
    // 2: clear
    // 3: on/off
    // 63-48: backoff value
    assign manual_reset = uncached_reg[uncached_regfile_num - 1][0];
    assign monitor_on = uncached_reg[uncached_regfile_num-1][1];
    assign backoff_value = uncached_reg[uncached_regfile_num - 1][63:48];
    assign serialization_ratio = uncached_reg[uncached_regfile_num - 1][47:32];
    assign deserialization_ratio = uncached_reg[uncached_regfile_num - 1][31:16];
    assign wait_cycles = uncached_reg[uncached_regfile_num - 1][15:4];

	`ifdef COHORT_PERF
    genvar i;
    generate
        for (i = 0; i < 35; i++) begin : generate_performance_counter
            assign performance_counters[i] = coherency_perf.counter_r[i];
        end : generate_performance_counter
        for (i = 35; i < 35+20; i++) begin : generate_debug
            assign performance_counters[i] = impl_debug.dbg_data[i-35];
        end : generate_debug

    endgenerate
	`endif
  
    // maybe we don't even need reset anymore? 
   // [7] is clear
   // [8] is start 
    uncached_configuration_unit #(
        .reg_number        (uncached_regfile_num),
        .ro_register_number(35 + 20               )
    ) i_uncached_configuration_unit (
        .clk          (clk                 ),
        .rst_n        (rst_n               ),
        .conf         (conf                ),
		`ifdef COHORT_PERF
        .ro_register_i(performance_counters),
		`endif
        .uncached_reg (uncached_reg        )
    );
    

    logic [127:0]        reg_file_o       [4:0];
    fifo_ctrl_pkg::ptr_t producer_tail_ptr     ;
    fifo_ctrl_pkg::ptr_t consumer_head_ptr     ;

    logic element_fetched;

    logic secondary_rst_n;
    assign secondary_rst_n = rst_n & element_fetched & manual_reset;

    coherency_manager_top i_coherency_manager_top (
        .clk                (clk                                   ),
        .rst_n              (rst_n                                 ),
        .monitor_on         (monitor_on                            ),
        .base_addr_r        (uncached_reg[uncached_regfile_num-2:0]),
        .backoff_value      (backoff_value                         ),
		`ifdef COHORT_PERF
        .perf               (coherency_perf                        ),
        .debug              (impl_debug                            ),
		`endif
        .element_fetched    (element_fetched                       ),
        .tri_l2             (tri_source[0].master                  ),
        .reg_file_o         (reg_file_o                            ),
        .producer_tail_ptr_i(producer_tail_ptr                     ),
        .consumer_head_ptr_i(consumer_head_ptr                     )
    );

    // wire coherency manager and fifo config
    assign consumer_config.fifo_ptr.tail = reg_file_o[0];
    assign consumer_config.addr_base     = reg_file_o[1][63:0];
    assign consumer_config.element_size  = reg_file_o[1][95:64];
    assign consumer_config.fifo_length   = reg_file_o[1][127:96];

    assign producer_config.fifo_ptr.head = reg_file_o[2];
    assign producer_config.addr_base     = reg_file_o[3][63:0];
    assign producer_config.element_size  = reg_file_o[3][95:64];
    assign producer_config.fifo_length   = reg_file_o[3][127:96];

    assign acc_config = reg_file_o[4];

    // wire noc signals
    pmesh_pkg::pmesh_noc2_i_t  noc2_i ;
    pmesh_pkg::pmesh_noc2_o_t  noc2_o ;
    pmesh_pkg::pmesh_noc3_in_t noc3_in;

    assign noc3_in.valid = atomic_resp.valid;
    assign noc3_in.mshrid = atomic_resp.mshrid;
    assign noc3_in.resp_data = atomic_resp.data;

    assign load_req_untranslated.valid = noc2_o.valid;
    assign load_req_untranslated.req_type = noc2_o.req_type;
    assign load_req_untranslated.mshrid = noc2_o.mshrid;
    assign load_req_untranslated.address = noc2_o.address;
    assign load_req_untranslated.size = noc2_o.size;
    assign load_req_untranslated.homeid = noc2_o.homeid;
    assign load_req_untranslated.write_mask = noc2_o.write_mask;
    assign load_req_untranslated.data_0 = noc2_o.data_0;
    assign load_req_untranslated.data_1 = noc2_o.data_1;

    assign noc2_i.ready = load_req_untranslated.ready;




    import fifo_config_pkg::fifo_config_t;


    fifo_controller i_fifo_controller (
        .clk                  (clk                  ),
        .rst_n                (secondary_rst_n      ),
        .noc2_i               (noc2_i               ),
        .noc2_o               (noc2_o               ),
        .noc3_in              (noc3_in              ),
        .acc_config           (acc_config           ),
        .consumer_config      (consumer_config      ),
        .producer_config      (producer_config      ),
        .serialization_ratio  (serialization_ratio  ),
        .deserialization_ratio(deserialization_ratio),
        .wait_cycles          (wait_cycles          ),
        .tri_bus              (tri_source[1].master ),
        .producer_tail_ptr_o  (producer_tail_ptr    ),
        .consumer_head_ptr_o  (consumer_head_ptr    )
    );



    mshr_tri_unit #(.source_num(2)) i_mshr_tri_unit (
        .clk       (clk                ),
        .rst_n     (rst_n              ),
        .tri_source(tri_source         ),
        .tri_sink  (tri_l2_untranslated)
    );
 
    
    translator_unit_top i_translator_unit_top (
        .clk         (clk                  ),
        .rst_n       (rst_n                ),
        .tlb_req     (tlb_req              ),
        .tri_source  (tri_l2_untranslated  ),
        .tri_sink    (tri_l2               ),
        .pmesh_source(load_req_untranslated),
        .pmesh_sink  (load_req             )
    );
 



endmodule : cohort_impl

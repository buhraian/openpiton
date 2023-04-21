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

/*
    mem_controller module handles all configuration writes from
    ariane, and issues corresponding memory requests
    note that mem
    Note that the size is always 32 bits
    make this give a simple output and use adapter to translate them
    to the outside
*/
`include "dcp.h"
module uncached_configuration_unit #(
    parameter int unsigned reg_number         = 4 , // limited by noc1, reg can only be 32bits
    parameter int unsigned reg_width          = 64,
    parameter int unsigned ro_register_number = -1,
    parameter int unsigned RORegisterWidth    = 64
) (
    input                              clk                                   , // Clock
    input                              rst_n                                 , // Asynchronous reset active low
    config_if.slave                    conf                                  ,
	`ifdef COHORT_PERF
    input  logic [RORegisterWidth-1:0] ro_register_i [ro_register_number-1:0], // the uncached configuration output
	`endif
    output logic [      reg_width-1:0] uncached_reg [reg_number-1:0]          // the uncached configuration output
);
    import config_pkg::*;

    logic [reg_width-1:0] regfile_r [reg_number-1:0];
    logic [reg_width-1:0] regfile_n [reg_number-1:0];

    logic [        $clog2(reg_number)+1:0] wo_conf_addr;

    

    assign wo_conf_addr    = conf.addr[$clog2(reg_number)+4:3];

	`ifdef COHORT_PERF
    assign conf.read_valid = readback_req;
    assign conf.read_data  = readback_data;
	`else
	assign conf.read_valid = '0;
	assign conf.read_data  = '0;
	`endif


    genvar i;
    generate
        for (i = 0; i < reg_number; i++) begin
            assign uncached_reg[i] = regfile_r[i];
            always_ff @(posedge clk) begin : proc_regfile_r
                if(~rst_n) begin
                    regfile_r[i] <= '0;
                end else begin
                    regfile_r[i] <= regfile_n[i];
                end
            end

            always_comb begin : proc_regfile_nr
                regfile_n[i] = regfile_r[i];
                if (wo_conf_addr == i && conf.valid && conf.config_type == T_STORE) begin
                    regfile_n[i] = conf.data[reg_width-1:0];
                end
            end
        end
    endgenerate

	`ifdef COHORT_PERF
    logic [63:0] readback_data;
    logic readback_req;
    
	always_comb begin : proc_readback
        readback_data = '0;
        readback_req = 1'b0;
        for (int j = 0; j < ro_register_number; j++) begin
            if (conf.addr == (j << 3) && conf.valid && conf.config_type == T_LOAD ) begin
                readback_req = 1'b1;
                readback_data = ro_register_i[j];
            end
        end
    end
	`endif

endmodule: uncached_configuration_unit

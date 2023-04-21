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

// uncached signals
interface config_if (
    input logic clk,
    input logic rst_n
);
    logic valid;
    config_pkg::paddr_t addr;
    config_pkg::data_t data;
    config_pkg::size_t size;
    config_pkg::transaction_t config_type;

    config_pkg::data_t read_data;
    logic read_valid;


    modport slave(
        input valid, addr, data, size, config_type,
        output read_data, read_valid
    );

    modport master(
        output valid, addr, data, size, config_type,
        input read_data, read_valid
    );


`ifndef SYNTHESIS
    task set_config(input paddr_t addr_in, data_t data_in);
        $display("Adding configuration");
        @(negedge clk);
        valid = 1'b1;
        data = data_in;
        addr = addr_in;
        @(posedge clk);
    endtask: set_config

    task transact(input paddr_t addr_in, size_t size_in, req_type_t op_in);
        $display("Beginning transaction\n");
        set_config(12'h0, addr_in);
        set_config(12'h4, op_in);
        set_config(12'h8, size_in);
        set_config(12'hc, 1'b1);
        valid = 1'b0;
    endtask: transact
`endif

endinterface : config_if

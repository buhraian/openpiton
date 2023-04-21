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

`include "assert_macros.svh"
interface mem_req_if (
    input logic clk,
    input logic rst_n
);

    import dcp_pkg::*;
    logic        ready     ;
    logic        valid     ;
    req_type_t   req_type  ;
    mshrid_t     mshrid    ;
    paddr_t      address   ;
    // real size = size * 8 bytes
    size_t       size      ;
    homeid_t     homeid    ;
    write_mask_t write_mask;
    data_t       data_0    ;
    data_t       data_1    ;


    modport master (
        input ready,
        output valid, req_type, mshrid, address, size, homeid, write_mask, data_0, data_1
    );

    modport slave (
        output ready,
        input valid, req_type, mshrid, address, size, homeid, write_mask, data_0, data_1
    );


        `assert_hold_valid({req_type, mshrid, address, size, homeid, write_mask, data_0, data_1}, valid, ready, "memory request should hold valid")

        `assert_finish_handshake(valid, ready, {req_type, mshrid, address, size, homeid, write_mask, data_0, data_1}, "memory request should finish handshake")

`ifndef SYNTHESIS
    task initialize();
        ready = 1'b0;
    endtask : initialize

    task check_output(input paddr_t ref_addr);
        wait(valid == 1);
        if (address != ref_addr) begin :check_address
            $fatal(1, "Output address is not equal to reference address");
        end
    endtask : check_output
`endif


endinterface : mem_req_if

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

/**
 * this module translates the load request into another load
 * request, the second load request will bear virtual page
 * number instead of physical page number
 */
 `include "dcp.h"
module pmesh_translator_unit (
    input clk,    // Clock
    input rst_n,  // Asynchronous reset active low
    
    // assert data doesn't change before handshake in interface
    mem_req_if.slave load_req_vpn,
    mem_req_if.master load_req_ppn,
    tlb_if.master tlb_req
);
    import translator_pkg::pn_t;

    pn_t load_addr_ppn, load_addr_ppn_d;

    // there are 3 fsm-state for this module
    // when idle, there's no signal passing through this module
    //            every valid is low
    //            handshake early, assert load_req_vpn is ready
    //            record the physical address during the handshake
    // when query, it outputs invalid request and hang the incoming request
    //            it then goes to tlb to translate the memory
    // when req, the address has been translated
    //           then it simply wait for handshake, the de-assert the translated
    //           signal
    typedef enum logic [1:0] {S_IDLE, S_QUERY, S_REQ} state_t;

    state_t state, state_d;

    assign tlb_req.valid = state_d == S_QUERY;
    assign tlb_req.vpn = load_req_vpn.address[`DCP_PADDR-1:12];

    assign load_req_vpn.ready = (state_d == S_REQ) ? load_req_ppn.ready : 1'b0;
    // FIXME: simply this expression, assert a |-> b
    assign load_req_ppn.valid = (state_d == S_REQ) ? load_req_vpn.valid : 1'b0;

    // other stuff are connected as is
    assign load_req_ppn.address = {load_addr_ppn_d, load_req_vpn.address[11:0]};
    assign load_req_ppn.req_type = load_req_vpn.req_type;
    assign load_req_ppn.mshrid = load_req_vpn.mshrid;
    assign load_req_ppn.size = load_req_vpn.size;
    assign load_req_ppn.homeid = load_req_vpn.homeid;
    assign load_req_ppn.write_mask = load_req_vpn.write_mask;
    assign load_req_ppn.data_0 = load_req_vpn.data_0;
    assign load_req_ppn.data_1 = load_req_vpn.data_1;

    always_ff @(posedge clk) begin : proc_state_d
        if(~rst_n) begin
            state_d <= S_IDLE;
        end else begin
            state_d <= state;
        end
    end : proc_state_d

    always_comb begin : proc_state
        state = state_d;
        unique case(state_d)
            S_IDLE  : state = load_req_vpn.valid ? S_QUERY : S_IDLE;
            S_QUERY : state = tlb_req.valid & tlb_req.ack ? S_REQ : S_QUERY;
            S_REQ   : state = load_req_ppn.ready & load_req_ppn.valid ? S_IDLE : S_REQ;
            default : ;
        endcase // state_d
    end : proc_state




    always_ff @(posedge clk) begin
        if(~rst_n) begin
            load_addr_ppn_d <= '0;
        end else begin
            load_addr_ppn_d <= load_addr_ppn;
        end
    end

    always_comb begin : proc_load_registers
        load_addr_ppn = tlb_req.valid & tlb_req.ack ? tlb_req.ppn : load_addr_ppn_d;
    end


`ifndef SYNTHESIS

`endif

endmodule : pmesh_translator_unit

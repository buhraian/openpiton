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
module mem_parse (
    input clk,    // Clock
    input rst_n,  // Asynchronous reset active low
    
    mem_req_if.master load_req,
    atomic_resp_if.slave atomic_resp
);
    /* in this simplified state, there is no communication between
       mem_parse and mem_controller
       If we want to ignore some request, simply de-assert the ack
       this will simply things a great deal.
       Assuming all responses are from load requests, we
       load things from the load request, and then return the load
       to some other locaton
       The current fsm implementation requires that there are no
       outstanding requests from mem_controller
       We could allocate different mshr id to mitigate this problem
       TODO:
       - make this thing into a fifo
       - communication with mem_controller
       - signal to the cpu that we're done
      */


    typedef enum logic [1:0] {S_IDLE, S_REQ, S_RESP, S_DONE} state_t;
    state_t state, state_d;
    paddr_t addr_d, addr;
    assign load_req.valid = state_d == S_REQ;
    //FIXME: fix corrent type and size
    assign load_req.req_type = `MSG_TYPE_STORE_REQ;
    //FIXME: fix load request size to 8 bytes now
    assign load_req.size     = 2'h1;
    assign load_req.address  = addr_d;

    //FIXME: get the noc stuff right
    assign load_req.mshrid = 8'd145;
    assign load_req.homeid = '0;
    assign load_req.write_mask = '1;
    assign load_req.data_0 = 32'hdeadbeef;
    assign load_req.data_1 = 32'hbeefdead;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            state_d <= S_IDLE;
        end else begin
            state_d <= state;
        end
    end

    always_comb begin
        unique case (state_d)
            S_IDLE  : state = (atomic_resp.valid) ? S_REQ : S_IDLE;
            S_REQ   : state = ((load_req.valid & load_req.ready)) ? S_RESP : S_REQ;
            S_RESP  : state = (atomic_resp.valid) ? S_DONE : S_RESP;
            S_DONE  : state = S_IDLE;
            default : ;
        endcase // state_d
    end

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            addr_d <= 0;
        end else begin
            addr_d <= addr;
        end
    end

    assign addr = (atomic_resp.valid) ? atomic_resp.data : addr_d;


endmodule

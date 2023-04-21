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

module req_arbiter (
    mem_req_if.slave mem_controller_if,
    mem_req_if.slave mem_if       ,
    mem_req_if.master load_req
);
    // 0 is for mem_controller interface
    // 1 is for memory parser interface
    // if mem_controller interface is up, always issue request for mem_controller first
    // otherwise issue request for memory parse interface
    logic select;

    //TODO: is it safe to leave it at this? Would it cause a glitch?
    assign select = (mem_controller_if.valid) ? 1'b0 : 1'b1;

    assign mem_controller_if.ready = load_req.ready & !select;
    assign mem_if.ready        = load_req.ready & select;
    assign load_req.valid      = mem_controller_if.valid | mem_if.valid;
    assign load_req.req_type   = (select) ? mem_if.req_type : mem_controller_if.req_type;
    assign load_req.mshrid     = (select) ? mem_if.mshrid : mem_controller_if.mshrid;
    assign load_req.address   = (select) ? mem_if.address : mem_controller_if.address;
    assign load_req.size   = (select) ? mem_if.size : mem_controller_if.size;
    assign load_req.homeid   = (select) ? mem_if.homeid : mem_controller_if.homeid;
    assign load_req.write_mask   = (select) ? mem_if.write_mask : mem_controller_if.write_mask;
    assign load_req.data_0   = (select) ? mem_if.data_0 : mem_controller_if.data_0;
    assign load_req.data_1  = (select) ? mem_if.data_1 : mem_controller_if.data_1;

endmodule

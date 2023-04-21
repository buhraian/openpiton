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

bind mem_controller mem_controller_formal mem_controller_formal_inst(.*);
typedef enum logic {S_IDLE, S_REQ} state_t;
module mem_controller_formal (
    input               clk      , // Clock
    input               rst_n    , // Asynchronous reset active low
    config_if.slave   conf     ,
    mem_req_if.master load_req ,
    input               conf_fire,
    state_t             state_d
);

    default clocking
        @(posedge clk);
    endclocking
        default disable iff (rst_n);

    only_fire_on_idle: assert property (
        conf_fire |-> state_d == S_IDLE ##1 state_d == S_WRITE
    ) else $fatal(1, "Write request through noc2 should only fire when it's idle");

    conf_address_in_range: assert property (
        conf_fire |-> conf.addr inside {ADDR_BASE, ADDR_SIZE, ADDR_FIRE}
    ) else $fatal(1, "Invalid configuration address");


endmodule

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

/* this interface establishes the interface
 * which is a valid-ack interface. The valid is asserted when the master initiates a request
   and will keep asserted until it's acked
   the ack will assert for a single cycle if the data returns
 */

`include "assert_macros.svh"
interface tlb_if (
    input clk,
    input rst_n
);
    import dcp_pkg::*;

    logic valid;
    logic ack;
    logic [`DCP_VADDR   -12-1:0] vpn;
    logic [`DCP_VADDR   -12-1:0] ppn;

    modport slave (
        input valid, vpn, 
        output ack, ppn
    );

    // master will ack ppn
    modport master (
        input ack, ppn,
        output valid, vpn
    );

//        `assert_hold_valid(vpn, valid, ready, "Valid and vpn should hold until ack");
//       `assert_finish_handshake(valid, ready, "Valid should lower after handshake");

endinterface : tlb_if

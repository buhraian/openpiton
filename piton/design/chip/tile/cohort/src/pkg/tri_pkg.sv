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

package tri_pkg;
    // to l1.5 (only marked subset is used)
    typedef enum logic [4:0] {
        TRI_LOAD_RQ    = 5'b00000, // load request
        TRI_IMISS_RQ   = 5'b10000, // instruction fill request
        TRI_STORE_RQ   = 5'b00001, // store request
        TRI_ATOMIC_RQ  = 5'b00110, // atomic op
        //TRI_CAS1_RQ     = 5'b00010, // compare and swap1 packet (OpenSparc atomics)
        //TRI_CAS2_RQ     = 5'b00011, // compare and swap2 packet (OpenSparc atomics)
        //TRI_SWAP_RQ     = 5'b00110, // swap packet (OpenSparc atomics)
        TRI_STRLOAD_RQ = 5'b00100 // unused
        //TRI_STRST_RQ   = 5'b00101, // unused
        //TRI_STQ_RQ     = 5'b00111, // unused
        //TRI_INT_RQ     = 5'b01001, // interrupt request
        //TRI_FWD_RQ     = 5'b01101, // unused
        //TRI_FWD_RPY    = 5'b01110, // unused
        //TRI_RSVD_RQ    = 5'b11111  // unused
    } l15_reqtypes_t;

    // from l1.5 (only marked subset is used)
    typedef enum logic [3:0] {
        TRI_LOAD_RET               = 4'b0000, // load packet
        // TRI_INV_RET                = 4'b0011, // invalidate packet, not unique...
        TRI_ST_ACK                 = 4'b0100, // store ack packet
        //TRI_AT_ACK                 = 4'b0011, // unused, not unique...
        TRI_INT_RET                = 4'b0111, // interrupt packet
        TRI_TEST_RET               = 4'b0101, // unused
        TRI_FP_RET                 = 4'b1000, // unused
        TRI_IFILL_RET              = 4'b0001, // instruction fill packet
        TRI_EVICT_REQ              = 4'b0011, // eviction request
        TRI_ERR_RET                = 4'b1100, // unused
        TRI_STRLOAD_RET            = 4'b0010, // unused
        TRI_STRST_ACK              = 4'b0110, // unused
        TRI_FWD_RQ_RET             = 4'b1010, // unused
        TRI_FWD_RPY_RET            = 4'b1011, // unused
        TRI_RSVD_RET               = 4'b1111, // unused
        TRI_CPX_RESTYPE_ATOMIC_RES = 4'b1110  // custom type for atomic responses
    } l15_rtrntypes_t;

    typedef struct packed {
        logic         req_valid ;
        l15_reqtypes_t req_type  ;
        logic [  3:0] req_amo_op;
        logic [  2:0] req_size  ;
        logic [ 39:0] req_addr  ;
        logic [127:0] req_data  ;
        logic         resp_ack  ;
    } tri_req_t;

    typedef struct packed {
        logic         resp_val      ;
        l15_rtrntypes_t resp_type     ;
        logic         resp_atomic   ;
        logic [127:0] resp_data     ;
        logic [ 15:4] resp_inv_addr ;
        logic         resp_inv_valid;
        logic         req_ack       ;
    } tri_resp_t;
    endpackage : tri_pkg

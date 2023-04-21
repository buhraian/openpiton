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
module cohort (
    input                                    clk                              , // Clock
    input                                    rst_n                            , // Asynchronous reset active low
    input                                    config_hsk                       ,
    input       [                      22:0] config_addr                      ,
    input       [                      31:0] config_data_hi                   ,
    input       [                      31:0] config_data_lo                   ,
    input                                    config_load                      ,
    input       [  `MSG_DATA_SIZE_WIDTH-1:0] config_size                      ,
    // TLB interface
    output wire                              tlb_cohort_req                   ,
    input  wire                              tlb_cohort_ack                   ,
    output wire [         `DCP_VADDR-12-1:0] tlb_cohort_vpage                 ,
    input  wire [         `DCP_PADDR-12-1:0] tlb_ppn                          ,
    // noc1 request interface
    input                                    noc1buffer_rdy                   ,
    output                                   noc1buffer_val                   ,
    output      [       `MSG_TYPE_WIDTH-1:0] noc1buffer_type                  ,
    output      [     `DCP_MSHRID_WIDTH-1:0] noc1buffer_mshrid                ,
    output      [           `DCP_PADDR_MASK] noc1buffer_address               ,
    output      [          `DCP_UNPARAM_2_0] noc1buffer_size                  ,
    output      [         `DCP_UNPARAM_63_0] noc1buffer_data_0                ,
    output      [         `DCP_UNPARAM_63_0] noc1buffer_data_1                ,
    output      [   `MSG_AMO_MASK_WIDTH-1:0] noc1buffer_write_mask            ,
    // noc2 response interface
    input                                    noc2decoder_val                  ,
    input       [     `DCP_MSHRID_WIDTH-1:0] noc2decoder_mshrid               ,
    input       [`DCP_NOC_RES_DATA_SIZE-1:0] noc2decoder_data                 ,
    // TRI request signals
    output                                   tri_req_val               , // New request from core
    output      [                       4:0] tri_req_rqtype            , // Request type
    output      [                       3:0] tri_req_amo_op            , // Atomic type (if rqtype is atomic)
    output      [                       2:0] tri_req_size              , // Size of request (power-of-2 minus 1)
    output      [                      39:0] tri_req_address           , // 40 bit physical address
    output      [                      63:0] tri_req_data              , // 64 bits of data
    output      [                      63:0] tri_req_data_next_entry   , // further 64 bits of data
    input                                    tri_req_ack               , // L1.5 can accept next request
    // TRI response signals:
    input                                    tri_resp_val               , // L1.5 has response for core
    input       [                       3:0] tri_resp_returntype        , // Response type
    input                                    tri_resp_atomic            , // Response to an atomic request
    input       [                      63:0] tri_resp_data_0            , // Data response (used by L1D and L1I)
    input       [                      63:0] tri_resp_data_1            , // Data response (used by L1D and L1I)
    input       [                      15:4] tri_resp_inval_address_15_4, // Invalidate selected line - ignore
    input                                    tri_resp_inval_val         , // Way to invalidate - ignore
    output                                   tri_resp_req_ack           , // Response received by core

    // direct communication interface with ariane
    output      [         `DCP_UNPARAM_63_0] read_to_ariane_data              ,
    output                                   read_to_ariane_val
);

    config_if conf (.clk(clk), .rst_n(rst_n));
    mem_req_if load_req (.clk(clk), .rst_n(rst_n));
    atomic_resp_if atomic_resp (.clk(clk), .rst_n(rst_n));
    tlb_if tlb_req(.clk(clk), .rst_n(rst_n));
    tri_if tri_l2(.clk(clk), .rst_n(rst_n));
    logic [127:0] tri_req_data_rev                                   ;

    wire  [ 63:0] config_data      = {config_data_lo, config_data_hi};

    assign tri_req_data_rev = tri_l2.req_data;

    logic [127:0] tri_req_data_forward;

    assign conf.config_type = config_load ? config_pkg::T_LOAD : config_pkg::T_STORE;
    assign conf.valid       = config_hsk;
    assign conf.addr        = config_addr;
    assign conf.size        = config_size;

    assign read_to_ariane_data = conf.read_data;
    assign read_to_ariane_val  = conf.read_valid;

    assign load_req.ready        = noc1buffer_rdy;
    assign noc1buffer_val        = load_req.valid;
    assign noc1buffer_type       = load_req.req_type;
    assign noc1buffer_mshrid     = load_req.mshrid;
    assign noc1buffer_address    = load_req.address;
    assign noc1buffer_size       = load_req.size;
    assign noc1buffer_data_0     = load_req.data_0;
    assign noc1buffer_data_1     = load_req.data_1;
    assign noc1buffer_write_mask = load_req.write_mask;

    assign atomic_resp.valid = noc2decoder_val;
    assign atomic_resp.mshrid = noc2decoder_mshrid;

    assign tlb_req.ack = tlb_cohort_ack;
    assign tlb_req.ppn = tlb_ppn;


    assign tlb_cohort_vpage = tlb_req.vpn;
    assign tlb_cohort_req   = tlb_req.valid;

    // connect tri interface signals
    assign {tri_req_data_next_entry, tri_req_data} = tri_req_data_forward;


    assign tri_req_address          = tri_l2.req_addr;
    assign tri_req_amo_op           = tri_l2.req_amo_op;
    assign tri_req_rqtype           = tri_l2.req_type;
    assign tri_req_size             = tri_l2.req_size;
    assign tri_req_val              = tri_l2.req_valid;
    assign tri_l2.req_ack        = tri_req_ack;

    assign tri_l2.resp_val       = tri_resp_val;
    assign tri_l2.resp_type      = tri_resp_returntype;
    assign tri_l2.resp_atomic    = tri_resp_atomic;
    wire [127:0] resp_data_full  = {tri_resp_data_1, tri_resp_data_0};
    assign tri_l2.resp_inv_addr  = tri_resp_inval_address_15_4;
    assign tri_l2.resp_inv_valid = tri_resp_inval_val;
    assign tri_resp_req_ack         = tri_l2.resp_ack;

    genvar i, j;
    generate
        for (i = 0; i < 512/64; i++) begin: atomic_flip_endian_outer
            for (j = 0; j < 8; j++) begin: atomic_flip_endian_inner
                assign atomic_resp.data[64*i + 8*j +: 8] = noc2decoder_data[64*(i+1)-8*j-1 -: 8];
            end: atomic_flip_endian_inner
        end: atomic_flip_endian_outer

        // flip configuration data as well
        for (i = 0; i < 64/64; i++) begin: config_if_flip_endian_outer
            for (j = 0; j < 8; j++) begin: config_if_flip_endian_inner
                assign conf.data[64*i + 8*j +: 8] = config_data[64*(i+1)-8*j-1 -: 8];
            end: config_if_flip_endian_inner
        end: config_if_flip_endian_outer


        for (i = 0; i < 128/64; i++) begin: tri_flip_endian_outer
            for (j = 0; j < 8; j++) begin: tri_flip_endian_inner
                assign tri_l2.resp_data[64*i + 8*j +: 8] = resp_data_full[64*(i+1)-8*j-1 -: 8];
            end: tri_flip_endian_inner
        end: tri_flip_endian_outer

        for (i = 0; i < 128/64; i++) begin: tri_req_data_flip_endian_outer
            for (j = 0; j < 8; j++) begin: tri_req_data_flip_endian_inner
                assign tri_req_data_forward[64*i + 8*j +: 8] = tri_req_data_rev[64*(i+1)-8*j-1 -: 8];
            end: tri_req_data_flip_endian_inner
        end: tri_req_data_flip_endian_outer


    endgenerate


    cohort_impl cohort_impl_inst(.*);

endmodule: cohort

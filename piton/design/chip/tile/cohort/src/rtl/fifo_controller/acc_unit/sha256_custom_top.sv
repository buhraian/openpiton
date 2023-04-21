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

// this should only act as the top level wrapper for acc
// the data parts are completely decoupled now without address information
// this is dummy and the data width can be adjusted at the higher level
module sha256_custom_top #(
    parameter int unsigned SRC_IF_DATA_W    = 64
    ,parameter int unsigned BYTE_W          = 8
    ,parameter int unsigned SHA_IF_DATA_W   = 256
    ,parameter int unsigned SHA256_BLOCK_W  = 512
    ,parameter int unsigned SHA256_DIGEST_W = 256
    ,parameter int unsigned SHA_IF_BYTES    = 256/8
    ,parameter int unsigned SHA_IF_BYTES_W  = $clog2(SHA_IF_BYTES)
)(
	input clk,    
	input rst_n, 
	input acc_pkg::acc_config_t acc_config, 
	decoupled_vr_if.slave consumer_data,
	decoupled_vr_if.master producer_data
);
    `define NUM_OF_CHUNKS SHA_IF_DATA_W/SRC_IF_DATA_W

    logic                          src_padder_data_val;
    logic  [SHA_IF_DATA_W-1:0]     src_padder_data;
    logic                          src_padder_data_last; 
    logic                          padder_src_rdy;

    logic                          padder_manager_data_val;
    logic  [SHA_IF_DATA_W-1:0]     padder_manager_data;
    logic                          padder_manager_data_last; 
    logic                          manager_padder_rdy;

    logic                          manager_core_init;
    logic                          manager_core_next;
    logic                          manager_core_mode;
    logic  [SHA256_BLOCK_W-1:0]    manager_core_block;
    logic                          core_manager_ready;
    logic  [SHA256_DIGEST_W-1:0]   core_manager_digest;
    logic                          core_manager_digest_valid;
    
    logic  [$clog2(`NUM_OF_CHUNKS):0]    counter_q, counter_n; 
    logic                                saturated_q, saturated_n;
    
    logic  [`NUM_OF_CHUNKS-1:0][SRC_IF_DATA_W-1:0]     block_reg;
    logic  [`NUM_OF_CHUNKS-1:0][SRC_IF_DATA_W-1:0]     block_reg_n;

    // save consumer data before feeding to the padder(256bits)
    assign src_padder_data = {block_reg[03], block_reg[02], block_reg[01], block_reg[00]};

    always_ff @(posedge clk or negedge rst_n) begin : synch_counters
        if (~rst_n) begin
            counter_q <= `NUM_OF_CHUNKS; // start from full number to have additional cycle for a data_val signal reset
            block_reg <= '0;
            saturated_q <= '0;
        end else begin
            counter_q <= counter_n;
            block_reg <= block_reg_n;
            saturated_q <= saturated_n;
        end
    end

    always_comb begin : block_regs
        block_reg_n = block_reg;

        if (consumer_data.valid && consumer_data.ready) begin
            block_reg_n[counter_q-1] = consumer_data.data;
        end
    end

    always_comb begin : incr_counters
        counter_n = counter_q;
        saturated_n = saturated_q;

        // as long as the consumer data is valid, keep processing an input
        if (consumer_data.valid && consumer_data.ready) begin
            counter_n -= 'b1; 
        end else if(!counter_q) begin
            counter_n  = `NUM_OF_CHUNKS;
            saturated_n += 'd1; 
        end

    end
    
    assign src_padder_data_val  = !counter_q; 
    assign src_padder_data_last = !counter_q && saturated_q;

    logic [SHA_IF_BYTES_W-1:0] padbytes; 
    // padbytes = all bytes - valid bytes
    // assumption - each input block will contain 256 valid bits - 32 bytes always
    assign padbytes = '0; 

    sha256_padder padder(
        .clk  ( clk    )
        ,.rst ( ~rst_n )
        ,.src_padder_data_val        (  src_padder_data_val       )         
        ,.src_padder_data            (  src_padder_data           )
        ,.src_padder_data_padbytes   (  padbytes                  )
        ,.src_padder_data_last       (  src_padder_data_last      ) 
        ,.padder_src_rdy             (  consumer_data.ready       )
        ,.padder_dst_data_val        (  padder_manager_data_val   )         
        ,.padder_dst_data            (  padder_manager_data       )
        ,.padder_dst_data_last       (  padder_manager_data_last  )
        ,.dst_padder_data_rdy        (  manager_padder_rdy        )
    );

    sha256_manager manager (
         .clk   (clk       )
        ,.rst   (~rst_n    )

        ,.src_manager_data_val      ( padder_manager_data_val    )
        ,.src_manager_data          ( padder_manager_data        )
        ,.src_manager_data_last     ( padder_manager_data_last   ) 
        ,.manager_src_rdy           ( manager_padder_rdy         ) // out
 
        ,.manager_dst_digest_val    ( producer_data.valid        )
        ,.manager_dst_digest        ( producer_data.data         )
        ,.dst_manager_digest_rdy    ( producer_data.ready        ) // in

        ,.manager_core_init         ( manager_core_init          )
        ,.manager_core_next         ( manager_core_next          )
        ,.manager_core_mode         ( manager_core_mode          )
        ,.manager_core_block        ( manager_core_block         )
        ,.core_manager_ready        ( core_manager_ready         )
                                      
        ,.core_manager_digest       ( core_manager_digest        )
        ,.core_manager_digest_valid ( core_manager_digest_valid  )
    );

    sha256_core DUT (
         .clk       (clk    )
        ,.reset_n   (rst_n   )

        ,.init          (  manager_core_init          )
        ,.next          (  manager_core_next          )
        ,.mode          (  manager_core_mode          )
        ,.block         (  manager_core_block         )
        ,.ready         (  core_manager_ready         )
  
        ,.digest        (  core_manager_digest        )
        ,.digest_valid  (  core_manager_digest_valid  )
    );

endmodule : sha256_custom_top

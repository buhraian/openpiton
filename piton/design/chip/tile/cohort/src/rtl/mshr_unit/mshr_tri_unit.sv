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
module mshr_tri_unit #(parameter int unsigned source_num = 4) (
	input clk  , // Clock
	input rst_n, // Asynchronous reset active low
	tri_if.slave tri_source[source_num-1:0],
	tri_if.master tri_sink
);

	import tri_pkg::*;

	typedef enum logic [2:0] {S_IDLE, S_LOAD_REQ, S_LOAD_RESP, S_STORE_REQ, S_STORE_RESP, S_U='x} state_t;

	logic [$clog2(source_num):0] index_r, index_n; // index for the arbiter

	state_t state, state_next;

	
	logic [$clog2(source_num):0] encoder_index;
	logic [source_num-1:0] elements;
	logic encoder_onehot;

	genvar i;
	generate
		for (i = 0; i < source_num; i++) begin
			assign elements[i] = tri_source[i].req_valid;
		end
	endgenerate
	
	priority_encoder #(.NumberOfElement(source_num)) i_priority_encoder (
		.elements (elements      ),
		.index    (encoder_index ),
		.is_onehot(encoder_onehot)
	);

	tri_pkg::l15_reqtypes_t tri_req_type;
	tri_pkg::l15_reqtypes_t encoded_req_type;
	logic [2:0] tri_req_size;
	logic [39:0] tri_req_addr;
	logic [127:0] tri_req_data;

	tri_pkg::l15_reqtypes_t tri_source_req_types[source_num-1:0];
	logic [  2:0]           tri_source_req_sizes[source_num-1:0];
	logic [ 39:0]           tri_source_req_addrs[source_num-1:0];
	logic [127:0]           tri_source_req_datas[source_num-1:0];

	generate
		for (i = 0; i < source_num; i++) begin : generate_source
			// pass through invalidation signal without any handling
			assign tri_source[i].resp_inv_addr = tri_sink.resp_inv_addr;
			assign tri_source[i].resp_inv_valid = tri_sink.resp_inv_valid;

			assign tri_source[i].resp_atomic = tri_sink.resp_atomic;
			assign tri_source[i].resp_data = tri_sink.resp_data;
			assign tri_source[i].resp_type = tri_sink.resp_type;
			assign tri_source[i].resp_val = (index_r == i) && (tri_sink.resp_val) && ((state == S_LOAD_RESP && tri_sink.resp_type == TRI_LOAD_RET) || (state == S_STORE_RESP && tri_sink.resp_type == TRI_ST_ACK));

			// req signals
			assign tri_source[i].req_ack = (index_r == i) && (tri_sink.req_ack) && ((state == S_LOAD_REQ ) || (state == S_STORE_REQ));

			assign tri_source_req_types[i] = tri_source[i].req_type;
			assign tri_source_req_sizes[i] = tri_source[i].req_size;
			assign tri_source_req_addrs[i] = tri_source[i].req_addr;
			assign tri_source_req_datas[i] = tri_source[i].req_data;

		end
		endgenerate

	always_comb begin
		tri_req_type = TRI_IMISS_RQ; // note that this is pointless
		tri_req_data = '0;
		tri_req_size = '0;
		tri_req_addr = '0;

		for (int j = 0; j < source_num; j++) begin: req_gen
			if (j == index_r) begin
				tri_req_type = tri_source_req_types[j];
				tri_req_data = tri_source_req_datas[j];
				tri_req_size = tri_source_req_sizes[j];
				tri_req_addr = tri_source_req_addrs[j];
			end
		end
	end

	always_comb begin
		encoded_req_type = TRI_IMISS_RQ;
		for (int j = 0; j < source_num; j++) begin: type_gen
			if (j == encoder_index) begin
				encoded_req_type = tri_source_req_types[j];
			end
		end
	end


        assign tri_sink.resp_ack   = tri_sink.resp_val;
	assign tri_sink.req_amo_op = '0;
	assign tri_sink.req_valid  = state == S_LOAD_REQ || state == S_STORE_REQ;
	assign tri_sink.req_type   = tri_req_type;
	assign tri_sink.req_size   = tri_req_size;
	assign tri_sink.req_data   = tri_req_data;
	assign tri_sink.req_addr   = tri_req_addr;

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			index_r <= '0;
		end else begin
			state <= state_next;
			index_r <= index_n;
		end
	end


	always_comb begin : proc_state_next
		state_next = state;
		index_n = index_r;
		unique case (state)
			S_IDLE       : begin
				if (encoder_onehot) begin
					if (encoded_req_type == TRI_LOAD_RQ) begin
						state_next = S_LOAD_REQ;
					end else if (encoded_req_type == TRI_STORE_RQ) begin
						state_next = S_STORE_REQ;
					end else begin
						state_next = S_U;
					end
					index_n = encoder_index;
				end
			end
			S_LOAD_REQ   : begin
				if (tri_sink.req_ack) begin
					state_next = S_LOAD_RESP;
				end
			end
			S_LOAD_RESP  : begin
				if (tri_sink.resp_val && tri_sink.resp_type == TRI_LOAD_RET) begin
					state_next = S_IDLE; // always ack immediately
				end
			end
			S_STORE_REQ  : begin
				if (tri_sink.req_ack) begin
					state_next = S_STORE_RESP;
				end
			end
			S_STORE_RESP : begin
				if (tri_sink.resp_val && tri_sink.resp_type == TRI_ST_ACK) begin
					state_next = S_IDLE;
				end
			end
		endcase
	end	

endmodule : mshr_tri_unit

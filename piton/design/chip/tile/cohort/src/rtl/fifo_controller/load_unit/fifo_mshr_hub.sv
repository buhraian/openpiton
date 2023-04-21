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

// this module generates load requests. By using multiple MSHRs in the future, we
// can allow multiple OoO memory requests
// Note that this not only keeps track of MSHR, but also issues and rececives load
// results

module fifo_mshr_hub
	import fifo_ctrl_pkg::*;
#(parameter int unsigned checkpoint_interval = 32) (
	input               clk          , // Clock
	input               rst_n        , // Asynchronous reset active low
	input  addr_gen_o_t addr_i       ,
	input  length_t     fifo_length  ,
	output addr_gen_i_t addr_o       ,
	output ld_req_i_t   ld_req_o     ,
	input  ld_req_o_t   ld_req_i     ,
	input  ld_resp_o_t  ld_resp      ,
	output transact_o_t transact_o   ,
	input  transact_i_t transact_i   ,
	input  paddr_t      tail_ptr_addr
);
	typedef enum logic [2:0] {S_INVALID, S_SEND, S_RESP, S_CHECKPOINT, S_NEXT} state_t;

	ptr_t tail_ptr_r, tail_ptr_n;

	always_ff @(posedge clk) begin
		if (!rst_n) begin
			tail_ptr_r <= '0;
		end else begin
			tail_ptr_r <= tail_ptr_n;
		end
	end // always_ff @(posedge clk)

	always_comb begin
		tail_ptr_n = tail_ptr_r;
		if (transact_o.valid && transact_i.ready) begin
			if (tail_ptr_r == (fifo_length - 1)) begin
				tail_ptr_n = '0;
			end else begin
				tail_ptr_n = tail_ptr_r + 1'b1;
			end
		end
	end // always_comb

	// there is no state machine here
	// this is a case for a single entry mshr hub
	state_t state_d, state_q;
	size_t size_d, size_q;
	mshrid_t mshrid_q;
	addr_t addr_d, addr_q;
	data_t data_d, data_q;

	logic [$clog2(checkpoint_interval)-1: 0] trans_ctr_d, trans_ctr_q;

	assign addr_o.ready = state_q == S_INVALID;
	assign ld_req_o.valid = state_q == S_SEND;
	assign ld_req_o.addr = addr_q;
	assign ld_req_o.mshrid = mshrid_q;
	assign ld_req_o.size = size_q;
	// also write for a transaction
	assign transact_o.valid = state_q == S_NEXT || state_q == S_CHECKPOINT;
	//assign transact_o.size = size_q;
	//assign transact_o.addr = addr_q;
	assign transact_o.data = data_q;

	always_ff @(posedge clk) begin : proc_valid_d
		if(~rst_n) begin
			state_q <= S_INVALID;
			size_q <= '0;
			mshrid_q <= 8'd145;
			addr_q <= '0;
			data_q <= '0;
			trans_ctr_q <= '0;
		end else begin
			state_q <= state_d;
			size_q <= size_d;
			mshrid_q <= 8'd145;
			addr_q <= addr_d;
			data_q <= data_d;
			trans_ctr_q <= trans_ctr_d;
		end
	end

	always_comb begin
		addr_d = addr_q;
		state_d = state_q;
		size_d = size_q;
		data_d = data_q;
		trans_ctr_d = trans_ctr_q;
		// we can use generate statement here
		// we use generate for later anyway!
		unique case (state_q)
			S_INVALID: begin 
				if (addr_i.valid && addr_o.ready) begin 
					state_d = S_SEND;
					addr_d = addr_i.addr;
					size_d = addr_i.size;
				end
			end
			S_SEND: begin 
				if (ld_req_o.valid & ld_req_i.ready) begin 
					state_d = S_RESP;
				end
			end
			S_RESP: begin 
				if (ld_resp.valid && mshrid_q == ld_resp.mshrid) begin 
					state_d = S_NEXT;
					data_d = ld_resp.data;				
				end
			end
			S_NEXT: begin 
				if (transact_o.valid && transact_i.ready) begin 
					trans_ctr_d = trans_ctr_q + 1'b1;
					if (trans_ctr_q == '1) begin 
						size_d = 32'hdeadbeef;
						addr_d = tail_ptr_addr;
						data_d = tail_ptr_r;
						state_d = S_CHECKPOINT;
					end else begin
						state_d = S_INVALID;
					end
				end
			end
			S_CHECKPOINT: begin 
				if (transact_o.valid && transact_i.ready) begin
					state_d = S_INVALID;
				end
			end
		endcase
	end

endmodule : fifo_mshr_hub

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
module acc_dummy (
	input                       clk                  , // Clock
	input                       rst_n                , // Asynchronous reset active low
	input acc_pkg::acc_config_t acc_config           , // acclerator uncached configuration interface
	input logic [15:0]          serialization_ratio  ,
	input logic [15:0]          deserialization_ratio,
	input logic [13:0]          wait_cycles          ,
	decoupled_vr_if.slave       consumer_data        ,
	decoupled_vr_if.master      producer_data
);
	import fifo_ctrl_pkg::data_t;

`ifdef COHORT_ACC_AES
	aes_top i_aes_top (
		.clk          (clk          ),
		.rst_n        (rst_n        ),
		.acc_config   (acc_config   ),
		.consumer_data(consumer_data),
		.producer_data(producer_data)
	);
 `elsif COHORT_ACC_SHA
	sha256_custom_top sha256_custom_top_i (
		.clk			( clk			),
		.rst_n			( rst_n			),
		.acc_config  	( acc_config	),
		.consumer_data  ( consumer_data	),
		.producer_data	( producer_data	)
	);
`else
	logic [15:0] s_counter_r, s_counter_n;	
	logic [15:0] d_counter_r, d_counter_n;	
	logic [13:0] wait_counter_r, wait_counter_n;

	data_t data_r;
	data_t data_n;

	// to avoid trouble, I'll just do the sedes here without new modules
	// I hate deadlines
	// man this code was so beautiful before

	typedef enum logic [1:0] {S_IDLE, S_SERIALIZE, S_WAIT, S_DESERIALIZE} state_t;


	state_t state, state_next; 

	always_ff @(posedge clk) begin : proc_state
		if(~rst_n) begin
			state <= S_IDLE;
			s_counter_r <= '0;
			d_counter_r <= '0;
			data_r <= '0;
			wait_counter_r <= '0;
		end else begin
			state <= state_next;
			s_counter_r <= s_counter_n;
			d_counter_r <= d_counter_n;
			wait_counter_r <= wait_counter_n;
			data_r <= data_n;
		end
	end

	assign producer_data.data  = data_r;
	assign producer_data.valid = state == S_DESERIALIZE;
	assign consumer_data.ready = state == S_SERIALIZE;

	always_comb begin : proc_state_next
		state_next     = state;
		s_counter_n    = s_counter_r;
		d_counter_n    = d_counter_r;
		data_n         = data_r;
		wait_counter_n = wait_counter_r;
		unique case (state)
			S_IDLE : begin
				if (consumer_data.valid) begin
					state_next     = S_SERIALIZE;
					s_counter_n    = '0;
					d_counter_n    = '0;
					data_n         = '0;
					wait_counter_n = '0;
				end
			end
			S_SERIALIZE : begin
				if (consumer_data.ready & consumer_data.valid) begin
					s_counter_n = s_counter_r + 1;
					data_n      = consumer_data.data;
				end
				if (s_counter_n == serialization_ratio) begin
					state_next = S_WAIT;
				end
			end
			S_WAIT : begin
				wait_counter_n = wait_counter_r + 1;
				if (wait_counter_n == wait_cycles) begin
					state_next = S_DESERIALIZE;
				end
			end
			S_DESERIALIZE : begin
				if (producer_data.ready & producer_data.valid) begin
					d_counter_n = d_counter_r + 1;
				end
				if (d_counter_n == deserialization_ratio) begin
					state_next = S_IDLE;
				end

			end
		endcase
	end	


`endif

endmodule : acc_dummy

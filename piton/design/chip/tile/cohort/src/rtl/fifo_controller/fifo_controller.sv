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

// note that we should split the parameterization into producer data width and consumer data width
// this is to mitigate the case where the acc has different producer vs consumer data width
module fifo_controller (
	input                                 clk                  , // Clock
	input                                 rst_n                , // Asynchronous reset active low
	input  pmesh_pkg::pmesh_noc2_i_t      noc2_i               ,
	output pmesh_pkg::pmesh_noc2_o_t      noc2_o               ,
	input  pmesh_pkg::pmesh_noc3_in_t     noc3_in              ,
	input  acc_pkg::acc_config_t          acc_config           ,
	input  fifo_config_pkg::fifo_config_t consumer_config      ,
	input  fifo_config_pkg::fifo_config_t producer_config      ,
	input  logic [15:0]                   serialization_ratio  ,
	input  logic [15:0]                   deserialization_ratio,
	input  logic [13:0]                   wait_cycles,
	tri_if.master                         tri_bus              ,
	output fifo_ctrl_pkg::ptr_t           producer_tail_ptr_o  ,
	output fifo_ctrl_pkg::ptr_t           consumer_head_ptr_o
);


	decoupled_vr_if #(.DataWidth(fifo_ctrl_pkg::data_width)) consumer_data (
		.clk  (clk  ),
		.rst_n(rst_n)
	);
	
	decoupled_vr_if #(.DataWidth(fifo_ctrl_pkg::data_width)) producer_data (
		.clk  (clk  ),
		.rst_n(rst_n)
	);

	consumer_unit_top i_consumer_unit_top (
		.clk                 (clk                 ),
		.rst_n               (rst_n               ),
		.noc2_i              (noc2_i              ),
		.noc2_o              (noc2_o              ),
		.noc3_in             (noc3_in             ),
		.fifo_config_r       (consumer_config     ),
		.consumer_transaction(consumer_data.master),
		.consumer_head_ptr_o (consumer_head_ptr_o )
	);

	acc_dummy i_acc_dummy (
		.clk                  (clk                  ),
		.rst_n                (rst_n                ),
		.acc_config           (acc_config           ),
		.serialization_ratio  (serialization_ratio  ),
		.deserialization_ratio(deserialization_ratio),
		.wait_cycles          (wait_cycles),
		.consumer_data        (consumer_data.slave  ),
		.producer_data        (producer_data.master )
	);

	producer_unit_top i_producer_unit_top (
		.clk                (clk                 ),
		.rst_n              (rst_n               ),
		.fifo_config_r      (producer_config     ),
		.producer_data      (producer_data.slave),
		.tri_bus            (tri_bus             ),
		.producer_tail_ptr_o(producer_tail_ptr_o )
	);

endmodule

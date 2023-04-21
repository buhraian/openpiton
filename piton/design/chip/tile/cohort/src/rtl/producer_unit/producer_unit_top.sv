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

// top level of producer unit
// needs 3 interfaces: one to tri, one to decoupled data from acc, and
// one "uncached" that takes data from main bus
module producer_unit_top (
	input                                 clk                , // Clock
	input                                 rst_n              , // Asynchronous reset active low
	input  fifo_config_pkg::fifo_config_t fifo_config_r      ,
	decoupled_vr_if.slave                 producer_data      ,
	tri_if.master                         tri_bus            , // tri bus directly to l15, admittedly through an adapter
	output fifo_ctrl_pkg::ptr_t           producer_tail_ptr_o
);

	logic trans_ack;
	decoupled_vr_if producer_transaction(.clk(clk), .rst_n(rst_n));

	producer_transaction_generator i_producer_transaction_generator (
		.clk                 (clk                        ),
		.rst_n               (rst_n                      ),
		.fifo_config_r       (fifo_config_r              ),
		.trans_ack           (trans_ack                  ),
		.producer_transaction(producer_transaction.master),
		.producer_tail_ptr_o (producer_tail_ptr_o        )
	);


	producer_transaction_to_tri_adapter i_producer_transaction_to_tri_adapter (
		.clk          (clk                       ),
		.rst_n        (rst_n                     ),
		.fifo_config_r(fifo_config_r             ),
		.trans        (producer_transaction.slave),
		.acc_data     (producer_data             ),
		.trans_ack    (trans_ack                 ),
		.tri_intf     (tri_bus                   )
	);

endmodule : producer_unit_top
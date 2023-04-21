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

`include "assert_macros.svh"
module valid_ready_interface_asserts #(
	parameter DataWidth = -1,
	parameter ModuleName = "ThisName",
	parameter IsAssume = 1
)(
	input logic clk,    // Clock
	input logic rst_n,  // Asynchronous reset active low
	input logic valid,
	input logic ready,
	input logic [DataWidth-1: 0] data
);
generate
	if (IsAssume) begin
		assert_no_change_before_ready: `assert_clk_xrst(valid & !ready -> ##1 !$changed({valid, data}), {"assert data and valid should not chnage once valid if not readyed in", ModuleName})
	end
	else begin
		assume_no_change_before_ready: `assume_clk_xrst(valid & !ready -> ##1 !$changed({valid, data}), {"assume data and valid should not chnage once valid if not readyed in", ModuleName})
	end
endgenerate

genvar i;
generate
	for (int i = 0; i < 2; i++) begin
		`cover_clk_xrst(valid == i)
		`cover_clk_xrst(ready == i)
	end
endgenerate

endmodule : valid_ready_interface_asserts
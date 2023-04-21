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

module translator_unit_top (
	input clk,    // Clock
	input rst_n,
	tlb_if.master tlb_req,
	tri_if.slave tri_source,
	tri_if.master tri_sink,
	mem_req_if.slave pmesh_source,
	mem_req_if.master pmesh_sink
);

	tlb_if tlb_req_untranslated[1:0](
        .clk(clk),
        .rst_n(rst_n)
    );

	tri_translator_unit i_tri_translator_unit (
		.clk        (clk                    ),
		.rst_n      (rst_n                  ),
		.tri_req_vpn(tri_source             ),
		.tri_req_ppn(tri_sink               ),
		.tlb_req    (tlb_req_untranslated[0])
	);

	pmesh_translator_unit i_pmesh_translator_unit (
		.clk         (clk                    ),
		.rst_n       (rst_n                  ),
		.load_req_vpn(pmesh_source           ),
		.load_req_ppn(pmesh_sink             ),
		.tlb_req     (tlb_req_untranslated[1])
	);

	tlb_arbiter i_tlb_arbiter (
		.clk           (clk                 ),
		.rst_n         (rst_n               ),
		.tlb_req_source(tlb_req_untranslated),
		.tlb_req_sink  (tlb_req             )
	);

endmodule : translator_unit_top

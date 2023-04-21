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

module tb_cohort ();

    bit clk;
    bit rst_n;

    config_intf      conf(.clk(clk), .rst_n(rst_n))       ;
    mem_req_intf     load_req (.clk(clk), .rst_n(rst_n))   ;
    atomic_resp_intf atomic_resp(.clk(clk), .rst_n(rst_n)) ;


    task clk_gen ();
        forever begin
            clk <= 1'b0;
            #1;
            clk <= 1'b1;
            #1;
        end
    endtask : clk_gen

    task apply_rst_n();
        #100 rst_n <= 0;
        rst_n <= 1;
    endtask : apply_rst_n

    task apply_stimulus();
        // apply input at the posedge clk
        conf.transact(32'hdeadbeef, 3'h7, 4'h4);
        load_req.check_output(32'hdeadbeef);
        #10;
        $finish();
    endtask	

    initial begin
        clk_gen();
    end

    initial begin
        apply_rst_n();
        apply_stimulus();
    end

    initial begin
        load_req.initialize();
    end

    initial begin
        $fsdbDumpfile("tb_cohort.fsdb",50);
        $fsdbDumpvars(0, tb_cohort,"+all");
    end

    cohort_impl cohort_impl_inst(.*);

endmodule

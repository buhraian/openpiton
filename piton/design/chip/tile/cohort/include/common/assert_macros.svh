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
`ifndef ASSERT_MACROS
`define ASSERT_MACROS

//TODO: add lable
//TODO: add message replacement
//TODO: add default arguments instead of using clk and rst_n
//TODO: add combine into modules instead of large macros
//TODO: assume and assert flipping
// first 2 macros are from Clifford Cummings
`define assert_clk_xrst(prop, message) \
	assert property (@(posedge clk) disable iff (!rst_n) prop) \
		else $fatal(1, message);

`define assert_clk(prop, message) \
	assert property (@(posedge clk) prop) \
		else $fatal(1, message);

`define cover_clk_xrst(prop) \
	cover property (@(posedge clk) disable iff (!rst_n) prop);


`define cover_clk(prop) \
	cover property (@(posedge clk) prop);


`define assume_clk_xrst(prop, message) \
	assume property (@(posedge clk) disable iff (!rst_n) prop) \
		else $fatal(1, message);

`define assume_clk(prop, message) \
	assume property (@(posedge clk) prop) \
		else $fatal(1, message);

`define assert_hold_valid(valid, ready, data, message) \
	`assert_clk_xrst( valid && !ready |-> ##1 (valid && !$changed(data)), message)

`define assert_finish_handshake(valid, ready, data, message) \
	`assert_clk_xrst(valid && ready |-> ##1 (!valid || $changed(data)), message)

`define fpv_ready_valid_if(valid, ready, data) \
	`assert_hold_valid( valid, ready, data, "valid shouldn't change when waiting for ready") \
	`assert_finish_handshake( valid, ready, data, "valid should clear or data should change after handshake") \
	`cover_clk_xrst($rose(valid)) \
	`cover_clk_xrst($fell(valid))

// waiter waits for waitee to go high, then it goes high at the same cycle
// there isn't much to describe here because there's no cover statement ( should assert indenpendently)
`define fpv_wait_for_high(waiter, waitee) \
	`assert_clk_xrst(waiter |-> waitee, "waiter should not be high when the signal being waited is low")

// the relationship here is that
// 1. ack is high first
// 2. valid is high after ack is high, ack keeps high
// 3. when valid, ack and header_ack is all high, do a handshake, then all drop to low
// 4. all other should remain the same, and presumably valid should still remain low
// 5. until ack goes high, then we can assert again
`define fpv_ack_header_if(valid, header_ack, ack, data) \
	`fpv_wait_for_high(header_ack, valid) \
	`fpv_wait_for_high(valid, ack) \
	`assume_clk_xrst(valid && ack |-> ##1 ack, "ack doesn't change when it's waiting for header_ack with valid") \
	`fpv_ready_valid_if(valid, header_ack, data) \
	`assert_hold_valid(valid, ack, data, "valid should hold for ack") \
	`assert_clk_xrst(valid && header_ack |-> ##1 (!valid && !$changed(data) && !header_ack && !ack) s_until ack, "valid should lower after handshake") \
	`cover_clk_xrst($rose(valid)) \
	`cover_clk_xrst($fell(valid)) \
	`assert_clk_xrst(!valid ##1 valid |-> (##[0:$] header_ack ##[1:$] ack) and (!ack until header_ack ##1 !header_ack), "header ack must appear before ack")

// this is a valid->ack sequence
// 1. valid should be high first, and possibly wait for ack
// 2. valid and data should hold, until ack is high
// 3. valid will hold
`define fpv_valid_ack_if(valid, ack, data) \
	`assert_clk_xrst(!valid |-> !ack, "should not ack if not valid") \
	`assert_hold_valid(valid, ack, data, "ack should hold with valid") \
	`assert_clk_xrst(valid & ack |-> ##1 !ack & !valid, "should lower everything after handshake")


// cover state transition and assert the state transition at the same time
`define fpv_state_transition (state_r, state_0, state_1, trigger, assert_message, cover_message) \
	`assert_clk_xrst( trigger |-> state_r == state_0 ##1 state_r == state_1, assert_message) \
	`cover_clk_xrst( state_r == state_0 ##1 state_r == state_1)

`define fpv_no_state_transition(state_r, state_0, state_1) \
	`assert_clk_xrst(state_r == state_0 |-> ##1 state_r != state_1, "state_r shouldn't transit from 0 to 1")



`endif

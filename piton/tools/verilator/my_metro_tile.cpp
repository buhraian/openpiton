/*
Copyright (c) 2019 Princeton University
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Princeton University nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY PRINCETON UNIVERSITY "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL PRINCETON UNIVERSITY BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#include "Vmetro_tile.h"
#include "verilated.h"
#include <iostream>
//#define VERILATOR_VCD 1 
#ifdef VERILATOR_VCD
#include "verilated_vcd_c.h"
#endif
#include <iomanip>

const int YUMMY_NOC_1 = 0;
const int DATA_NOC_1  = 1;
const int YUMMY_NOC_2 = 2;
const int DATA_NOC_2  = 3;
const int YUMMY_NOC_3 = 4;
const int DATA_NOC_3  = 5;

// Compilation flags parameters
const int PITON_X_TILES = X_TILES;
const int PITON_Y_TILES = Y_TILES;

uint64_t main_time = 0; // Current simulation time
uint64_t clk = 0;
Vmetro_tile* top;
int rank, dest, size;
int rankN, rankS, rankW, rankE;
int tile_x, tile_y;//, PITON_X_TILES, PITON_Y_TILES;

void initialize();

// MPI Yummy functions
unsigned short mpi_receive_yummy(int origin, int flag);

void mpi_send_yummy(unsigned short message, int dest, int rank, int flag);
// MPI data&Valid functions
void mpi_send_data(unsigned long long data, unsigned char valid, int dest, int rank, int flag);

unsigned long long mpi_receive_data(int origin, unsigned short* valid, int flag);
int getRank();

int getSize();

void finalize();

#ifdef VERILATOR_VCD
VerilatedVcdC* tfp;
#endif
// This is a 64-bit integer to reduce wrap over issues and
// // allow modulus. You can also use a double, if you wish.
double sc_time_stamp () { // Called by $time in Verilog
    return main_time; // converts to double, to match
    // what SystemC does
}

int get_rank_fromXY(int x, int y) {
    return 1 + ((x)+((PITON_X_TILES)*y));
}

// MPI ID funcitons
int getDimX () {
    if (rank==0) // Should never happen
        return 0;
    else
        return (rank-1)%PITON_X_TILES;
}

int getDimY () {
    if (rank==0) // Should never happen
        return 0;
    else
        return (rank-1)/PITON_X_TILES;
}

int getRankN () {
    if (tile_y == 0)
        return -1;
    else
        return get_rank_fromXY(tile_x, tile_y-1);
}

int getRankS () {
    if (tile_y+1 == PITON_Y_TILES)
        return -1;
    else
        return get_rank_fromXY(tile_x, tile_y+1);
}

int getRankE () {
    if (tile_x+1 == PITON_X_TILES)
        return -1;
    else
        return get_rank_fromXY(tile_x+1, tile_y);
}

int getRankW () {
    if (rank==1) { // go to chipset
        return 0;
    }
    else if (tile_x == 0) {
        return -1;
    }
    else {
        return get_rank_fromXY(tile_x-1, tile_y);
    }
}

void tick() {
    top->core_ref_clk = !top->core_ref_clk;
    main_time += 250;
    top->eval();
#ifdef VERILATOR_VCD
    tfp->dump(main_time);
#endif
    top->core_ref_clk = !top->core_ref_clk;
    main_time += 250;
    top->eval();
#ifdef VERILATOR_VCD
    tfp->dump(main_time);
#endif
}
void mpi_work_N() {

    // send data
    mpi_send_data(top->out_N_noc1_data, top->out_N_noc1_valid, rankN, rank, DATA_NOC_1);
    // send yummy
    mpi_send_yummy(top->out_N_noc1_yummy, rankN, rank, YUMMY_NOC_1);

    // send data
    mpi_send_data(top->out_N_noc2_data, top->out_N_noc2_valid, rankN, rank, DATA_NOC_2);
    // send yummy
    mpi_send_yummy(top->out_N_noc2_yummy, rankN, rank, YUMMY_NOC_2);

    // send data
    mpi_send_data(top->out_N_noc3_data, top->out_N_noc3_valid, rankN, rank, DATA_NOC_3);
    // send yummy
    mpi_send_yummy(top->out_N_noc3_yummy, rankN, rank, YUMMY_NOC_3);

    // receive data
    unsigned short valid_aux;
    top->in_N_noc1_data = mpi_receive_data(rankN, &valid_aux, DATA_NOC_1);
    top->in_N_noc1_valid = valid_aux;
    // receive yummy
    top->in_N_noc1_yummy = mpi_receive_yummy(rankN, YUMMY_NOC_1);
    
    top->in_N_noc2_data = mpi_receive_data(rankN, &valid_aux, DATA_NOC_2);
    top->in_N_noc2_valid = valid_aux;
    // receive yummy
    top->in_N_noc2_yummy = mpi_receive_yummy(rankN, YUMMY_NOC_2);

    top->in_N_noc3_data = mpi_receive_data(rankN, &valid_aux, DATA_NOC_3);
    top->in_N_noc3_valid = valid_aux;
    // receive yummy
    top->in_N_noc3_yummy = mpi_receive_yummy(rankN, YUMMY_NOC_3);
}

void mpi_work_S() {

    // send data
    mpi_send_data(top->out_S_noc1_data, top->out_S_noc1_valid, rankS, rank, DATA_NOC_1);
    // send yummy
    mpi_send_yummy(top->out_S_noc1_yummy, rankS, rank, YUMMY_NOC_1);

    // send data
    mpi_send_data(top->out_S_noc2_data, top->out_S_noc2_valid, rankS, rank, DATA_NOC_2);
    // send yummy
    mpi_send_yummy(top->out_S_noc2_yummy, rankS, rank, YUMMY_NOC_2);

    // send data
    mpi_send_data(top->out_S_noc3_data, top->out_S_noc3_valid, rankS, rank, DATA_NOC_3);
    // send yummy
    mpi_send_yummy(top->out_S_noc3_yummy, rankS, rank, YUMMY_NOC_3);

    // receive data
    unsigned short valid_aux;
    top->in_S_noc1_data = mpi_receive_data(rankS, &valid_aux, DATA_NOC_1);
    top->in_S_noc1_valid = valid_aux;
    // receive yummy
    top->in_S_noc1_yummy = mpi_receive_yummy(rankS, YUMMY_NOC_1);
    
    top->in_S_noc2_data = mpi_receive_data(rankS, &valid_aux, DATA_NOC_2);
    top->in_S_noc2_valid = valid_aux;
    // receive yummy
    top->in_S_noc2_yummy = mpi_receive_yummy(rankS, YUMMY_NOC_2);

    top->in_S_noc3_data = mpi_receive_data(rankS, &valid_aux, DATA_NOC_3);
    top->in_S_noc3_valid = valid_aux;
    // receive yummy
    top->in_S_noc3_yummy = mpi_receive_yummy(rankS, YUMMY_NOC_3);
}

void mpi_work_E() {

    // send data
    mpi_send_data(top->out_E_noc1_data, top->out_E_noc1_valid, rankE, rank, DATA_NOC_1);
    // send yummy
    mpi_send_yummy(top->out_E_noc1_yummy, rankE, rank, YUMMY_NOC_1);

    // send data
    mpi_send_data(top->out_E_noc2_data, top->out_E_noc2_valid, rankE, rank, DATA_NOC_2);
    // send yummy
    mpi_send_yummy(top->out_E_noc2_yummy, rankE, rank, YUMMY_NOC_2);

    // send data
    mpi_send_data(top->out_E_noc3_data, top->out_E_noc3_valid, rankE, rank, DATA_NOC_3);
    // send yummy
    mpi_send_yummy(top->out_E_noc3_yummy, rankE, rank, YUMMY_NOC_3);

    // receive data
    unsigned short valid_aux;
    top->in_E_noc1_data = mpi_receive_data(rankE, &valid_aux, DATA_NOC_1);
    top->in_E_noc1_valid = valid_aux;
    // receive yummy
    top->in_E_noc1_yummy = mpi_receive_yummy(rankE, YUMMY_NOC_1);
    
    top->in_E_noc2_data = mpi_receive_data(rankE, &valid_aux, DATA_NOC_2);
    top->in_E_noc2_valid = valid_aux;
    // receive yummy
    top->in_E_noc2_yummy = mpi_receive_yummy(rankE, YUMMY_NOC_2);

    top->in_E_noc3_data = mpi_receive_data(rankE, &valid_aux, DATA_NOC_3);
    top->in_E_noc3_valid = valid_aux;
    // receive yummy
    top->in_E_noc3_yummy = mpi_receive_yummy(rankE, YUMMY_NOC_3);
}

void mpi_work_W() {

    // send data
    mpi_send_data(top->out_W_noc1_data, top->out_W_noc1_valid, rankW, rank, DATA_NOC_1);
    // send yummy
    mpi_send_yummy(top->out_W_noc1_yummy, rankW, rank, YUMMY_NOC_1);

    // send data
    mpi_send_data(top->out_W_noc2_data, top->out_W_noc2_valid, rankW, rank, DATA_NOC_2);
    // send yummy
    mpi_send_yummy(top->out_W_noc2_yummy, rankW, rank, YUMMY_NOC_2);

    // send data
    mpi_send_data(top->out_W_noc3_data, top->out_W_noc3_valid, rankW, rank, DATA_NOC_3);
    // send yummy
    mpi_send_yummy(top->out_W_noc3_yummy, rankW, rank, YUMMY_NOC_3);

    // receive data
    unsigned short valid_aux;
    top->in_W_noc1_data = mpi_receive_data(rankW, &valid_aux, DATA_NOC_1);
    top->in_W_noc1_valid = valid_aux;
    // receive yummy
    top->in_W_noc1_yummy = mpi_receive_yummy(rankW, YUMMY_NOC_1);
    
    top->in_W_noc2_data = mpi_receive_data(rankW, &valid_aux, DATA_NOC_2);
    top->in_W_noc2_valid = valid_aux;
    // receive yummy
    top->in_W_noc2_yummy = mpi_receive_yummy(rankW, YUMMY_NOC_2);

    top->in_W_noc3_data = mpi_receive_data(rankW, &valid_aux, DATA_NOC_3);
    top->in_W_noc3_valid = valid_aux;
    // receive yummy
    top->in_W_noc3_yummy = mpi_receive_yummy(rankW, YUMMY_NOC_3);
}


void mpi_tick() {
    top->core_ref_clk = !top->core_ref_clk;
    main_time += 250;
    top->eval();
    
    // Do MPI
    if (rankN != -1) mpi_work_N();
    if (rankS != -1) mpi_work_S();
    if (rankE != -1) mpi_work_E();
    if (rankW != -1) mpi_work_W();
    
    top->eval();
#ifdef VERILATOR_VCD
    tfp->dump(main_time);
#endif
    top->core_ref_clk = !top->core_ref_clk;
    main_time += 250;
    top->eval();
#ifdef VERILATOR_VCD
    tfp->dump(main_time);
#endif
}



void reset_and_init() {
    
//    fail_flag = 1'b0;
//    stub_done = 4'b0;
//    stub_pass = 4'b0;

//    // Clocks initial value
    top->core_ref_clk = 0;

//    // Resets are held low at start of boot
    top->sys_rst_n = 0;
    top->pll_rst_n = 0;

    top->ok_iob = 0;

//    // Mostly DC signals set at start of boot
//    clk_en = 1'b0;
    top->pll_bypass = 1; // trin: pll_bypass is a switch in the pll; not reliable
    top->clk_mux_sel = 0; // selecting ref clock
//    // rangeA = x10 ? 5'b1 : x5 ? 5'b11110 : x2 ? 5'b10100 : x1 ? 5'b10010 : x20 ? 5'b0 : 5'b1;
    top->pll_rangea = 1; // 10x ref clock
//    // pll_rangea = 5'b11110; // 5x ref clock
//    // pll_rangea = 5'b00000; // 20x ref clock
    
//    // JTAG simulation currently not supported here
//    jtag_modesel = 1'b1;
//    jtag_datain = 1'b0;

    top->async_mux = 0;

    top->in_N_noc1_data  = 0;
    top->in_E_noc1_data  = 0;
    top->in_W_noc1_data  = 0;
    top->in_S_noc1_data  = 0;
    top->in_N_noc1_valid = 0;
    top->in_E_noc1_valid = 0;
    top->in_W_noc1_valid = 0;
    top->in_S_noc1_valid = 0;
    top->in_N_noc1_yummy = 0;
    top->in_E_noc1_yummy = 0;
    top->in_W_noc1_yummy = 0;
    top->in_S_noc1_yummy = 0;

    top->in_N_noc2_data  = 0;
    top->in_E_noc2_data  = 0;
    top->in_W_noc2_data  = 0;
    top->in_S_noc2_data  = 0;
    top->in_N_noc2_valid = 0;
    top->in_E_noc2_valid = 0;
    top->in_W_noc2_valid = 0;
    top->in_S_noc2_valid = 0;
    top->in_N_noc2_yummy = 0;
    top->in_E_noc2_yummy = 0;
    top->in_W_noc2_yummy = 0;
    top->in_S_noc2_yummy = 0;

    top->in_N_noc3_data  = 0;
    top->in_E_noc3_data  = 0;
    top->in_W_noc3_data  = 0;
    top->in_S_noc3_data  = 0;
    top->in_N_noc3_valid = 0;
    top->in_E_noc3_valid = 0;
    top->in_W_noc3_valid = 0;
    top->in_S_noc3_valid = 0;
    top->in_N_noc3_yummy = 0;
    top->in_E_noc3_yummy = 0;
    top->in_W_noc3_yummy = 0;
    top->in_S_noc3_yummy = 0;

    //init_jbus_model_call((char *) "mem.image", 0);

    std::cout << "Before first ticks" << std::endl << std::flush;
    tick();
    std::cout << "After very first tick" << std::endl << std::flush;
//    // Reset PLL for 100 cycles
//    repeat(100)@(posedge core_ref_clk);
//    pll_rst_n = 1'b1;
    for (int i = 0; i < 100; i++) {
        tick();
    }
    top->pll_rst_n = 1;

    std::cout << "Before second ticks" << std::endl << std::flush;
    //    // Wait for PLL lock
    //    wait( pll_lock == 1'b1 );
    //    while (!top->pll_lock) {
    //        tick();
    //    }

    std::cout << "Before third ticks" << std::endl << std::flush;
//    // After 10 cycles turn on chip-level clock enable
//    repeat(10)@(posedge `CHIP_INT_CLK);
//    clk_en = 1'b1;
    for (int i = 0; i < 10; i++) {
        tick();
    }
    top->clk_en = 1;

//    // After 100 cycles release reset
//    repeat(100)@(posedge `CHIP_INT_CLK);
//    sys_rst_n = 1'b1;
//    jtag_rst_l = 1'b1;
    for (int i = 0; i < 100; i++) {
        tick();
    }
    top->sys_rst_n = 1;

//    // Wait for SRAM init, trin: 5000 cycles is about the lowest
//    repeat(5000)@(posedge `CHIP_INT_CLK);
    for (int i = 0; i < 5000; i++) {
        tick();
    }

//    top->diag_done = 1;

    //top->ciop_fake_iob.ok_iob = 1;
    top->ok_iob = 1;
    std::cout << "Reset complete" << std::endl << std::flush;
}

int main(int argc, char **argv, char **env) {
    std::cout << "Started" << std::endl << std::flush;
    Verilated::commandArgs(argc, argv);
    //if (argc != 2) {
    //    std::cerr << "Usage ./VMetro_tile num_tiles_x num_tiles_y"
    //}
    top = new Vmetro_tile;
    std::cout << "Vmetro_tile created" << std::endl << std::flush;

#ifdef VERILATOR_VCD
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace (tfp, 99);
    tfp->open ("my_metro_tile.vcd");

    Verilated::debug(1);
#endif

    // MPI work 
    initialize();
    rank = getRank();
    size = getSize();
    std::cout << "TILE size: " << size << ", rank: " << rank <<  std::endl;
    if (rank==0) {
        dest = 1;
    } else {
        dest = 0;
    }
    tile_x = getDimX();
    tile_y = getDimY();
    rankN  = getRankN();
    rankS  = getRankS();
    rankW  = getRankW();
    rankE  = getRankE();

    std::cout << "tile_y: " << tile_y << std::endl;
    std::cout << "tile_x: " << tile_x << std::endl;
    std::cout << "rankN: " << rankN << std::endl;
    std::cout << "rankS: " << rankS << std::endl;
    std::cout << "rankW: " << rankW << std::endl;
    std::cout << "rankE: " << rankE << std::endl;

    top->default_chipid = 0;
    top->default_coreid_x = tile_x;
    top->default_coreid_y = tile_y;
    top->flat_tileid = rank-1;

    reset_and_init();

    /*hile (!Verilated::gotFinish()) { 
        mpi_tick();
    }*/

    for (int i = 0; i < 350000; i++) {
        if (i %10000 == 0) {
            std::cout << "######TIME######" << i << std::endl;
        }
        mpi_tick();
    }
    std::cout << std::setprecision(10) << sc_time_stamp() << std::endl;
    /*while (!Verilated::gotFinish()) { 
        mpi_tick();
    }*/

    #ifdef VERILATOR_VCD
    std::cout << "Trace done" << std::endl;
    tfp->close();
    #endif

    finalize();

    delete top;
    exit(0);
}
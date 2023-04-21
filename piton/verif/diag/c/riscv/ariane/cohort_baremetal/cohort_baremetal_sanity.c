#include <stdio.h>
#include "util.h"
#include "cohort_fifo.h"

#define NUM_WORDS 16
static uint32_t Dp[2] = {0x000000FF,0x000000AA};
static uint32_t Ap[NUM_WORDS] = {0x33221100,
                                                 0x77665544,
                                                 0xBBAA9988,
                                                 0xFFEEDDCC,
                                                 0x11111111,
                                                 0x22222222,
                                                 0x33333333,
                                                 0x44444444,
                                                 0x55555555,
                                                 0x66666666,
                                                 0x77777777,
                                                 0x88888888,
                                                 0x99999999,
                                                 0xAAAAAAAA,
                                                 0xBBBBBBBB,
                                                 0xCCCCCCCC};


#ifndef NUM_A
    #define NUM_A 1
#endif

void _kernel_(uint32_t id, uint32_t core_num){
}

int main(int argc, char ** argv) {
    volatile static uint32_t amo_cnt = 0;
    uint32_t id, core_num;
#ifdef BARE_METAL
    id = argv[0][0];
    core_num = argv[0][1];
#else
    id = 0;
    core_num = 1;
#endif
    // only make the first ariane initialize the tile
    if (id == 0) init_tile(NUM_A);

#ifdef BARE_METAL
    cohort_set_tlb(0x80004, 0x80004);
    cohort_set_tlb(0x80005, 0x80005);
#endif
    
    // 32 bits elements, fifo length = 8
    fifo_ctrl_t *sw_to_cohort_fifo = fifo_init( 16, 64, 0);
    fifo_ctrl_t *cohort_to_sw_fifo = fifo_init( 16, 64, 1);
    void *acc_address = memalign(128, 128);
    memset(acc_address, 0, 128);

    baremetal_write(0, 6, (uint64_t) acc_address);

    cohort_on();

    uint64_t write_val = 11;
    write_val |= 0x800000400000000;
    
    sw_to_cohort_fifo->fifo_push_func(0x1, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x2, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x3, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x4, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x5, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x6, sw_to_cohort_fifo);
    sw_to_cohort_fifo->fifo_push_func(0x7, sw_to_cohort_fifo);


    uint64_t ret;
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    ret = cohort_to_sw_fifo->fifo_pop_func(cohort_to_sw_fifo);
    printf("%lx\n", ret);


    cohort_off();
    fifo_deinit(sw_to_cohort_fifo);
    fifo_deinit(cohort_to_sw_fifo);
    free(acc_address);

#ifdef BARE_METAL
    if (ret == 7) {
        pass();
    } else {
        fail();
    }
#endif
    return 0;
}

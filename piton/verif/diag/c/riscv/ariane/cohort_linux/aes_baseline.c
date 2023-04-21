#include <stdio.h>
#include "util.h"
#include "cohort.h"
#ifndef PRODUCER_FIFO_LENGTH 
#define PRODUCER_FIFO_LENGTH 32
#endif

#ifndef CONSUMER_FIFO_LENGTH 
#define CONSUMER_FIFO_LENGTH 32
#endif

#ifndef WAIT_COUNTER_VAL 
#define WAIT_COUNTER_VAL 1024
#endif

#ifndef SERIALIZATION_VAL
#define SERIALIZATION_VAL 1
#endif

#ifndef DESERIALIZATION_VAL
#define DESERIALIZATION_VAL 1
#endif

#ifndef BACKOFF_COUNTER_VAL
#define BACKOFF_COUNTER_VAL 0x800
#endif

#define NUM_WORDS 16
static uint64_t A,D;
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
    #define NUM_A 2
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
    core_num = 2;
#endif
    // only make the first ariane initialize the tile
    if (id == 0) init_tile(NUM_A);


    uint64_t ret;
	cohort_t *cohort_0 = cohort_init(0, 32, 64);

//	dec_open_producer(0);
//	dec_open_consumer(0);

	for (int i = 0; i < 8; i++) {
		for (int j = 0; j < 16; j++) {
			cohort_0->push(j, cohort_0);
		}
			cohort_push_sync(cohort_0);
			cohort_pop_sync(cohort_0);
		for (int j = 0; j < 16; j++) {
			cohort_0->pop(cohort_0);
		}

	}
//	dec_close_producer(0);
//	dec_close_consumer(0);
//	print_stats_fifos(1);

	cohort_deinit(cohort_0);
    return 0;
}

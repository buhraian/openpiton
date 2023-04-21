#ifndef COHORT_FIFO_PARAM_H
#define COHORT_FIFO_PARAM_H

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <malloc.h>
#include <string.h>
#include <stdbool.h>
#include "dcpn.h"
#ifndef BARE_METAL
#include <fcntl.h>
#include <unistd.h>
#endif

#ifdef PRI
#define PRINTBT printf("%s\n", __func__);
//#define PRI_DEBUG
#else
#define PRINTBT 
#endif

static uint64_t back_off_count = 0;
typedef uint64_t addr_t; // though we only use the lower 32 bits
typedef uint32_t len_t; // length of fifo
typedef len_t ptr_t;
typedef uint32_t el_size_t; // element size width

struct _fifo_ctrl_t;

typedef struct _fifo_ctrl_t fifo_ctrl_t;

/*
 * generic type for fifo_push functions and pop functions
 * actual memory operation size depends on the configured fifo size
 * always wrap in 64 bits
 */
typedef void (*fifo_push_func_t)(uint64_t element, fifo_ctrl_t* fifo_ctrl);
typedef uint64_t (*fifo_pop_func_t)(fifo_ctrl_t* fifo_ctrl);


typedef struct __attribute__((__packed__)) {
    addr_t addr;
    el_size_t size;
    len_t len;
} meta_t;

struct _fifo_ctrl_t {
    uint32_t fifo_length;
    uint32_t element_size;
    volatile ptr_t* head_ptr;
    volatile ptr_t* tail_ptr;
    volatile meta_t* meta_ptr;
    volatile void* data_array;
    
};


void fifo_push_64(uint64_t element, fifo_ctrl_t* fifo_ctrl, uint32_t idx);
uint64_t fifo_pop_64 (fifo_ctrl_t* fifo_ctrl, uint32_t idx);

uint16_t clog2(uint16_t el);

//TODO: 128 bits are not supported, see https://github.com/rust-lang/rust/issues/54341

void fifo_start(fifo_ctrl_t *fifo_ctrl, bool is_consumer, uint8_t c_id);

/**
 *@fifo_length: the length of the fifo, in bytes
 *@element_size: the size of each element in fifo, in bytes
 *@is_consumer: if it's true, then it is a consumer; otherwise it's a producer. It's used to calculate uncached_write offset. The software producer thread produces into 0-2, the other produces to 3-5
 */
fifo_ctrl_t *fifo_init(uint32_t fifo_length, uint16_t element_size, bool is_consumer, uint8_t c_id)
{
    PRINTBT
    // 128 is the cache line width of openpiton
    fifo_ctrl_t *fifo_ctrl = (fifo_ctrl_t *) malloc(sizeof(fifo_ctrl_t));

    fifo_ctrl->head_ptr =   memalign(128, 128);
    fifo_ctrl->meta_ptr =   memalign(128, 128);
    fifo_ctrl->tail_ptr =   memalign(128, 128);
    fifo_ctrl->data_array = memalign(128, sizeof(uint64_t) * fifo_length);

#ifdef PRI
    printf("fhead %lx\n", fifo_ctrl->head_ptr);
    printf("fmeta %lx\n", fifo_ctrl->meta_ptr);
    printf("ftail %lx\n", fifo_ctrl->tail_ptr);
    printf("fdata %lx\n", fifo_ctrl->data_array);
#endif

    fifo_ctrl->fifo_length = fifo_length;
    fifo_ctrl->element_size = (element_size / 8);

    
    fifo_start(fifo_ctrl, is_consumer, c_id);

    //TODO: use generic push/pop here
    return fifo_ctrl;
}

void fifo_start(fifo_ctrl_t *fifo_ctrl, bool is_consumer, uint8_t c_id)
{
    PRINTBT
    *(fifo_ctrl->tail_ptr) = 0x00000000ULL;
    *(fifo_ctrl->head_ptr) = 0x00000000ULL;
    fifo_ctrl->meta_ptr->addr = (uint64_t) fifo_ctrl->data_array;
    fifo_ctrl->meta_ptr->len = fifo_ctrl->fifo_length;
    fifo_ctrl->meta_ptr->size = fifo_ctrl->element_size;
    memset(fifo_ctrl->data_array, 0, sizeof(uint64_t) * fifo_ctrl->fifo_length);
    if (is_consumer) {
        cohort_ni_write(c_id, 3,( uint64_t )fifo_ctrl->head_ptr);
        cohort_ni_write(c_id, 4,( uint64_t )fifo_ctrl->meta_ptr);
        cohort_ni_write(c_id, 5,( uint64_t )fifo_ctrl->tail_ptr);
    } else {
        cohort_ni_write(c_id, 0,( uint64_t ) fifo_ctrl->tail_ptr);
        cohort_ni_write(c_id, 1,( uint64_t ) fifo_ctrl->meta_ptr);
        cohort_ni_write(c_id, 2,( uint64_t ) fifo_ctrl->head_ptr);
    }
}



ptr_t private_get_tail(fifo_ctrl_t *fifo_ctrl)
{
    return  *((ptr_t *)(fifo_ctrl->tail_ptr));
}

ptr_t private_get_head(fifo_ctrl_t *fifo_ctrl)
{
    return *((ptr_t *)(fifo_ctrl->head_ptr));
}


/**
 *@return: 0 if not empty, 1 if empty
 **/
int fifo_is_empty(fifo_ctrl_t* fifo_ctrl)
{
 #ifdef PRI
    printf("%s: the head ptr is %lx\n", __func__, private_get_head(fifo_ctrl));
    printf("%s: the tail ptr is %lx\n", __func__, private_get_tail(fifo_ctrl));
#endif
   return private_get_tail(fifo_ctrl) == private_get_head(fifo_ctrl);
}

addr_t fifo_get_base(fifo_ctrl_t fifo_ctrl)
{
    PRINTBT
    return (uint64_t) fifo_ctrl.data_array;
}






void fifo_deinit(fifo_ctrl_t *fifo_ctrl)
{
    PRINTBT
    // first free the large data array
    free(fifo_ctrl->data_array);

    // then free 3 cachelines
    free(fifo_ctrl->head_ptr);
    free(fifo_ctrl->tail_ptr);
    free(fifo_ctrl->meta_ptr);

    // at long last free the fifo pointer
    free(fifo_ctrl);
}


// philosophy: don't chunk requests in software for better transparency
// as 128 bits aren't supported, 64 would suffice
//
//
void fifo_push_64(uint64_t element, fifo_ctrl_t* fifo_ctrl, uint32_t pos)
{
    PRINTBT
    // loop whilie the fifo is full
#ifdef PRI
    if (fifo_is_full(fifo_ctrl)) {
        sleep(1);
        printf("fifo is full\n");
        return;
    }
#else
	//while (fifo_is_full(fifo_ctrl));
#endif
    *((volatile uint64_t *)((volatile uint64_t *) fifo_ctrl->data_array) + (pos)) = (volatile uint64_t) element;
}

volatile uint64_t fifo_pop_64(fifo_ctrl_t *fifo_ctrl, uint32_t pos)
{
    PRINTBT
#ifdef PRI
    if (fifo_is_empty(fifo_ctrl)) {
        sleep(1);
        printf("fifo is empty\n");
        return 0xdeadbeef;
    }
#else
    while ((*((volatile uint64_t *)fifo_ctrl->tail_ptr))<= pos){
        for (int i=0; i< LOOP_NUM;i++, back_off_count++);
    }
#endif
    uint64_t element = *((volatile uint64_t *)(((volatile uint64_t *) fifo_ctrl->data_array) + pos ));
    return element;
}

void fifo_dump(fifo_ctrl_t *fifo_ctrl)
{    
	printf("fifo length: %d\n", fifo_ctrl->fifo_length);
//	for (int pos = 0; pos < fifo_ctrl->fifo_length; pos++) {
//	uint64_t element = *((volatile uint64_t *)(((volatile uint64_t *) fifo_ctrl->data_array) + pos * 2 ));
//    printf("dump %d, %llx\n", pos, element);
//	}

}


void fifo_push_sync(fifo_ctrl_t* fifo_ctrl, uint32_t pos)
{
    __sync_synchronize();
	*(fifo_ctrl->tail_ptr) = pos;
    __sync_synchronize();
}

void fifo_pop_sync(fifo_ctrl_t* fifo_ctrl, uint32_t pos)
{
    __sync_synchronize();
	*(fifo_ctrl->head_ptr) = pos;
    __sync_synchronize();
}

// note that we cannot operate at sub-byte level in c
// this is not how c works
// note also that el is bits
// we need a byte clog2

uint16_t clog2(uint16_t bitswidth)
{
    uint16_t el = bitswidth / 8;
    switch (el) {
        case 8:
            return 3;
        case 4:
            return 2;
        case 2:
            return 1;
        case 1:
            return 0;
    }
}



#endif // COHORT_FIFO_PARAM_H

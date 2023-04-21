#include <stdint.h>

#define QUEUE_SIZE 128
#define MAX_QUEUES 256

#define DEC_DEBUG 1 // Do some runtime checks, but potentially slows

uint32_t dec_fifo_init(uint32_t count, uint32_t size);
uint32_t dec_fifo_cleanup();
uint64_t dec_fifo_stats(uint64_t qid, uint32_t stat, uint32_t* result);
void dec_produce32(uint64_t qid, uint32_t data);
void dec_produce64(uint64_t qid, uint64_t data);
uint32_t dec_consume32(uint64_t qid);
uint64_t dec_consume64(uint64_t qid);

// Async Loads
void dec_load32_async(uint64_t qid, uint32_t *addr);
void dec_load64_async(uint64_t qid, uint64_t *addr);

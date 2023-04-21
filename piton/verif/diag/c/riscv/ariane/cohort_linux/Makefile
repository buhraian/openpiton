GCC=riscv64-buildroot-linux-gnu-gcc

DEBUG ?= 0
COHERENT ?= 0

ifeq ($(DEBUG), 0) # running in benchmark modes
	GCC_OPTS := -O3
else
	GCC_OPTS := -O0 -gdwarf-4 -ggdb -g3
endif

ifeq ($(COHERENT), 0)
	GCC_OPTS += -DCOHERENT=0
else
	GCC_OPTS += -DCOHERENT=1
endif

#SRC = dma.c cohort_aes_base.c dma-aes.c dcpn-aes.c cohort_sha_base.c new_aes.c
#SRC = dma.c    new_aes.c
#SRC =  stress.c dma-aes.c dma_aes.c dcpn_aes.c aes_baseline.c sha_baseline.c
SRC = cohort_aes_base.c dcpn_aes.c dma_aes.c
#EXECUTABLE := $(patsubst %.c,%,$(SRC))
EXECUTABLE := $(patsubst %.c,%,$(SRC))

# NUMBERS = 1536 # for H264
# NUMBERS = 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072
NUMBERS = 64 128 256 512 1024 
ITERS = 1 
# BATCH_SIZES= 4 # for H264
BATCH_SIZES= 8 16 32 64 # put 4 for aes as well

BACKOFF_NUM = 240
# BACKOFF_NUM = 2 4 8 16 32 64 128 256  
# BACKOFF_NUM = 512 1024 2048 4096 8192 16384 32768 65536 

LOOP_NUMBERS = 20
# LOOP_NUMBERS = 10 20 30 40 50 
# LOOP_NUMBERS = 60 70 80 90 100

WAIT_COUNTERS = 16
# WAIT_COUNTERS = 2 4 8 16 32 64 128 
# WAIT_COUNTERS = 256 512 1024 2048 4096 8191 16384

AES_ITERS = 1 2 4 8 16 32 64 128 256 512 1024

GCC_OPTS += -DNO_DRIVER=1
# GCC_OPTS += -DDRIVER_EVALS=1

.PHONY: all clean

all: $(EXECUTABLE)

%: %.c
	$(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ $< -o build/$@

# benchmarks that uses an accelerator
cohort_benchmarks:
	 @mkdir -p build
	 $(foreach var,$(NUMBERS), $(foreach loop_time,$(LOOP_NUMBERS), $(foreach backoff_time,$(BACKOFF_NUM), $(foreach wait_time,$(WAIT_COUNTERS), $(foreach batch,$(BATCH_SIZES),  $(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ -DLOOP_NUM=$(loop_time) -DBACKOFF_COUNTER_VAL=$(backoff_time) -DWAIT_COUNTER_VAL=$(wait_time) -DFIFO_SIZE=$(var) -DBATCH_SIZE=$(batch) cohort_aes_base.c -o build/cohort_aes_base_$(loop_time)_$(backoff_time)_$(wait_time)_$(var)_$(batch) ;)))))

h264_benchmarks:
	 @mkdir -p build
	 $(foreach var,$(NUMBERS), $(foreach loop_time,$(LOOP_NUMBERS), $(foreach backoff_time,$(BACKOFF_NUM), $(foreach wait_time,$(WAIT_COUNTERS), $(foreach batch,$(BATCH_SIZES),  $(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ -DLOOP_NUM=$(loop_time) -DBACKOFF_COUNTER_VAL=$(backoff_time) -DWAIT_COUNTER_VAL=$(wait_time) -DFIFO_SIZE=$(var) -DBATCH_SIZE=$(batch) cohort_h264.c -o build/cohort_h264_$(loop_time)_$(backoff_time)_$(wait_time)_$(var)_$(batch) ;)))))

# Benchmark for Marcelo's ni/nc maple engine
ninc_aes_benchmarks:
	 @mkdir -p build
	 $(foreach iter,$(AES_ITERS),  $(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ -DNUM_ITER=$(iter)  dcpn_aes.c -o build/dcpn_aes_$(iter) ;)

# Benchmarks for Marcelo's empty DMA engine
dma_aes_benchmarks:
	 @mkdir -p build
	 $(foreach iter,$(AES_ITERS),  $(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ -DNUM_ITER=$(iter)  dma_aes.c -o build/dma_aes_$(iter) ;)

# Benchmarks that uses an empty cohort
cohort_bandwidth_benchmarks:
	 @mkdir -p build
	 $(foreach var,$(NUMBERS), $(foreach wait_counter,$(WAIT_COUNTERS), $(foreach batch,$(BATCH_SIZES),  $(GCC) $(GCC_OPTS) -I$(PITON_ROOT)/piton/verif/diag/assembly/include/riscv/ariane/ -DFIFO_SIZE=$(var) -DNUM_ITER=$(iter) -DBATCH_SIZE=$(batch) cohort_aes_base.c -o build/cohort_aes_base_$(batch)_$(wait_counter)_$(var) ;)))


clean:
	rm -f build/*

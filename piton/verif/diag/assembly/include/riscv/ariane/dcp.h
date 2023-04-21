
#define BYTE         8
#define TILE         28
#define FIFO         9
#define BASE   0xe100900000

#define DCP_SIZE_8  0
#define DCP_SIZE_16 1
#define DCP_SIZE_32 2
#define DCP_SIZE_48 3
#define DCP_SIZE_64 4
#define DCP_SIZE_80 5
#define DCP_SIZE_96 6
#define DCP_SIZE_128 7  

#define DCP_NULL 8

static uint32_t fid[8] = {DCP_NULL,DCP_NULL,DCP_NULL,DCP_NULL,
                                    DCP_NULL,DCP_NULL,DCP_NULL,DCP_NULL};

void print64(char * str,uint64_t s) {
    printf("%s: data 0x%08x 0x%08x\n", str, ((uint64_t)s)>>32,((uint64_t)s) & 0xFFFFFFFF);
}
void print32(char * str,uint32_t s) {
    printf("%s: data 0x%08x\n",str,((uint32_t)s));
}

static volatile uint64_t reset_addr = (uint64_t)(BASE);
static volatile uint64_t stats_addr = (uint64_t)(BASE + 12*BYTE);

static volatile uint64_t cons_addr = (uint64_t)(BASE + 7*BYTE);
static volatile uint64_t prod_addr = (uint64_t)(BASE + 8*BYTE);

static volatile volatile uint64_t add_addr = (uint64_t)(BASE  + 32*BYTE);
static volatile volatile uint64_t and_addr = (uint64_t)(BASE  + 33*BYTE);
static volatile volatile uint64_t or_addr  = (uint64_t)(BASE  + 34*BYTE);
static volatile volatile uint64_t xor_addr = (uint64_t)(BASE  + 35*BYTE);
static volatile volatile uint64_t max_addr = (uint64_t)(BASE  + 36*BYTE);
static volatile volatile uint64_t maxu_addr = (uint64_t)(BASE + 37*BYTE);
static volatile volatile uint64_t min_addr  = (uint64_t)(BASE + 38*BYTE);
static volatile volatile uint64_t minu_addr = (uint64_t)(BASE + 39*BYTE);
static volatile volatile uint64_t swap_addr = (uint64_t)(BASE + 40*BYTE);
static volatile volatile uint64_t cas1_addr = (uint64_t)(BASE + 41*BYTE);
static volatile volatile uint64_t cas2_addr = (uint64_t)(BASE + 42*BYTE);


static volatile volatile uint64_t tload_addr32 = (uint64_t)(BASE + 10*BYTE);
static volatile volatile uint64_t tload_addr64 = (uint64_t)(BASE + 11*BYTE);

static volatile uint64_t access_fifoc_addr  = (uint64_t)(BASE + 6*BYTE);
static volatile uint64_t access_aconf_addr  = (uint64_t)(BASE + 2*BYTE);
static volatile uint64_t execute_aconf_addr = (uint64_t)(BASE + 3*BYTE);
static volatile uint64_t access_dconf_addr  = (uint64_t)(BASE + 4*BYTE);
static volatile uint64_t execute_dconf_addr = (uint64_t)(BASE + 5*BYTE);

//ATOMICs
void amo_add (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(add_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_and (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(and_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_or (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(or_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_xor (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(xor_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_max (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(max_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_min (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(min_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}
void amo_swap (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data) {
    *(uint64_t *)(swap_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data;}

void amo_cas (uint32_t tile, uint32_t fifo, uint64_t addr, uint32_t data1, uint32_t data2) {
    if (data1<-32768 || data1>32767 || data2 <-32768 || data2>32767){ //Two messages
        *(uint64_t *)(cas1_addr | (tile << TILE) | (fifo << FIFO) ) = ((uint64_t) data2) << 32 | (uint32_t)data1;
    } 
    *(uint64_t *)(cas2_addr | (tile << TILE) | (fifo << FIFO) ) = addr << 32 | data2 << 16 | (uint16_t)data1;  
}




//TLOAD
void tload32 (uint32_t tile, uint32_t fifo, uint64_t addr) {
    *(uint64_t *)(tload_addr32 | (tile << TILE) | (fifo << FIFO) ) = addr;
}
void tload32_offset (uint32_t tile, uint32_t fifo, uint64_t addr, uint64_t offset) {
    *(uint64_t *)(tload_addr32 | (tile << TILE) | (fifo << FIFO) ) = addr | (offset << 37);
}

void tload64 (uint32_t tile, uint32_t fifo, uint64_t addr) {
    //print64("TLOAD",addr);
    *(uint64_t *)(tload_addr64 | (tile << TILE) | (fifo << FIFO) ) = addr;
}

void produce32(uint32_t tile, uint32_t fifo, uint32_t data) {
    //print32("PRODUCE DATA",data);
    *(uint32_t *)(prod_addr | (tile << TILE)| (fifo << FIFO)) = data;
}
void produce64(uint32_t tile, uint32_t fifo, uint64_t data) {
    //print64("PRODUCE DATA",data);
    *(uint64_t *)(prod_addr | (tile << TILE)| (fifo << FIFO)) = data;
}

uint32_t consume32(uint32_t tile, uint32_t fifo){
    volatile uint32_t res = *(uint32_t *)(cons_addr | (tile << TILE)| (fifo << FIFO));
    //print32("CONSUME DATA",res);          
    return res;
}
uint64_t consume64(uint32_t tile, uint32_t fifo){
    volatile uint64_t res = *(uint64_t *)(cons_addr | (tile << TILE)| (fifo << FIFO));
    //print64("CONSUME DATA",res);          
    return res;
}
void reset(uint32_t tile){
    volatile uint64_t res_reset = *(uint64_t*)(reset_addr | (tile << TILE) );
}
//void config_access(uint64_t tile){
//     volatile uint64_t access_conf_addr  = (uint64_t)(BASE + 2*BYTE);
//     uint64_t res_access_conf;
//     do {res_access_conf = *(uint64_t*)(access_conf_addr | (tile << TILE));} while ((res_access_conf & 0x2) == 0x2);
//     //print_stats("ACCESS CONF", res_access_conf);
//}
//void config_execute(uint64_t tile, uint64_t fifo){
//    volatile uint64_t execute_conf_addr = (uint64_t)(BASE + 3*BYTE);
//    uint64_t res_execute_conf;
//    do {res_execute_conf = *(uint64_t*)(execute_conf_addr | (tile << TILE));} while ((res_execute_conf & 0x1) == 0x1);
//}

uint32_t open_access(uint32_t tile, uint32_t * fifo, uint64_t size){
    volatile uint64_t res_access_conf = *(volatile uint64_t*)(access_fifoc_addr | (tile << TILE) | (size << FIFO));
    *fifo = (uint32_t)(res_access_conf >> 32);
    return (uint32_t) res_access_conf;
}

uint32_t open_access2(uint32_t tile, uint32_t * fifo){
    uint32_t f = *(volatile uint32_t *)fifo;
    if (f >= DCP_NULL) return 0;
    else {
        volatile uint64_t res_access_conf = *(volatile uint64_t*)(access_aconf_addr | (tile << TILE) | (f << FIFO));
        return (uint32_t) res_access_conf;
    }
}

uint32_t open_execute(uint32_t tile, uint32_t * fifo){
    uint32_t f = *(volatile uint32_t *)fifo;
    if (f >= DCP_NULL) return 0;
    else {
        volatile uint64_t res_execute_conf = *(volatile uint64_t*)(execute_aconf_addr | (tile << TILE) | (f << FIFO));
        return (uint32_t)(res_execute_conf & 0x1);
    }
}
uint32_t close_access(uint64_t tile, uint32_t * fifo){
    uint32_t f = *(volatile uint32_t *)fifo;
    if (f >= DCP_NULL) return 0;
    else {
        volatile uint64_t res_conf = *(volatile uint64_t*)(access_dconf_addr | (tile << TILE) | (f << FIFO));
        return (uint32_t)(res_conf & 0x2);
    }
}
uint32_t close_execute(uint64_t tile, uint32_t * fifo){
    uint32_t f = *(volatile uint32_t *)fifo;
    if (f >= DCP_NULL) return 0;
    else {
        volatile uint64_t res_conf = *(volatile uint64_t*)(execute_dconf_addr | (tile << TILE) | (f << FIFO));
        return (uint32_t)(res_conf & 0x1);
    }
}

uint64_t get_stats(uint64_t tile, uint32_t fifo){
    volatile uint64_t res_stat = *(volatile uint64_t*)(stats_addr | (tile << TILE) | (fifo << FIFO));
    return res_stat;
    //print_stats("STATS", res_stats);
}

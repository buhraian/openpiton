#include <iostream>
#include <mpi.h>

using namespace std;

unsigned long long message_async;
MPI_Status status_async;
MPI_Request request_async;

const int nitems=2;
int          blocklengths[2] = {1,1};
MPI_Datatype types[2] = {MPI_UNSIGNED_SHORT, MPI_UNSIGNED_LONG_LONG};
MPI_Datatype mpi_data_type;
MPI_Aint     offsets[2];



typedef struct {
    unsigned short valid;
    unsigned long long data;
} mpi_data_t;

extern "C" void initialize(){
    MPI_Init(NULL, NULL);
    cout << "initializing" << endl;
    
    // Initialize the struct data&valid
    offsets[0] = offsetof(mpi_data_t, valid);
    offsets[1] = offsetof(mpi_data_t, data);

    MPI_Type_create_struct(nitems, blocklengths, offsets, types, &mpi_data_type);
    MPI_Type_commit(&mpi_data_type);

}

// MPI Yummy functions
extern "C" unsigned short mpi_receive_yummy(int origin, int flag){
    //cout << "mpi_receive_yummy origin: " << origin << " flag: " << flag << endl;
    unsigned short message;
    int message_len = 1;
    MPI_Status status;
    //cout << "[DPI CPP] Block Receive YUMMY from rank: " << origin << endl << std::flush;
    MPI_Recv(&message, message_len, MPI_UNSIGNED_SHORT, origin, flag, MPI_COMM_WORLD, &status);
    if (short(message)) {
        cout << flag << " [DPI CPP] Yummy received: " << std::hex << (short)message << endl << std::flush;
    }
    return message;
}

extern "C" void mpi_send_yummy(unsigned short message, int dest, int rank, int flag){
    //cout << "mpi_send_yummy message: " << message << " dest: " << dest << "flag: " << flag << endl;
    int message_len = 1;
    if (message) {
        cout << flag << " [DPI CPP] Sending YUMMY " << std::hex << (int)message << " to " << dest << endl << std::flush;
    }
    MPI_Send(&message, message_len, MPI_UNSIGNED_SHORT, dest, flag, MPI_COMM_WORLD);
}

// MPI valid functions

extern "C" unsigned short mpi_receive_valid(int origin, int flag){
    //cout << "mpi_receive_yummy origin: " << origin << " flag: " << flag << endl;
    unsigned short message;
    int message_len = 1;
    MPI_Status status;
    //cout << "[DPI CPP] Block Receive YUMMY from rank: " << origin << endl << std::flush;
    MPI_Recv(&message, message_len, MPI_UNSIGNED_SHORT, origin, flag, MPI_COMM_WORLD, &status);
    if (short(message)) {
        cout << flag << " [DPI CPP] VALID received: " << std::hex << (short)message << endl << std::flush;
    }
    return message;
}

extern "C" void mpi_send_valid(unsigned short message, int dest, int rank, int flag){
    //cout << "mpi_send_yummy message: " << message << " dest: " << dest << "flag: " << flag << endl;
    int message_len = 1;
    if (message) {
        cout << flag << " [DPI CPP] Sending VALID " << std::hex << (int)message << " to " << dest << endl << std::flush;
    }
    MPI_Send(&message, message_len, MPI_UNSIGNED_SHORT, dest, flag, MPI_COMM_WORLD);
}

// MPI data functions
extern "C" void mpi_send_data(unsigned long long data, unsigned char valid, int dest, int rank, int flag){
    //cout << "mpi_send_data data: " << data << " valid: " << valid << " dest: " << dest <<  " flag: " << flag <<endl;
    int message_len = 1;
    //cout << "valid: " << std::hex << valid << std::endl;
    if (valid) {
        cout << flag << " [DPI CPP] Sending DATA: " << std::hex << data << " to " << dest << endl;
    }
    MPI_Send(&data, message_len, MPI_UNSIGNED_LONG_LONG, dest, flag, MPI_COMM_WORLD);
}

extern "C" unsigned long long mpi_receive_data(int origin, int flag){
    //cout << "mpi_receive_data origin: " << origin << " flag: " << flag << endl;
    int message_len = 1;
    MPI_Status status;
    unsigned long long message;
    //cout << flag << " [DPI CPP] Blocking Receive data rank: " << origin << endl << std::flush;
    MPI_Recv(&message, message_len, MPI_UNSIGNED_LONG_LONG, origin, flag, MPI_COMM_WORLD, &status);
    if (message) {
        cout << flag << " [DPI CPP] Data Message received: " << std::hex << message << endl << std::flush;
    }
    return message;
}

extern "C" void barrier(){
    MPI_Barrier(MPI_COMM_WORLD);
    cout << "barrier" << endl;
}

extern "C" int getRank(){
    int rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    return rank;
}

extern "C" int getSize(){
    int size;
    MPI_Comm_rank(MPI_COMM_WORLD, &size);
    return size;
}

extern "C" void finalize(){
    cout << "[DPI CPP] Finalizing" << endl;
    MPI_Finalize();
}


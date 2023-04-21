//==================================================================================================
//  Filename      : aes_top_buffered_wrapper.v
//  Created On    : 2021-04-12
//  Revision      :
//  Author        : August Ning, Yajun Zhu
//  Company       : Princeton University
//  Email         : aning@princeton.edu
//
//  Description   : Wrapper for AES module that to allow it to accept commands from dcp
//                  The buffer helps with pipelining
//
//==================================================================================================

`define AES_DATA_WIDTH_BITS             128
module aes_top_buffered_wrapper (
    input  wire clk,
    input  wire rst_n,

    input  wire                             config_hsk,     // When handshake is high, address is valid
    input  wire [15:0]                      config_addr,    // noc1decoder_dcp_address, address will correspond with instruction
    input  wire [31:0]                      config_data_hi, // noc1decoder_dcp_data
    input  wire [31:0]                      config_data_lo,
    input  wire                             config_load,    // It is a Load if high (a read ciphertext), if low it's a store (write to plaintext or key reg?)
    output wire                             aes_ready,
    output wire                             aes_out_valid,
    output wire [63:0]                      aes_out_data,

    output wire                             buffer_val,
    output wire [127:0]                     buffer_data,
    input  wire                             buffer_pop,
    output wire [3:0]                       buffer_idx,
    output wire [15:0]                      buffer_entries_val
);
    
    // instructions corresond to inputs you'll get from config_addr
    localparam AES_WRITE_KEY_HIGH_ADDR      = 16'h0010;
    localparam AES_WRITE_KEY_LOW_ADDR       = 16'h0020;
    localparam AES_WRITE_PLAIN_HIGH_ADDR    = 16'h0030;
    localparam AES_WRITE_PLAIN_LOW_ADDR     = 16'h0040;
    localparam AES_READ_CIPHER_HIGH_ADDR    = 16'h0050;
    localparam AES_READ_CIPHER_LOW_ADDR     = 16'h0060;

    reg [`AES_DATA_WIDTH_BITS-1:0]  aes_key_data_reg;
    reg [`AES_DATA_WIDTH_BITS-1:0]  aes_plaintext_data_reg;
    reg                             aes_inputs_valid_reg;

    localparam BUFFER_SIZE = 16;
    localparam BUFFER_BITS = 4;

    // make ciphertext output write to a circular buffer
    // wires are used as outputs from AES module
    reg [`AES_DATA_WIDTH_BITS-1:0]  text_data_reg  [BUFFER_SIZE-1:0];
    wire [`AES_DATA_WIDTH_BITS-1:0] text_data;
    reg  [BUFFER_SIZE-1:0]          text_valid_reg ;
    wire                            text_valid;

    // regs used to keep track of circular buffer
    reg [BUFFER_BITS-1:0] text_data_reg_head;
    reg [BUFFER_BITS-1:0] text_data_reg_tail;
    reg [BUFFER_BITS-1:0] text_data_reg_curr;

    wire read_cipher_high = (config_addr == AES_READ_CIPHER_HIGH_ADDR);
    wire write_plainlow = config_hsk && ( config_addr == AES_WRITE_PLAIN_LOW_ADDR );
    wire read_plainlow = aes_out_valid && ( config_addr == AES_READ_CIPHER_LOW_ADDR );

    wire tail_invalid = !text_valid_reg[text_data_reg_tail];
    //wire curr_valid = text_valid_reg[text_data_reg_curr];
    wire head_valid = text_valid_reg[text_data_reg_head];
    assign buffer_entries_val = text_valid_reg;

    assign buffer_val = head_valid;
    assign buffer_data = text_data_reg[text_data_reg_head];
    assign buffer_idx = text_data_reg_head;

    wire advance_head = read_plainlow && head_valid || buffer_pop;
    wire advance_tail = write_plainlow && tail_invalid;
    wire advance_curr = text_valid;// && curr_valid;
    // Ready if we have space and we can request a new cypher to the accelerator
    assign aes_ready = !aes_inputs_valid_reg && tail_invalid;

    // this genvar loop is used for creating the control logic for the output buffer 
    genvar k;
    generate
    for (k = 0; k < BUFFER_SIZE; k = k + 1) begin
        always @( posedge clk ) begin 
            if (! rst_n ) begin
                text_data_reg[k]  <= {64'hAAAA_AAAA_AAAA_AAAA, {64-BUFFER_BITS{1'b1}}, k[BUFFER_BITS-1:0]};
                text_valid_reg[k] <= 1'b0;
            end else begin
                // when the write plaintext low command is received, allocate a valid spot
                // at the tail of the ciphertext buffer
                // if ( advance_tail && ( k[BUFFER_BITS-1:0] == text_data_reg_tail ) ) begin
                    
                // end
                // the curr reg keeps track of where to write the output of the aes module
                // output of the aes module is only valid if the curr index is valid
                if ( advance_curr && ( k[BUFFER_BITS-1:0] == text_data_reg_curr ) ) begin
                    text_data_reg[k]      <= text_data;
                    text_valid_reg[k]     <= 1'b1;
                end
                // head register is where the output from aes read instructions should return from
                // after the encryption result has been consumed, free it for the next encryption
                if ( advance_head && ( k[BUFFER_BITS-1:0] == text_data_reg_head ) ) begin
                    text_valid_reg[k]     <= 1'b0;
                end
            end
        end
    end
    endgenerate

    // always block used for populating aes key and plaintext registers
    // accepts valid instructions and will update the corresponding registers
    always @(posedge clk) begin
        if ( !rst_n ) begin
            aes_key_data_reg        <= 128'b0;
            aes_plaintext_data_reg  <= 128'b0;
        end
        else if ( config_hsk && ( config_addr == AES_WRITE_KEY_HIGH_ADDR ) ) begin
            aes_key_data_reg[127:96]    <= config_data_hi;
            aes_key_data_reg[95:64]     <= config_data_lo;  
        end
        else if ( config_hsk && ( config_addr == AES_WRITE_KEY_LOW_ADDR ) ) begin
            aes_key_data_reg[63:32]    <= config_data_hi;
            aes_key_data_reg[31:0]     <= config_data_lo;  
        end
        else if ( config_hsk && ( config_addr == AES_WRITE_PLAIN_HIGH_ADDR ) ) begin
            aes_plaintext_data_reg[127:96]    <= config_data_hi;
            aes_plaintext_data_reg[95:64]     <= config_data_lo;  
        end
        // when the plaintext lower bits are written, that signals the module to start
        // encrypting. it's up to the programmer to use this correctly
        else if ( advance_tail ) begin
            aes_plaintext_data_reg[63:32]    <= config_data_hi;
            aes_plaintext_data_reg[31:0]     <= config_data_lo;
        end
    end

    always @(posedge clk) begin
        if ( !rst_n ) begin
            aes_inputs_valid_reg <= 1'b0;
        end else begin
            aes_inputs_valid_reg <= advance_tail && !aes_inputs_valid_reg;
        end
    end

    always @(posedge clk) begin
        if ( !rst_n ) begin
            text_data_reg_head <= {BUFFER_BITS{1'b0}};
            text_data_reg_tail <= {BUFFER_BITS{1'b0}};
            text_data_reg_curr <= {BUFFER_BITS{1'b0}};
        end else begin
            text_data_reg_head <= advance_head ? (text_data_reg_head + 1'b1) % BUFFER_SIZE : text_data_reg_head;
            text_data_reg_tail <= advance_tail ? (text_data_reg_tail + 1'b1) % BUFFER_SIZE : text_data_reg_tail;
            text_data_reg_curr <= advance_curr ? (text_data_reg_curr + 1'b1) % BUFFER_SIZE : text_data_reg_curr;
        end
    end

    // assign the output. the lowerbit -1 indexing has to do with the circular buffer's logic
    assign aes_out_data = read_cipher_high ? 
                            text_data_reg[text_data_reg_head][127:64] : 
                            text_data_reg[text_data_reg_head][63:0];
    assign aes_out_valid = config_hsk && config_load;

    // pipelined aes module from open cores. module is plug and play, and designer only
    // has to implement the control signals and how to pass data to the module

    Top_PipelinedCipher aes_top
    ( 
        .clk(clk),
        .reset(rst_n),

        .data_valid_in(aes_inputs_valid_reg),
        .cipherkey_valid_in(aes_inputs_valid_reg),
        .cipher_key(aes_key_data_reg),
        .plain_text(aes_plaintext_data_reg),

        .valid_out(text_valid),
        .cipher_text(text_data)
    );

    // decoupled_vr_if consumer_data (
	// 	.clk  (clk  ),
	// 	.rst_n(rst_n)
	// );
	
	// decoupled_vr_if producer_data (
	// 	.clk  (clk  ),
	// 	.rst_n(rst_n)
	// );
    // assign consumer_data.valid = aes_inputs_valid_reg;
    // assign consumer_data.data = aes_plaintext_data_reg[63:0];
    // //ready
    // assign text_valid = producer_data.valid;
    // assign text_data = producer_data.data[63:0];
    // assign producer_data.ready = producer_data.valid;
    
    // sha256_custom_top sha256_custom_top_i (
    //     .clk            ( clk            ),
    //     .rst_n          ( rst_n            ),
    //     .acc_config     ( acc_config    ),
    //     .consumer_data  ( consumer_data.slave    ),
    //     .producer_data  ( producer_data.master   )
    // );

endmodule

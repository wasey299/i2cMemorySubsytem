module master
(
    // System Interface
    input logic         rst, 
    input logic         clk, 
    
    // Command Interface
    input logic         rw,         // 1:read, 0:write 
    input logic         dataValid,  // To starrt the transaction
    input logic [6:0]   addr,       // &-bit slave address

    // Data Input/Output
    input logic [7:0]   din,        // 8-bit input data
    output logic [7:0]  dout,       // 8-bit outptu data
    
    // Status flags
    output logic        busy,       // High during transaction 
    output logic        ackErr,     // High when NACK is received when not expected
    output logic        done,       // High when transaction finishes`

    // I2C Bus Interface
    inout tri           sda,
    inout tri           scl
);

    //================================================================
    // Parameters
    //================================================================
    parameter freqSystem = 50000000; //System CLock Frequency: 50 MHz
    parameter freqI2C    = 100000;   //I2C Clock Frequency   : 100 kHz 

    // Clock divider/baud rate generator
    parameter clockFull = freqSystem / freqI2C; //500

    // Calculate the number of clocks for one quarter of an I2C clock period
    parameter clockQuart = clockFull/4; //125


    //================================================================
    // Internal Signals
    //================================================================

    // --- Timing Generator Signals ---
    int             countFull;  // Counte from 0 to clockQuart - 1
    logic [1:0]     countPulse; // Counts four phases: 0, 1, 2, 3
    logic           core_en;
    
    // --- Counters ---
    logic [3:0]     countBit;   // Helps is transferring the data on SDA bit by bit from MSB to LSB
    logic [3:0]     next_countBit;

    // --- FSM States Enum Logic ---
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_BYTE,
        WAIT_ACK,
        WAIT_CMD,
        READ_BYTE,
        SEND_NACK,
        STOP
    } state_t;
    state_t state, next_state;

    // --- Internal Registers ---
    logic [7:0]     data_shift_reg, next_data_reg; 
    logic           sda_tmp;            // Temporary holding regs for sda and scl
    logic           scl_tmp;
    logic [7:0]     read_reg;           // Register to receive incoming data from SDA line form the slave 
    logic           start_transaction;
    logic           latched_rw_reg;     // LTakes the snapshot of the rw port for the entire operation
    logic           done_reg;
    logic           nack_received;
    logic           sample_data;
  
    // --- Tri-State Buffers for connection to sda and scl lines ---
    logic sda_en;
    logic scl_en;


    // --- Acknowledgement registers ---
    logic ackSlave;

    //================================================================
    // Timing Generator
    //================================================================
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            countFull <= '0;
            countPulse <= '0;
        end

        // Only starts counting when the core_en is asserted and there is
        // clock strecthcing happening, i.e., scl_en is low and also ecl is
        // being driven by a strong low at the same time.
        else if (core_en && !(scl_en == 1'b0 && scl == 1'b0)) begin
            if ((countFull  == clockQuart - 1) || (countFull  == clockQuart*2 - 1 )|| (countFull  == clockQuart*3 - 1))  begin
                countFull <= countFull + 1;                   
                countPulse <= countPulse + 1;            
            end 
            else if (countFull  == clockFull - 1) begin
                countFull <= '0;                  
                countPulse <= '0;             
            end 
            else countFull <= countFull + 1;
        end
    end
     
    //================================================================
    // SCL Genrator
    //================================================================
    always_comb
    unique case (countPulse)
        2'b00: scl_en = (state == START || state == STOP) ? 1'b0 : 1'b1;
        2'b01: scl_en = (state == START || state == STOP) ? 1'b0 : 1'b1;  
        2'b10: scl_en = (state == START || state == STOP) ? 1'b0 : 1'b0;  
        2'b11: scl_en = (state == START || state == STOP) ? 1'b0 : 1'b0;  
    endcase
    
    //================================================================
    // Main Finite State Machines
    //================================================================
    always_ff @(posedge clk or negedge rst)
    if (!rst) begin 
        state          <= IDLE;
        countBit       <= '0;
        done           <= 1'b0;
        ackErr         <= 1'b0;
        latched_rw_reg <= 1'b0;
    end
    else begin
        state    <= next_state; 
        countBit <= next_countBit;
        if (start_transaction) begin
            data_shift_reg  <= {addr, rw};
            latched_rw_reg  <= rw;
        end else data_shift_reg <= next_data_reg;

        if (sample_data) read_reg[countBit] <= sda;
        done    <= done_reg;
        ackErr  <= nack_received;
    end

    always_comb begin
        next_state          = state;
        sda_tmp             = 1'b1;
        next_countBit       = countBit;
        next_data_reg       = data_shift_reg;
        start_transaction   = 1'b0;
        sample_data         = 1'b0;
        done_reg            = 1'b0;
        nack_received       = 1'b0;

        unique case (state)
                    
                    IDLE: 
                        if (dataValid) begin
                           start_transaction    = 1'b1;
                           next_state           = START;                           
                           next_countBit        = 7;
                       end 
                    
                    START: begin
                        // ---The start condition:---
                        if (countPulse < 2) sda_tmp = 1'b1;
                        else sda_tmp = 1'b0;

                        if (countFull == clockFull - 1) begin
                            next_state = SEND_BYTE;
                        end 
                     end

                     SEND_BYTE: begin
                        sda_tmp = data_shift_reg[countBit];
                        if (countFull == clockFull - 1) begin
                            if (countBit == 0) next_state = WAIT_ACK;
                            else next_countBit = countBit - 1;
                        end
                     end

                     WAIT_ACK: begin
                         if (countPulse == 2) ackSlave = 1'b0;//sda;
                         if (countFull == clockFull -1) begin
                             if (ackSlave == 1'b1) begin
                                nack_received   = 1'b1;
                                next_state      = STOP;
                            end 
                            else begin
                                if (latched_rw_reg) begin
                                    next_state      = READ_BYTE;
                                    next_countBit   = 7; 
                                end else next_state = WAIT_CMD;
                            end
                           end
                     end

                     WAIT_CMD: begin
                         if (dataValid) begin
                             next_state     = SEND_BYTE;
                             next_countBit   = 7;
                             next_data_reg  = din;
                         end else next_state = STOP;
                     end

                    READ_BYTE: begin
                        if (countPulse == 2) sample_data = 1'b1;
                        if (countFull == clockFull - 1) begin
                            if (countBit == 0) next_state = SEND_NACK;
                            else next_countBit = countBit - 1;
                        end
                    end
                    
                    // --- Negative acknowledgment to slave to initiate the stop condition ---
                    SEND_NACK: begin
                        sda_tmp = 1'b1;
                        if (countFull == clockFull - 1) next_state = STOP;
                    end

                    STOP: begin
                        done_reg = 1'b1;

                        // ---The stop condition:---
                        if (countPulse < 2) sda_tmp = 1'b0;
                        else sda_tmp = 1'b1;

                        if (countFull == clockFull - 1) next_state = IDLE;
                    end
           endcase
    end

 //================================================================
 // Final Output Logic
 //================================================================
    assign sda  = (sda_en) ? sda_tmp : 1'bz;
    assign scl  = (scl_en) ? 1'b0 : 1'bz;

    assign busy     = (state != IDLE);
    assign dout     = read_reg;
    assign core_en  = (state != IDLE);
    assign sda_en   = (state == START || state == SEND_BYTE || state == SEND_NACK || state == STOP);

endmodule

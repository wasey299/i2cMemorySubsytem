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
    
    // --- Counters ---
    logic [3:0]     countBit;   // Helps is transferring the data on SDA bit by bit from MSB to LSB

    // --- FSM States Enum Logic ---
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_ADDR,
        SLAVE_ACK_ADDR,
        WRITE,
        READ,
        STOP,
        SLAVE_ACK_DATA,
        MASTER_ACK
    } state_t;
    state_t state, next_state;

    // --- Internal Registers ---
    logic [7:0]     addr_reg;   //Register to store {addr, rw}
    logic [7:0]     data_reg;   //Register to store din  
    logic            sda_tmp;   //Temporary holding regs for sda and scl
    logic           scl_tmp;
    logic [7:0]     read_reg;   //Register to receive incoming data from SDA line form the slave 
  
    assign dout =   read_reg;

    // --- Tri-State Buffers for connection to sda and scl lines ---
    logic sda_en;
    logic scl_en;

    assign sda = (sda_en) ? (!sda_tmp) ? 1'b0 : 1'b1 : 1'bz;
    assign scl = (scl_en) ? (!scl_tmp) ? 1'b0 : 1'b1 : 1'bz;

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

        else if (scl_en) begin
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
        2'b00: scl_tmp = (state == START || state == STOP) ? 1'b1 : 1'b0;
        2'b01: scl_tmp = (state == START || state == STOP) ? 1'b1 : 1'b0;  
        2'b10: scl_tmp = (state == START || state == STOP) ? 1'b1 : 1'b1;  
        2'b11: scl_tmp = (state == START || state == STOP) ? 1'b1 : 1'b1;  
    endcase

    //================================================================
    // Main Finite State Machines
    //================================================================
    always_ff @(posedge clk or negedge rst)
    if (!rst) state <= IDLE;
    else state <= next_state; 

    always_comb begin
        unique case (state)
                    IDLE: begin
                        done        = 1'b0;
                        ackErr      = 1'b0;
                        sda_tmp     = 1'b0;
                        countBit    = 1'b0;
                        if (dataValid) begin
                           addr_reg     = {addr, rw};
                           data_reg     = din; 
                           busy         = 1'b1;
                           next_state   = START;                           
                       end else begin
                           busy         = 1'b0;
                           next_state   = IDLE;
                           addr_reg     = '0;
                           data_reg     = '0;
                       end
                    end
                    
                    START: begin
                        sda_en = 1'b1;
                        scl_en = 1'b1;
                        // ---The start condition:---
                        unique case (countPulse)
                                        2'b00: sda_tmp = 1'b1;
                                        2'b01: sda_tmp = 1'b1;
                                        2'b10: sda_tmp = 1'b0;
                                        2'b11: sda_tmp = 1'b0;
                        endcase

                        if (countFull == clockFull - 1) begin
                            next_state = SEND_ADDR;
                        end 
                    end

                    SEND_ADDR: begin
                        if (countBit <= 7) begin
                            unique case (countPulse)
                                        2'b00: sda_tmp = 1'b0;
                                        2'b01: sda_tmp = addr_reg[7 - countBit]; // Helps in transferring from MSB to LSB
                                        2'b10: begin end
                                        2'b11: begin end
                            endcase

                            if (countFull == clockFull - 1) countBit++; // Moves to next to next clock cylce for next bit
                        
                        end else begin
                             countBit   = '0;
                             next_state = SLAVE_ACK_ADDR;
                         end
                     end
                    
                     SLAVE_ACK_ADDR: begin
                            sda_en = 1'b0;
                            unique case (countPulse)
                                        2'b00: begin end
                                        2'b01: begin end
                                        2'b10: ackSlave = 1'b0;  // Will be assigned to sda after slave is implemented
                                        2'b11: begin end
                            endcase

                            if (countFull == clockFull - 1)  next_state = (!ackSlave) ? (addr_reg[0]) ? READ : WRITE : STOP; 
                     end

                     WRITE: begin
                        sda_en = 1'b1;
                        if (countBit <= 7) begin
                            unique case (countPulse)
                                        2'b00: sda_tmp = 1'b0;
                                        2'b01: sda_tmp = data_reg[7 - countBit]; // Helps in transferring from MSB to LSB
                                        2'b10: begin end
                                        2'b11: begin end

                            endcase
                            if (countFull == clockFull - 1) countBit++; // Moves to next to next clock cylce for next bit
                        
                        end else begin
                             countBit   = '0;
                             next_state = SLAVE_ACK_DATA;
                         end
                    end

                    SLAVE_ACK_DATA: begin
                            sda_en = 1'b0;
                            unique case (countPulse)
                                        2'b00: begin end
                                        2'b01: begin end
                                        2'b10: ackSlave    = 1'b0;  // Will be assigned to sda after slave is implemented
                                        2'b11: begin end
                            endcase

                            if (countFull == clockFull - 1)  begin
                                ackErr = (!ackSlave) ? 1'b0 : 1'b1;
                                next_state = STOP;
                            end 
                    end

                    READ: begin
                        sda_en = 1'b0;
                        if (countBit <= 7) begin
                            unique case (countPulse)
                                        2'b00: sda_tmp = 1'b0;
                                        2'b01: if (countFull == clockQuart * 2) read_reg = {read_reg[6:0] , sda}; // Shifts incoming data form sda
                                        2'b10: begin end 
                                        2'b11: begin end 
                            endcase

                            if (countFull == clockFull - 1) countBit++; // Moves to next to next clock cylce for next bit
                        
                        end else begin
                             countBit   = '0;
                             next_state = MASTER_ACK;
                         end
                    end
                    
                    // --- Negative acknowledgment to slave to initiate the stop condition ---
                    MASTER_ACK: begin
                        sda_en = 1'b1;

                        unique case (countPulse)
                                        2'b00: sda_tmp = 1'b1;
                                        2'b01: sda_tmp = 1'b1;
                                        2'b10: sda_tmp = 1'b1;
                                        2'b11: sda_tmp = 1'b1;
                        endcase

                        if (countFull == clockFull - 1)  next_state = STOP;
                    end

                    STOP: begin
                        sda_en = 1'b1;
                        // ---The stop condition:---
                        unique case (countPulse)
                                        2'b00: sda_tmp = 1'b0;
                                        2'b01: sda_tmp = 1'b0;
                                        2'b10: sda_tmp = 1'b1;
                                        2'b11: sda_tmp = 1'b1;
                        endcase

                        if (countFull == clockFull - 1) begin
                            next_state = IDLE;
                        end 
                    end
           endcase
    end

endmodule




























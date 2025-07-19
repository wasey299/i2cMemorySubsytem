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
    parameter clockQuart = clockFull/4; //100


    //================================================================
    // Internal Signals
    //================================================================

    // --- Timing Generator Signals ---
    logic [$clog2(clockQuart) - 1:0]    countQuart; // Counte from 0 to clockQuart - 1
    logic [1:0]                         countPulse; // Counts four phases: 0, 1, 2, 3

    // --- FSM States Enum Logic ---
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_ADDR,
        SLAVE_ACK_1,
        WRITE,
        READ,
        STOP,
        SLAVE_ACK_2,
        MASTER_ACK
    } state_t;
    state_t state, next_state;

    //================================================================
    // Timing Generator
    //================================================================
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            countQuart <= '0;
            countPulse <= '0;
        end

        else begin
            if (countQuart  == clockQuart - 1) begin
                countQuart <= '0;    // Explcitly resetting. Reason: As per the width, there will be 128 possible vaues, whereas this hsould have 125 max.
                countPulse <= countPulse + 1;       // Pulse generation : 0, 1, 2, 3      
            end else begin
                countQuart <= countQuart + 1;
            end
        end
    end
     
    //================================================================
    // Main Finite State Machines
    //================================================================
    always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
        busy    <= 1'b0;
        ackErr <= 1'b0;
        done    <= 1'b0;       
    end else state <= next_state; 
    end
endmodule




























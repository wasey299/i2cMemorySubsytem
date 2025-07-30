module master
(
    // System Interface
    input logic         rst, 
    input logic         clk, 
    
    // Command Interface
    input logic         rw,         // 1:read, 0:write 
    input logic         dataValid,  // To starrt the transaction
    input logic [6:0]   addr,       // &-bit slave address

    // Busy logic to allow clock streching
 //   input logic        busy,       // High during transaction 

    // Status flags
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
        READ_ADDR,
        SLAVE_ACK_ADDR,
        READ_DATA,
        WRITE_DATA,
        WAITE,
        STOP_DETECT,
        SLAVE_ACK_DATA,
        MASTER_ACK
    } state_t;
    state_t state, next_state;
    
    // -- Memory Array and signals---
    logic [7:0] mem [128];
    logic       write_en;
    logic       read_en;
    logic [6:0] mem_addr;   // Takes 7 MSB from the master via sda
    
    // --- Internal Registers ---
    logic       sda_tmp;
    logic       scl_tmp;
    logic [7:0] din;        // Received data from the master
    logic [7:0] dout;       // Data sent to the master
    logic       busy;

    // --- Tri-State Buffers for connection to sda and scl lines ---
    logic       sda_en;
    logic       scl_en;

    assign sda = (sda_en) ? (!sda_tmp) ? 1'b0 : 1'b1 : 1'bz;
    assign scl = (scl_en) ? (!scl_tmp) ? 1'b0 : 1'b1 : 1'bz;

    // --- Acknowledgement registers ---
    logic ackMaster;

    //================================================================
    // Memory Operation
    //================================================================
    always_ff @(posedge clk) begin
        if (write_en) mem[mem_addr] <= din;
        else if (read_en) dout <= mem[mem_addr];
    end 

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
    // Main Finite State Machines
    //================================================================
    always_ff @(posedge clk or negedge rst)
    if (!rst) state <= IDLE;
    else state <= next_state;

    always_comb begin
        unique case (state) 
                     IDLE :  
        endcase
    end 
endmodule




























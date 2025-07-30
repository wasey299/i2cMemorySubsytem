`timescale 1ns / 1ps //Precision of 0.001 ns

`include "master.sv"

module master_tb; 
    //================================================================
    // Testbench Signals
    //================================================================
    
    // System Interface
    logic         rst; 
    logic         clk; 
    
    // Command Interface
    logic         rw;         // 1:read, 0:write 
    logic         dataValid;  // To starrt the transaction
    logic [6:0]   addr;       // &-bit slave address

    // Data Input/Output
    logic [7:0]   din;        // 8-bit data
    logic [7:0]  dout;       // 8-bit outptu data
    
    // Status flags
    logic        busy;       // High during transaction 
    logic        ackErr;     // High when NACK is received when not expected
    logic        done;       // High when transaction finishes`

    // I2C Bus Interface
    tri           sda;
    tri           scl;
    
    //================================================================
    // DUT Instantiation
    //================================================================
    master dut (.*);

    logic sda_tmp;
   // assign sda = sda_tmp;
    //================================================================
    // Testbench Parameters
    //================================================================
    localparam CLOCK_PERIOD     = 20;
    localparam I2C_CLOCK        = 500;

    //================================================================
    // Clock Generation
    //================================================================
    always #(CLOCK_PERIOD / 2) clk = ~clk;

    //================================================================
    // Reset and Stimulus
    //================================================================
    initial begin
        clk = 1'b0;
        rst = 1'b0;

        repeat (I2C_CLOCK) @ (negedge clk);
        
        rst = 1'b1;
        dataValid = 1'b1;
        rw = 1'b0;
        addr = 7'b1010101; //1010101_0
        din = 8'b00101111;
        // START: 1
        // ADDR + RW: 8
        // SLAVE_ACK : 1
        repeat (10 * I2C_CLOCK) @ (negedge clk); // To reach till Data is required for SDA that will be fed to master
        sda_tmp = 1'b0; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b1; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b0; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b1; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b0; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b0; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b1; repeat (I2C_CLOCK) @ (negedge clk);
        sda_tmp = 1'b1; dataValid = 1'b0; repeat (I2C_CLOCK) @ (negedge clk); 
    //    repeat (8 * I2C_CLOCK) @ (negedge clk);
        repeat (3 * I2C_CLOCK) @ (negedge clk); 

        $stop();  
    end    
endmodule

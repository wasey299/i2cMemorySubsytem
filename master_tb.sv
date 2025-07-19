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

    //================================================================
    // Testbench Parameters
    //================================================================
    localparam CLOCK_PERIOD = 20;

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

        repeat (500) @ (negedge clk);
        
        rst = 1'b1;
        dataValid = 1'b1;
        rw = 1'b0;
        addr = 8'b01010101;
        din = 7'b0001111;
        
        repeat (2500) @ (negedge clk); // Equivalent to 5 full i2c clock cycles.

        $finish;  
    end    
endmodule

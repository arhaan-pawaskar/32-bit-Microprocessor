//! The problem of pipeline hazard is eliminated in this testbench by using dummy instructions to stall the processor for a max of two clock cycles
//! This program executes the code for adding three numbers

`timescale 1ns/1ps
`include "32_Bit_Processor.v"

module Processor_testbench;

    reg clk1, clk2;
    integer k;

    Prototype_processor P(clk1, clk2);

    // Generating two-phase clock
    initial begin 
        clk1 = 0; clk2 = 0;

        repeat(20) begin

            #5 clk1 = 1;
            #5 clk1 = 0;

            #5 clk2 = 1;
            #5 clk2 = 0;

        end

    end

    // For assembly language execution
    initial begin
        for (k = 0; k < 31 ; k = k + 1) begin

            P.REG[k] = k;

            P.MEM[0] = 32'h2801000a; // ADDI R1, R0, 10
            P.MEM[1] = 32'h28020014; // ADDI R2, R0, 20
            P.MEM[2] = 32'h28030019; // ADDI R3, R0, 25
            P.MEM[3] = 32'h0ce77800; // OR   R7, R7, R7 -- Dummy instruction
            P.MEM[4] = 32'h0ce77800; // OR   R7, R7, R7 -- Dummy instruction
            P.MEM[5] = 32'h00222000; // ADD  R4, R1, R2
            P.MEM[6] = 32'h0ce77800; // OR   R7, R7, R7 -- Dummy instruction
            P.MEM[7] = 32'h00832800; // ADD  R5, R4, R3
            P.MEM[8] = 32'hfc000000; // HLT

        end

        P.HALTED = 0;
        P.PC = 0;
        P.TAKEN_BRANCH = 0;

        #280 for (k = 0; k<31 ; k = k + 1) begin
            $display("R%1d - %2d", k, P.REG[k]);
        end

    end

    // For gtk wave
    initial begin
        $dumpfile("processor.vcd");
        $dumpvars(0, Processor_testbench);
        #300 $finish;
    end

endmodule


//! The processor created here is just a prototype and contains subset of the instruction set of the original processor
//! To make this code better we can declare modules for ALU, Memory and Register Bank
//! This code does not handle Pipeline hazards
//! This follows RISC architecture

`timescale 1ns/1ps

module Prototype_processor(clk1, clk2); // Top-level module 

    input clk1, clk2; // Two-phase clock

    // For Pipelining
    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;
    reg [2:0] ID_EX_TYPE, EX_MEM_TYPE, MEM_WB_TYPE;
    reg [31:0] EX_MEM_IR, EX_MEM_ALUOUT, EX_MEM_B;
    reg EX_MEM_COND; // For jump and call instructions
    reg [31:0] MEM_WB_IR, MEM_WB_ALUOUT, MEM_WB_LMD;

    reg [31:0] REG [0:31]; // 32-bit register bank with 32 different registers
    reg [31:0] MEM [0:1023]; // 32-bit memory with 1024 locations

    parameter ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011, SLT = 6'b000100,
    MUL = 6'b000101, HLT = 6'b111111, LW = 6'b001000, SW = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011,
    SLTI = 6'b001100, BNEQZ = 6'b001101, BEQZ = 6'b001110;

    parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;

    reg HALTED; // Status for halt instruction

    reg TAKEN_BRANCH; // Status for branch instruction

    //imp IF Stage
    always@(posedge clk1) begin
        if (HALTED == 0) // When halted flag is not set
        begin
            // For jump instructions
            if (((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_COND == 1)) || 
            ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_COND == 0)))
            begin
                IF_ID_IR <= MEM[EX_MEM_ALUOUT];
                TAKEN_BRANCH <= 1'b1;
                IF_ID_NPC <= EX_MEM_ALUOUT + 1; // NPC is essential during branching instruction and pipeline
                PC <= EX_MEM_ALUOUT + 1;
            end
            // For instructions other than jump instruction
            else
            begin
                IF_ID_IR <= MEM[PC];
                IF_ID_NPC <= PC + 1;
                PC <= PC + 1;
            end

        end

    end

    //imp ID Stage
    always@(posedge clk2) begin
        if(HALTED == 0) begin
            if(IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= 0;
            else ID_EX_A <= REG[IF_ID_IR[25:21]]; // rs

            if(IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= 0;
            else ID_EX_B <= REG[IF_ID_IR[20:16]]; // rt

            ID_EX_NPC <= IF_ID_NPC;
            ID_EX_IR <= IF_ID_IR;
            ID_EX_IMM <= {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}}; // Sign extension
            
            case(IF_ID_IR[31:26]) // For opcodes
                
                ADD, SUB, AND, OR, SLT, MUL : ID_EX_TYPE <= RR_ALU;
                ADDI, SUBI, SLTI : ID_EX_TYPE <= RM_ALU;
                LW : ID_EX_TYPE <= LOAD;
                SW : ID_EX_TYPE <= STORE;
                BNEQZ, BEQZ : ID_EX_TYPE <= BRANCH;
                HLT : ID_EX_TYPE <= HALT;
                default : ID_EX_TYPE <= HALT; // Invalid opcode
                
            endcase

        end

    end

    //imp EX Stage
    // The ALU is inbuilt in this stage
    always@(posedge clk1) begin // This stage is important from logical point of view
        if(HALTED == 0) begin
            EX_MEM_TYPE <= ID_EX_TYPE;
            EX_MEM_IR <= ID_EX_IR;
            TAKEN_BRANCH <= 0;

            case(ID_EX_TYPE)

                RR_ALU : begin
                    case(ID_EX_IR[31:26]) // opcode
                        ADD : EX_MEM_ALUOUT <= ID_EX_A + ID_EX_B;
                        SUB : EX_MEM_ALUOUT <= ID_EX_A - ID_EX_B;
                        AND : EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;
                        OR : EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;
                        SLT : EX_MEM_ALUOUT <= ID_EX_A < ID_EX_B;
                        MUL : EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;
                        default : EX_MEM_ALUOUT <= 32'd0;
                    endcase
                end

                RM_ALU : begin
                    case (ID_EX_IR[31:26]) // opcode
                        ADDI : EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                        SUBI : EX_MEM_ALUOUT <= ID_EX_A - ID_EX_IMM;
                        SLTI : EX_MEM_ALUOUT <= ID_EX_A < ID_EX_IMM;
                        default : EX_MEM_ALUOUT <= 32'd0;
                    endcase
                end

                LOAD, STORE : begin
                    EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                    EX_MEM_B <= ID_EX_B;
                end

                BRANCH : begin
                    EX_MEM_ALUOUT <= ID_EX_NPC + ID_EX_IMM;
                    EX_MEM_COND <= (ID_EX_A == 0);
                end

            endcase

        end

    end

    //imp Memory Stage
    always@(posedge clk2) begin
        if(HALTED == 0) begin
            MEM_WB_TYPE <= EX_MEM_TYPE;
            MEM_WB_IR <= EX_MEM_IR;

            case(EX_MEM_TYPE)

                RR_ALU, RM_ALU : MEM_WB_ALUOUT <= EX_MEM_ALUOUT;

                LOAD : MEM_WB_LMD <= MEM[EX_MEM_ALUOUT];

                STORE : if(TAKEN_BRANCH == 0) begin MEM[EX_MEM_ALUOUT] <= EX_MEM_B; end

            endcase

        end

    end

    //imp WB Stage
    always@(posedge clk1) begin
        if(TAKEN_BRANCH == 0) begin
            case(MEM_WB_TYPE)

                RR_ALU : REG[MEM_WB_IR[15:11]] <= MEM_WB_ALUOUT; // rs

                RM_ALU : REG[MEM_WB_IR[20:16]] <= MEM_WB_ALUOUT; // rt

                LOAD : REG[MEM_WB_IR[20:16]] <= MEM_WB_LMD; // rt

                HALT : HALTED <= 1'b1;

            endcase

        end

    end

endmodule
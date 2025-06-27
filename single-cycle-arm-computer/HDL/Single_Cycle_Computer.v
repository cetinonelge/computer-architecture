module Single_Cycle_Computer (
    input         clk,
    input         reset,
    input  [3:0]  debug_reg_select,
    output [31:0] debug_reg_out,
    output [31:0] PC
);

    // ------------------------------------------------------
    // Control and Status Wires
    // ------------------------------------------------------
    wire         ALUSrc, MemWrite, RegWrite, PCSrc, MemtoReg;
    wire [2:0]   RegSrc;
    wire [1:0]   ImmSrc;
    wire [3:0]   ALUControl;
    wire         CO, OVF, N, Z, C_In;
    wire [1:0]   Shifter_control;
    wire [4:0]   shamt;
    wire [31:0]  Instruction;

    // ------------------------------------------------------
    // Datapath Instantiation
    // ------------------------------------------------------
    Datapath my_datapath (
        .clk              (clk),
        .reset            (reset),
        .ALUSrc           (ALUSrc),
        .MemWrite         (MemWrite),
        .RegWrite         (RegWrite),
        .PCSrc            (PCSrc),
        .MemtoReg         (MemtoReg),
        .RegSrc           (RegSrc),
        .ImmSrc           (ImmSrc),
        .ALUControl       (ALUControl),
        .CO               (CO),
        .OVF              (OVF),
        .N                (N),
        .Z                (Z),
        .C_In             (C_In),
        .Shifter_control  (Shifter_control),
        .shamt            (shamt),
        .debug_reg_select (debug_reg_select),
        .debug_reg_out    (debug_reg_out),
        .PC               (PC),
        .Instruction      (Instruction)
    );

    // ------------------------------------------------------
    // Controller Instantiation
    // ------------------------------------------------------
    Controller my_controller (
        .clk               (clk),
        .reset             (reset),
        .Op                (Instruction[27:26]),
        .Funct             (Instruction[25:20]),
        .Rd                (Instruction[15:12]),
        .Src2              (Instruction[11:0]),
        .Cond              (Instruction[31:28]),
        .CO                (CO),
        .OVF               (OVF),
        .N                 (N),
        .Z                 (Z),
        .RegSrc            (RegSrc),
        .ImmSrc            (ImmSrc),
        .Shifter_control   (Shifter_control),
        .MemtoReg          (MemtoReg),
        .ALUControl        (ALUControl),
        .shamt             (shamt),
        .PCSrc             (PCSrc),
        .ALUSrc            (ALUSrc),
        .C_In              (C_In),
        .RegWrite          (RegWrite),
        .MemWrite          (MemWrite)
    );

endmodule

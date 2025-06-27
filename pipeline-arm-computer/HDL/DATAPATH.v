// -------------------------------------------------------------
// Module: DATAPATH
// Description: 5-stage pipelined CPU datapath.
// -------------------------------------------------------------
module DATAPATH #(parameter WIDTH=32) (
    input                         clk,
    input                         reset,
    // Control signals
    input                         PCSrcW,
    input                         MemtoRegW,
    input                         MemWriteM,
    input                         RegWriteW,
    input                         BranchTakenE,
    input                         shifter_control,
    // Pipeline control
    input                         StallF,
    input                         StallD,
    input                         FlushD,
    input                         FlushE,
    // Forwarding selects
    input       [1:0]             ForwardAE,
    input       [1:0]             ForwardBE,
    // ALU controls
    input       [3:0]             ALUControlE,
    input       [1:0]             ALUSrcE,
    // Immediate & register source selects
    input       [1:0]             ImmSrcD,
    input       [1:0]             RegSrc,
    input                         RegSrcZeroW,
    // Debug interface
    input       [3:0]             debug_reg_sel,
    // Haz outputs
    output      [3:0]             RA1E_Haz,
    output      [3:0]             RA2E_Haz,
    output      [3:0]             RA1D_Haz,
    output      [3:0]             RA2D_Haz,
    output      [3:0]             WA3E_Haz,
    output      [3:0]             WA3M_Haz,
    output      [3:0]             WA3W_Haz,
    // Register file debug output
    output      [WIDTH-1:0]       debug_reg_out,
    // Program counter & flags
    output      [WIDTH-1:0]        PC,
    output                         CO_out,
    output                         OVF_out,
    output                         N_out,
    output                         Z_out,
    // Instruction fields
    output      [3:0]             Cond,
    output      [1:0]             Op,
    output      [5:0]             Funct,
    output      [3:0]             Rd
);

// -------------------------------------------------------------
// Fetch Stage
// -------------------------------------------------------------
wire [WIDTH-1:0] MuxPC_out;
wire [WIDTH-1:0] PC_prime;
wire [WIDTH-1:0] PCF;
wire [WIDTH-1:0] InstructionF;
wire [WIDTH-1:0] PCPlus4;
Mux_2to1 #(.WIDTH(WIDTH)) FMUX_PC(
    .select(PCSrcW), .input_0(PCPlus4), .input_1(ResultW), .output_value(MuxPC_out)
);
Mux_2to1 #(.WIDTH(WIDTH)) FMUX_Branch(
    .select(BranchTakenE), .input_0(MuxPC_out), .input_1(ALUResultE), .output_value(PC_prime)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Fetch_PC(
    .clk(clk), .reset(reset), .we(~StallF), .DATA(PC_prime), .OUT(PCF)
);
Instruction_memory #(.ADDR_WIDTH(8)) IM(
    .ADDR(PCF[7:0]), .RD(InstructionF)
);
Adder #(.WIDTH(WIDTH)) Adder_PC4(
    .DATA_A(PCF), .DATA_B(4), .OUT(PCPlus4)
);

// -------------------------------------------------------------
// Decode Stage
// -------------------------------------------------------------
wire [WIDTH-1:0] PC4D;
wire [WIDTH-1:0] InstructionD;
wire [3:0]        RA1D;
wire [3:0]        RA2D;
wire [3:0]        MUX3_out;
wire [WIDTH-1:0]  WD3;
wire [3:0]        WA3D;
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Decode_InstD(
    .clk(clk), .reset(FlushD), .we(~StallD), .DATA(InstructionF), .OUT(InstructionD)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Decode_PC4D(
    .clk(clk), .reset(FlushD), .we(~StallD), .DATA(PCPlus4), .OUT(PC4D)
);
Mux_2to1 #(.WIDTH(4)) DMUX_RA1(
    .select(RegSrc[0]), .input_0(InstructionD[19:16]), .input_1(4'b1111), .output_value(RA1D)
);
Mux_2to1 #(.WIDTH(4)) DMUX_RA2(
    .select(RegSrc[1]), .input_0(InstructionD[3:0]),  .input_1(InstructionD[15:12]), .output_value(RA2D)
);
//BL MUX
Mux_2to1 #(.WIDTH(4)) DMUX_WA3W(
    .select(RegSrcZeroW), .input_0(WA3W), .input_1(4'b1110), .output_value(MUX3_out)
);
Mux_2to1 #(.WIDTH(WIDTH)) DMUX_WD3(
    .select(RegSrcZeroW), .input_0(ResultW), .input_1(PC4W), .output_value(WD3)
);

// Register file
wire [WIDTH-1:0]  RD1;
wire [WIDTH-1:0]  RD2;
Register_file reg_file_dp(
    .clk(clk), .write_enable(RegWriteW), .reset(reset),
    .Source_select_0(RA1D), .Source_select_1(RA2D),
    .Destination_select(MUX3_out), .Debug_Source_select(debug_reg_sel),
    .DATA(WD3), .Reg_15(PCPlus4),
    .out_0(RD1), .out_1(RD2), .Debug_out(debug_reg_out)
);
Extender EXT(
    .Extended_data(Extend_out), .DATA(InstructionD[23:0]), .select(ImmSrcD)
);

// -------------------------------------------------------------
// Execute Stage
// -------------------------------------------------------------
wire [WIDTH-1:0]  PC4E;
wire [WIDTH-1:0]  RD1E;
wire [WIDTH-1:0]  RD2E;
wire [3:0]        RA1E;
wire [3:0]        RA2E;
wire [3:0]        WA3E;
wire [WIDTH-1:0]  InstructionE;
wire [WIDTH-1:0]  Extend_out;
wire [WIDTH-1:0]  ExtImmE;
wire [WIDTH-1:0]  SrcAE;
wire [WIDTH-1:0]  MuxSrcBOut;
wire [WIDTH-1:0]  SrcBE;
wire [WIDTH-1:0]  ALUResultE;
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Execute_RD1E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(RD1), .OUT(RD1E)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Execute_RD2E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(RD2), .OUT(RD2E)
);
Register_rsten #(.WIDTH(4)) PipeREG_Execute_RA1E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(RA1D), .OUT(RA1E)
);
Register_rsten #(.WIDTH(4)) PipeREG_Execute_RA2E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(RA2D), .OUT(RA2E)
);
Register_rsten #(.WIDTH(4)) PipeREG_Execute_WA3E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(WA3D), .OUT(WA3E)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Execute_InstE(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(InstructionD), .OUT(InstructionE)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Execute_ExtImmE(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(Extend_out), .OUT(ExtImmE)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Execute_PC4E(
    .clk(clk), .reset(FlushE), .we(1'b1), .DATA(PC4D), .OUT(PC4E)
);

Mux_4to1 #(.WIDTH(WIDTH)) EMUX_SrcA(
    .select(ForwardAE), .input_0(RD1E), .input_1(ResultW), .input_2(ALUOutM), .input_3(0), .output_value(SrcAE)
);
Mux_4to1 #(.WIDTH(WIDTH)) EMUX_SrcB_PRE(
    .select(ForwardBE), .input_0(RD2E), .input_1(ResultW), .input_2(ALUOutM), .input_3(0), .output_value(MuxSrcBOut)
);
wire [WIDTH-1:0]  Shifter_out;
Mux_4to1 #(.WIDTH(WIDTH)) EMUX_SrcB(
    .select(ALUSrcE), .input_0(MuxSrcBOut), .input_1(ExtImmE), .input_2(Shifter_out), .input_3(0), .output_value(SrcBE)
);

ALU #(.WIDTH(WIDTH)) Alu(
    .control(ALUControlE), .CI(1'b0), .DATA_A(SrcAE), .DATA_B(SrcBE),
    .OUT(ALUResultE), .CO(CO_out), .OVF(OVF_out), .N(N_out), .Z(Z_out)
);

// Shifter path
wire [WIDTH-1:0]  shifter_input;
wire [4:0]        shifter_shamt;
wire [1:0]        shifter_sh;
Mux_2to1 #(.WIDTH(WIDTH)) EMUX_Shifter_input(
    .select(shifter_control), .input_0(MuxSrcBOut), .input_1(ExtImmE), .output_value(shifter_input)
);
Mux_2to1 #(.WIDTH(5)) EMUX_Shifter_shamt(
    .select(shifter_control), .input_0(InstructionE[11:7]), .input_1({InstructionE[11:8],1'b0}), .output_value(shifter_shamt)
);
Mux_2to1 #(.WIDTH(2)) EMUX_Shifter_sh(
    .select(shifter_control), .input_0(InstructionE[6:5]), .input_1(2'b11), .output_value(shifter_sh)
);
shifter #(.WIDTH(WIDTH)) Shifter(
    .control(shifter_sh), .shamt(shifter_shamt), .DATA(shifter_input), .OUT(Shifter_out)
);

// -------------------------------------------------------------
// Memory Stage
// -------------------------------------------------------------
wire [WIDTH-1:0]  PC4M;
wire [WIDTH-1:0]  ALUOutM;
wire [WIDTH-1:0]  WriteDataE;
wire [WIDTH-1:0]  WD;
wire [3:0]        WA3M;
wire [WIDTH-1:0]  ReadData;
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Memory_ALUOutM(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(ALUResultE), .OUT(ALUOutM)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Memory_WD(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(WriteDataE), .OUT(WD)
);
Register_rsten #(.WIDTH(4)) PipeREG_Memory_WA3M(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(WA3E), .OUT(WA3M)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_Memory_PC4M(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(PC4E), .OUT(PC4M)
);
Memory #(.ADDR_WIDTH(8)) Data_Memory(
    .clk(clk), .WE(MemWriteM), .ADDR(ALUOutM[7:0]), .WD(WD), .RD(ReadData)
);

// -------------------------------------------------------------
// Write-Back Stage
// -------------------------------------------------------------
wire [WIDTH-1:0]  PC4W;
wire [WIDTH-1:0]  ReadDataW;
wire [WIDTH-1:0]  ALUOutW;
wire [3:0]        WA3W;
wire [WIDTH-1:0]  ResultW;
Register_rsten #(.WIDTH(WIDTH)) PipeREG_WB_ReadDataW(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(ReadData), .OUT(ReadDataW)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_WB_ALUOutW(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(ALUOutM), .OUT(ALUOutW)
);
Register_rsten #(.WIDTH(4)) PipeREG_WB_WA3W(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(WA3M), .OUT(WA3W)
);
Register_rsten #(.WIDTH(WIDTH)) PipeREG_WB_PC4W(
    .clk(clk), .reset(reset), .we(1'b1), .DATA(PC4M), .OUT(PC4W)
);
Mux_2to1 #(.WIDTH(WIDTH)) WBMUX_ResultW(
    .select(MemtoRegW), .input_0(ALUOutW), .input_1(ReadDataW), .output_value(ResultW)
);

// Prepare write data for memory stage
assign WriteDataE = MuxSrcBOut;
// Decode write-register
assign WA3D = InstructionD[15:12];

// -------------------------------------------------------------
// Hazard & Instruction field assignments
// -------------------------------------------------------------
assign RA1E_Haz = RA1E;
assign RA2E_Haz = RA2E;
assign RA1D_Haz = RA1D;
assign RA2D_Haz = RA2D;
assign WA3E_Haz = WA3E;
assign WA3M_Haz = WA3M;
assign WA3W_Haz = WA3W;

assign Cond = InstructionD[31:28];
assign Op   = InstructionD[27:26];
assign Funct= InstructionD[25:20];
assign Rd   = InstructionD[15:12];
assign PC   = PCF;

endmodule

module Multi_Cycle_Computer(
	input clk, reset,
	input [3:0] debug_reg_select,
	output [31:0] debug_reg_out,
	output [31:0] fetchPC,
	output [3:0] fsm_state
);

wire PCSrc, PCWrite, AdrSrc, MemWrite, RegWrite, SetFlags, ALUSrcA, IRWrite, Shift_ctrl;
wire [3:0] ALUControl, ALUFlags;
wire [1:0] ALUSrcB, ImmSrc, RegSrc, BL_ctrl, ResultSrc;
wire [31:0] Instr, PC;
assign fetchPC = PC;

// This top-level module connects the DATAPATH and CONTROLLER modules, exposing debug signals and fsm_state.

DATAPATH my_datapath(
    .clk(clk),
    .reset(reset),
    .PCWrite(PCWrite),
    .AdrSrc(AdrSrc),
    .MemWrite(MemWrite),
    .RegWrite(RegWrite),
    .IRWrite(IRWrite),
    .CarryIN(1'b0),
    .SetFlags(SetFlags),
    .ALUSrcA(ALUSrcA),
    .Shift_ctrl(Shift_ctrl),
    .ALUControl(ALUControl),
    .ImmSrc(ImmSrc),
    .RegSrc(RegSrc),
    .BL_ctrl(BL_ctrl),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .debug_reg_select(debug_reg_select),
    .Instr(Instr),
    .ALUFlags(ALUFlags),
    .debug_reg_out(debug_reg_out),
    .PC(PC)
);

// The CONTROLLER module determines control signals for the DATAPATH based on the current instruction and state.

CONTROLLER my_controller (
    .clk(clk),
    .reset(reset),
    .Instr(Instr),
    .PC(PC),
    .ALUFlags(ALUFlags),
    .PCWrite(PCWrite),
    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .IRWrite(IRWrite),
    .AdrSrc(AdrSrc),
    .SetFlags(SetFlags),
    .Shift_ctrl(Shift_ctrl),
    .ResultSrc(ResultSrc),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .ImmSrc(ImmSrc),
    .RegSrc(RegSrc),
    .ALUControl(ALUControl),
    .BL_ctrl(BL_ctrl),
    .fsm_state(fsm_state)
);

endmodule

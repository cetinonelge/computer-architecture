module Controller(
	input clk, reset,
	
	// conditional logic
	input [3:0] Cond,
	input CO, OVF, N, Z,
	
	// decoder signls
	input [1:0] Op,
	input [5:0] Funct,
	input [3:0] Rd,
	
	output PCSrc, RegWrite, MemWrite, MemtoReg, ALUSrc, C_In,
	output [1:0] ImmSrc,
	output [2:0] RegSrc,
	output [3:0] ALUControl,
	
	// shifter signals
	input [11:0] Src2,
	output [4:0] shamt,
	output [1:0] Shifter_control
);
// Controller is split into conditional logic & decoder as the Harris & Harris book did
// signals are named according to the book
wire [1:0] FlagW;
wire PCS, RegW, MemW;

Decoder Controller_Decoder(	.Op(Op),.Funct(Funct),.Rd(Rd),.Src2(Src2),.PCS(PCS),.RegW(RegW),
							.MemW(MemW),.ALUSrc(ALUSrc),.MemtoReg(MemtoReg),.ALUControl(ALUControl),
							.FlagW(FlagW),.RegSrc(RegSrc),.ImmSrc(ImmSrc),.Shifter_control(Shifter_control),.shamt(shamt));

Conditional_Logic Controller_CL( .clk(clk),.reset(reset),.PCS(PCS),.RegW(RegW),.MemW(MemW),.FlagW(FlagW),.Cond(Cond),.ALUFlags({CO,OVF,N,Z}),
								 .C_In(C_In),.PCSrc(PCSrc),.RegWrite(RegWrite),.MemWrite(MemWrite));
								 
endmodule

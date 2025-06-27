module Conditional_Logic(
	input clk, reset,
	input PCS, RegW, MemW,
	input [1:0] FlagW,
	input [3:0] Cond, ALUFlags,
	
	output C_In,
	output PCSrc, RegWrite, MemWrite
);

wire [1:0] FlagWrite;

//	flags
wire CO,OVF,N,Z;
assign C_In = CO;
Register_rsten #(2) Flags3_2 (.clk(clk),.reset(reset),.we(FlagWrite[1]),.DATA(ALUFlags[3:2]),.OUT({CO,OVF}));
Register_rsten #(2) Flags1_0 (.clk(clk),.reset(reset),.we(FlagWrite[0]),.DATA(ALUFlags[1:0]),.OUT({N,Z}));

//	Condition check
Mux_16to1 #(1) Condition_Check( .select(Cond),
								.output_value(CondEx),
								.input_0(Z),
								.input_1(~Z),
								.input_2(CO),
								.input_3(~CO),
								.input_4(N),
								.input_5(~N),
								.input_6(OVF),
								.input_7(~OVF),
								.input_8(CO & ~Z),
								.input_9(~CO | Z),
								.input_10(N ~^ OVF),
								.input_11(N ^ OVF),
								.input_12(~Z & (N ~^ OVF)),
								.input_13(Z | (N ^ OVF)),
								.input_14(1'b1), //always
								.input_15(1'b0)  //unused, given 0 to avoid latches
);

// condex ANDs
assign PCSrc = PCS & CondEx;
assign RegWrite = RegW & CondEx;
assign MemWrite = MemW & CondEx;
assign FlagWrite[0] = FlagW[0] & CondEx;
assign FlagWrite[1] = FlagW[1] & CondEx;

endmodule

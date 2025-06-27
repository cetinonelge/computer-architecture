module Datapath#(parameter DATA_WIDTH=32)
	  (
		input clk, reset,
		
		//	Control unit signals
		input PCSrc, MemtoReg, MemWrite,
		input [3:0] ALUControl,
		input ALUSrc,
		input [1:0] ImmSrc,
		input RegWrite,
		input [2:0] RegSrc, // increased for extra mux
		
		//	Shifter signals
		input [1:0] Shifter_control,
		input [4:0] shamt,
		
		//	ALU related signals
		input C_In,
		output CO, OVF, N, Z,
		
		//	debug signals
		input [3:0] debug_reg_select,
		output [DATA_WIDTH-1:0] debug_reg_out, PC, Instruction
		);

//	1-Fetch
wire [DATA_WIDTH-1:0] PCPrime, PCPlus4;
Register_rsten_neg #(DATA_WIDTH) Register1_PC (.clk(clk),.reset(reset),.we(1'b1),.DATA(PCPrime),.OUT(PC));	
Adder #(DATA_WIDTH) Adder1_PCPlus4 (.DATA_A(PC),.DATA_B(32'd4),.OUT(PCPlus4));
Instruction_memory #(.BYTE_SIZE (4),.ADDR_WIDTH(DATA_WIDTH)) IM_combinational (.ADDR(PC), .RD(Instruction));

//	2-Decode
wire [3:0] Rn = Instruction[19:16];
wire [3:0] Rm = Instruction[3:0];
wire [3:0] Rd = Instruction[15:12];
wire [3:0] RA1,RA2;
Mux_2to1 #(4) Mux1_RA1 (.input_0(Rn),.input_1(4'd15),.select(RegSrc[0]),.output_value(RA1));	
Mux_2to1 #(4) Mux2_RA2 (.input_0(Rm),.input_1(Rd),.select(RegSrc[1]),.output_value(RA2));

wire [DATA_WIDTH-1:0] PCPLus8;
Adder #(DATA_WIDTH) Adder2_PCPlus8 (.DATA_A(PCPlus4),.DATA_B(32'd4),.OUT(PCPLus8));

wire [DATA_WIDTH-1:0] RD1, RD2, WD3;
wire [3:0] WA3; // BL EDITED MUX
Mux_2to1 #(32) Mux3_BL (.input_0(Result),.input_1(PCPlus4),.select(RegSrc[2]),.output_value(WD3));
Mux_2to1 #(4) Mux4_RA3(.input_0(Rd),.input_1(4'd14),.select(RegSrc[2]),.output_value(WA3));
Register_file #(DATA_WIDTH) RF ( .clk(clk),.write_enable(RegWrite),.reset(reset),.Source_select_0(RA1),
								 .Source_select_1(RA2),.Debug_Source_select(debug_reg_select),.Destination_select(WA3),.DATA(WD3),
								 .Reg_15(PCPLus8),.out_0(RD1),.out_1(RD2),.Debug_out(debug_reg_out));

// Extender
wire [23:0] ExtendInput = Instruction[23:0];
wire [DATA_WIDTH-1:0] ExtImm;
Extender Extend_Imm (.DATA(ExtendInput),.Extended_data(ExtImm),.select(ImmSrc));

//	3-Execute
wire [DATA_WIDTH-1:0] SrcA = RD1;
wire [DATA_WIDTH-1:0] ALUResult, SrcB;
wire [DATA_WIDTH-1:0] ALUShifter;
Mux_2to1 #(DATA_WIDTH) Mux5_SrcB (.input_0(RD2),.input_1(ExtImm),.select(ALUSrc),.output_value(ALUShifter));
shifter #(DATA_WIDTH) shifter_ep(.control(Shifter_control),.shamt(shamt),.DATA(ALUShifter),.OUT(SrcB));
ALU #(DATA_WIDTH) Alu (.control(ALUControl),.CI(C_In),.DATA_A(SrcA),.DATA_B(SrcB),.OUT(ALUResult),.CO(CO),.OVF(OVF),.N(N),.Z(Z));

//	4-Memory
wire [DATA_WIDTH-1:0] ReadData;
wire [DATA_WIDTH-1:0] WriteData = RD2;
Memory #(.BYTE_SIZE (4),.ADDR_WIDTH(DATA_WIDTH)) Data_memory (.clk(clk),.WE(MemWrite),.ADDR(ALUResult),.WD(WriteData),.RD(ReadData));

//	5-Write Back Stage
wire [DATA_WIDTH-1:0]  Result;
Mux_2to1 #(DATA_WIDTH) Mux6_Registerback (.input_0(ALUResult),.input_1(ReadData),.select(MemtoReg),.output_value(Result));
Mux_2to1 #(DATA_WIDTH) Mux7_PCback (.input_0(PCPlus4),.input_1(Result),.select(PCSrc),.output_value(PCPrime));

endmodule
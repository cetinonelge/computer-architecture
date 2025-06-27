module DATAPATH #(parameter DATA_WIDTH = 32)
(
	input clk, reset, 
	input PCWrite, AdrSrc, MemWrite, IRWrite, CarryIN, SetFlags, Shift_ctrl,
	input [1:0] ResultSrc,
	input [3:0] ALUControl,
	input [1:0] ALUSrcB,
	input ALUSrcA,
	input [1:0] ImmSrc,
	input RegWrite,
	input [1:0] RegSrc,
	input [1:0] BL_ctrl,
	input [3:0] debug_reg_select,

	output [31:0] Instr,
	output [3:0] ALUFlags,
	output [DATA_WIDTH-1:0] debug_reg_out,
	output [DATA_WIDTH-1:0] PC
);

// 1- Fetch
wire [DATA_WIDTH-1:0] Result, Adr, WriteData, ReadData, Data;
Register_rsten_neg #(DATA_WIDTH) Register1_PC (.clk(clk),.reset(reset),.we(PCWrite),.DATA(Result),.OUT(PC));
Mux_2to1 #(DATA_WIDTH) Mux1_Adr (.input_0(PC),.input_1(Result),.select(AdrSrc),.output_value(Adr));		
ID_memory #(4,8) IDM(.clk(clk), .WE(MemWrite),.ADDR(Adr[7:0]), .WD(WriteData), .RD(ReadData));
Register_rsten_neg #(DATA_WIDTH) Register2_Instr(.clk(clk), .reset(reset), .we(IRWrite), .DATA(ReadData), .OUT(Instr));
Register_rsten_neg #(DATA_WIDTH) Register3_Data(.clk(clk), .reset(reset), .we(1'b1), .DATA(ReadData), .OUT(Data));

// 2- Decode
wire [3:0] RA1, RA2, WA3;
wire [DATA_WIDTH-1:0] WD3;
Mux_2to1 #(4) Mux2_RA1(.select(RegSrc[0]), .input_0(Instr[19:16]), .input_1(4'd15), .output_value(RA1));
Mux_2to1 #(4) Mux3_RA2(.select(RegSrc[1]), .input_0(Instr[3:0]), .input_1(Instr[15:12]), .output_value(RA2));
Mux_2to1 #(4) Mux4_WA3(.select(BL_ctrl[0]), .input_0(Instr[15:12]), .input_1(4'd14), .output_value(WA3));
Mux_2to1 #(DATA_WIDTH) Mux5_BL(.select(BL_ctrl[1]), .input_0(Result), .input_1(PC), .output_value(WD3));

wire [DATA_WIDTH-1:0] RD1, RD2, A;
Register_file reg_file_dp(.clk(clk), .write_enable(RegWrite), .reset(reset),
	.Source_select_0(RA1), .Source_select_1(RA2), .Destination_select(WA3),
	.Debug_Source_select(debug_reg_select), .DATA(WD3), .Reg_15(Result), 
	.out_0(RD1), .out_1(RD2), .Debug_out(debug_reg_out));
	
Register_rsten_neg #(DATA_WIDTH) Register2_RD1(.clk(clk), .reset(reset), .we(1'b1), .DATA(RD1), .OUT(A));
Register_rsten_neg #(DATA_WIDTH) Register3_RD2(.clk(clk), .reset(reset), .we(1'b1), .DATA(RD2), .OUT(WriteData));

wire [DATA_WIDTH-1:0] ExtImm;
Extender Extend(.Extended_data(ExtImm), .DATA(Instr[23:0]), .select(ImmSrc)) ;

// Shifter
wire [1:0] sh;
wire [4:0] shamt5;
wire [DATA_WIDTH-1:0] shifter_input, shifted_data;
Mux_2to1 #(2) Mux6_Shifter1(.select(Shift_ctrl), .input_0(Instr[6:5]),
    	.input_1(2'b11), .output_value(sh));
Mux_2to1 #(5) Mux7_Shifter2(.select(Shift_ctrl), .input_0(Instr[11:7]),
   		.input_1({Instr[11:8], 1'b0}), .output_value(shamt5));
Mux_2to1 #(DATA_WIDTH) Mux7_Shifter3(.select(Shift_ctrl), .input_0(WriteData), 
		.input_1(ExtImm), .output_value(shifter_input));
shifter #(DATA_WIDTH) shifter_all(
    .control(sh),
    .shamt(shamt5),
    .DATA(shifter_input),
    .OUT(shifted_data)
);

// 3- Execute stage
wire [DATA_WIDTH-1:0] SrcA, SrcB, ALUResult, ALUOut;
Mux_2to1 #(DATA_WIDTH) Mux8_SrcA(.select(ALUSrcA), .input_0(A), .input_1(PC), .output_value(SrcA));
Mux_4to1 #(DATA_WIDTH) Mux9_SrcB(.select(ALUSrcB), .input_0(WriteData), .input_1(ExtImm),
	.input_2(32'd4), .input_3(shifted_data), .output_value(SrcB)) ;

wire Z, N, CO, OVF;	
ALU #(DATA_WIDTH) Alu(.control(ALUControl), .CI(CarryIN), .DATA_A(SrcA), .DATA_B(SrcB),
	.OUT(ALUResult), .CO(CO), .OVF(OVF), .N(N), .Z(Z));

Register_rsten_neg#(4) Register4_ALUFlags(clk, reset, SetFlags, {Z, N, CO, OVF}, ALUFlags);
Register_rsten_neg #(DATA_WIDTH) Register5_ALU(.clk(clk), .reset(reset), .we(1'b1), .DATA(ALUResult), .OUT(ALUOut));
	
Mux_4to1 #(DATA_WIDTH) Mux11_Result(.select(ResultSrc), .input_0(ALUOut), .input_1(Data), 
						   .input_2(ALUResult), .input_3(32'd0), .output_value(Result));

endmodule

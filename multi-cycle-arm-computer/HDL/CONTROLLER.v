	// This module implements the controller for a multi-cycle CPU. It determines the next FSM
	// state based on the current state, instruction fields, and condition flags, then sets the 
	// appropriate control signals for each stage.
	module CONTROLLER(
		input clk, reset,
		input [31:0] Instr, PC,
		input [3:0] ALUFlags,
		
		output reg PCWrite, RegWrite, MemWrite, IRWrite, AdrSrc, SetFlags, Shift_ctrl,
		output reg [1:0] ResultSrc,
		output reg ALUSrcA,
		output reg [1:0] ALUSrcB, ImmSrc, RegSrc,
		output reg [3:0] ALUControl,
		output reg [1:0] BL_ctrl,
		output [3:0] fsm_state
	);

	localparam ADD = 4'b0100,
			 SUB = 4'b0010,
			 AND = 4'b0000,
			 ORR = 4'b1100,
			 MOV = 4'b1101,
			 CMP = 4'b1010,
			 STR = 4'b1010;

	localparam Fetch      = 4'd0,
			 Decode        = 4'd1,
			 MemAdr        = 4'd2,
			 MemRead       = 4'd3,
			 MemWB         = 4'd4,
			 MemWrite_state= 4'd5,
			 ExecuteR      = 4'd6,
			 Executel      = 4'd7,
			 ALUWB         = 4'd8,
			 Branch        = 4'd9,
			 BL            = 4'd10,
			 BX            = 4'd11;

	// These wires extract fields from the instruction. Cond, Op, Funct, and Rd help
	// decide the next state and control signals.
	wire [3:0] Cond = Instr[31:28];
	wire [1:0] Op   = Instr[27:26];
	wire [5:0] Funct= Instr[25:20];
	wire [3:0] Rd   = Instr[15:12];

	reg [3:0] next_fsm_state;

	// This wire encodes both the next state (bits [5:2]) and a register source code (bits [1:0]),
	// determined by condition checks and the instruction opcode.
	wire [5:0] decode_out;
	assign decode_out = (Cond == 4'b0000 && ALUFlags[3]) ? (
							(Op == 2'b00) ? {4'd6, 2'b00} :
							(Op == 2'b01) ? {4'd2, 2'b00} :
							(Op == 2'b10) ? {4'd9, 2'b01} : {4'd0, 2'b00}
						) : ( (Cond == 4'b0001 && ~ALUFlags[3]) ? (
							(Op == 2'b00) ? {4'd6, 2'b00} :
							(Op == 2'b01) ? {4'd2, 2'b00} :
							(Op == 2'b10) ? {4'd9, 2'b01} : {4'd0, 2'b00}
						) : ( (Cond == 4'b1110) ? (
							(Op == 2'b00) ? {4'd6, 2'b00} :
							(Op == 2'b01) ? {4'd2, 2'b00} :
							(Op == 2'b10) ? {4'd9, 2'b01} : {4'd0, 2'b00}
						) : {4'd0, 2'b00} ));

	reg [3:0] CS;
	Register_rsten_neg #(4) FSM_Reg (
		.clk(clk),
		.reset(reset),
		.we(1'b1),
		.DATA(next_fsm_state),
		.OUT(fsm_state)
	);

	always @(posedge clk) begin
		if(reset)
			CS <= Fetch;
		else
			CS <= next_fsm_state;
	end  

	// The main FSM uses the current state (CS) to decide how to set control signals,
	// then calculates next_fsm_state. Each state corresponds to a cycle in the multi-cycle CPU.
	always @(*) begin
		case(CS)
		Fetch: begin
			AdrSrc = 1'b0;
			ALUSrcA = 1'b1;
			ALUSrcB = 2'b10;
			ALUControl = ADD;
			ResultSrc = 2'b10;
			IRWrite = 1'b1;
			PCWrite = 1'b1;
			MemWrite = 1'b0;
			RegWrite = 1'b0;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			RegSrc = 2'b00;
			ImmSrc = 2'b00;
			Shift_ctrl = 1'b0;
			next_fsm_state = Decode;
		end
		Decode: begin
			next_fsm_state = decode_out[5:2];
			RegSrc         = decode_out[1:0];
			AdrSrc = 1'b0;
			ALUSrcA = 1'b1;
			ALUSrcB = 2'b10;
			ALUControl = ADD;
			ResultSrc = 2'b10;
			IRWrite = 1'b0;
			PCWrite = 1'b0;
			MemWrite = 1'b0;
			RegWrite = 1'b0;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			ImmSrc = 2'b00;
			Shift_ctrl = 1'b0;
		end
		MemAdr: begin
			if(Instr[20])
				next_fsm_state = MemRead;
			else
				next_fsm_state = MemWrite_state;
			AdrSrc = 1'b1;
			ALUSrcA = 1'b0;
			if(Instr[25])
				ALUSrcB = 2'b11;
			else
				ALUSrcB = 2'b01;
			ALUControl = ADD;
			ResultSrc = 2'b10;
			IRWrite = 1'b0;
			PCWrite = 1'b0;
			MemWrite = 1'b0;
			RegWrite = 1'b0;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			RegSrc = 2'b10;
			ImmSrc = 2'b01;
			Shift_ctrl = 1'b0;
		end
		MemRead: begin
			next_fsm_state = Fetch;
			AdrSrc = 1'b1;
			ALUSrcA = 1'b0;
			if(Instr[25])
				ALUSrcB = 2'b11;
			else
				ALUSrcB = 2'b01;
			ALUControl = ADD;
			ResultSrc = 2'b01;
			IRWrite = 1'b0;
			PCWrite = 1'b0;
			MemWrite = 1'b0;
			RegWrite = 1'b1;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			RegSrc = 2'b10;
			ImmSrc = 2'b01;
			Shift_ctrl = 1'b0;
		end
		MemWrite_state: begin
			next_fsm_state = Fetch;
			AdrSrc = 1'b1;
			ALUSrcA = 1'b0;
			if(Instr[25])
				ALUSrcB = 2'b11;
			else
				ALUSrcB = 2'b01;
			ALUControl = ADD;
			ResultSrc = 2'b00;
			IRWrite = 1'b0;
			PCWrite = 1'b0;
			MemWrite = 1'b1;
			RegWrite = 1'b0;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			RegSrc = 2'b10;
			ImmSrc = 2'b01;
			Shift_ctrl = 1'b0;
		end
		ExecuteR: begin
			next_fsm_state = Fetch;
			AdrSrc = 1'b0;
			ALUSrcA = 1'b0;
			if(Instr[27:4] == 24'b000100101111111111110001) begin
				ALUSrcB = 2'b00;
				PCWrite = 1'b1;
				ALUControl = MOV;
				RegWrite = 1'b0;
			end else begin
				ALUSrcB = 2'b11;
				PCWrite = (&Rd);
				case(Instr[24:21])
				4'b0000: begin
					ALUControl = 4'b0000;
					RegWrite = 1'b1;
				end
				4'b0001: begin
					ALUControl = 4'b0001;
					RegWrite = 1'b1;
				end
				4'b0010: begin
					ALUControl = 4'b0010;
					RegWrite = 1'b1;
				end
				4'b0011: begin
					ALUControl = 4'b0011;
					RegWrite = 1'b1;
				end
				4'b0100: begin
					ALUControl = ADD;
					RegWrite = 1'b1;
				end
				4'b0101: begin
					ALUControl = 4'b0101;
					RegWrite = 1'b1;
				end
				4'b0110: begin
					ALUControl = 4'b0110;
					RegWrite = 1'b1;
				end
				4'b0111: begin
					ALUControl = 4'b0111;
					RegWrite = 1'b1;
				end
				4'b1000: begin
					ALUControl = 4'b0000;
					RegWrite = 1'b0;
				end
				4'b1001: begin
					ALUControl = 4'b0001;
					RegWrite = 1'b0;
				end
				4'b1010: begin
					ALUControl = 4'b0010;
					RegWrite = 1'b0;
				end
				4'b1011: begin
					ALUControl = ADD;
					RegWrite = 1'b0;
				end
				4'b1100: begin
					ALUControl = ORR;
					RegWrite = 1'b1;
				end
				4'b1101: begin
					ALUControl = MOV;
					RegWrite = 1'b1;
				end
				4'b1110: begin
					ALUControl = 4'b1110;
					RegWrite = 1'b1;
				end
				4'b1111: begin
					ALUControl = 4'b1111;
					RegWrite = 1'b1;
				end
				default: begin
					ALUControl = ADD;
					RegWrite = 1'b0;
				end
				endcase
			end
			ResultSrc = 2'b10;
			IRWrite = 1'b0;
			MemWrite = 1'b0;
			SetFlags = Instr[20];
			BL_ctrl = 2'b00;
			RegSrc = 2'b00;
			ImmSrc = 2'b00;
			Shift_ctrl = Instr[25];
		end
		Branch: begin
			next_fsm_state = Fetch;
			AdrSrc = 1'b0;
			IRWrite = 1'b0;
			PCWrite = 1'b1;
			MemWrite = 1'b0;
			SetFlags = 1'b0;
			RegSrc = 2'b01;
			ImmSrc = 2'b10;
			Shift_ctrl = 1'b0;
			ALUSrcA = 1'b0;
			ALUSrcB = 2'b01;
			ALUControl = ADD;
			ResultSrc = 2'b10;
			RegWrite = Instr[24];
			BL_ctrl = {2{Instr[24]}};
		end
		default: begin
			next_fsm_state = Fetch;
			AdrSrc = 1'b0;
			ALUSrcA = 1'b1;
			ALUSrcB = 2'b10;
			ALUControl = ADD;
			ResultSrc = 2'b10;
			IRWrite = 1'b0;
			PCWrite = 1'b0;
			MemWrite = 1'b0;
			RegWrite = 1'b0;
			SetFlags = 1'b0;
			BL_ctrl = 2'b00;
			RegSrc = 2'b00;
			ImmSrc = 2'b00;
			Shift_ctrl = 1'b0;
		end
		endcase
	end

endmodule

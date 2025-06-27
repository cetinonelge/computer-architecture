module Decoder(
	input [1:0] Op,
	input [5:0] Funct,
	input [3:0] Rd,
	
	output reg PCS, RegW, MemW, MemtoReg, ALUSrc,
	output reg [2:0] RegSrc,
	output reg [1:0] ImmSrc, FlagW,
	output reg [3:0] ALUControl,
	
	// shifter signals
	input [11:0] Src2,
	output reg [1:0] Shifter_control,
	output reg [4:0] shamt
);

// Main Decoder
always @(*) case (Op)
	2'b00: begin
		// 1) Check for BX (branch and exchange) if needed
		if ((Funct == 6'b010010) && (Rd == 4'b1111)) begin
			// BX operation
			PCS             = 1'b1;
			RegW            = 1'b0;
			MemW            = 1'b0;
			ALUSrc          = 1'b0;
			ALUControl      = 4'b1101; // Pass operand through (like MOV)
			FlagW           = 2'b00;
			RegSrc          = 3'b000;
			ImmSrc          = 2'b00;
			MemtoReg        = 1'b0;
			Shifter_control = 2'b00;
			shamt           = 5'b00000;
		end
		else begin
			// 2) Data‐processing instructions (ADD, SUB, AND, ORR, MOV, CMP)
			//    excluding other "test" ops like TST, TEQ, CMN, etc.

			MemW     = 1'b0;       // No memory writes here
			RegSrc   = 3'b000;
			ImmSrc   = 2'b00;
			MemtoReg = 1'b0;

			// ALUSrc is set by the immediate bit (Funct[5]):
			//  - 0 => second operand is register (Rm) possibly shifted
			//  - 1 => second operand is a rotated immediate
			ALUSrc = Funct[5];

			// Default: do not update flags (except for CMP, which sets them)
			FlagW = 2'b00;
			RegW  = 1'b1; // Most instructions write a result unless it's CMP

			// Pick the ALU operation based on bits [4:1] of Funct
			case (Funct[4:1])
				4'b0000: ALUControl = 4'b0000; // AND
				4'b1100: ALUControl = 4'b1100; // ORR
				4'b0100: ALUControl = 4'b0100; // ADD
				4'b0010: ALUControl = 4'b0010; // SUB
				4'b1101: begin
					// MOV => pass operand B (register or immediate)
					ALUControl = 4'b1101; // pass B
					// RegW remains 1, so Rd is updated
					// Typically MOV doesn't set flags (unless your design says MOVS)
				end
				4'b1010: begin
					// CMP => a SUB that updates flags and does NOT write Rd
					ALUControl = 4'b0010; // subtract
					RegW       = 1'b0;    // no register write
					FlagW      = 2'b01;   // set condition flags
				end
				default: ALUControl = 4'bxxxx; // not used
			endcase

			// If writing to R15 (PC) and RegW=1, treat it as a PC update (e.g., MOV PC, Rx)
			PCS = (&Rd) & RegW;

			// 3) Shifter configuration
			//    If immediate bit is set => rotate immediate
			//    else => shift register operand
			if (Funct[5]) begin
				// "rot-imm8" type operand
				Shifter_control = 2'b11;
				// Often in ARM, the rotate amount is in bits [11:8], plus a '0' bit
				shamt = {Src2[11:8], 1'b0};
			end
			else begin
				// Register shift: bits [6:5] => shift type, [11:7] => shift amount
				Shifter_control = Src2[6:5];
				shamt           = Src2[11:7];
			end
		end
	end

	2'b01: begin
		// memory
		PCS	   = 0;
		RegW   = Funct[0];
		MemW   = ~Funct[0];
		MemtoReg  = Funct[0];
		ALUSrc     = 1;
		ImmSrc     = 2'b01;
		RegSrc     = 3'b010;
		ALUControl = Funct[3] ? 4'b0100 : 4'b0010; // check for U, 1->add
		FlagW  = 2'b00;
		// shifter no use here
		Shifter_control = 2'b00;
		shamt        = 5'b00000;
	end
	2'b10: begin
		// branch
		PCS	   = 1;
		RegW   = Funct[4]; // BL
		MemW   = 0;
		MemtoReg  =  0;
		ALUSrc     = 1;
		ImmSrc     = 2'b10;
		RegSrc     = {Funct[4], 2'b01}; // BL R14 WRITE SIGNAL
		ALUControl = 4'b0100; // add
		FlagW  = 2'b00;
		// shifter no use here
		Shifter_control = 2'b00;
		shamt        = 5'b00000;
	end
	default: begin
		// to avoid latches
		PCS	   = 0;
		RegW   = 0;
		MemW   = 0;
		MemtoReg  = 0;
		ALUSrc     = 0;
		ImmSrc     = 2'bXX;
		RegSrc     = 3'bXXX;
		ALUControl = 4'bXXXX;
		FlagW  = 2'bXX;
		// shifter
		Shifter_control = 2'bXX;
		shamt        = 5'bXXXXX;
	end
endcase

endmodule

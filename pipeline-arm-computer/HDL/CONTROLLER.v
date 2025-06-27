// CONTROLLER.v: Pipeline controller for ARM-like datapath
// Handles decode, execute, memory, and writeback stages,
// including Hazard signaling, branching, and control signal generation.

module CONTROLLER #(parameter WIDTH = 32    // Data path width (bits)
)(
    // Clock and reset signals
    input              clk,        // Global clock
    input              reset,      // Global reset for Memory/Writeback pipelines
    input              FlushE,     // Flush signal for Execute pipeline register

    // Condition flags from ALU stage
    input              CO_Flag,    // Carry-out flag
    input              OVF_Flag,   // Overflow flag
    input              Z_Flag,     // Zero flag
    input              N_Flag,     // Negative flag

    // Instruction fields
    input [3:0]        Cond,       // Condition code field
    input [1:0]        Op,         // Opcode type (00: DP, 01: Mem, 10: Branch)
    input [5:0]        Funct,      // Function/operation field
    input [3:0]        Rd,         // Destination register

    // Outputs to pipeline stages and Hazard unit
    output reg         BranchTakenE,      // Branch taken flag at Execute stage
    output             MemWriteM,         // Memory write enable at Memory stage
    output             MemtoRegW,         // Select memory data for writeback
    output             MemtoRegE_Haz,  // Hazard signal: memory-to-reg at Execute
    output             RegWriteW,         // Register write enable at Writeback
    output             RegWriteM_Haz,  // Hazard signal: reg-write at Memory
    output             PCSrcW,            // PC select at Writeback (for branch-retire)
    output             RegSrcZeroW,       // Reg source zero (forwarding) at Writeback
    output [3:0]       ALUControlE_out,   // ALU control signals forwarded from Execute
    output [1:0]       ALUSrcE_out,       // ALU source select forwarded from Execute
    output reg [1:0]   ImmSrcD,           // Immediate extraction control in Decode
    output [1:0]       RegSrc,            // Register source select in Decode
    output             shifter_control,             // Shift control at Execute stage
    output             PCSrcD_Haz,     // Hazard: PCSrc in Decode
    output             PCSrcE_Haz,     // Hazard: PCSrc in Execute
    output             PCSrcM_Haz     // Hazard: PCSrc in Memory
);

//====================================================================
// Local parameters: ALU operation encodings (4-bit)
//====================================================================
localparam ADD = 4'b0100,
           SUB = 4'b0010,
           AND = 4'b0000,
           ORR = 4'b1100,
           MOV = 4'b1101,
           CMP = 4'b1010,
           STR = 4'b1010;

//====================================================================
// Internal signals: pipeline latches, control wires, flags
//====================================================================
wire       PCSrcE, BranchE;    // Signals in Execute stage
wire       MemtoRegE, MemWriteE, RegWriteE, FlagWriteE;
wire [3:0] CondE;              // Condition code latched into Execute
wire       RegSrcZeroE;        // Forwarding zero-source flag
wire       Flags;              // Selected condition flag for comparisons
wire       FlagsE;             // Latched Flags value into Execute
wire [3:0] ALUControlE;        // ALU control latched into Execute
wire [1:0] ALUSrcE;            // ALU source select latched into Execute

// Decode stage registers
reg        BranchD, MemtoRegD, MemWriteD, RegWriteD, PCSrcD;
reg        FlagWriteD, shifter_controlD;
reg [3:0]  ALUControlD;
reg [1:0]  ALUSrcD;
reg [1:0]  RegSrcD;

//====================================================================
// 1) Evaluate whether the ARM condition code passes, given Z‑flag.
//    AL (1110) always passes; EQ (0000) if Z==1; NE (0001) if Z==0.
//====================================================================
reg condOK;
always @(*) begin
    case (CondE)
        4'b1110:      condOK = 1'b1;       // AL: always
        4'b0000:      condOK = Flags;      // EQ: zero?
        4'b0001:      condOK = ~Flags;     // NE: not zero?
        default:      condOK = 1'b0;       // others: disable
    endcase
end

// Conditional enables (after checking condition codes)
reg        PCSrcE_conditional, RegWriteE_conditional, MemWriteE_conditional;
wire       PCSrcE_conditionalWire, RegWriteE_conditionalWire, MemWriteE_conditionalWire;

//====================================================================
// 2) Apply the gating to each pipeline‑E control signal
//    If condOK==0, everything is forced low; else forward original.
//====================================================================
always @(*) begin
    PCSrcE_conditional    = PCSrcE    & condOK;
    MemWriteE_conditional = MemWriteE & condOK;
    RegWriteE_conditional = RegWriteE & condOK;
    BranchTakenE  = BranchE   & condOK;
end


//====================================================================
// Decode stage: generate control signals based on Op, Funct, and Rd
//====================================================================
always @(*) begin
    case (Op)
    2'b00: begin  // Data-processing instructions
    // ===== BX: branch and exchange =====
    if ({Funct, Rd} == 10'b010010_1111) begin
        RegSrcD     = 2'b00;
        MemtoRegD   = 1'b0;
        MemWriteD   = 1'b0;
        ALUControlD = MOV;      // use MOV localparam
        ALUSrcD     = 2'b00;    // select Rm
        ImmSrcD     = 2'b00;
        RegWriteD   = 1'b0;
        shifter_controlD      = 1'b0;
        FlagWriteD  = 1'b0;
        BranchD     = 1'b1;
        PCSrcD      = 1'b0;
    end
    else begin
        // ===== Standard DP: decode Funct[4:1] =====
        case (Funct[4:1])
            ADD: begin
            // defaults:
            RegSrcD           = 2'b00;
            MemtoRegD         = 1'b0;
            MemWriteD         = 1'b0;
            ImmSrcD           = 2'b00;
            shifter_controlD  = 1'b0;
            FlagWriteD        = 1'b0;
            BranchD           = 1'b0;
            PCSrcD            = 1'b0;
            RegWriteD         = 1'b0;

            // Now distinguish register‑(I=0) vs immediate‑(I=1) ADD:
            if (Funct[5] == 1'b0) begin
                // Register‑operand ADD
                ALUControlD = ADD;     // localparam for addition
                ALUSrcD     = 2'b10;   // choose Rm (through shifter bypass)
                RegWriteD   = 1'b1;    // write result
            end else begin
                // Immediate‑operand path (as in your original snippet)
                ALUControlD = AND;     // (!!) per original code
                ALUSrcD     = 2'b00;   // select immediate extender directly
                // RegWriteD remains 0 here
            end
        end

            SUB: begin
            // default safe values
            RegSrcD          = 2'b00;
            MemtoRegD        = 1'b0;
            MemWriteD        = 1'b0;
            ImmSrcD          = 2'b00;
            shifter_controlD = 1'b0;
            FlagWriteD       = 1'b0;
            BranchD          = 1'b0;
            PCSrcD           = 1'b0;
            RegWriteD        = 1'b0;  // will enable for register form

            if (Funct[5] == 1'b0) begin
                ALUControlD = SUB;   // register‑operand subtract
                ALUSrcD     = 2'b10;
                RegWriteD   = 1'b1;
            end else begin
                ALUControlD = AND;   // immediate‑operand Uses AND per original
                ALUSrcD     = 2'b00;
            end
        end

            AND: begin
            // default safe values
            RegSrcD          = 2'b00;
            MemtoRegD        = 1'b0;
            MemWriteD        = 1'b0;
            ImmSrcD          = 2'b00;
            shifter_controlD = 1'b0;
            FlagWriteD       = 1'b0;
            BranchD          = 1'b0;
            PCSrcD           = 1'b0;
            RegWriteD        = 1'b0;  // only register form writes

            if (Funct[5] == 1'b0) begin
                ALUControlD = AND;   // register‑operand AND
                ALUSrcD     = 2'b10;
                RegWriteD   = 1'b1;
            end else begin
                ALUControlD = AND;   // immediate‑operand AND
                ALUSrcD     = 2'b00;
            end
        end

            ORR: begin
            // defaults
            RegSrcD          = 2'b00;
            MemtoRegD        = 1'b0;
            MemWriteD        = 1'b0;
            ImmSrcD          = 2'b00;
            shifter_controlD = 1'b0;
            FlagWriteD       = 1'b0;
            BranchD          = 1'b0;
            PCSrcD           = 1'b0;
            RegWriteD        = 1'b0;  // only register form writes

            if (Funct[5] == 1'b0) begin
                ALUControlD = ORR;   // register‑operand OR
                ALUSrcD     = 2'b10;
                RegWriteD   = 1'b1;
            end else begin
                ALUControlD = AND;   // immediate path as per original
                ALUSrcD     = 2'b00;
            end
        end

            MOV: begin
            // defaults
            RegSrcD          = 2'b00;
            MemtoRegD        = 1'b0;
            MemWriteD        = 1'b0;
            ImmSrcD          = 2'b00;
            ALUSrcD          = 2'b10;  // use shifter path
            shifter_controlD = 1'b0;
            FlagWriteD       = 1'b0;
            BranchD          = 1'b0;
            PCSrcD           = 1'b0;
            RegWriteD        = 1'b0;   // enabled below

            if (Rd == 4'd15) begin
                // MOV to PC via immediate or register
                ALUControlD     = MOV;
                RegWriteD       = 1'b1;
                PCSrcD          = 1'b1;
                shifter_controlD = Funct[5];  // immediate if I=1, else reg
            end
            else if (Funct[5] == 1'b0) begin
                // register‑operand MOV
                ALUControlD = MOV;
                RegWriteD   = 1'b1;
                // shifter_controlD remains 0
            end else begin
                // rotate‑immediate MOV
                ALUControlD     = MOV;
                RegWriteD       = 1'b1;
                shifter_controlD = 1'b1;
            end
        end

            CMP: begin
                RegSrcD     = 2'b00;
                MemtoRegD   = 1'b0;
                MemWriteD   = 1'b0;
                ALUControlD = SUB;       // compare via SUB
                ALUSrcD     = 2'b00;
                ImmSrcD     = 2'b00;
                RegWriteD   = 1'b0;
                shifter_controlD      = 1'b0;
                FlagWriteD  = 1'b1;
                BranchD     = 1'b0;
                PCSrcD      = 1'b0;
            end

            default: begin  // undefined DP
                RegSrcD     = 2'b00;
                MemtoRegD   = 1'b0;
                MemWriteD   = 1'b0;
                ALUControlD = AND;
                ALUSrcD     = 2'b00;
                ImmSrcD     = 2'b00;
                RegWriteD   = 1'b0;
                shifter_controlD      = 1'b0;
                FlagWriteD  = 1'b0;
                BranchD     = 1'b0;
                PCSrcD      = 1'b0;
            end
        endcase
    end
end
		
	2'b01: begin
        // defaults for both LDR and STR
        RegSrcD          = 2'b00;
        MemtoRegD        = 1'b0;
        MemWriteD        = 1'b0;
        RegWriteD        = 1'b0;
        ALUControlD      = ADD;    // address calc uses ADD
        ALUSrcD          = 2'b01;  // select extended immediate
        ImmSrcD          = 2'b01;  // 12‑bit offset
        shifter_controlD = 1'b0;
        FlagWriteD       = 1'b0;
        BranchD          = 1'b0;
        PCSrcD           = 1'b0;

        if (Funct[0]) begin
            // LDR: read from memory into register
            MemtoRegD  = 1'b1;
            RegWriteD  = 1'b1;
        end else begin
            // STR: write register to memory
            RegSrcD    = 2'b10;  // use Rm field for store data
            MemWriteD  = 1'b1;
        end
    end

    2'b10: begin
        // defaults for branch (B) and branch‑link (BL)
        RegSrcD          = 2'b01;  // use PC+4 for link
        MemtoRegD        = 1'b0;
        MemWriteD        = 1'b0;
        ALUControlD      = ADD;    // PC + offset
        ALUSrcD          = 2'b01;  // extended immediate
        ImmSrcD          = 2'b10;  // branch offset
        shifter_controlD = 1'b0;
        FlagWriteD       = 1'b0;
        BranchD          = 1'b1;
        PCSrcD           = 1'b0;
        RegWriteD        = 1'b0;   // only BL writes link reg

        if (Funct[4]) begin
            // BL: enable link register write
            RegWriteD = 1'b1;
        end
    end

        default: begin // NOP / undefined
            RegSrcD     = 2'b00;  MemtoRegD = 0;
            MemWriteD   = 0;      ALUControlD = 0;
            ALUSrcD     = 0;      ImmSrcD  = 0;
            RegWriteD   = 0;      shifter_controlD   = 0;
            FlagWriteD = 0;       BranchD = 0;
            PCSrcD    = 0;
        end
    endcase
end

// Memory and Writeback stage signals
wire       PCSrcM, MemtoRegM, RegWriteM;
wire       RegSrcZeroM;

//====================================================================
// Pipeline registers: latch control signals into Execute, Memory, Writeback
//====================================================================
// Pack/unpack all EX‑stage control bits in one 19‑bit flops
reg [18:0] ctrlE;
always @(posedge clk) 
    ctrlE <= FlushE 
           ? 19'b0 
           : {PCSrcD,BranchD,RegWriteD,MemWriteD,MemtoRegD,
              ALUControlD,ALUSrcD,Flags,FlagWriteD,
              shifter_controlD,RegSrcD[0],Cond};

assign {PCSrcE,BranchE,RegWriteE,MemWriteE,MemtoRegE,
        ALUControlE,ALUSrcE,FlagsE,FlagWriteE,
        shifter_control,RegSrcZeroE,CondE} = ctrlE;


// Memory‑stage control register, packed into 5 flops
reg [4:0] ctrlM;
always @(posedge clk)
    ctrlM <= reset
          ? 5'b0
          : {PCSrcE_conditionalWire,
             RegWriteE_conditionalWire,
             MemWriteE_conditionalWire,
             MemtoRegE,
             RegSrcZeroE};

assign {PCSrcM,
        RegWriteM,
        MemWriteM,
        MemtoRegM,
        RegSrcZeroM} = ctrlM;

// Write‑back stage control register (4 flops)
reg [3:0] ctrlW;
always @(posedge clk)
    ctrlW <= reset
          ? 4'b0
          : {PCSrcM, RegWriteM, MemtoRegM, RegSrcZeroM};

assign {PCSrcW, RegWriteW, MemtoRegW, RegSrcZeroW} = ctrlW;

//====================================================================
// Output assignments to Hazard detection / forwarding units
//====================================================================
assign RegSrc         = RegSrcD;
assign Flags          = FlagWriteE ? Z_Flag : FlagsE;   // Choose zero flag if writing flags, else pass latched
assign ALUControlE_out = ALUControlE;
assign ALUSrcE_out     = ALUSrcE;
assign PCSrcE_conditionalWire  = PCSrcE_conditional;
assign RegWriteE_conditionalWire = RegWriteE_conditional;
assign MemWriteE_conditionalWire = MemWriteE_conditional;
assign RegWriteM_Haz  = RegWriteM;
assign MemtoRegE_Haz  = MemtoRegE;
assign PCSrcD_Haz     = PCSrcD;
assign PCSrcE_Haz     = PCSrcE;
assign PCSrcM_Haz     = PCSrcM;

endmodule



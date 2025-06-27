//-----------------------------------------------------------------------------
// HAZARD_UNIT.v
// 32‑bit Pipeline Hazard Detection & Forwarding Unit
// Detects data hazards for forwarding and load‑use stalls, and control hazards
// for stalls and pipeline flushes.
//-----------------------------------------------------------------------------

module HAZARD_UNIT #(parameter WIDTH = 32
)(
    input  wire        reset,        // global synchronous reset
    // PC update requests from each stage
    input  wire        PCSrcW,       // WB-stage PCSrc
    input  wire        PCSrcD,       // ID-stage PCSrc
    input  wire        PCSrcE,       // EX-stage PCSrc
    input  wire        PCSrcM,       // MEM-stage PCSrc
    // EX stage source registers
    input  wire [3:0]  RA1E,         // EX-stage operand A address
    input  wire [3:0]  RA2E,         // EX-stage operand B address
    // ID stage source registers
    input  wire [3:0]  RA1D,         // ID-stage operand A address
    input  wire [3:0]  RA2D,         // ID-stage operand B address
    // Destination registers in the pipeline
    input  wire [3:0]  WA3E,         // EX-stage write‑back address
    input  wire [3:0]  WA3M,         // MEM-stage write‑back address
    input  wire [3:0]  WA3W,         // WB-stage write‑back address
    // Write‑enable signals through the pipeline
    input  wire        RegWriteW,    // writes in WB stage
    input  wire        RegWriteM,    // writes in MEM stage
    input  wire        MemtoRegE,    // EX-stage is a load (needs stall)
    // Branch signals
    input  wire        BranchTakenE, // branch taken in EX stage

    // Outputs
    output reg  [1:0]  ForwardAE,    // forwarding control for EX-stage A
    output reg  [1:0]  ForwardBE,    // forwarding control for EX-stage B
    output reg         StallF,       // stall IF stage
    output reg         StallD,       // stall ID stage
    output reg         FlushD,       // flush ID pipeline register
    output reg         FlushE        // flush EX pipeline register
);

    // Internal flags for matching registers
    reg matchE1M, matchE1W;
    reg matchE2M, matchE2W;
    reg loadUseHazard;
    reg pcPending;

    //------------------------------------------------------------------------
    // FORWARDING LOGIC
    //   - If EX-stage source matches MEM‑stage destination, forward from ALUOutM
    //   - Else if matches WB‑stage destination, forward from ResultW
    //   - Otherwise use register file output
    //------------------------------------------------------------------------
    always @(*) begin
        // Compare EX‑stage RA1 against later write addresses
        matchE1M = (RA1E == WA3M);
        matchE1W = (RA1E == WA3W);
        if (matchE1M && RegWriteM)
            ForwardAE = 2'b10;    // Forward from MEM stage
        else if (matchE1W && RegWriteW)
            ForwardAE = 2'b01;    // Forward from WB stage
        else
            ForwardAE = 2'b00;    // No forwarding

        // Compare EX‑stage RA2 similarly
        matchE2M = (RA2E == WA3M);
        matchE2W = (RA2E == WA3W);
        if (matchE2M && RegWriteM)
            ForwardBE = 2'b10;    // Forward from MEM stage
        else if (matchE2W && RegWriteW)
            ForwardBE = 2'b01;    // Forward from WB stage
        else
            ForwardBE = 2'b00;    // No forwarding
    end

    //------------------------------------------------------------------------
    // STALL & FLUSH LOGIC
    //   - Load‑use hazard: stall one cycle if ID uses a result from a load in EX
    //   - Control hazard: stall IF if any stage will update PC
    //   - Flush ID/EX or EX/MEM when needed on branch or reset
    //------------------------------------------------------------------------
    always @(*) begin
        // Detect load‑use: EX is a load, and ID reads same reg
        loadUseHazard = MemtoRegE && ((RA1D == WA3E) || (RA2D == WA3E));

        // Any pending PC update (branch or jump) in ID, EX, or MEM
        pcPending = PCSrcD || PCSrcE || PCSrcM;

        // Stall signals
        StallF = loadUseHazard || pcPending;
        StallD = loadUseHazard;

        // Flush conditions
        // - Flush ID on branch/computed PC, completed writes, or reset
        FlushD = reset || BranchTakenE || pcPending || PCSrcW;
        // - Flush EX on load‑use, branch taken, or reset
        FlushE = reset || BranchTakenE || loadUseHazard;
    end

endmodule

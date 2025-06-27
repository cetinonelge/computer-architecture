// -----------------------------------------------------------------------------
// EE446 Lab 4 — Top‑Level Pipelined Processor Wrapper
// -----------------------------------------------------------------------------
// Instantiates the Datapath, Controller, and Hazard modules, and connects
// their interfaces. Exposes clock, reset, debug inputs, and pipeline status
// signals for test bench and on‑board LEDs.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module Pipeline_Computer #(parameter WIDTH = 32
)(
    // Global clocks & resets
    input  wire              clk,
    input  wire              reset,

    // Debug register file select and output
    input  wire [3:0]        debug_reg_sel,
    output wire [WIDTH-1:0]  debug_reg_out,

    // Program Counter output after fetch stage
    output wire [WIDTH-1:0]  fetchPC,

    // Pipeline control/status outputs (for LEDs or TB observation)
    output wire              StallF_out,
    output wire              StallD_out,
    output wire              FlushD_out,
    output wire              FlushE_out
);

    // -------------------------------------------------------------------------
    // Internal control and data signals between modules
    // -------------------------------------------------------------------------
    // Controller → Datapath
    wire        PCSrcW;
    wire        MemtoRegW;
    wire        MemWriteM;
    wire        RegWriteW;
    wire        BranchTakenE;
    wire        shifter_control;
    wire [1:0]  RegSrc;
    wire        RegSrcZeroW;
    wire [1:0]  ForwardAE;
    wire [1:0]  ForwardBE;
    wire [3:0]  ALUControlE;
    wire [1:0]  ALUSrcE;
    wire [1:0]  ImmSrcD;

    // Datapath → Controller & Hazard
    wire [3:0]  RA1E_Haz;
    wire [3:0]  RA2E_Haz;
    wire [3:0]  RA1D_Haz;
    wire [3:0]  RA2D_Haz;
    wire [3:0]  WA3E_Haz;
    wire [3:0]  WA3M_Haz;
    wire [3:0]  WA3W_Haz;

    wire        CO_out;
    wire        OVF_out;
    wire        N_out;
    wire        Z_out;

    wire [3:0]  Cond;
    wire [1:0]  Op;
    wire [5:0]  Funct;
    wire [3:0]  Rd;

    // Hazard → Controller
    wire        PCSrcD_Haz;
    wire        PCSrcE_Haz;
    wire        PCSrcM_Haz;
    wire        MemtoRegE_Haz;
    wire        RegWriteM_Haz;

    // Hazard control signals → Datapath
    wire        StallF;
    wire        StallD;
    wire        FlushD;
    wire        FlushE;

    // Connect test‑bench outputs to internal Hazard signals
    assign StallF_out  = StallF;
    assign StallD_out  = StallD;
    assign FlushD_out  = FlushD;
    assign FlushE_out  = FlushE;

    // -------------------------------------------------------------------------
    // Datapath Instance
    // -------------------------------------------------------------------------
    DATAPATH #(.WIDTH(WIDTH)) my_datapath (
        .clk              (clk),
        .reset            (reset),

        // Control inputs from controller/Hazard
        .PCSrcW           (PCSrcW),
        .MemtoRegW        (MemtoRegW),
        .RegWriteW        (RegWriteW),
        .MemWriteM        (MemWriteM),
        .BranchTakenE     (BranchTakenE),
        .shifter_control  (shifter_control),
        .RegSrc           (RegSrc),
        .RegSrcZeroW      (RegSrcZeroW),
        .ForwardAE        (ForwardAE),
        .ForwardBE        (ForwardBE),
        .ALUControlE      (ALUControlE),
        .ALUSrcE          (ALUSrcE),
        .ImmSrcD          (ImmSrcD),

        // Hazard control inputs
        .StallF           (StallF),
        .StallD           (StallD),
        .FlushD           (FlushD),
        .FlushE           (FlushE),

        // Register file debug
        .debug_reg_sel (debug_reg_sel),

        // Hazard signal exports
        .RA1E_Haz      (RA1E_Haz),
        .RA2E_Haz      (RA2E_Haz),
        .RA1D_Haz      (RA1D_Haz),
        .RA2D_Haz      (RA2D_Haz),
        .WA3E_Haz      (WA3E_Haz),
        .WA3M_Haz      (WA3M_Haz),
        .WA3W_Haz      (WA3W_Haz),

        // ALU status flags
        .CO_out           (CO_out),
        .OVF_out          (OVF_out),
        .N_out            (N_out),
        .Z_out            (Z_out),

        // Decode signals back to controller
        .Cond             (Cond),
        .Op               (Op),
        .Funct            (Funct),
        .Rd               (Rd),

        // Debug outputs
        .debug_reg_out     (debug_reg_out),
        .PC               (fetchPC)
    );

    // -------------------------------------------------------------------------
    // Controller Instance
    // -------------------------------------------------------------------------
    CONTROLLER #(.WIDTH(WIDTH)) my_controller (
        .clk                (clk),
        .reset              (reset),
        .FlushE             (FlushE),

        // Flags from ALU
        .CO_Flag            (CO_out),
        .OVF_Flag           (OVF_out),
        .Z_Flag             (Z_out),
        .N_Flag             (N_out),

        // Instruction decode fields
        .Cond               (Cond),
        .Op                 (Op),
        .Funct              (Funct),
        .Rd                 (Rd),

        // Outputs to datapath/Hazard
        .PCSrcW             (PCSrcW),
        .MemtoRegW          (MemtoRegW),
        .RegWriteW          (RegWriteW),
        .MemWriteM          (MemWriteM),
        .BranchTakenE       (BranchTakenE),
        .RegSrc             (RegSrc),
        .RegSrcZeroW        (RegSrcZeroW),
        .ALUControlE_out    (ALUControlE),
        .ALUSrcE_out        (ALUSrcE),
        .ImmSrcD            (ImmSrcD),
        .shifter_control    (shifter_control),

        // Hazard taps
        .PCSrcD_Haz      (PCSrcD_Haz),
        .PCSrcE_Haz      (PCSrcE_Haz),
        .PCSrcM_Haz      (PCSrcM_Haz),
        .MemtoRegE_Haz   (MemtoRegE_Haz),
        .RegWriteM_Haz   (RegWriteM_Haz)
    );

    // -------------------------------------------------------------------------
    // Hazard Unit Instance
    // -------------------------------------------------------------------------
    HAZARD_UNIT #(.WIDTH(WIDTH)) my_hazard_unit (
        .reset              (reset),

        // Register address comparisons
        .RA1E               (RA1E_Haz),
        .RA2E               (RA2E_Haz),
        .WA3E               (WA3E_Haz),
        .WA3M               (WA3M_Haz),
        .WA3W               (WA3W_Haz),
        .RA1D               (RA1D_Haz),
        .RA2D               (RA2D_Haz),

        // Control signals from controller
        .RegWriteW          (RegWriteW),
        .RegWriteM          (RegWriteM_Haz),
        .MemtoRegE          (MemtoRegE_Haz),
        .BranchTakenE       (BranchTakenE),
        .PCSrcW             (PCSrcW),
        .PCSrcD             (PCSrcD_Haz),
        .PCSrcE             (PCSrcE_Haz),
        .PCSrcM             (PCSrcM_Haz),

        // Forwarding outputs
        .ForwardAE          (ForwardAE),
        .ForwardBE          (ForwardBE),

        // Stall/flush handshakes
        .StallF             (StallF),
        .StallD             (StallD),
        .FlushD             (FlushD),
        .FlushE             (FlushE)
    );

endmodule

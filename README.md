# 🧠 Computer Architecture Projects

This repository contains Verilog implementations of ARM-based CPUs developed for the **EE446 - Computer Architecture II** course at **Middle East Technical University (METU)**.

## ✅ Architectures Implemented

- **Single-Cycle Processor**
- **Multi-Cycle Processor**
- **Pipelined Processor**

Each CPU design is verified through cocotb testbench simulation and FPGA demonstration, instruction memory files are inside Test_expX/.

## 🛠️ Tools 

- **Verilog HDL** – Hardware design
- **Cocotb** – Python-based testbench framework
- **Icarus Verilog** – Open-source Verilog simulator
- **Vivado** – FPGA synthesis and deployment
- **Nexys A7 100T FPGA Board** – Hardware testing platform

## 🧪 Testing & Simulation

All CPU implementations are supported with **Cocotb** testbenches that verify:

- Functional correctness of datapath and control logic
- Instruction execution based on provided `.hex` programs
- Cycle-accurate signal behavior via waveform dumps

# CS207 Digital Logic Project - Matrix Calculator

## 📖 Overview
This project is a hardware-based **Matrix Calculator** implemented on the **EGO1 FPGA board** using **SystemVerilog**. It features a custom-designed architecture for matrix storage, arithmetic operations, and random generation. The system communicates with a PC-based **Python Client** via UART for user-friendly interaction, data visualization, and control.

## ✨ Features

### 1. Matrix Operations
- **Addition ($A + B$)**: Element-wise addition of two matrices.
- **Scalar Multiplication ($k \times A$)**: Multiply a matrix by a scalar value.
- **Matrix Multiplication ($A \times B$)**: Full matrix multiplication.
- **Transpose ($A^T$)**: Matrix transposition.
- **Convolution**: 2D convolution using a 3x3 kernel.

### 2. System Modes
- **Input Mode**: Manually input matrix dimensions and data via the PC client.
- **Generation Mode**: Create random matrices with configurable size and value ranges.
- **Display Mode**: View stored matrices and operation results on the PC.
- **Calculation Mode**: Select operands and perform ALU operations.
- **Settings Mode**: Configure system parameters (Error timeout, Random seed range, Storage limits).

### 3. Technical Highlights
- **Pipelined ALU**: Optimized arithmetic logic unit for high-throughput calculations.
- **UART Communication**: Robust 115200 baud serial interface for data exchange.
- **Decentralized FSM Control**: Modular state machine design for stable mode switching.
- **Resource Optimization**: Efficient use of FPGA resources (LUTs/FFs) for matrix storage.

## 📂 Project Structure

```text
cs207-digital-logic-project/
├── client/                 # Python PC Client
│   ├── main.py            # Entry point for the GUI/CLI
│   ├── matrix_client.py   # UART communication handler
│   └── modules/           # Client-side logic modules
├── constraints/            # FPGA Constraints
│   └── EGO1_Master.xdc    # Pin mappings for EGO1 board
├── src/                    # SystemVerilog Source Code
│   ├── calc/              # ALU and Calculation Logic
│   ├── common/            # Shared packages and UART modules
│   ├── controller/        # IO and LED/Seg Controllers
│   ├── display_sys/       # Matrix Display System
│   ├── gen_sys/           # Random Matrix Generator
│   ├── input_sys/         # Matrix Input Handler
│   ├── matrix_storage/    # Matrix Storage Management
│   ├── setting_sys/       # System Settings
│   ├── system_core.sv     # Top-level System Integration
│   └── fpga_top.sv        # FPGA Top Module
└── README.md               # This file
```

## 🚀 Getting Started

### Prerequisites
- **Hardware**: EGO1 FPGA Board (Xilinx Artix-7).
- **Software**: 
  - Vivado (for synthesis and implementation).
  - Python 3.x (for the client).
  - Python libraries: `pyserial`, `colorama` (install via `pip install -r client/requirements.txt`).

### Running the Project
1.  **FPGA**:
    - Open the project in Vivado.
    - Generate Bitstream and program the EGO1 board.
2.  **Client**:
    - Connect the EGO1 board to your PC via USB.
    - Identify the COM port (e.g., `COM3` on Windows or `/dev/ttyUSB0` on Linux).
    - Run the client:
      ```bash
      cd client
      python main.py
      ```

## 📌 Pin Assignments (EGO1 Board)

### System
| Port Name | Pin | Description |
| :--- | :--- | :--- |
| `clk` | **P17** | System Clock (100 MHz) |
| `rst_n` | **P15** | System Reset (Active Low), mapped to **S6** Button |

### Input Devices
| Port Name | Pin | Physical Component |
| :--- | :--- | :--- |
| `sw[0]` | **R1** | Slide Switch 0 (Rightmost) |
| `sw[1]` | **N4** | Slide Switch 1 |
| `sw[2]` | **M4** | Slide Switch 2 |
| `sw[3]` | **R2** | Slide Switch 3 |
| `sw[4]` | **P2** | Slide Switch 4 |
| `sw[5]` | **P3** | Slide Switch 5 |
| `sw[6]` | **P4** | Slide Switch 6 |
| `sw[7]` | **P5** | Slide Switch 7 (Leftmost) |
| `btn_confirm` | **R11** | Button S1 (Confirm / Enter) |
| `btn_esc` | **R15** | Button S6 (Escape / Reset / Back) |

### Output Devices
| Port Name | Pin | Physical Component |
| :--- | :--- | :--- |
| `seg_data[7:0]` | **B4, A4, A3, B1, A1, B3, B2, D5** | 7-Segment Display Segments (CA-DP) |
| `seg_sel[7:0]` | **G2, C2, C1, H1, G1, F1, E1, G6** | 7-Segment Display Anodes (AN7-AN0) |
| `led[7:0]` | **K3, M1, L1, K6, J5, H5, H6, K1** | LEDs (LD7-LD0) |
| `uart_tx` | **B16** | UART Transmit (to PC) |
| `uart_rx` | **B17** | UART Receive (from PC) |

## 🎮 Operation Guide

1.  **Mode Selection**: Use the Python Client to switch between modes (Input, Gen, Calc, Display, Settings). The FPGA will acknowledge the mode switch.
2.  **Input**: In Input Mode, type matrix data in the client.
3.  **Calculation**: 
    - Enter Calc Mode.
    - Use **Switches [7:3]** to select operation type (Add, Mul, Scalar, Transpose, Conv).
    - Press **S1 (Confirm)** to proceed.
    - Follow on-screen (Client) or 7-Seg prompts to select operands.
4.  **Reset**: Press **S6** to reset the current state or return to the main menu.

---
*University Project for CS207 Digital Logic Design @ SUSTech*
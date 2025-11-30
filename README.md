# cs207-digital-logic-project

## 📌 Pin Assignments (EGO1 Board)

The following table lists the pin mappings used in the `EGO1_Master.xdc` constraint file.

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
| `btn[0]` | **R11** | Button S0 (Right) |
| `btn[1]` | **R17** | Button S1 (Up) |
| `btn[2]` | **R15** | Button S2 (Down) |
| `btn[3]` | **V1** | Button S3 (Left) |
| `btn[4]` | **U4** | Button S4 (Center) |

### Output Devices (LEDs)
| Port Name | Pin | Physical Component |
| :--- | :--- | :--- |
| `led[0]` - `led[7]` | **K3** .. **K1** | Right Group LEDs (0 is rightmost) |
| `led[8]` - `led[15]`| **K2** .. **F6** | Left Group LEDs |

### 7-Segment Display
The EGO1 board uses two separate buses for the Left and Right 4-digit displays.
* **`an[7:0]`**: Digit Enables (Active Low).
* **`seg0[7:0]`**: Segment Data for Right 4 digits (A,B,C,D,E,F,G,DP).
* **`seg1[7:0]`**: Segment Data for Left 4 digits.

| Port Name | Pins (0->7) | Description |
| :--- | :--- | :--- |
| `an[3:0]` | **G2, C2, C1, H1** | Right 4 Digits Enable |
| `an[7:4]` | **G1, F1, E1, G6** | Left 4 Digits Enable |
| `seg0` | **B4, A4, A3, B1, A1, B3, B2, D5** | Segments for Right Group |
| `seg1` | **D4, E3, D3, F4, F3, E2, D2, H2** | Segments for Left Group |

### Communication (UART)
| Port Name | Pin | Description |
| :--- | :--- | :--- |
| `uart_rx` | **N5** | FPGA RX (Receives from PC) |
| `uart_tx` | **T4** | FPGA TX (Sends to PC) |
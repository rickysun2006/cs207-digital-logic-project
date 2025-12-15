# FPGA Matrix Calculator - User Instruction Manual

## 1. Project Overview
This project is an FPGA-based Matrix Calculator running on the EGO1 development board. It supports matrix input via PC, internal storage, random generation, display, and various matrix operations (Addition, Multiplication, Transpose, etc.). A Python-based GUI client is provided for easy interaction.

## 2. Hardware Setup
### 2.1 Board Connections
- **Board:** EGO1 FPGA Board.
- **Power:** Connect the USB cable to the computer.
- **Switches & Buttons:**
    - **Switches (SW0-SW7):** Used for mode selection and parameter input.
    - **Buttons:**
        - **Center (S4):** Confirm / Enter.
        - **Up (S1):** Reset Logic / Back / Escape.
        - **Right (S0):** System Reset (Active Low).

### 2.2 Pin Mapping Summary
| Component | Function | Description |
| :--- | :--- | :--- |
| **SW[7:4]** | Mode Select | High 4 switches select the operating mode. |
| **SW[7:0]** | Data Input | Used for scalar values or operation selection. |
| **BTN_MID** | Confirm | Execute command or enter submenu. |
| **BTN_UP** | Back/Esc | Return to previous menu or cancel. |
| **UART** | Data I/O | Connects to PC for matrix transfer. |

## 3. Software Setup (PC Client)
1. Ensure Python 3.x is installed.
2. Install dependencies:
   ```bash
   pip install flet pyserial
   ```
3. Run the client:
   ```bash
   cd client
   python3 matrix_client.py
   ```
4. In the client GUI:
   - Select the correct **COM Port** (e.g., `/dev/tty.usbserial...` on Mac or `COMx` on Windows).
   - Set **Baud Rate** to `115200`.
   - Click **Connect**.

## 4. Operation Guide

The system is controlled by a Main Menu state machine. Use **Switches** to select a mode and press **Confirm (Center Button)** to enter.

### 4.1 Mode 1: Matrix Input (PC -> FPGA)
**Goal:** Send a matrix from the computer to the FPGA storage.

1. **Enter Mode:**
   - Set **SW[4] = ON** (others OFF).
   - Press **Confirm**.
   - FPGA Display: `1nPUT`.
2. **Send Data:**
   - Open the Python Client.
   - Go to **"Matrix Input"** card.
   - Enter Rows (R) and Columns (C).
   - Fill in the matrix values.
   - Click **"Send to FPGA"**.
3. **Finish:**
   - The FPGA will store the matrix and assign it an ID.
   - Press **BTN_UP** on FPGA to return to Main Menu.

### 4.2 Mode 2: Matrix Generation
**Goal:** Generate random matrices internally.

1. **Enter Mode:**
   - Set **SW[5] = ON**.
   - Press **Confirm**.
   - FPGA Display: `GEn`.
2. **Operation:**
   - The system will automatically generate matrices and store them.
   - Wait for the process to complete (LEDs may indicate progress).
3. **Exit:**
   - Press **BTN_UP** to return.

### 4.3 Mode 3: Matrix Display (FPGA -> PC)
**Goal:** View stored matrices on the computer.

1. **Enter Mode:**
   - Set **SW[6] = ON**.
   - Press **Confirm**.
   - FPGA Display: `15PLA` (Display) and total count.
2. **View Data:**
   - In the Python Client, go to **"Storage Viewer"**.
   - Click **"Refresh Summary"** to see a list of stored matrix types.
   - To view specific matrices, enter dimensions (e.g., 3x3) and click the **Download Icon**.
   - The matrices will appear in the "System Logs" tab or Output section.

### 4.4 Mode 4: Matrix Calculation
**Goal:** Perform operations on stored matrices.

1. **Enter Mode:**
   - Set **SW[7] = ON**.
   - Press **Confirm**.
2. **Select Operation:**
   - Use switches to select the operation type (LED/Seg will indicate Op):
     - **SW[7] ON:** Addition (A)
     - **SW[6] ON:** Matrix Multiplication (b)
     - **SW[5] ON:** Scalar Multiplication (C)
     - **SW[4] ON:** Transpose (t)
     - **SW[3] ON:** Convolution (J)
   - Press **Confirm**.
3. **Select Operands:**
   - **Matrix A:** The system waits for Matrix ID A.
     - *Note:* You need to send the ID byte via UART.
   - **Matrix B:** (For Add/Mul) System waits for Matrix ID B.
   - **Scalar:** (For Scalar Mul)
     - Set the scalar value using **SW[7:0]** (binary).
     - Press **Confirm**.
4. **Result:**
   - The result is calculated and stored as a new matrix.
   - Use **Mode 3 (Display)** to view the result.

### 4.5 Mode 5: System Settings
**Goal:** Configure system parameters (Error Timeout, Value Limits, Storage Limits).

1. **Enter Mode:**
   - Set **SW[3] = ON** (others OFF).
   - Press **Confirm**.
   - FPGA Display: `SEt`.

2. **Select Parameter:**
   - **SW[7] = ON**: Set Error Countdown Time (Default: 10s).
   - **SW[6] = ON**: Set Matrix Element Max Value (Default: 9).
   - **SW[5] = ON**: Set Matrix Element Min Value (Default: 0).
   - **SW[4] = ON**: Set Storage Limit per Dimension (Default: 2 matrices).
   - Press **Confirm** to enter parameter edit mode.

3. **Edit Parameter:**
   - Use **SW[7:0]** to set the value (binary/integer).
     - For Max/Min Value, it supports signed 8-bit integers (2's complement).
   - Display shows the current value (e.g., `E 10`, `H 9`, `L 0`).
   - Press **Confirm** to save.
   - Press **Back (Up Button)** to cancel/return.

4. **Exit Settings:**
   - Press **Back (Up Button)** in the main Settings menu (`SEt`) to return to IDLE.

## 5. Troubleshooting
- **Client not connecting:** Check if the USB cable is plugged in and the correct port is selected. Close other terminal software.
- **FPGA stuck:** Press **BTN_UP** to try to cancel the current operation. If that fails, press **BTN_RIGHT** (System Reset).
- **Data errors:** Ensure the Baud Rate is exactly **115200**.
- **Calculation ID Selection:** The current client version may require a raw serial terminal to send specific Matrix IDs (0-49) for calculation selection if the GUI buttons don't cover your specific ID needs.

---

# FPGA 矩阵计算器 - 用户使用说明书 (中文版)

## 1. 项目概述
本项目是一个基于 FPGA (EGO1 开发板) 的矩阵计算器。它支持通过 PC 端输入矩阵、内部存储、随机生成、显示以及多种矩阵运算（加法、乘法、转置等）。项目提供了一个基于 Python 的 GUI 客户端，方便用户进行交互。

## 2. 硬件设置
### 2.1 开发板连接
- **开发板:** EGO1 FPGA 开发板。
- **电源:** 将 USB 线连接到电脑。
- **开关与按键:**
    - **拨码开关 (SW0-SW7):** 用于模式选择和参数输入。
    - **按键:**
        - **中间键 (S4):** 确认 / 进入 (Confirm)。
        - **上键 (S1):** 逻辑复位 / 返回 / 退出 (Back/Esc)。
        - **右键 (S0):** 系统复位 (低电平有效)。

### 2.2 引脚映射摘要
| 组件 | 功能 | 描述 |
| :--- | :--- | :--- |
| **SW[7:4]** | 模式选择 | 高 4 位开关用于选择工作模式。 |
| **SW[7:0]** | 数据输入 | 用于输入标量值或选择运算类型。 |
| **BTN_MID** | 确认 | 执行命令或进入子菜单。 |
| **BTN_UP** | 返回/退出 | 返回上一级菜单或取消操作。 |
| **UART** | 数据 I/O | 连接电脑进行矩阵传输。 |

## 3. 软件设置 (PC 客户端)
1. 确保已安装 Python 3.x。
2. 安装依赖库:
   ```bash
   pip install flet pyserial
   ```
3. 运行客户端:
   ```bash
   cd client
   python3 matrix_client.py
   ```
4. 在客户端界面中:
   - 选择正确的 **COM 端口** (例如 Mac 上的 `/dev/tty.usbserial...` 或 Windows 上的 `COMx`)。
   - 设置 **波特率 (Baud Rate)** 为 `115200`。
   - 点击 **Connect (连接)**。

## 4. 操作指南

系统由主菜单状态机控制。使用 **拨码开关** 选择模式，按下 **确认键 (中间按键)** 进入。

### 4.1 模式 1: 矩阵输入 (PC -> FPGA)
**目标:** 将矩阵从电脑发送到 FPGA 存储中。

1. **进入模式:**
   - 设置 **SW[4] = ON** (其他为 OFF)。
   - 按下 **确认键**。
   - FPGA 数码管显示: `1nPUT`。
2. **发送数据:**
   - 打开 Python 客户端。
   - 进入 **"Matrix Input"** 卡片。
   - 输入行数 (R) 和列数 (C)。
   - 填入矩阵数值。
   - 点击 **"Send to FPGA"**。
3. **完成:**
   - FPGA 将存储该矩阵并分配一个 ID。
   - 按下 FPGA 上的 **上键 (BTN_UP)** 返回主菜单。

### 4.2 模式 2: 矩阵生成
**目标:** 在内部自动生成随机矩阵。

1. **进入模式:**
   - 设置 **SW[5] = ON**。
   - 按下 **确认键**。
   - FPGA 数码管显示: `GEn`。
2. **操作:**
   - 系统将自动生成矩阵并存储。
   - 等待过程完成 (LED 灯可能会指示进度)。
3. **退出:**
   - 按下 **上键 (BTN_UP)** 返回。

### 4.3 模式 3: 矩阵显示 (FPGA -> PC)
**目标:** 在电脑上查看存储的矩阵。

1. **进入模式:**
   - 设置 **SW[6] = ON**。
   - 按下 **确认键**。
   - FPGA 数码管显示: `15PLA` (Display) 和当前矩阵总数。
2. **查看数据:**
   - 在 Python 客户端中，进入 **"Storage Viewer"**。
   - 点击 **"Refresh Summary"** 查看已存储的矩阵类型列表。
   - 要查看具体矩阵，输入维度 (例如 3x3) 并点击 **下载图标**。
   - 矩阵将显示在 "System Logs" 标签页或 Output 区域。

### 4.4 模式 4: 矩阵计算
**目标:** 对存储的矩阵执行运算。

1. **进入模式:**
   - 设置 **SW[7] = ON**。
   - 按下 **确认键**。
2. **选择运算:**
   - 使用开关选择运算类型 (LED/数码管会指示操作):
     - **SW[7] ON:** 加法 (A)
     - **SW[6] ON:** 矩阵乘法 (b)
     - **SW[5] ON:** 标量乘法 (C)
     - **SW[4] ON:** 转置 (t)
     - **SW[3] ON:** 卷积 (J)
   - 按下 **确认键**。
3. **选择操作数:**
   - **矩阵 A:** 系统等待输入矩阵 A 的 ID。
     - *注意:* 你需要通过 UART 发送 ID 字节。
   - **矩阵 B:** (针对加法/乘法) 系统等待输入矩阵 B 的 ID。
   - **标量:** (针对标量乘法)
     - 使用 **SW[7:0]** 设置标量值 (二进制)。
     - 按下 **确认键**。
4. **结果:**
   - 计算结果将作为新矩阵存储。
   - 使用 **模式 3 (Display)** 查看结果。

## 5. 故障排除
- **客户端无法连接:** 检查 USB 线是否插好，端口是否选择正确。关闭其他占用串口的软件。
- **FPGA 卡死:** 按下 **上键 (BTN_UP)** 尝试取消当前操作。如果无效，按下 **右键 (BTN_RIGHT)** 进行系统复位。
- **数据错误:** 确保波特率严格设置为 **115200**。
- **计算 ID 选择:** 当前版本的客户端可能需要使用原始串口终端发送特定的矩阵 ID (0-49) 来进行计算选择，如果 GUI 按钮没有覆盖你的特定 ID 需求。

---
*Created by Ruqi (Ricky) Sun for CS207 Digital Logic Project.*

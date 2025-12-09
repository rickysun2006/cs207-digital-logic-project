# CS207 Project Requirements: FPGA-Based Matrix Calculator

> **Purpose:** This document serves as the central source of truth for project requirements, grading criteria, and submission specifications. It is intended for team synchronization and as context for AI coding assistants (GitHub Copilot).

---

## 📅 Critical Deadlines & Submission

### 1. Architecture Document (3 pts)
- **Deadline:** Week 13 Tuesday, Before 11:30 AM.
- **Content:** Architecture design based on team discussion.

### 2. Code Submission (Basic Function + Bonus)
- **Advance Defense (Week 15):** Submit before Week 15 Tuesday 13:00 (Coeff: 1.05).
- **Normal Defense (Week 16):** Submit before Week 16 Tuesday 13:00 (Coeff: 1.0).
- **Delayed:** Late submissions receive penalty coefficients (0.9 ~ 0.5).
- **File Format:** Compressed Vivado Project (delete `.runs` directory).
- **Naming Convention:** `c[TimeCode]_[SID1]_[SID2]_[SID3]` (e.g., `c160278_1211xxx_1212xxx_1213xxx`).

### 3. Final Documentation & Video (Week 16)
- **Deadline:** Week 16 Sunday, Before 23:59.
- **Documents:**
    - **Project Document (PDF):** Naming `d[TimeCode]_[NameList]`.
    - **Video (MP4, <200MB):** Mandatory for Convolution Bonus. Naming `v[TimeCode]_[NameList]`.

---

## 🛠 Hardware & Interface Specifications

- **Platform:** FPGA Development Board (Vivado).
- **Primary Input:** UART Serial (Computer) + Board Switches/Buttons.
    - *Note:* If UART input is difficult, Keyboard input is acceptable without penalty.
- **Primary Output:** UART Serial (Computer) + Board LEDs/7-Segment.
    - *Note:* If UART output is difficult, VGA output is acceptable without penalty.
- **Clock Frequency:** Standard board clock (verify constraints).

---

## 💻 Functional Requirements (Checklist)

### 1. System Control & Menu
- [ ] **Mode Selection:** Use Switches/Buttons to toggle between modes.
    1. Matrix Input & Storage.
    2. Matrix Generation & Storage.
    3. Matrix Display.
    4. Matrix Operations.
- [ ] **State Machine:** Clear states for Menu, Input, Calculation, and Output. Support returning to Main Menu after operations.

### 2. Matrix Data Specifications
- [ ] **Dimensions:** Configurable $m \times n$ (Default max $5 \times 5$).
- [ ] **Values:** Integers (Default range 0-9).
- [ ] **Storage:** Store at least 2 matrices per specification (e.g., two $2 \times 3$ matrices).
- [ ] **Overwrite Logic:** New input overwrites old matrices of the same dimension.

### 3. Input & Generation Mode
- [ ] **User Input (UART):** Input dimensions ($m, n$) $\rightarrow$ Input elements row-major.
- [ ] **Random Generation:** Input dimensions + Count $\rightarrow$ Generate random elements (must NOT be sorted/ordered).
- [ ] **Validation:**
    - [ ] Check dimension limits (1-5).
    - [ ] Check value range (0-9).
    - [ ] **Error Handling:** If invalid, light LED.
    - [ ] **Incomplete Input:** Pad with 0s if too few; truncate if too many.

### 4. Display Mode
- [ ] **Format:** Output matrices via UART with clear formatting (spaces/newlines).
- [ ] **Batch Display:** Show all stored matrices in sequence.

### 5. Operation Mode
- [ ] **Operation Selection:** Use Switches to select:
    - Transpose ($A^T$)
    - Addition ($A + B$)
    - Scalar Multiplication ($k \times A$)
    - Matrix Multiplication ($A \times B$)
    - [Bonus] Convolution
- [ ] **Display 7-Seg:** Show Op Type (T, A, b, C, J).
- [ ] **Operand Selection:**
    - User selects matrix dimensions $\rightarrow$ System lists available matrices $\rightarrow$ User selects index.
- [ ] **Operand Validation:**
    - Check if dimensions match operation rules (e.g., $A+B$ needs same dims).
    - **Error Handling:** If mismatch $\rightarrow$ LED Error + **Countdown Timer** (5-15s) on 7-seg.
    - **Timeout:** If no valid input within countdown, reset/fail.
- [ ] **Calculation:** Perform logic and output result via UART.

---

## 🌟 Bonus Features (Max 10 pts)

### 1. Convolution (10 pts) - *High Priority*
- [ ] **Input Image:** Hard-coded $10 \times 12$ matrix (Values provided in PDF Page 15).
- [ ] **Kernel:** User inputs $3 \times 3$ kernel via UART/Switches.
- [ ] **Logic:** Stride = 1. Output dimension = $8 \times 10$.
- [ ] **Performance:** Count clock cycles and display on 7-Segment.
- [ ] **Deliverable:** Requires PPT + Explanation Video.

### 2. Parameter Configuration (4 pts)
- [ ] Dynamically configure max dimensions (e.g., upgrade to max $6 \times 6$).
- [ ] Dynamically configure value range (e.g., allow negative numbers -3 to 20).
- [ ] Dynamically configure storage limit (e.g., store 5 matrices instead of 2).

### 3. UI Design (4 pts)
- [ ] Python/Java-based host computer interface for UART interaction.
- [ ] Must still be compatible with standard Serial Assistant.

### 4. Output Alignment (2 pts)
- [ ] Left-aligned columns in UART output for cleaner visuals.

---

## 🤖 Context for GitHub Copilot

**System Architecture Hints:**
1.  **Top Module:** Should connect UART RX/TX, Switches/Buttons, and 7-Seg/LEDs.
2.  **FSM (Finite State Machine):** Use a clean 3-segment or 2-segment FSM Verilog style.
3.  **Memory:** Use Block RAM (BRAM) or Distributed RAM for matrix storage due to the "Overwrite" requirement.
4.  **Arithmetic:** Be careful with bit-widths. Matrix Multiplication of $5 \times 5$ with values 0-9 can result in max value $5 \times (9 \times 9) = 405$ (needs ~9 bits).
5.  **Clock Division:** UART needs specific baud rate generation (e.g., 9600 or 115200). 7-Segment needs scanning clock (~1kHz).
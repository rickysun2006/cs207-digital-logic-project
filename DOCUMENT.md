# Project Document
## Developer Information
### Developers
- **Jiayao Qin**, SID: 12412619, Completed the overall structure design, FSM for main project and all sub systems, all detailed logics for sub systems, and improved the client for advanced features.
- **Ruqi Sun**; SID: 12412620; Completed functional simulation, ALU, Convolution Bonus, Front-end Client, and an LLM application aiming to support Digital Logic teaching.

### Contribution
Two developers contributed equally to this project, each accounts for 50%.

## Development Plan Schedule
### Plan
Week 13: Complete the overall structure design for the project, and complete Architecture Design Document accordingly.
Week 14: Complete the sub systems for basic requirements.
Week 15: Complete some bonus features, and fix numorous potential problems to improve stability.

### Submit History
See attached file for github submission record.

## Project Architecture Design Description

The project adopts a highly modular and hierarchical architecture designed for scalability, maintainability, and low coupling. The system is divided into three main layers: Physical Layer, System Integration Layer, and Functional Layer.

### 1. Hierarchical Design Strategy
*   **Physical Top Layer (`fpga_top.sv`)**: This module serves as the interface to the physical hardware. It is strictly responsible for signal conditioning, including clock buffering, button debouncing, and mapping physical I/O pins to internal logic signals. No complex business logic resides here.
*   **Logical Top Layer (`system_core.sv`)**: This module acts as the system integrator. It instantiates all functional sub-systems and interconnects them. It contains no specific algorithmic logic, ensuring that the system integration remains clean and the coupling between modules is minimized.
*   **Functional Layer**: Specific logic is encapsulated within dedicated sub-modules (e.g., `matrix_calc`, `matrix_input`), which operate independently under the coordination of the system core.

### 2. Modular Control & Resource Arbitration
The control logic follows a decentralized pattern:
*   **Main FSM (`main_fsm.sv`)**: Manages the high-level system states (e.g., switching between Input, Calculation, and Display modes). It delegates specific control authority to the active sub-system.
*   **Sub-System Autonomy**: Each functional module (Input, Gen, Calc, Display, Settings) possesses its own internal Finite State Machine (FSM) to handle specific tasks. Once activated, a sub-system takes control until its task is complete.
*   **Resource Controllers**: To manage shared hardware resources efficiently, we introduced dedicated controllers:
    *   **`output_controller`**: Arbitrates access to the UART transmission line, allowing multiple modules to send data without conflict.
    *   **`input_controller`**: Manages write access to the central storage.
    *   **`seg_controller` & `led_controller`**: Centralize the logic for visual feedback, preventing display conflicts.
This design significantly reduced code complexity and made adding new features (like the `settings` module) seamless, as it only required hooking into the existing controller interfaces.

### 3. Structured Organization & Standardization
*   **Directory Structure**: Source files are organized by functionality (e.g., `src/calc/`, `src/display_sys/`) rather than a flat directory, improving navigability.
*   **Common Library**: Reusable components such as UART drivers, LFSRs, and debounce logic are placed in a `src/common/` directory to promote code reuse.
*   **Package Management (`project_pkg.sv`)**: We utilize SystemVerilog packages to centralize global parameters (e.g., matrix dimensions, opcodes) and custom data structures (e.g., `matrix_t`, `matrix_element_t`). This ensures type safety and consistency across the entire project.

### 4. Data-Centric Storage Architecture
*   **Centralized Storage (`matrix_storage_sys`)**: Matrix data is decoupled from processing logic. The storage system acts as a server, providing read/write ports to other modules.
*   **Standardized Interfaces**: Communication between modules relies on standardized handshake signals (`start`, `done`, `ready`) and structured data types, ensuring robust data flow and easier debugging.

## Bonus Implementation Description

### Output Alignment

### Parameter Configuration

## Open Source and AI Usage
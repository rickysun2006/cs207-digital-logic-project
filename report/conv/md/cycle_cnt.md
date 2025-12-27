# Convolution Cycle Count Analysis

Based on the `matrix_alu.sv` implementation, the performance counter `cycle_cnt` outputs a constant value of **1520** for a 10x12 input image with a 3x3 kernel. This value represents the pure execution time excluding handshake overhead.

## 1. Counting Mechanism
The `perf_cnt` register (which drives `cycle_cnt`) only increments when the FSM is in the `ALU_EXEC` state:
\\\systemverilog
ALU_EXEC: begin
  perf_cnt <= perf_cnt + 1; // Only counts in this state
  // ...
end
\\\`nThis means wait states (`ALU_WAIT_TX`) and idle states are ignored.

## 2. Per-Pixel Cycle Breakdown
For each output pixel, the convolution operation iterates through the 3x3 kernel (=0$ to $).

*   **Accumulation Phase (=0..8$)**:
    *   The logic uses a 2-stage pipeline (Fetch $\to$ Accumulate).
    *   **Fetch**: 1 cycle (`!pipe_valid`).
    *   **Accumulate**: 1 cycle (`pipe_valid`).
    *   Total for 9 weights:  \times 2 = 18$ cycles.

*   **Writeback Phase (=9$)**:
    *   One cycle is consumed to detect completion, write to `stream_data_reg`, and transition to `ALU_WAIT_TX`.
    *   Total: **1 cycle**.

**Total cycles per pixel**:  + 1 = 19$ cycles.

## 3. Total Calculation
*   **Output Dimensions**: Hardcoded as 8 rows $\times$ 10 columns.
*   **Total Pixels**:  \times 10 = 80$ pixels.

}
\text{Total Cycles} = \text{Pixels} \times \text{Cycles/Pixel}
}
}
1520 = 80 \times 19
}

## Conclusion
The value **1520** accurately reflects the hardware's active processing time for the convolution task.

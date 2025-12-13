/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_alu.sv
# Module Name    : matrix_alu
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Handles matrix calculations, accepts calc_type, extracts matrices from matrix_storage, and distributes them to other modules for calculation.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
# v1.1  | 2025-12-09 | GitHub Copilot |   Implemented ALU logic
# v1.2  | 2025-12-10 | GitHub Copilot |   Optimized ALU resources (Shared Multipliers)
#
#=============================================================================*/
`include "../common/project_pkg.sv"
import project_pkg::*;

module matrix_alu (
    input wire clk,
    input wire rst_n,

    // --- Control Interface ---
    input wire      start,
    input op_code_t op_code,

    // --- Data Interface ---
    input matrix_t         matrix_A,
    input matrix_t         matrix_B,
    input matrix_element_t scalar_val,

    // --- Output Interface ---
    output logic           done,
    output matrix_t        result_matrix,
    output logic           error_flag,
    output logic    [31:0] cycle_cnt
);

  // --- Internal State ---
  typedef enum logic [2:0] {
    ALU_IDLE,
    ALU_EXEC,
    ALU_DONE
  } alu_state_t;
  alu_state_t state;

  // Counters
  logic [3:0] cnt_i;  // Row
  logic [3:0] cnt_j;  // Col
  logic [3:0] cnt_k;  // Dot product accumulator iterator

  logic [3:0] limit_i;
  logic [3:0] limit_j;
  logic [3:0] limit_k;  // For dot product loop

  // Cycle Counter
  logic [31:0] perf_cnt;

  // Accumulators (Width expanded to prevent overflow)
  logic signed [23:0] accum;
  logic signed [23:0] current_prod;

  // --- Hardcoded Image Data (Keep your original ROM data) ---
  // [为了节省篇幅，这里省略 img_data 的初始化代码，请保留你原来的 rom 初始化部分]
  logic [3:0] img_data[0:119];
  initial begin
    // ... 请在此处保留原来的 img_data 初始化代码 (0-119) ...
    // 简单起见，这里只写开头结尾，实际请复制你原来的内容
    img_data[0]   = 4'd3;
    // ...
    img_data[119] = 4'd7;
  end

  // Helper function for saturation
  function automatic matrix_element_t saturate(input logic signed [23:0] val);
    if (val > 24'sd127) return 8'sd127;
    else if (val < -24'sd128) return -8'sd128;
    else return val[7:0];
  endfunction

  // --- Sequential Logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ALU_IDLE;
      done          <= 0;
      error_flag    <= 0;
      result_matrix <= '0;
      cnt_i         <= 0;
      cnt_j         <= 0;
      cnt_k         <= 0;
      limit_i       <= 0;
      limit_j       <= 0;
      limit_k       <= 0;
      perf_cnt      <= 0;
      accum         <= 0;
    end else begin
      case (state)
        // ------------------------------------------------------------
        // 1. IDLE & PREPARE
        // ------------------------------------------------------------
        ALU_IDLE: begin
          done <= 0;
          if (start) begin
            error_flag             <= 0;
            perf_cnt               <= 0;
            result_matrix.is_valid <= 0;

            cnt_i                  <= 0;
            cnt_j                  <= 0;
            cnt_k                  <= 0;
            accum                  <= 0;  // Clear accumulator

            case (op_code)
              OP_ADD: begin
                if ((matrix_A.rows != matrix_B.rows) || (matrix_A.cols != matrix_B.cols)) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_A.cols;
                  limit_i <= matrix_A.rows;
                  limit_j <= matrix_A.cols;
                  limit_k <= 1;  // Not used loop
                  state <= ALU_EXEC;
                end
              end

              OP_SCALAR_MUL: begin
                result_matrix.rows <= matrix_A.rows;
                result_matrix.cols <= matrix_A.cols;
                limit_i <= matrix_A.rows;
                limit_j <= matrix_A.cols;
                limit_k <= 1;
                state <= ALU_EXEC;
              end

              OP_TRANSPOSE: begin
                result_matrix.rows <= matrix_A.cols;
                result_matrix.cols <= matrix_A.rows;
                limit_i <= matrix_A.cols;
                limit_j <= matrix_A.rows;
                limit_k <= 1;
                state <= ALU_EXEC;
              end

              OP_MAT_MUL: begin
                if (matrix_A.cols != matrix_B.rows) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_B.cols;
                  limit_i <= matrix_A.rows;
                  limit_j <= matrix_B.cols;
                  limit_k <= matrix_A.cols;  // The common dimension
                  state <= ALU_EXEC;
                end
              end

              OP_CONV: begin
                if (matrix_B.rows != 3 || matrix_B.cols != 3) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= 8;
                  result_matrix.cols <= 10;
                  limit_i <= 8;
                  limit_j <= 10;
                  limit_k <= 0;  // Convolution uses fixed loops
                  state <= ALU_EXEC;
                end
              end

              default: state <= ALU_DONE;
            endcase
          end
        end

        // ------------------------------------------------------------
        // 2. EXECUTION (Serialized)
        // ------------------------------------------------------------
        ALU_EXEC: begin
          perf_cnt <= perf_cnt + 1;

          case (op_code)
            // --- Simple Operations (1 cycle per element) ---
            OP_ADD: begin
              result_matrix.cells[cnt_i][cnt_j] <= saturate(
                  24'(signed'(matrix_A.cells[cnt_i][cnt_j])) + 
                    24'(signed'(matrix_B.cells[cnt_i][cnt_j]))
              );
              // Loop Logic (i, j)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            OP_SCALAR_MUL: begin
              result_matrix.cells[cnt_i][cnt_j] <= saturate(
                  24'(signed'(matrix_A.cells[cnt_i][cnt_j])) * 24'(signed'(scalar_val))
              );
              // Loop Logic (same as ADD)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            OP_TRANSPOSE: begin
              result_matrix.cells[cnt_i][cnt_j] <= matrix_A.cells[cnt_j][cnt_i];
              // Loop Logic
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            // --- Complex Operation: Matrix Mul (Serialized Loop) ---
            OP_MAT_MUL: begin
              // Accumulate: sum += A[i][k] * B[k][j]
              // Note: We use one extra cycle per element to write back, or optimize inside loop.
              // Here: Accumulate in 'accum'. When k reaches limit, write and reset.

              accum <= accum + (24'(signed'(matrix_A.cells[cnt_i][cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])));

              if (cnt_k == limit_k - 1) begin
                // Dot product finished for this cell
                result_matrix.cells[cnt_i][cnt_j] <= saturate(
                    accum + (24'(signed'(matrix_A.cells[cnt_i][cnt_k])) * 24'(signed'(matrix_B.cells[cnt_k][cnt_j])))
                );
                accum <= 0;  // Reset for next cell
                cnt_k <= 0;

                // Move to next cell (j, then i)
                if (cnt_j == limit_j - 1) begin
                  cnt_j <= 0;
                  if (cnt_i == limit_i - 1) begin
                    result_matrix.is_valid <= 1;
                    state <= ALU_DONE;
                  end else cnt_i <= cnt_i + 1;
                end else cnt_j <= cnt_j + 1;

              end else begin
                cnt_k <= cnt_k + 1;
              end
            end

            // --- Complex Operation: Convolution ---
            // For simplicity, we can keep convolution combinational per pixel (it's only 3x3=9 ops),
            // or serialize it if needed. 9 ops is much smaller than 12x12=144 parallel ops.
            // Let's keep it simple (combinational logic inside the state) for now, 
            // as MatMul was the main offender.
            OP_CONV: begin
              // Using blocking assignment logic variable for cleaner code,
              // or just write the sum expression.
              // Since `img_data` and `matrix_B` are small, 9 muls is usually fine.
              // If this still fails timing, we can serialize this too.

              logic signed [23:0] conv_sum_temp;
              conv_sum_temp = 0;
              for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                  conv_sum_temp += 24'(signed'({4'b0, img_data[(cnt_i + r) * 12 + (cnt_j + c)]})) * 24'(signed'(matrix_B.cells[r][c]));
                end
              end

              result_matrix.cells[cnt_i][cnt_j] <= saturate(conv_sum_temp);

              // Loop Logic (8x10 output)
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) begin
                  result_matrix.is_valid <= 1;
                  state <= ALU_DONE;
                end else cnt_i <= cnt_i + 1;
              end else cnt_j <= cnt_j + 1;
            end

            default: state <= ALU_DONE;
          endcase
        end

        // ------------------------------------------------------------
        // 3. DONE
        // ------------------------------------------------------------
        ALU_DONE: begin
          done <= 1;
          if (!start) state <= ALU_IDLE;
        end
      endcase
    end
  end

  assign cycle_cnt = perf_cnt;

endmodule

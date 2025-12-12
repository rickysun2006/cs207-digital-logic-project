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
    input wire       start,
    input op_code_t  op_code,

    // --- Data Interface ---
    input matrix_t          matrix_A,
    input matrix_t          matrix_B,
    input matrix_element_t  scalar_val,

    // --- Output Interface ---
    output logic     done,
    output matrix_t  result_matrix,
    output logic     error_flag,
    output logic [31:0] cycle_cnt // Bonus: Cycle Counter
);

  // --- Internal State ---
  typedef enum logic [2:0] {
    ALU_IDLE,
    ALU_EXEC,
    ALU_DONE
  } alu_state_t;

  alu_state_t state;

  // Counters for Iteration
  logic [3:0] cnt_i; // 建议稍微加大位宽，防止 index 溢出（假设矩阵最大16x16）
  logic [3:0] cnt_j;
  logic [3:0] limit_i;
  logic [3:0] limit_j;

  // Cycle Counter
  logic [31:0] perf_cnt;

  // Calculation Signals
  // [FIX] 扩宽中间变量以防止溢出。
  // 假设 input 是 8-bit, 乘法结果是 16-bit.
  // 累加 8 次(假设 MAX_COLS=8) 需要额外 3 bits。安全起见给 24 bits。
  logic signed [23:0] calc_result_wide; 
  logic signed [23:0] mat_mul_sum;
  logic signed [23:0] conv_sum;

  // --- Hardcoded Image Data for Convolution (10x12) ---
  // Flattened array for easier access: 10 rows * 12 cols = 120 elements
  logic [3:0] img_data [0:119];
  initial begin
      // 第 1 行
      img_data[0] = 4'd3; img_data[1] = 4'd7; img_data[2] = 4'd2; img_data[3] = 4'd9;
      img_data[4] = 4'd0; img_data[5] = 4'd5; img_data[6] = 4'd1; img_data[7] = 4'd8;
      img_data[8] = 4'd4; img_data[9] = 4'd6; img_data[10] = 4'd3; img_data[11] = 4'd2;
      // 第 2 行
      img_data[12] = 4'd8; img_data[13] = 4'd1; img_data[14] = 4'd6; img_data[15] = 4'd4;
      img_data[16] = 4'd7; img_data[17] = 4'd3; img_data[18] = 4'd9; img_data[19] = 4'd0;
      img_data[20] = 4'd5; img_data[21] = 4'd2; img_data[22] = 4'd8; img_data[23] = 4'd1;
      // 第 3 行
      img_data[24] = 4'd4; img_data[25] = 4'd9; img_data[26] = 4'd0; img_data[27] = 4'd2;
      img_data[28] = 4'd6; img_data[29] = 4'd8; img_data[30] = 4'd3; img_data[31] = 4'd5;
      img_data[32] = 4'd7; img_data[33] = 4'd1; img_data[34] = 4'd4; img_data[35] = 4'd9;
      // 第 4 行
      img_data[36] = 4'd7; img_data[37] = 4'd3; img_data[38] = 4'd8; img_data[39] = 4'd5;
      img_data[40] = 4'd1; img_data[41] = 4'd4; img_data[42] = 4'd9; img_data[43] = 4'd2;
      img_data[44] = 4'd0; img_data[45] = 4'd6; img_data[46] = 4'd7; img_data[47] = 4'd3;
      // 第 5 行
      img_data[48] = 4'd2; img_data[49] = 4'd6; img_data[50] = 4'd4; img_data[51] = 4'd0;
      img_data[52] = 4'd8; img_data[53] = 4'd7; img_data[54] = 4'd5; img_data[55] = 4'd3;
      img_data[56] = 4'd1; img_data[57] = 4'd9; img_data[58] = 4'd2; img_data[59] = 4'd4;
      // 第 6 行
      img_data[60] = 4'd9; img_data[61] = 4'd0; img_data[62] = 4'd7; img_data[63] = 4'd3;
      img_data[64] = 4'd5; img_data[65] = 4'd2; img_data[66] = 4'd8; img_data[67] = 4'd6;
      img_data[68] = 4'd4; img_data[69] = 4'd1; img_data[70] = 4'd9; img_data[71] = 4'd0;
      // 第 7 行
      img_data[72] = 4'd5; img_data[73] = 4'd8; img_data[74] = 4'd1; img_data[75] = 4'd6;
      img_data[76] = 4'd4; img_data[77] = 4'd9; img_data[78] = 4'd2; img_data[79] = 4'd7;
      img_data[80] = 4'd3; img_data[81] = 4'd0; img_data[82] = 4'd5; img_data[83] = 4'd8;
      // 第 8 行
      img_data[84] = 4'd1; img_data[85] = 4'd4; img_data[86] = 4'd9; img_data[87] = 4'd2;
      img_data[88] = 4'd7; img_data[89] = 4'd0; img_data[90] = 4'd6; img_data[91] = 4'd8;
      img_data[92] = 4'd5; img_data[93] = 4'd3; img_data[94] = 4'd1; img_data[95] = 4'd4;
      // 第 9 行
      img_data[96] = 4'd6; img_data[97] = 4'd2; img_data[98] = 4'd5; img_data[99] = 4'd8;
      img_data[100] = 4'd3; img_data[101] = 4'd1; img_data[102] = 4'd7; img_data[103] = 4'd4;
      img_data[104] = 4'd9; img_data[105] = 4'd0; img_data[106] = 4'd6; img_data[107] = 4'd2;
      // 第 10 行
      img_data[108] = 4'd0; img_data[109] = 4'd7; img_data[110] = 4'd3; img_data[111] = 4'd9;
      img_data[112] = 4'd5; img_data[113] = 4'd6; img_data[114] = 4'd4; img_data[115] = 4'd1;
      img_data[116] = 4'd8; img_data[117] = 4'd2; img_data[118] = 4'd0; img_data[119] = 4'd7;
  end

  // Helper function for saturation
  // [FIX] 输入改为 24-bit
  function automatic matrix_element_t saturate(input logic signed [23:0] val);
    if (val > 24'sd127) return 8'sd127;
    else if (val < -24'sd128) return -8'sd128;
    else return val[7:0];
  endfunction

  // --- Combinational Calculation Logic ---
  always_comb begin
    // 1. Matrix Multiplication Dot Product Logic
    // [NOTE] 这会综合出并行乘法器。如果 MAX_COLS 很大，注意时序违例。
    mat_mul_sum = 24'sd0;
    for (int k = 0; k < MAX_COLS; k++) begin
      // 必须判断 k < matrix_A.cols，防止读取未定义的内存区域影响结果
      if (k < matrix_A.cols) begin
        // 强制转换位宽进行计算，明确符号扩展
        mat_mul_sum += (24'(signed'(matrix_A.cells[cnt_i][k])) * 24'(signed'(matrix_B.cells[k][cnt_j])));
      end
    end

    // 2. Convolution Logic (3x3 Kernel)
    // Kernel is matrix_B (3x3). Input is img_data (10x12).
    // Current output pixel is (cnt_i, cnt_j).
    // Window top-left is (cnt_i, cnt_j).
    conv_sum = 24'sd0;
    if (op_code == OP_CONV) begin
        for (int r = 0; r < 3; r++) begin
            for (int c = 0; c < 3; c++) begin
                // img_index = (cnt_i + r) * 12 + (cnt_j + c)
                // kernel_val = matrix_B.cells[r][c]
                conv_sum += 24'(signed'({4'b0, img_data[(cnt_i + r) * 12 + (cnt_j + c)]})) * 24'(signed'(matrix_B.cells[r][c]));
            end
        end
    end

    // 3. Operation Selection
    case (op_code)
      OP_ADD:        calc_result_wide = 24'(signed'(matrix_A.cells[cnt_i][cnt_j])) + 24'(signed'(matrix_B.cells[cnt_i][cnt_j]));
      OP_SCALAR_MUL: calc_result_wide = 24'(signed'(matrix_A.cells[cnt_i][cnt_j])) * 24'(signed'(scalar_val));
      OP_TRANSPOSE:  calc_result_wide = 24'(signed'(matrix_A.cells[cnt_j][cnt_i])); // Swap indices
      OP_MAT_MUL:    calc_result_wide = mat_mul_sum;
      OP_CONV:       calc_result_wide = conv_sum;
      default:       calc_result_wide = 24'sd0;
    endcase
  end

  assign cycle_cnt = perf_cnt;

  // --- Sequential Control Logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ALU_IDLE;
      done          <= 0;
      error_flag    <= 0;
      result_matrix <= '0; // SystemVerilog clear all structure
      cnt_i         <= 0;
      cnt_j         <= 0;
      limit_i       <= 0;
      limit_j       <= 0;
      perf_cnt      <= 0;
    end else begin
      case (state)
        ALU_IDLE: begin
          done <= 0;
          if (start) begin
            error_flag    <= 0;
            perf_cnt      <= 0;
            // 不要在这里清空 result_matrix，这会消耗大量逻辑资源。
            // 只需要重置 is_valid 和 rows/cols 即可，数据会被覆盖。
            result_matrix.is_valid <= 0; 
            
            cnt_i         <= 0;
            cnt_j         <= 0;
            
            case (op_code)
              OP_ADD: begin
                if ((matrix_A.rows != matrix_B.rows) || (matrix_A.cols != matrix_B.cols)) begin
                  error_flag <= 1;
                  state      <= ALU_DONE;
                end else begin
                  result_matrix.rows     <= matrix_A.rows;
                  result_matrix.cols     <= matrix_A.cols;
                  limit_i                <= matrix_A.rows;
                  limit_j                <= matrix_A.cols;
                  state                  <= ALU_EXEC;
                end
              end

              OP_SCALAR_MUL: begin
                result_matrix.rows     <= matrix_A.rows;
                result_matrix.cols     <= matrix_A.cols;
                limit_i                <= matrix_A.rows;
                limit_j                <= matrix_A.cols;
                state                  <= ALU_EXEC;
              end

              OP_TRANSPOSE: begin
                result_matrix.rows     <= matrix_A.cols;
                result_matrix.cols     <= matrix_A.rows;
                limit_i                <= matrix_A.cols; 
                limit_j                <= matrix_A.rows; 
                state                  <= ALU_EXEC;
              end

              OP_MAT_MUL: begin
                if (matrix_A.cols != matrix_B.rows) begin
                  error_flag <= 1;
                  state      <= ALU_DONE;
                end else begin
                  result_matrix.rows     <= matrix_A.rows;
                  result_matrix.cols     <= matrix_B.cols;
                  limit_i                <= matrix_A.rows;
                  limit_j                <= matrix_B.cols;
                  state                  <= ALU_EXEC;
                end
              end

              OP_CONV: begin
                // Kernel (matrix_B) must be 3x3
                if (matrix_B.rows != 3 || matrix_B.cols != 3) begin
                    error_flag <= 1;
                    state <= ALU_DONE;
                end else begin
                    // Output dim: (10-3+1) x (12-3+1) = 8 x 10
                    result_matrix.rows <= 8;
                    result_matrix.cols <= 10;
                    limit_i <= 8;
                    limit_j <= 10;
                    state <= ALU_EXEC;
                end
              end

              default: state <= ALU_DONE;
            endcase
          end
        end

        ALU_EXEC: begin
          perf_cnt <= perf_cnt + 1; // Count cycles

          // 这里的写入是同步的，calc_result_wide 在时钟沿前已稳定
          result_matrix.cells[cnt_i][cnt_j] <= saturate(calc_result_wide);

          // Update Counters
          if (cnt_j == limit_j - 1) begin
            cnt_j <= 0;
            if (cnt_i == limit_i - 1) begin
              result_matrix.is_valid <= 1; // 计算完成后设为 valid
              state <= ALU_DONE;
            end else begin
              cnt_i <= cnt_i + 1;
            end
          end else begin
            cnt_j <= cnt_j + 1;
          end
        end

        ALU_DONE: begin
          done <= 1;
          if (!start) begin
            state <= ALU_IDLE;
          end
        end
      endcase
    end
  end

endmodule
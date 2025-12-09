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
    output logic     error_flag
);

  // --- Internal State ---
  typedef enum logic [2:0] {
    ALU_IDLE,
    ALU_EXEC,
    ALU_DONE
  } alu_state_t;

  alu_state_t state;

  // Counters for Matrix Multiplication
  logic [2:0] mul_i;
  logic [2:0] mul_j;

  // Pre-compute all 25 dot products combinationally (5x5)
  // Fully unrolled to avoid iverilog limitations
  logic signed [15:0] dot_prod_array [0:4][0:4];

  // Generate all dot products (fully unrolled)
  always_comb begin
    // Row 0
    dot_prod_array[0][0] = matrix_A.cells[0][0] * matrix_B.cells[0][0] +
      (1 < matrix_A.cols ? matrix_A.cells[0][1] * matrix_B.cells[1][0] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[0][2] * matrix_B.cells[2][0] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[0][3] * matrix_B.cells[3][0] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[0][4] * matrix_B.cells[4][0] : 16'sd0);
    
    dot_prod_array[0][1] = matrix_A.cells[0][0] * matrix_B.cells[0][1] +
      (1 < matrix_A.cols ? matrix_A.cells[0][1] * matrix_B.cells[1][1] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[0][2] * matrix_B.cells[2][1] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[0][3] * matrix_B.cells[3][1] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[0][4] * matrix_B.cells[4][1] : 16'sd0);
    
    dot_prod_array[0][2] = matrix_A.cells[0][0] * matrix_B.cells[0][2] +
      (1 < matrix_A.cols ? matrix_A.cells[0][1] * matrix_B.cells[1][2] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[0][2] * matrix_B.cells[2][2] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[0][3] * matrix_B.cells[3][2] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[0][4] * matrix_B.cells[4][2] : 16'sd0);
    
    dot_prod_array[0][3] = matrix_A.cells[0][0] * matrix_B.cells[0][3] +
      (1 < matrix_A.cols ? matrix_A.cells[0][1] * matrix_B.cells[1][3] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[0][2] * matrix_B.cells[2][3] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[0][3] * matrix_B.cells[3][3] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[0][4] * matrix_B.cells[4][3] : 16'sd0);
    
    dot_prod_array[0][4] = matrix_A.cells[0][0] * matrix_B.cells[0][4] +
      (1 < matrix_A.cols ? matrix_A.cells[0][1] * matrix_B.cells[1][4] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[0][2] * matrix_B.cells[2][4] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[0][3] * matrix_B.cells[3][4] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[0][4] * matrix_B.cells[4][4] : 16'sd0);

    // Row 1
    dot_prod_array[1][0] = matrix_A.cells[1][0] * matrix_B.cells[0][0] +
      (1 < matrix_A.cols ? matrix_A.cells[1][1] * matrix_B.cells[1][0] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[1][2] * matrix_B.cells[2][0] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[1][3] * matrix_B.cells[3][0] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[1][4] * matrix_B.cells[4][0] : 16'sd0);
    
    dot_prod_array[1][1] = matrix_A.cells[1][0] * matrix_B.cells[0][1] +
      (1 < matrix_A.cols ? matrix_A.cells[1][1] * matrix_B.cells[1][1] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[1][2] * matrix_B.cells[2][1] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[1][3] * matrix_B.cells[3][1] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[1][4] * matrix_B.cells[4][1] : 16'sd0);
    
    dot_prod_array[1][2] = matrix_A.cells[1][0] * matrix_B.cells[0][2] +
      (1 < matrix_A.cols ? matrix_A.cells[1][1] * matrix_B.cells[1][2] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[1][2] * matrix_B.cells[2][2] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[1][3] * matrix_B.cells[3][2] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[1][4] * matrix_B.cells[4][2] : 16'sd0);
    
    dot_prod_array[1][3] = matrix_A.cells[1][0] * matrix_B.cells[0][3] +
      (1 < matrix_A.cols ? matrix_A.cells[1][1] * matrix_B.cells[1][3] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[1][2] * matrix_B.cells[2][3] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[1][3] * matrix_B.cells[3][3] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[1][4] * matrix_B.cells[4][3] : 16'sd0);
    
    dot_prod_array[1][4] = matrix_A.cells[1][0] * matrix_B.cells[0][4] +
      (1 < matrix_A.cols ? matrix_A.cells[1][1] * matrix_B.cells[1][4] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[1][2] * matrix_B.cells[2][4] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[1][3] * matrix_B.cells[3][4] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[1][4] * matrix_B.cells[4][4] : 16'sd0);

    // Row 2
    dot_prod_array[2][0] = matrix_A.cells[2][0] * matrix_B.cells[0][0] +
      (1 < matrix_A.cols ? matrix_A.cells[2][1] * matrix_B.cells[1][0] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[2][2] * matrix_B.cells[2][0] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[2][3] * matrix_B.cells[3][0] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[2][4] * matrix_B.cells[4][0] : 16'sd0);
    
    dot_prod_array[2][1] = matrix_A.cells[2][0] * matrix_B.cells[0][1] +
      (1 < matrix_A.cols ? matrix_A.cells[2][1] * matrix_B.cells[1][1] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[2][2] * matrix_B.cells[2][1] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[2][3] * matrix_B.cells[3][1] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[2][4] * matrix_B.cells[4][1] : 16'sd0);
    
    dot_prod_array[2][2] = matrix_A.cells[2][0] * matrix_B.cells[0][2] +
      (1 < matrix_A.cols ? matrix_A.cells[2][1] * matrix_B.cells[1][2] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[2][2] * matrix_B.cells[2][2] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[2][3] * matrix_B.cells[3][2] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[2][4] * matrix_B.cells[4][2] : 16'sd0);
    
    dot_prod_array[2][3] = matrix_A.cells[2][0] * matrix_B.cells[0][3] +
      (1 < matrix_A.cols ? matrix_A.cells[2][1] * matrix_B.cells[1][3] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[2][2] * matrix_B.cells[2][3] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[2][3] * matrix_B.cells[3][3] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[2][4] * matrix_B.cells[4][3] : 16'sd0);
    
    dot_prod_array[2][4] = matrix_A.cells[2][0] * matrix_B.cells[0][4] +
      (1 < matrix_A.cols ? matrix_A.cells[2][1] * matrix_B.cells[1][4] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[2][2] * matrix_B.cells[2][4] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[2][3] * matrix_B.cells[3][4] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[2][4] * matrix_B.cells[4][4] : 16'sd0);

    // Row 3
    dot_prod_array[3][0] = matrix_A.cells[3][0] * matrix_B.cells[0][0] +
      (1 < matrix_A.cols ? matrix_A.cells[3][1] * matrix_B.cells[1][0] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[3][2] * matrix_B.cells[2][0] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[3][3] * matrix_B.cells[3][0] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[3][4] * matrix_B.cells[4][0] : 16'sd0);
    
    dot_prod_array[3][1] = matrix_A.cells[3][0] * matrix_B.cells[0][1] +
      (1 < matrix_A.cols ? matrix_A.cells[3][1] * matrix_B.cells[1][1] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[3][2] * matrix_B.cells[2][1] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[3][3] * matrix_B.cells[3][1] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[3][4] * matrix_B.cells[4][1] : 16'sd0);
    
    dot_prod_array[3][2] = matrix_A.cells[3][0] * matrix_B.cells[0][2] +
      (1 < matrix_A.cols ? matrix_A.cells[3][1] * matrix_B.cells[1][2] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[3][2] * matrix_B.cells[2][2] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[3][3] * matrix_B.cells[3][2] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[3][4] * matrix_B.cells[4][2] : 16'sd0);
    
    dot_prod_array[3][3] = matrix_A.cells[3][0] * matrix_B.cells[0][3] +
      (1 < matrix_A.cols ? matrix_A.cells[3][1] * matrix_B.cells[1][3] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[3][2] * matrix_B.cells[2][3] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[3][3] * matrix_B.cells[3][3] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[3][4] * matrix_B.cells[4][3] : 16'sd0);
    
    dot_prod_array[3][4] = matrix_A.cells[3][0] * matrix_B.cells[0][4] +
      (1 < matrix_A.cols ? matrix_A.cells[3][1] * matrix_B.cells[1][4] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[3][2] * matrix_B.cells[2][4] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[3][3] * matrix_B.cells[3][4] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[3][4] * matrix_B.cells[4][4] : 16'sd0);

    // Row 4
    dot_prod_array[4][0] = matrix_A.cells[4][0] * matrix_B.cells[0][0] +
      (1 < matrix_A.cols ? matrix_A.cells[4][1] * matrix_B.cells[1][0] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[4][2] * matrix_B.cells[2][0] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[4][3] * matrix_B.cells[3][0] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[4][4] * matrix_B.cells[4][0] : 16'sd0);
    
    dot_prod_array[4][1] = matrix_A.cells[4][0] * matrix_B.cells[0][1] +
      (1 < matrix_A.cols ? matrix_A.cells[4][1] * matrix_B.cells[1][1] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[4][2] * matrix_B.cells[2][1] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[4][3] * matrix_B.cells[3][1] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[4][4] * matrix_B.cells[4][1] : 16'sd0);
    
    dot_prod_array[4][2] = matrix_A.cells[4][0] * matrix_B.cells[0][2] +
      (1 < matrix_A.cols ? matrix_A.cells[4][1] * matrix_B.cells[1][2] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[4][2] * matrix_B.cells[2][2] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[4][3] * matrix_B.cells[3][2] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[4][4] * matrix_B.cells[4][2] : 16'sd0);
    
    dot_prod_array[4][3] = matrix_A.cells[4][0] * matrix_B.cells[0][3] +
      (1 < matrix_A.cols ? matrix_A.cells[4][1] * matrix_B.cells[1][3] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[4][2] * matrix_B.cells[2][3] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[4][3] * matrix_B.cells[3][3] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[4][4] * matrix_B.cells[4][3] : 16'sd0);
    
    dot_prod_array[4][4] = matrix_A.cells[4][0] * matrix_B.cells[0][4] +
      (1 < matrix_A.cols ? matrix_A.cells[4][1] * matrix_B.cells[1][4] : 16'sd0) +
      (2 < matrix_A.cols ? matrix_A.cells[4][2] * matrix_B.cells[2][4] : 16'sd0) +
      (3 < matrix_A.cols ? matrix_A.cells[4][3] * matrix_B.cells[3][4] : 16'sd0) +
      (4 < matrix_A.cols ? matrix_A.cells[4][4] * matrix_B.cells[4][4] : 16'sd0);
  end


  // Helper function for saturation
  function automatic matrix_element_t saturate(input logic signed [15:0] val);
    if (val > 16'sd127) return 8'sd127;
    else if (val < -16'sd128) return -8'sd128;
    else return val[7:0];
  endfunction

  // --- Main Logic ---
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ALU_IDLE;
      done          <= 0;
      error_flag    <= 0;
      result_matrix <= '0;
      mul_i         <= 0;
      mul_j         <= 0;
    end else begin
      case (state)
        ALU_IDLE: begin
          done <= 0;
          if (start) begin
            error_flag <= 0;
            result_matrix <= '0;
            
            case (op_code)
              OP_ADD: begin
                if ((matrix_A.rows != matrix_B.rows) || (matrix_A.cols != matrix_B.cols)) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_A.cols;
                  result_matrix.is_valid <= 1;
                  state <= ALU_EXEC;
                end
              end

              OP_SCALAR_MUL: begin
                result_matrix.rows <= matrix_A.rows;
                result_matrix.cols <= matrix_A.cols;
                result_matrix.is_valid <= 1;
                state <= ALU_EXEC;
              end

              OP_TRANSPOSE: begin
                result_matrix.rows <= matrix_A.cols;
                result_matrix.cols <= matrix_A.rows;
                result_matrix.is_valid <= 1;
                state <= ALU_EXEC;
              end

              OP_MAT_MUL: begin
                if (matrix_A.cols != matrix_B.rows) begin
                  error_flag <= 1;
                  state <= ALU_DONE;
                end else begin
                  result_matrix.rows <= matrix_A.rows;
                  result_matrix.cols <= matrix_B.cols;
                  result_matrix.is_valid <= 1;
                  mul_i <= 0;
                  mul_j <= 0;
                  state <= ALU_EXEC;
                end
              end

              default: begin
                state <= ALU_DONE;
              end
            endcase
          end
        end

        ALU_EXEC: begin
          case (op_code)
            // ================================================================
            // Matrix Addition
            // ================================================================
            OP_ADD: begin
              // Unroll all 25 cells
              if (0 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[0][0] <= saturate(matrix_A.cells[0][0] + matrix_B.cells[0][0]);
              else result_matrix.cells[0][0] <= 0;
              
              if (0 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[0][1] <= saturate(matrix_A.cells[0][1] + matrix_B.cells[0][1]);
              else result_matrix.cells[0][1] <= 0;
              
              if (0 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[0][2] <= saturate(matrix_A.cells[0][2] + matrix_B.cells[0][2]);
              else result_matrix.cells[0][2] <= 0;
              
              if (0 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[0][3] <= saturate(matrix_A.cells[0][3] + matrix_B.cells[0][3]);
              else result_matrix.cells[0][3] <= 0;
              
              if (0 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[0][4] <= saturate(matrix_A.cells[0][4] + matrix_B.cells[0][4]);
              else result_matrix.cells[0][4] <= 0;

              if (1 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[1][0] <= saturate(matrix_A.cells[1][0] + matrix_B.cells[1][0]);
              else result_matrix.cells[1][0] <= 0;
              
              if (1 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[1][1] <= saturate(matrix_A.cells[1][1] + matrix_B.cells[1][1]);
              else result_matrix.cells[1][1] <= 0;
              
              if (1 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[1][2] <= saturate(matrix_A.cells[1][2] + matrix_B.cells[1][2]);
              else result_matrix.cells[1][2] <= 0;
              
              if (1 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[1][3] <= saturate(matrix_A.cells[1][3] + matrix_B.cells[1][3]);
              else result_matrix.cells[1][3] <= 0;
              
              if (1 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[1][4] <= saturate(matrix_A.cells[1][4] + matrix_B.cells[1][4]);
              else result_matrix.cells[1][4] <= 0;

              if (2 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[2][0] <= saturate(matrix_A.cells[2][0] + matrix_B.cells[2][0]);
              else result_matrix.cells[2][0] <= 0;
              
              if (2 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[2][1] <= saturate(matrix_A.cells[2][1] + matrix_B.cells[2][1]);
              else result_matrix.cells[2][1] <= 0;
              
              if (2 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[2][2] <= saturate(matrix_A.cells[2][2] + matrix_B.cells[2][2]);
              else result_matrix.cells[2][2] <= 0;
              
              if (2 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[2][3] <= saturate(matrix_A.cells[2][3] + matrix_B.cells[2][3]);
              else result_matrix.cells[2][3] <= 0;
              
              if (2 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[2][4] <= saturate(matrix_A.cells[2][4] + matrix_B.cells[2][4]);
              else result_matrix.cells[2][4] <= 0;

              if (3 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[3][0] <= saturate(matrix_A.cells[3][0] + matrix_B.cells[3][0]);
              else result_matrix.cells[3][0] <= 0;
              
              if (3 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[3][1] <= saturate(matrix_A.cells[3][1] + matrix_B.cells[3][1]);
              else result_matrix.cells[3][1] <= 0;
              
              if (3 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[3][2] <= saturate(matrix_A.cells[3][2] + matrix_B.cells[3][2]);
              else result_matrix.cells[3][2] <= 0;
              
              if (3 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[3][3] <= saturate(matrix_A.cells[3][3] + matrix_B.cells[3][3]);
              else result_matrix.cells[3][3] <= 0;
              
              if (3 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[3][4] <= saturate(matrix_A.cells[3][4] + matrix_B.cells[3][4]);
              else result_matrix.cells[3][4] <= 0;

              if (4 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[4][0] <= saturate(matrix_A.cells[4][0] + matrix_B.cells[4][0]);
              else result_matrix.cells[4][0] <= 0;
              
              if (4 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[4][1] <= saturate(matrix_A.cells[4][1] + matrix_B.cells[4][1]);
              else result_matrix.cells[4][1] <= 0;
              
              if (4 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[4][2] <= saturate(matrix_A.cells[4][2] + matrix_B.cells[4][2]);
              else result_matrix.cells[4][2] <= 0;
              
              if (4 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[4][3] <= saturate(matrix_A.cells[4][3] + matrix_B.cells[4][3]);
              else result_matrix.cells[4][3] <= 0;
              
              if (4 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[4][4] <= saturate(matrix_A.cells[4][4] + matrix_B.cells[4][4]);
              else result_matrix.cells[4][4] <= 0;

              state <= ALU_DONE;
            end

            // ================================================================
            // Scalar Multiplication
            // ================================================================
            OP_SCALAR_MUL: begin
              // Unroll all 25 cells
              if (0 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[0][0] <= saturate(matrix_A.cells[0][0] * scalar_val);
              else result_matrix.cells[0][0] <= 0;
              
              if (0 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[0][1] <= saturate(matrix_A.cells[0][1] * scalar_val);
              else result_matrix.cells[0][1] <= 0;
              
              if (0 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[0][2] <= saturate(matrix_A.cells[0][2] * scalar_val);
              else result_matrix.cells[0][2] <= 0;
              
              if (0 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[0][3] <= saturate(matrix_A.cells[0][3] * scalar_val);
              else result_matrix.cells[0][3] <= 0;
              
              if (0 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[0][4] <= saturate(matrix_A.cells[0][4] * scalar_val);
              else result_matrix.cells[0][4] <= 0;

              if (1 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[1][0] <= saturate(matrix_A.cells[1][0] * scalar_val);
              else result_matrix.cells[1][0] <= 0;
              
              if (1 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[1][1] <= saturate(matrix_A.cells[1][1] * scalar_val);
              else result_matrix.cells[1][1] <= 0;
              
              if (1 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[1][2] <= saturate(matrix_A.cells[1][2] * scalar_val);
              else result_matrix.cells[1][2] <= 0;
              
              if (1 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[1][3] <= saturate(matrix_A.cells[1][3] * scalar_val);
              else result_matrix.cells[1][3] <= 0;
              
              if (1 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[1][4] <= saturate(matrix_A.cells[1][4] * scalar_val);
              else result_matrix.cells[1][4] <= 0;

              if (2 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[2][0] <= saturate(matrix_A.cells[2][0] * scalar_val);
              else result_matrix.cells[2][0] <= 0;
              
              if (2 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[2][1] <= saturate(matrix_A.cells[2][1] * scalar_val);
              else result_matrix.cells[2][1] <= 0;
              
              if (2 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[2][2] <= saturate(matrix_A.cells[2][2] * scalar_val);
              else result_matrix.cells[2][2] <= 0;
              
              if (2 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[2][3] <= saturate(matrix_A.cells[2][3] * scalar_val);
              else result_matrix.cells[2][3] <= 0;
              
              if (2 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[2][4] <= saturate(matrix_A.cells[2][4] * scalar_val);
              else result_matrix.cells[2][4] <= 0;

              if (3 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[3][0] <= saturate(matrix_A.cells[3][0] * scalar_val);
              else result_matrix.cells[3][0] <= 0;
              
              if (3 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[3][1] <= saturate(matrix_A.cells[3][1] * scalar_val);
              else result_matrix.cells[3][1] <= 0;
              
              if (3 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[3][2] <= saturate(matrix_A.cells[3][2] * scalar_val);
              else result_matrix.cells[3][2] <= 0;
              
              if (3 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[3][3] <= saturate(matrix_A.cells[3][3] * scalar_val);
              else result_matrix.cells[3][3] <= 0;
              
              if (3 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[3][4] <= saturate(matrix_A.cells[3][4] * scalar_val);
              else result_matrix.cells[3][4] <= 0;

              if (4 < matrix_A.rows && 0 < matrix_A.cols) 
                result_matrix.cells[4][0] <= saturate(matrix_A.cells[4][0] * scalar_val);
              else result_matrix.cells[4][0] <= 0;
              
              if (4 < matrix_A.rows && 1 < matrix_A.cols) 
                result_matrix.cells[4][1] <= saturate(matrix_A.cells[4][1] * scalar_val);
              else result_matrix.cells[4][1] <= 0;
              
              if (4 < matrix_A.rows && 2 < matrix_A.cols) 
                result_matrix.cells[4][2] <= saturate(matrix_A.cells[4][2] * scalar_val);
              else result_matrix.cells[4][2] <= 0;
              
              if (4 < matrix_A.rows && 3 < matrix_A.cols) 
                result_matrix.cells[4][3] <= saturate(matrix_A.cells[4][3] * scalar_val);
              else result_matrix.cells[4][3] <= 0;
              
              if (4 < matrix_A.rows && 4 < matrix_A.cols) 
                result_matrix.cells[4][4] <= saturate(matrix_A.cells[4][4] * scalar_val);
              else result_matrix.cells[4][4] <= 0;

              state <= ALU_DONE;
            end

            // ================================================================
            // Transpose
            // ================================================================
            OP_TRANSPOSE: begin
              // Map A[i][j] to Result[j][i]
              if (0 < matrix_A.rows && 0 < matrix_A.cols) result_matrix.cells[0][0] <= matrix_A.cells[0][0];
              if (0 < matrix_A.rows && 1 < matrix_A.cols) result_matrix.cells[1][0] <= matrix_A.cells[0][1];
              if (0 < matrix_A.rows && 2 < matrix_A.cols) result_matrix.cells[2][0] <= matrix_A.cells[0][2];
              if (0 < matrix_A.rows && 3 < matrix_A.cols) result_matrix.cells[3][0] <= matrix_A.cells[0][3];
              if (0 < matrix_A.rows && 4 < matrix_A.cols) result_matrix.cells[4][0] <= matrix_A.cells[0][4];
              
              if (1 < matrix_A.rows && 0 < matrix_A.cols) result_matrix.cells[0][1] <= matrix_A.cells[1][0];
              if (1 < matrix_A.rows && 1 < matrix_A.cols) result_matrix.cells[1][1] <= matrix_A.cells[1][1];
              if (1 < matrix_A.rows && 2 < matrix_A.cols) result_matrix.cells[2][1] <= matrix_A.cells[1][2];
              if (1 < matrix_A.rows && 3 < matrix_A.cols) result_matrix.cells[3][1] <= matrix_A.cells[1][3];
              if (1 < matrix_A.rows && 4 < matrix_A.cols) result_matrix.cells[4][1] <= matrix_A.cells[1][4];
              
              if (2 < matrix_A.rows && 0 < matrix_A.cols) result_matrix.cells[0][2] <= matrix_A.cells[2][0];
              if (2 < matrix_A.rows && 1 < matrix_A.cols) result_matrix.cells[1][2] <= matrix_A.cells[2][1];
              if (2 < matrix_A.rows && 2 < matrix_A.cols) result_matrix.cells[2][2] <= matrix_A.cells[2][2];
              if (2 < matrix_A.rows && 3 < matrix_A.cols) result_matrix.cells[3][2] <= matrix_A.cells[2][3];
              if (2 < matrix_A.rows && 4 < matrix_A.cols) result_matrix.cells[4][2] <= matrix_A.cells[2][4];
              
              if (3 < matrix_A.rows && 0 < matrix_A.cols) result_matrix.cells[0][3] <= matrix_A.cells[3][0];
              if (3 < matrix_A.rows && 1 < matrix_A.cols) result_matrix.cells[1][3] <= matrix_A.cells[3][1];
              if (3 < matrix_A.rows && 2 < matrix_A.cols) result_matrix.cells[2][3] <= matrix_A.cells[3][2];
              if (3 < matrix_A.rows && 3 < matrix_A.cols) result_matrix.cells[3][3] <= matrix_A.cells[3][3];
              if (3 < matrix_A.rows && 4 < matrix_A.cols) result_matrix.cells[4][3] <= matrix_A.cells[3][4];
              
              if (4 < matrix_A.rows && 0 < matrix_A.cols) result_matrix.cells[0][4] <= matrix_A.cells[4][0];
              if (4 < matrix_A.rows && 1 < matrix_A.cols) result_matrix.cells[1][4] <= matrix_A.cells[4][1];
              if (4 < matrix_A.rows && 2 < matrix_A.cols) result_matrix.cells[2][4] <= matrix_A.cells[4][2];
              if (4 < matrix_A.rows && 3 < matrix_A.cols) result_matrix.cells[3][4] <= matrix_A.cells[4][3];
              if (4 < matrix_A.rows && 4 < matrix_A.cols) result_matrix.cells[4][4] <= matrix_A.cells[4][4];

              state <= ALU_DONE;
            end

            // ================================================================
            // Matrix Multiplication (Simplified - one cell per cycle)
            // ================================================================
            OP_MAT_MUL: begin
              // Use pre-computed dot products (combinational)
              // Access via case statement to avoid packed array index issues
              case ({mul_i, mul_j})
                9'b000_000: result_matrix.cells[0][0] <= saturate(dot_prod_array[0][0]);
                9'b000_001: result_matrix.cells[0][1] <= saturate(dot_prod_array[0][1]);
                9'b000_010: result_matrix.cells[0][2] <= saturate(dot_prod_array[0][2]);
                9'b000_011: result_matrix.cells[0][3] <= saturate(dot_prod_array[0][3]);
                9'b000_100: result_matrix.cells[0][4] <= saturate(dot_prod_array[0][4]);
                
                9'b001_000: result_matrix.cells[1][0] <= saturate(dot_prod_array[1][0]);
                9'b001_001: result_matrix.cells[1][1] <= saturate(dot_prod_array[1][1]);
                9'b001_010: result_matrix.cells[1][2] <= saturate(dot_prod_array[1][2]);
                9'b001_011: result_matrix.cells[1][3] <= saturate(dot_prod_array[1][3]);
                9'b001_100: result_matrix.cells[1][4] <= saturate(dot_prod_array[1][4]);
                
                9'b010_000: result_matrix.cells[2][0] <= saturate(dot_prod_array[2][0]);
                9'b010_001: result_matrix.cells[2][1] <= saturate(dot_prod_array[2][1]);
                9'b010_010: result_matrix.cells[2][2] <= saturate(dot_prod_array[2][2]);
                9'b010_011: result_matrix.cells[2][3] <= saturate(dot_prod_array[2][3]);
                9'b010_100: result_matrix.cells[2][4] <= saturate(dot_prod_array[2][4]);
                
                9'b011_000: result_matrix.cells[3][0] <= saturate(dot_prod_array[3][0]);
                9'b011_001: result_matrix.cells[3][1] <= saturate(dot_prod_array[3][1]);
                9'b011_010: result_matrix.cells[3][2] <= saturate(dot_prod_array[3][2]);
                9'b011_011: result_matrix.cells[3][3] <= saturate(dot_prod_array[3][3]);
                9'b011_100: result_matrix.cells[3][4] <= saturate(dot_prod_array[3][4]);
                
                9'b100_000: result_matrix.cells[4][0] <= saturate(dot_prod_array[4][0]);
                9'b100_001: result_matrix.cells[4][1] <= saturate(dot_prod_array[4][1]);
                9'b100_010: result_matrix.cells[4][2] <= saturate(dot_prod_array[4][2]);
                9'b100_011: result_matrix.cells[4][3] <= saturate(dot_prod_array[4][3]);
                9'b100_100: result_matrix.cells[4][4] <= saturate(dot_prod_array[4][4]);
              endcase

              // Update counters
              if (mul_j == matrix_B.cols - 1) begin
                mul_j <= 0;
                if (mul_i == matrix_A.rows - 1) begin
                  state <= ALU_DONE;
                end else begin
                  mul_i <= mul_i + 1;
                end
              end else begin
                mul_j <= mul_j + 1;
              end
            end

            default: state <= ALU_DONE;
          endcase
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


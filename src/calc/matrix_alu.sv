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
# v1.3  | 2025-12-15 | GitHub Copilot |   Refactored to use Scalar RAM Interface
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

    // --- Data Interface (Scalar Read) ---
    // Port A
    output logic    [ROW_IDX_W-1:0] rd_row_A,
    output logic    [COL_IDX_W-1:0] rd_col_A,
    input  matrix_element_t         rd_val_A,
    input  wire     [ROW_IDX_W-1:0] rd_dims_r_A,
    input  wire     [COL_IDX_W-1:0] rd_dims_c_A,

    // Port B
    output logic    [ROW_IDX_W-1:0] rd_row_B,
    output logic    [COL_IDX_W-1:0] rd_col_B,
    input  matrix_element_t         rd_val_B,
    input  wire     [ROW_IDX_W-1:0] rd_dims_r_B,
    input  wire     [COL_IDX_W-1:0] rd_dims_c_B,

    input matrix_element_t scalar_val,

    // --- Output Interface (Scalar Write) ---
    output logic           done,
    output logic           error_flag,
    output logic    [31:0] cycle_cnt,

    // Write Port to Storage
    output logic           alu_wr_en,
    output logic           alu_wr_new,
    output logic    [ROW_IDX_W-1:0] alu_wr_dims_r,
    output logic    [COL_IDX_W-1:0] alu_wr_dims_c,
    output logic    [ROW_IDX_W-1:0] alu_wr_row,
    output logic    [COL_IDX_W-1:0] alu_wr_col,
    output matrix_element_t         alu_wr_val
);

  // --- Internal State ---
  typedef enum logic [3:0] {
    ALU_IDLE,
    ALU_PREPARE, // Check dimensions, set up result dims
    ALU_ALLOC,   // Send 'new' command
    ALU_FETCH,   // Set read address
    ALU_WAIT,    // Wait for RAM
    ALU_CALC,    // Compute and Write
    ALU_DONE
  } alu_state_t;
  alu_state_t state;

  // Counters
  logic [3:0] cnt_i;  // Row
  logic [3:0] cnt_j;  // Col
  logic [3:0] cnt_k;  // Dot product accumulator iterator

  logic [3:0] limit_i;
  logic [3:0] limit_j;
  logic [3:0] limit_k;

  // Cycle Counter
  logic [31:0] perf_cnt;

  // Accumulators
  logic signed [23:0] accum;

  // --- Hardcoded Image Data (Optimized as Function) ---
  function automatic logic [3:0] get_img_data(input int idx);
    case (idx)
      // Row 1: 3 7 2 9 0 5 1 8 4 6 3 2
      0: return 4'd3; 1: return 4'd7; 2: return 4'd2; 3: return 4'd9;
      4: return 4'd0; 5: return 4'd5; 6: return 4'd1; 7: return 4'd8;
      8: return 4'd4; 9: return 4'd6; 10: return 4'd3; 11: return 4'd2;
      // Row 2: 8 1 6 4 7 3 9 0 5 2 8 1
      12: return 4'd8; 13: return 4'd1; 14: return 4'd6; 15: return 4'd4;
      16: return 4'd7; 17: return 4'd3; 18: return 4'd9; 19: return 4'd0;
      20: return 4'd5; 21: return 4'd2; 22: return 4'd8; 23: return 4'd1;
      // Row 3: 4 9 0 2 6 8 3 5 7 1 4 9
      24: return 4'd4; 25: return 4'd9; 26: return 4'd0; 27: return 4'd2;
      28: return 4'd6; 29: return 4'd8; 30: return 4'd3; 31: return 4'd5;
      32: return 4'd7; 33: return 4'd1; 34: return 4'd4; 35: return 4'd9;
      // Row 4: 7 3 8 5 1 4 9 2 0 6 7 3
      36: return 4'd7; 37: return 4'd3; 38: return 4'd8; 39: return 4'd5;
      40: return 4'd1; 41: return 4'd4; 42: return 4'd9; 43: return 4'd2;
      44: return 4'd0; 45: return 4'd6; 46: return 4'd7; 47: return 4'd3;
      // Row 5: 2 6 4 0 8 7 5 3 1 9 2 4
      48: return 4'd2; 49: return 4'd6; 50: return 4'd4; 51: return 4'd0;
      52: return 4'd8; 53: return 4'd7; 54: return 4'd5; 55: return 4'd3;
      56: return 4'd1; 57: return 4'd9; 58: return 4'd2; 59: return 4'd4;
      // Row 6: 9 0 7 3 5 2 8 6 4 1 9 0
      60: return 4'd9; 61: return 4'd0; 62: return 4'd7; 63: return 4'd3;
      64: return 4'd5; 65: return 4'd2; 66: return 4'd8; 67: return 4'd6;
      68: return 4'd4; 69: return 4'd1; 70: return 4'd9; 71: return 4'd0;
      // Row 7: 5 8 1 6 4 9 2 7 3 0 5 8
      72: return 4'd5; 73: return 4'd8; 74: return 4'd1; 75: return 4'd6;
      76: return 4'd4; 77: return 4'd9; 78: return 4'd2; 79: return 4'd7;
      80: return 4'd3; 81: return 4'd0; 82: return 4'd5; 83: return 4'd8;
      // Row 8: 1 4 9 2 7 0 6 8 5 3 1 4
      84: return 4'd1; 85: return 4'd4; 86: return 4'd9; 87: return 4'd2;
      88: return 4'd7; 89: return 4'd0; 90: return 4'd6; 91: return 4'd8;
      92: return 4'd5; 93: return 4'd3; 94: return 4'd1; 95: return 4'd4;
      // Row 9: 6 2 5 8 3 1 7 4 9 0 6 2
      96: return 4'd6; 97: return 4'd2; 98: return 4'd5; 99: return 4'd8;
      100: return 4'd3; 101: return 4'd1; 102: return 4'd7; 103: return 4'd4;
      104: return 4'd9; 105: return 4'd0; 106: return 4'd6; 107: return 4'd2;
      // Row 10: 0 7 3 9 5 6 4 1 8 2 0 7
      108: return 4'd0; 109: return 4'd7; 110: return 4'd3; 111: return 4'd9;
      112: return 4'd5; 113: return 4'd6; 114: return 4'd4; 115: return 4'd1;
      116: return 4'd8; 117: return 4'd2; 118: return 4'd0; 119: return 4'd7;
      default: return 4'd0;
    endcase
  endfunction

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
      
      alu_wr_en     <= 0;
      alu_wr_new    <= 0;
      alu_wr_dims_r <= 0;
      alu_wr_dims_c <= 0;
      alu_wr_row    <= 0;
      alu_wr_col    <= 0;
      alu_wr_val    <= 0;

      rd_row_A      <= 0;
      rd_col_A      <= 0;
      rd_row_B      <= 0;
      rd_col_B      <= 0;

      cnt_i         <= 0;
      cnt_j         <= 0;
      cnt_k         <= 0;
      limit_i       <= 0;
      limit_j       <= 0;
      limit_k       <= 0;
      perf_cnt      <= 0;
      accum         <= 0;
    end else begin
      // Default signals
      alu_wr_en  <= 0;
      alu_wr_new <= 0;

      case (state)
        // ------------------------------------------------------------
        // 1. IDLE
        // ------------------------------------------------------------
        ALU_IDLE: begin
          done <= 0;
          if (start) begin
            error_flag <= 0;
            perf_cnt   <= 0;
            cnt_i      <= 0;
            cnt_j      <= 0;
            cnt_k      <= 0;
            accum      <= 0;
            state      <= ALU_PREPARE;
          end
        end

        // ------------------------------------------------------------
        // 2. PREPARE (Check Dims)
        // ------------------------------------------------------------
        ALU_PREPARE: begin
          case (op_code)
            OP_ADD: begin
              if ((rd_dims_r_A != rd_dims_r_B) || (rd_dims_c_A != rd_dims_c_B)) begin
                error_flag <= 1;
                state <= ALU_DONE;
              end else begin
                alu_wr_dims_r <= rd_dims_r_A;
                alu_wr_dims_c <= rd_dims_c_A;
                limit_i <= rd_dims_r_A;
                limit_j <= rd_dims_c_A;
                state <= ALU_ALLOC;
              end
            end

            OP_SCALAR_MUL: begin
              alu_wr_dims_r <= rd_dims_r_A;
              alu_wr_dims_c <= rd_dims_c_A;
              limit_i <= rd_dims_r_A;
              limit_j <= rd_dims_c_A;
              state <= ALU_ALLOC;
            end

            OP_TRANSPOSE: begin
              alu_wr_dims_r <= rd_dims_c_A;
              alu_wr_dims_c <= rd_dims_r_A;
              limit_i <= rd_dims_c_A; // Result rows = A cols
              limit_j <= rd_dims_r_A; // Result cols = A rows
              state <= ALU_ALLOC;
            end

            OP_MAT_MUL: begin
              if (rd_dims_c_A != rd_dims_r_B) begin
                error_flag <= 1;
                state <= ALU_DONE;
              end else begin
                alu_wr_dims_r <= rd_dims_r_A;
                alu_wr_dims_c <= rd_dims_c_B;
                limit_i <= rd_dims_r_A;
                limit_j <= rd_dims_c_B;
                limit_k <= rd_dims_c_A; // Common dimension
                state <= ALU_ALLOC;
              end
            end

            OP_CONV: begin
              // Convolution: Output is 8x10 (fixed for this project)
              // Input B is 3x3 kernel
              if (rd_dims_r_B != 3 || rd_dims_c_B != 3) begin
                error_flag <= 1;
                state <= ALU_DONE;
              end else begin
                alu_wr_dims_r <= 8;
                alu_wr_dims_c <= 10;
                limit_i <= 8;
                limit_j <= 10;
                state <= ALU_ALLOC;
              end
            end

            default: state <= ALU_DONE;
          endcase
        end

        // ------------------------------------------------------------
        // 3. ALLOC (Create Result Matrix)
        // ------------------------------------------------------------
        ALU_ALLOC: begin
          alu_wr_new <= 1; // Pulse 'new'
          state <= ALU_FETCH;
        end

        // ------------------------------------------------------------
        // 4. FETCH (Set Read Addrs)
        // ------------------------------------------------------------
        ALU_FETCH: begin
          perf_cnt <= perf_cnt + 1;
          
          case (op_code)
            OP_ADD, OP_SCALAR_MUL: begin
              rd_row_A <= cnt_i;
              rd_col_A <= cnt_j;
              rd_row_B <= cnt_i;
              rd_col_B <= cnt_j;
            end
            OP_TRANSPOSE: begin
              // Result(i,j) comes from A(j,i)
              rd_row_A <= cnt_j;
              rd_col_A <= cnt_i;
            end
            OP_MAT_MUL: begin
              // Accumulate A(i,k) * B(k,j)
              rd_row_A <= cnt_i;
              rd_col_A <= cnt_k;
              rd_row_B <= cnt_k;
              rd_col_B <= cnt_j;
            end
            OP_CONV: begin
              // For convolution, we need to read B (kernel) and Image (ROM)
              // Image is in ROM, not in storage A.
              // But wait, the project spec says "Input Image ROM".
              // Does ALU read from ROM directly?
              // Yes, get_img_data() is the ROM.
              // So we only need to read B (Kernel) from storage.
              // We need to read B[0][0]...B[2][2].
              // Since we can only read 1 element per cycle from B,
              // we need a sub-state machine or just serialize the 9 reads.
              // Or, since B is small (3x3), maybe we can cache it?
              // For now, let's just read B[cnt_k/3][cnt_k%3]
              // We use cnt_k to iterate 0..8
              rd_row_B <= cnt_k / 3;
              rd_col_B <= cnt_k % 3;
            end
          endcase
          state <= ALU_WAIT;
        end

        // ------------------------------------------------------------
        // 5. WAIT (RAM Latency)
        // ------------------------------------------------------------
        ALU_WAIT: begin
          perf_cnt <= perf_cnt + 1;
          state <= ALU_CALC;
        end

        // ------------------------------------------------------------
        // 6. CALC (Compute & Write)
        // ------------------------------------------------------------
        ALU_CALC: begin
          perf_cnt <= perf_cnt + 1;

          case (op_code)
            // --- Simple Ops ---
            OP_ADD: begin
              alu_wr_en  <= 1;
              alu_wr_row <= cnt_i;
              alu_wr_col <= cnt_j;
              alu_wr_val <= saturate(24'(signed'(rd_val_A)) + 24'(signed'(rd_val_B)));
              
              // Loop Logic
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) state <= ALU_DONE;
                else begin
                  cnt_i <= cnt_i + 1;
                  state <= ALU_FETCH;
                end
              end else begin
                cnt_j <= cnt_j + 1;
                state <= ALU_FETCH;
              end
            end

            OP_SCALAR_MUL: begin
              alu_wr_en  <= 1;
              alu_wr_row <= cnt_i;
              alu_wr_col <= cnt_j;
              alu_wr_val <= saturate(24'(signed'(rd_val_A)) * 24'(signed'(scalar_val)));
              
              // Loop Logic
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) state <= ALU_DONE;
                else begin
                  cnt_i <= cnt_i + 1;
                  state <= ALU_FETCH;
                end
              end else begin
                cnt_j <= cnt_j + 1;
                state <= ALU_FETCH;
              end
            end

            OP_TRANSPOSE: begin
              alu_wr_en  <= 1;
              alu_wr_row <= cnt_i;
              alu_wr_col <= cnt_j;
              alu_wr_val <= rd_val_A;

              // Loop Logic
              if (cnt_j == limit_j - 1) begin
                cnt_j <= 0;
                if (cnt_i == limit_i - 1) state <= ALU_DONE;
                else begin
                  cnt_i <= cnt_i + 1;
                  state <= ALU_FETCH;
                end
              end else begin
                cnt_j <= cnt_j + 1;
                state <= ALU_FETCH;
              end
            end

            // --- Matrix Mul ---
            OP_MAT_MUL: begin
              // Accumulate
              accum <= accum + (24'(signed'(rd_val_A)) * 24'(signed'(rd_val_B)));

              if (cnt_k == limit_k - 1) begin
                // Finished dot product for this cell
                alu_wr_en  <= 1;
                alu_wr_row <= cnt_i;
                alu_wr_col <= cnt_j;
                alu_wr_val <= saturate(accum + (24'(signed'(rd_val_A)) * 24'(signed'(rd_val_B))));
                
                accum <= 0;
                cnt_k <= 0;

                // Move to next cell
                if (cnt_j == limit_j - 1) begin
                  cnt_j <= 0;
                  if (cnt_i == limit_i - 1) state <= ALU_DONE;
                  else begin
                    cnt_i <= cnt_i + 1;
                    state <= ALU_FETCH;
                  end
                end else begin
                  cnt_j <= cnt_j + 1;
                  state <= ALU_FETCH;
                end
              end else begin
                cnt_k <= cnt_k + 1;
                state <= ALU_FETCH;
              end
            end

            // --- Convolution ---
            OP_CONV: begin
               // We are iterating k from 0 to 8 (3x3 kernel)
               // rd_val_B is the kernel value
               // Image data comes from get_img_data
               
               // Calculate image index: (i+r)*12 + (j+c)
               // r = cnt_k / 3, c = cnt_k % 3
               // But get_img_data takes linear index.
               // Image is 10x12? No, ROM says 10 rows x 12 cols.
               // get_img_data takes 0..119.
               
               int r, c, img_r, img_c, img_idx;
               r = cnt_k / 3;
               c = cnt_k % 3;
               img_r = cnt_i + r;
               img_c = cnt_j + c;
               img_idx = img_r * 12 + img_c;
               
               accum <= accum + (24'(signed'(get_img_data(img_idx))) * 24'(signed'(rd_val_B)));
               
               if (cnt_k == 8) begin
                   // Finished 3x3 window
                   alu_wr_en  <= 1;
                   alu_wr_row <= cnt_i;
                   alu_wr_col <= cnt_j;
                   alu_wr_val <= saturate(accum + (24'(signed'(get_img_data(img_idx))) * 24'(signed'(rd_val_B))));
                   
                   accum <= 0;
                   cnt_k <= 0;
                   
                   // Move to next pixel
                   if (cnt_j == limit_j - 1) begin
                       cnt_j <= 0;
                       if (cnt_i == limit_i - 1) state <= ALU_DONE;
                       else begin
                           cnt_i <= cnt_i + 1;
                           state <= ALU_FETCH;
                       end
                   end else begin
                       cnt_j <= cnt_j + 1;
                       state <= ALU_FETCH;
                   end
               end else begin
                   cnt_k <= cnt_k + 1;
                   state <= ALU_FETCH;
               end
            end

          endcase
        end

        // ------------------------------------------------------------
        // 7. DONE
        // ------------------------------------------------------------
        ALU_DONE: begin
          done <= 1;
          cycle_cnt <= perf_cnt;
          if (!start) state <= ALU_IDLE;
        end

      endcase
    end
  end

endmodule

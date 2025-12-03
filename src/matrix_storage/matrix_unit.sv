/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_unit.sv
# Module Name    : matrix_unit
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Stores a single matrix (5x5 max).
#     Supports single element read/write and full matrix load/dump.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
# v1.1  | 2025-12-03 |   GitHub Copilot |   Implemented storage logic
#
#=============================================================================*/
import project_pkg::*;

module matrix_unit (
    input  wire clk,
    input  wire rst_n,

    // --- Control Signals ---
    input  wire        clear,        // Reset matrix data and valid flag
    input  wire        set_dims,     // Update dimensions
    input  wire [2:0]  dims_r,       // New rows
    input  wire [2:0]  dims_c,       // New cols

    // --- Single Element Write ---
    input  wire        we,           // Write Enable
    input  wire [2:0]  w_row,        // Write Row Index
    input  wire [2:0]  w_col,        // Write Col Index
    input  matrix_element_t w_data,  // Write Data

    // --- Full Matrix Load (from ALU) ---
    input  wire        load_all,     // Load entire matrix_t
    input  matrix_t    matrix_in,    // Input matrix structure

    // --- Single Element Read ---
    input  wire [2:0]  r_row,        // Read Row Index
    input  wire [2:0]  r_col,        // Read Col Index
    output matrix_element_t r_data,  // Read Data

    // --- Full Matrix Output ---
    output matrix_t    matrix_out    // Current stored matrix
);

    // Internal Storage (1D Packed Vector for maximum compatibility)
    logic [ROW_IDX_W-1:0] stored_rows;
    logic [COL_IDX_W-1:0] stored_cols;
    logic                 stored_valid;
    logic [MAX_ROWS*MAX_COLS*DATA_WIDTH-1:0] stored_vector;

    // Output Assignment (Bit-blasting to avoid iverilog struct member bug)
    // matrix_t is packed: {rows, cols, is_valid, cells}
    assign matrix_out = {stored_rows, stored_cols, stored_valid, stored_vector};
    
    /*
    assign matrix_out.rows = stored_rows;
    assign matrix_out.cols = stored_cols;
    assign matrix_out.is_valid = stored_valid;
    assign matrix_out.cells = stored_vector;
    */

    // Read Logic (Combinational)
    always_comb begin
        r_data = '0;
        if (r_row < MAX_ROWS && r_col < MAX_COLS) begin
            r_data = stored_vector[(r_row * MAX_COLS + r_col) * DATA_WIDTH +: DATA_WIDTH];
        end
    end

    // Write Logic (Sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stored_rows <= '0;
            stored_cols <= '0;
            stored_valid <= '0;
            stored_vector <= '0;
        end else begin
            if (clear) begin
                stored_valid <= '0;
                stored_vector <= '0;
            end else if (load_all) begin
                stored_rows <= matrix_in.rows;
                stored_cols <= matrix_in.cols;
                stored_valid <= matrix_in.is_valid;
                // Direct assignment using bit slicing (cells are at LSB)
                stored_vector <= matrix_in[MAX_ROWS*MAX_COLS*DATA_WIDTH-1:0];
            end else begin
                // 1. Set Dimensions
                if (set_dims) begin
                    stored_rows <= dims_r;
                    stored_cols <= dims_c;
                    stored_valid <= 1'b1;
                end

                // 2. Write Single Element
                if (we) begin
                    if (w_row < MAX_ROWS && w_col < MAX_COLS) begin
                        stored_vector[(w_row * MAX_COLS + w_col) * DATA_WIDTH +: DATA_WIDTH] <= w_data;
                    end
                end
            end
        end
    end

endmodule

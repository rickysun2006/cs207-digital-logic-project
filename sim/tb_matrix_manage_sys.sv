/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : tb_matrix_manage_sys.sv
# Module Name    : tb_matrix_manage_sys
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     Testbench for matrix_manage_sys (matrix_storage_sys.sv)
#
#=============================================================================*/
`timescale 1ns / 1ps
import project_pkg::*;

module tb_matrix_manage_sys;

    // --- Signals ---
    logic clk;
    logic rst_n;
    logic wr_en;
    logic [2:0] wr_id; // Unused in module but present in port list
    logic wr_cmd_clear;
    logic wr_cmd_set_dims;
    logic wr_cmd_load_all;
    logic wr_cmd_single;
    logic [ROW_IDX_W-1:0] wr_dims_r;
    logic [COL_IDX_W-1:0] wr_dims_c;
    logic [ROW_IDX_W-1:0] wr_row_idx;
    logic [COL_IDX_W-1:0] wr_col_idx;
    matrix_element_t wr_val_scalar;
    logic [MAT_ID_W-1:0] wr_target_id;
    matrix_t wr_val_matrix;
    logic [MAT_ID_W-1:0] rd_id_A;
    matrix_t rd_data_A;
    logic rd_valid_A;
    logic [MAT_ID_W-1:0] rd_id_B;
    matrix_t rd_data_B;
    logic rd_valid_B;

    // --- DUT Instantiation ---
    matrix_manage_sys u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_id(wr_id),
        .wr_cmd_clear(wr_cmd_clear),
        .wr_cmd_set_dims(wr_cmd_set_dims),
        .wr_cmd_load_all(wr_cmd_load_all),
        .wr_cmd_single(wr_cmd_single),
        .wr_dims_r(wr_dims_r),
        .wr_dims_c(wr_dims_c),
        .wr_row_idx(wr_row_idx),
        .wr_col_idx(wr_col_idx),
        .wr_val_scalar(wr_val_scalar),
        .wr_target_id(wr_target_id),
        .wr_val_matrix(wr_val_matrix),
        .rd_id_A(rd_id_A),
        .rd_data_A(rd_data_A),
        .rd_valid_A(rd_valid_A),
        .rd_id_B(rd_id_B),
        .rd_data_B(rd_data_B),
        .rd_valid_B(rd_valid_B)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // --- Test Procedure ---
    initial begin
        // Initialize
        rst_n = 0;
        wr_en = 0;
        wr_id = 0;
        wr_cmd_clear = 0;
        wr_cmd_set_dims = 0;
        wr_cmd_load_all = 0;
        wr_cmd_single = 0;
        wr_dims_r = 0;
        wr_dims_c = 0;
        wr_row_idx = 0;
        wr_col_idx = 0;
        wr_val_scalar = 0;
        wr_target_id = 0;
        wr_val_matrix = '0;
        rd_id_A = 0;
        rd_id_B = 0;

        #20 rst_n = 1;
        $display("--- Test Start: Matrix Storage ---");

        // Test 1: Create a 2x2 Matrix
        // This should allocate a matrix ID.
        // Since it's the first one, and 2x2 corresponds to some type index.
        // 2x2 -> type_idx = (2-1)*5 + (2-1) = 1*5 + 1 = 6.
        // base_addr = 6 * 8 = 48.
        // ptr = 0.
        // So ID should be 48.
        
        $display("Test 1: Create 2x2 Matrix");
        wr_en = 1;
        wr_cmd_set_dims = 1;
        wr_dims_r = 2;
        wr_dims_c = 2;
        #10;
        wr_cmd_set_dims = 0;
        
        // Now write data to it (ID 48)
        // (0,0) = 1
        wr_cmd_single = 1;
        wr_row_idx = 0; wr_col_idx = 0; wr_val_scalar = 1;
        #10;
        // (1,1) = 2
        wr_row_idx = 1; wr_col_idx = 1; wr_val_scalar = 2;
        #10;
        wr_cmd_single = 0;
        wr_en = 0;

        // Read back from ID 48
        rd_id_A = 48;
        #10;
        
        $display("Read ID %d: Rows=%d Cols=%d Valid=%d", rd_id_A, rd_data_A.rows, rd_data_A.cols, rd_data_A.is_valid);
        $display("Data: %d %d / %d %d", 
            rd_data_A.cells[0][0], rd_data_A.cells[0][1],
            rd_data_A.cells[1][0], rd_data_A.cells[1][1]);

        assert(rd_data_A.rows == 2) else $error("Rows mismatch");
        assert(rd_data_A.cells[0][0] == 1) else $error("Cell(0,0) mismatch");
        assert(rd_data_A.cells[1][1] == 2) else $error("Cell(1,1) mismatch");

        // Test 2: Load All (Overwrite)
        $display("Test 2: Load All to ID 48");
        wr_en = 1;
        wr_cmd_load_all = 1;
        wr_target_id = 48;
        wr_val_matrix.rows = 2;
        wr_val_matrix.cols = 2;
        wr_val_matrix.is_valid = 1;
        wr_val_matrix.cells[0][0] = 9;
        wr_val_matrix.cells[1][1] = 9;
        #10;
        wr_cmd_load_all = 0;
        wr_en = 0;
        
        #10;
        $display("Read ID %d: %d %d", rd_id_A, rd_data_A.cells[0][0], rd_data_A.cells[1][1]);
        assert(rd_data_A.cells[0][0] == 9) else $error("LoadAll mismatch");

        $display("--- Test End ---");
        $finish;
    end

endmodule

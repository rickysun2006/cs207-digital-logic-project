/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : tb_matrix_unit.sv
# Module Name    : tb_matrix_unit
# University     : SUSTech
#
# Create Date    : 2025-12-03
#
# Description    :
#     Testbench for matrix_unit.sv
#
#=============================================================================*/
`timescale 1ns / 1ps
import project_pkg::*;

module tb_matrix_unit;

    // --- Signals ---
    logic clk;
    logic rst_n;
    logic clear;
    logic set_dims;
    logic [2:0] dims_r;
    logic [2:0] dims_c;
    logic we;
    logic [2:0] w_row;
    logic [2:0] w_col;
    matrix_element_t w_data;
    logic load_all;
    matrix_t matrix_in;
    logic [2:0] r_row;
    logic [2:0] r_col;
    matrix_element_t r_data;
    matrix_t matrix_out;

    // --- DUT Instantiation ---
    matrix_unit u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .clear      (clear),
        .set_dims   (set_dims),
        .dims_r     (dims_r),
        .dims_c     (dims_c),
        .we         (we),
        .w_row      (w_row),
        .w_col      (w_col),
        .w_data     (w_data),
        .load_all   (load_all),
        .matrix_in  (matrix_in),
        .r_row      (r_row),
        .r_col      (r_col),
        .r_data     (r_data),
        .matrix_out (matrix_out)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // --- Test Procedure ---
    initial begin
        // 1. Initialize
        rst_n = 0;
        clear = 0;
        set_dims = 0;
        dims_r = 0;
        dims_c = 0;
        we = 0;
        w_row = 0;
        w_col = 0;
        w_data = 0;
        load_all = 0;
        matrix_in = '0;
        r_row = 0;
        r_col = 0;

        #20 rst_n = 1;
        $display("--- Test Start ---");

        // 2. Test Set Dimensions
        #10;
        $display("Test 1: Set Dimensions to 2x3");
        set_dims = 1;
        dims_r = 2;
        dims_c = 3;
        #10;
        set_dims = 0;
        
        assert(matrix_out.rows == 2) else $error("Rows mismatch!");
        assert(matrix_out.cols == 3) else $error("Cols mismatch!");
        assert(matrix_out.is_valid == 1) else $error("Valid flag mismatch!");

        // 3. Test Single Element Write
        $display("Test 2: Write (0,0)=10, (1,2)=-5");
        // Write (0,0) = 10
        we = 1; w_row = 0; w_col = 0; w_data = 8'd10;
        #10;
        // Write (1,2) = -5
        w_row = 1; w_col = 2; w_data = -8'd5;
        #10;
        we = 0;

        // 4. Test Single Element Read
        $display("Test 3: Read back values");
        r_row = 0; r_col = 0;
        #1;
        assert(r_data == 8'd10) else $error("Read (0,0) failed! Expected 10, got %d", r_data);
        
        r_row = 1; r_col = 2;
        #1;
        assert(r_data == -8'd5) else $error("Read (1,2) failed! Expected -5, got %d", r_data);

        // 5. Test Full Load
        $display("Test 4: Full Matrix Load");
        matrix_in.rows = 3;
        matrix_in.cols = 3;
        matrix_in.is_valid = 1;
        matrix_in.cells[0][0] = 1;
        matrix_in.cells[1][1] = 2;
        matrix_in.cells[2][2] = 3;
        
        load_all = 1;
        #10;
        load_all = 0;

        assert(matrix_out.rows == 3) else $error("Full load rows failed");
        assert(matrix_out.cells[2][2] == 3) else $error("Full load data failed");

        // 6. Test Clear
        $display("Test 5: Clear");
        clear = 1;
        #10;
        clear = 0;
        assert(matrix_out.is_valid == 0) else $error("Clear valid failed");
        assert(matrix_out.cells[0][0] == 0) else $error("Clear data failed");

        $display("--- Test Passed ---");
        $finish;
    end

endmodule

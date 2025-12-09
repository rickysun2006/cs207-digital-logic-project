/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : tb_matrix_alu.sv
# Module Name    : tb_matrix_alu
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     Testbench for matrix_alu.sv
#
#=============================================================================*/
`timescale 1ns / 1ps
import project_pkg::*;

module tb_matrix_alu;

    // --- Signals ---
    logic clk;
    logic rst_n;
    logic start;
    op_code_t op_code;
    matrix_t matrix_A;
    matrix_t matrix_B;
    matrix_element_t scalar_val;
    logic done;
    matrix_t result_matrix;
    logic error_flag;

    // --- DUT Instantiation ---
    matrix_alu u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .op_code(op_code),
        .matrix_A(matrix_A),
        .matrix_B(matrix_B),
        .scalar_val(scalar_val),
        .done(done),
        .result_matrix(result_matrix),
        .error_flag(error_flag)
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
        start = 0;
        op_code = OP_NONE;
        matrix_A = '0;
        matrix_B = '0;
        scalar_val = 0;

        #20 rst_n = 1;
        $display("--- Test Start ---");

        // Test 1: Matrix Addition
        $display("Test 1: Matrix Addition (2x2)");
        matrix_A.rows = 2; matrix_A.cols = 2; matrix_A.is_valid = 1;
        matrix_A.cells[0][0] = 1; matrix_A.cells[0][1] = 2;
        matrix_A.cells[1][0] = 3; matrix_A.cells[1][1] = 4;

        matrix_B.rows = 2; matrix_B.cols = 2; matrix_B.is_valid = 1;
        matrix_B.cells[0][0] = 5; matrix_B.cells[0][1] = 6;
        matrix_B.cells[1][0] = 7; matrix_B.cells[1][1] = 8;

        op_code = OP_ADD;
        start = 1;
        #10 start = 0;
        wait(done);
        #10;
        
        assert(result_matrix.cells[0][0] == 6) else $error("Add(0,0) failed");
        assert(result_matrix.cells[1][1] == 12) else $error("Add(1,1) failed");
        $display("Addition Result: %d %d / %d %d", 
            result_matrix.cells[0][0], result_matrix.cells[0][1],
            result_matrix.cells[1][0], result_matrix.cells[1][1]);

        // Test 2: Matrix Multiplication
        $display("Test 2: Matrix Multiplication (2x2 * 2x2)");
        // A = [[1, 2], [3, 4]]
        // B = [[1, 0], [0, 1]] (Identity)
        matrix_B.cells[0][0] = 1; matrix_B.cells[0][1] = 0;
        matrix_B.cells[1][0] = 0; matrix_B.cells[1][1] = 1;

        op_code = OP_MAT_MUL;
        start = 1;
        #10 start = 0;
        wait(done);
        #10;

        assert(result_matrix.cells[0][0] == 1) else $error("Mul(0,0) failed");
        assert(result_matrix.cells[1][1] == 4) else $error("Mul(1,1) failed");
        $display("Multiplication Result (Identity): %d %d / %d %d", 
            result_matrix.cells[0][0], result_matrix.cells[0][1],
            result_matrix.cells[1][0], result_matrix.cells[1][1]);

        // Test 3: Matrix Multiplication (2x3 * 3x2)
        $display("Test 3: Matrix Multiplication (2x3 * 3x2)");
        // A = [[1, 2, 3], [4, 5, 6]]
        matrix_A.rows = 2; matrix_A.cols = 3;
        matrix_A.cells[0][0] = 1; matrix_A.cells[0][1] = 2; matrix_A.cells[0][2] = 3;
        matrix_A.cells[1][0] = 4; matrix_A.cells[1][1] = 5; matrix_A.cells[1][2] = 6;

        // B = [[7, 8], [9, 1], [2, 3]]
        matrix_B.rows = 3; matrix_B.cols = 2;
        matrix_B.cells[0][0] = 7; matrix_B.cells[0][1] = 8;
        matrix_B.cells[1][0] = 9; matrix_B.cells[1][1] = 1;
        matrix_B.cells[2][0] = 2; matrix_B.cells[2][1] = 3;

        // Expected:
        // [0][0] = 1*7 + 2*9 + 3*2 = 7 + 18 + 6 = 31
        // [0][1] = 1*8 + 2*1 + 3*3 = 8 + 2 + 9 = 19
        // [1][0] = 4*7 + 5*9 + 6*2 = 28 + 45 + 12 = 85
        // [1][1] = 4*8 + 5*1 + 6*3 = 32 + 5 + 18 = 55

        op_code = OP_MAT_MUL;
        start = 1;
        #10 start = 0;
        wait(done);
        #10;

        assert(result_matrix.cells[0][0] == 31) else $error("Mul2(0,0) failed");
        assert(result_matrix.cells[1][0] == 85) else $error("Mul2(1,0) failed");
        $display("Multiplication Result (2x3*3x2): %d %d / %d %d", 
            result_matrix.cells[0][0], result_matrix.cells[0][1],
            result_matrix.cells[1][0], result_matrix.cells[1][1]);

        // Test 4: Matrix Multiplication (5x5 * 5x5)
        $display("Test 4: Matrix Multiplication (5x5 * 5x5) - All Ones");
        matrix_A.rows = 5; matrix_A.cols = 5;
        matrix_B.rows = 5; matrix_B.cols = 5;
        
        // Fill with 1s
        matrix_A = {3'd5, 3'd5, 1'b1, {25{8'sd1}}};
        matrix_B = {3'd5, 3'd5, 1'b1, {25{8'sd1}}};

        op_code = OP_MAT_MUL;
        start = 1;
        #10 start = 0;
        wait(done);
        #10;

        // Result should be all 5s
        // 1*1 + 1*1 + 1*1 + 1*1 + 1*1 = 5
        assert(result_matrix.cells[0][0] == 5) else $error("Mul5(0,0) failed");
        assert(result_matrix.cells[4][4] == 5) else $error("Mul5(4,4) failed");
        $display("Multiplication Result (5x5): (0,0)=%d, (4,4)=%d", 
            result_matrix.cells[0][0], result_matrix.cells[4][4]);

        $finish;
    end

endmodule

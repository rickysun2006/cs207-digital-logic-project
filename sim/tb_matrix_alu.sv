/*=============================================================================
# File Name      : tb_matrix_alu.sv
# Description    : Vivado Testbench for Matrix ALU
#=============================================================================*/
`timescale 1ns / 1ps

// 必须导入包
import project_pkg::*;

module tb_matrix_alu;

  // --- 信号定义 ---
  logic clk;
  logic rst_n;
  logic start;
  op_code_t op_code;
  matrix_t matrix_A;
  matrix_t matrix_B;
  matrix_element_t scalar_val;

  wire done;
  wire matrix_t result_matrix;
  wire error_flag;
  wire [31:0] cycle_cnt; // Bonus

  // --- 时钟生成 (100MHz) ---
  initial begin
    clk = 0;
    forever #5 clk = ~clk; 
  end

  // --- 例化 DUT (Device Under Test) ---
  matrix_alu u_alu (
    .clk          (clk),
    .rst_n        (rst_n),
    .start        (start),
    .op_code      (op_code),
    .matrix_A     (matrix_A),
    .matrix_B     (matrix_B),
    .scalar_val   (scalar_val),
    .done         (done),
    .result_matrix(result_matrix),
    .error_flag   (error_flag),
    .cycle_cnt    (cycle_cnt)
  );

  // --- 打印任务：Vivado 完美支持直接读取 struct ---
  task print_matrix(input string name, input matrix_t m);
    $display("---------------------------------------");
    $display("Matrix: %s (%0d x %0d)", name, m.rows, m.cols);
    if (!m.is_valid && name == "RESULT") $display("WARNING: Result is marked INVALID");
    
    for (int i = 0; i < m.rows; i++) begin
      $write("[ ");
      for (int j = 0; j < m.cols; j++) begin
        // Vivado 可以直接处理 m.cells[i][j]
        $write("%4d ", m.cells[i][j]); 
      end
      $display("]");
    end
    $display("---------------------------------------");
  endtask

  // --- 初始化任务 ---
  task init_sequence();
    rst_n = 0;
    start = 0;
    matrix_A = '0; // SV 清零语法
    matrix_B = '0;
    scalar_val = 0;
    op_code = OP_ADD;
    #100; // 等待全局复位
    rst_n = 1;
    #20;
    $display("\n=== Vivado Simulation Start ===\n");
  endtask

  // --- 主测试流程 ---
  initial begin
    init_sequence();

    // ------------------------------------------
    // Case 1: 加法
    // ------------------------------------------
    $display("\n[TEST 1] Matrix Addition (2x2)");
    matrix_A.rows = 2; matrix_A.cols = 2; matrix_A.is_valid = 1;
    matrix_A.cells[0][0] = 10; matrix_A.cells[0][1] = 20;
    matrix_A.cells[1][0] = 30; matrix_A.cells[1][1] = 40;

    matrix_B.rows = 2; matrix_B.cols = 2; matrix_B.is_valid = 1;
    matrix_B.cells[0][0] = 1;  matrix_B.cells[0][1] = 2;
    matrix_B.cells[1][0] = 3;  matrix_B.cells[1][1] = 4;

    op_code = OP_ADD;
    start = 1;
    @(posedge clk); start = 0;
    wait(done); #10;

    print_matrix("Input A", matrix_A);
    print_matrix("Input B", matrix_B);
    print_matrix("RESULT", result_matrix);

    // ------------------------------------------
    // Case 2: 矩阵乘法
    // ------------------------------------------
    #20;
    $display("\n[TEST 2] Matrix Multiplication (2x3 * 3x2)");
    matrix_A.rows = 2; matrix_A.cols = 3;
    matrix_A.cells[0][0] = 1; matrix_A.cells[0][1] = 2; matrix_A.cells[0][2] = 3;
    matrix_A.cells[1][0] = 4; matrix_A.cells[1][1] = 5; matrix_A.cells[1][2] = 6;

    matrix_B.rows = 3; matrix_B.cols = 2;
    matrix_B.cells[0][0] = 7; matrix_B.cells[0][1] = 8;
    matrix_B.cells[1][0] = 9; matrix_B.cells[1][1] = 1;
    matrix_B.cells[2][0] = 2; matrix_B.cells[2][1] = 3;

    op_code = OP_MAT_MUL;
    start = 1;
    @(posedge clk); start = 0;
    wait(done); #10;

    print_matrix("Input A", matrix_A);
    print_matrix("Input B", matrix_B);
    print_matrix("RESULT", result_matrix);

    // ------------------------------------------
    // Case 3: 卷积运算 (Bonus)
    // ------------------------------------------
    #20;
    $display("\n[TEST 3] Convolution (10x12 Image * 3x3 Kernel)");
    // Matrix A is ignored in CONV mode, but we clear it
    matrix_A = '0;

    // Setup 3x3 Kernel (Identity-like for easy check)
    // 1 0 1
    // 0 1 0
    // 1 0 1
    matrix_B.rows = 3; matrix_B.cols = 3; matrix_B.is_valid = 1;
    matrix_B.cells[0][0] = 1; matrix_B.cells[0][1] = 0; matrix_B.cells[0][2] = 1;
    matrix_B.cells[1][0] = 0; matrix_B.cells[1][1] = 1; matrix_B.cells[1][2] = 0;
    matrix_B.cells[2][0] = 1; matrix_B.cells[2][1] = 0; matrix_B.cells[2][2] = 1;

    op_code = OP_CONV;
    start = 1;
    @(posedge clk); start = 0;
    wait(done); #10;

    $display("Kernel:");
    print_matrix("Kernel (B)", matrix_B);
    
    $display("Convolution Result (8x10):");
    print_matrix("RESULT", result_matrix);
    $display("Performance: %0d cycles", cycle_cnt);

    $display("\n=== Simulation Finished ===");
    $stop;
  end

endmodule
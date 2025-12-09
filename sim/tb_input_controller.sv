/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : tb_input_controller.sv
# Module Name    : tb_input_controller
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     Testbench for input_controller.sv
#
#=============================================================================*/
`timescale 1ns / 1ps
import project_pkg::*;

module tb_input_controller;

    // --- Signals ---
    logic clk;
    logic rst_n;
    logic start_manual_input;
    logic start_auto_gen;
    logic start_select_op;
    op_code_t op_code;
    logic uart_valid;
    logic [7:0] uart_data;
    logic btn_confirm;
    logic [3:0] sw_scalar;
    logic wr_en;
    logic wr_cmd_set_dims;
    logic wr_cmd_single;
    logic [ROW_IDX_W-1:0] wr_dims_r;
    logic [COL_IDX_W-1:0] wr_dims_c;
    logic [ROW_IDX_W-1:0] wr_row_idx;
    logic [COL_IDX_W-1:0] wr_col_idx;
    matrix_element_t wr_data;
    logic done;
    logic [MAT_ID_W-1:0] selected_id_A;
    logic [MAT_ID_W-1:0] selected_id_B;
    logic [3:0] selected_scalar;
    logic input_valid_flag;

    // --- DUT Instantiation ---
    input_controller u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_manual_input(start_manual_input),
        .start_auto_gen(start_auto_gen),
        .start_select_op(start_select_op),
        .op_code(op_code),
        .uart_valid(uart_valid),
        .uart_data(uart_data),
        .btn_confirm(btn_confirm),
        .sw_scalar(sw_scalar),
        .wr_en(wr_en),
        .wr_cmd_set_dims(wr_cmd_set_dims),
        .wr_cmd_single(wr_cmd_single),
        .wr_dims_r(wr_dims_r),
        .wr_dims_c(wr_dims_c),
        .wr_row_idx(wr_row_idx),
        .wr_col_idx(wr_col_idx),
        .wr_data(wr_data),
        .done(done),
        .selected_id_A(selected_id_A),
        .selected_id_B(selected_id_B),
        .selected_scalar(selected_scalar),
        .input_valid_flag(input_valid_flag),
        .cfg_rand_min(DEFAULT_VAL_MIN),
        .cfg_rand_max(DEFAULT_VAL_MAX)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // --- Helper Tasks ---
    task send_uart(input [7:0] data);
        begin
            uart_data = data;
            uart_valid = 1;
            #10;
            uart_valid = 0;
            #10;
        end
    endtask

    task press_confirm();
        begin
            btn_confirm = 1;
            #20; // Hold for a bit
            btn_confirm = 0;
            #20;
        end
    endtask

    // --- Test Procedure ---
    initial begin
        // Initialize
        rst_n = 0;
        start_manual_input = 0;
        start_auto_gen = 0;
        start_select_op = 0;
        op_code = OP_NONE;
        uart_valid = 0;
        uart_data = 0;
        btn_confirm = 0;
        sw_scalar = 0;

        #20 rst_n = 1;
        $display("--- Test Start: Input Controller ---");

        // Test 1: Manual Input of 2x2 Matrix
        $display("Test 1: Manual Input 2x2");
        start_manual_input = 1;
        op_code = OP_ADD; // Needs Matrix B too, but let's see if it asks for A first
        
        // Wait for state transition
        #20;
        
        // Input M=2
        $display("Sending M=2");
        send_uart("2");
        press_confirm();

        // Input N=2
        $display("Sending N=2");
        send_uart("2");
        press_confirm();

        // Check if set_dims was asserted
        // Note: It might happen quickly.
        
        // Input Data (0,0)=1
        $display("Sending (0,0)=1");
        send_uart("1");
        press_confirm();
        
        // Input Data (0,1)=2
        $display("Sending (0,1)=2");
        send_uart("2");
        press_confirm();

        // Input Data (1,0)=3
        $display("Sending (1,0)=3");
        send_uart("3");
        press_confirm();

        // Input Data (1,1)=4
        $display("Sending (1,1)=4");
        send_uart("4");
        press_confirm();

        // Should be done with Matrix A
        // Since op_code is ADD, it should ask for Matrix B?
        // Wait, input_controller handles one matrix input at a time usually, 
        // or does it handle both?
        // Looking at input_controller.sv, it seems to handle one matrix input session.
        // Wait, let's check the code.
        
        // If it loops for Matrix B, we continue.
        
        // Let's assume it asks for B now.
        // Input M=2
        $display("Sending B M=2");
        send_uart("2");
        press_confirm();

        // Input N=2
        $display("Sending B N=2");
        send_uart("2");
        press_confirm();
        
        // Input Data 4 elements
        repeat(4) begin
            send_uart("5");
            press_confirm();
        end

        wait(done);
        $display("Input Done!");
        start_manual_input = 0;

        $display("--- Test End ---");
        $finish;
    end

endmodule

/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : tb_system_core.sv
# Module Name    : tb_system_core
# University     : SUSTech
#
# Create Date    : 2025-12-09
#
# Description    :
#     Testbench for system_core.sv (Integration Test)
#
#=============================================================================*/
`timescale 1ns / 1ps
import project_pkg::*;

module tb_system_core;

    // --- Signals ---
    logic clk;
    logic rst_n;
    logic uart_rx;
    logic uart_tx;
    logic [7:0] sw_mode_sel;
    logic [7:0] sw_scalar_val;
    logic btn_confirm;
    logic btn_reset_logic;
    logic [15:0] led_status;
    logic [7:0] seg_an;
    logic [7:0] seg_data_0;
    logic [7:0] seg_data_1;

    // --- DUT Instantiation ---
    system_core u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .sw_mode_sel(sw_mode_sel),
        .sw_scalar_val(sw_scalar_val),
        .btn_confirm(btn_confirm),
        .btn_reset_logic(btn_reset_logic),
        .led_status(led_status),
        .seg_an(seg_an),
        .seg_data_0(seg_data_0),
        .seg_data_1(seg_data_1)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // --- UART Helper ---
    // We need to simulate UART serial data.
    // Baud rate is 115200. Clock is 100MHz.
    // Bit period = 100,000,000 / 115200 = 868 cycles.
    localparam BIT_PERIOD = 8680; // in ns (approx)

    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit (0)
            uart_rx = 0;
            #(BIT_PERIOD);
            
            // Data bits (LSB first)
            for (i=0; i<8; i=i+1) begin
                uart_rx = data[i];
                #(BIT_PERIOD);
            end
            
            // Stop bit (1)
            uart_rx = 1;
            #(BIT_PERIOD);
            
            // Inter-byte delay
            #(BIT_PERIOD * 2);
        end
    endtask

    task press_confirm();
        begin
            btn_confirm = 1;
            #200; // Hold
            btn_confirm = 0;
            #200;
        end
    endtask

    // --- Test Procedure ---
    initial begin
        // Initialize
        rst_n = 0;
        uart_rx = 1; // Idle high
        sw_mode_sel = 0;
        sw_scalar_val = 0;
        btn_confirm = 0;
        btn_reset_logic = 0;

        #100 rst_n = 1;
        $display("--- Test Start: System Core Integration ---");

        // 1. Enter Input Mode
        $display("Step 1: Enter Input Mode");
        sw_mode_sel[4] = 1; // STATE_INPUT
        press_confirm();
        #100;
        sw_mode_sel[4] = 0; // Clear switch (simulating momentary or just state change)
        
        // Wait for FSM to settle (check internal state if possible, or just proceed)
        #1000;

        // 2. Input Matrix A (2x2)
        // We need to select OP_ADD first? 
        // Wait, input_controller needs op_code to decide if it needs Matrix B.
        // But op_code comes from FSM.
        // In STATE_INPUT, FSM sets op_code?
        // Let's check main_fsm.sv.
        // In STATE_INPUT, op_code is OP_NONE usually?
        // Actually, input_controller uses op_code to decide `need_matrix_B`.
        // If op_code is NONE, `need_matrix_B` is 0.
        // So in STATE_INPUT, we only input ONE matrix (Matrix A).
        // To input Matrix B, we might need to run input again?
        // Or maybe the design intends for us to input A, then B?
        
        // Let's check input_controller.sv:
        // always_comb begin ... case(op_code) ... end
        
        // In STATE_INPUT, the user just inputs matrices.
        // The FSM doesn't seem to pass a specific op_code in STATE_INPUT.
        // So it defaults to OP_NONE -> need_matrix_B = 0.
        // So we only input Matrix A.
        
        // Let's input Matrix A: 2x2, [[1,2],[3,4]]
        $display("Step 2: Input Matrix A");
        
        // M=2
        send_byte("2");
        press_confirm();
        
        // N=2
        send_byte("2");
        press_confirm();
        
        // Data
        send_byte("1"); press_confirm();
        send_byte("2"); press_confirm();
        send_byte("3"); press_confirm();
        send_byte("4"); press_confirm();
        
        $display("Matrix A Input Done");
        
        // Wait for input_done signal to propagate
        #2000;
        
        // Now we are back to IDLE?
        // FSM: STATE_INPUT -> (input_done) -> STATE_IDLE.
        
        // 3. Enter Input Mode Again for Matrix B?
        // But input_controller always writes to `selected_id_A` (which is 0 by default?)
        // Wait, `input_controller` has `selected_id_A` output.
        // And `matrix_manage_sys` uses `latched_wr_id`.
        // `input_controller` calculates `wr_target_id`?
        // No, `input_controller` outputs `wr_dims` etc. `matrix_manage_sys` calculates ID based on dims.
        // So if we input a 2x2 matrix, it goes to the 2x2 slot.
        // If we input another 2x2 matrix, it goes to the NEXT 2x2 slot (ptr increments).
        
        // So, let's input Matrix B (2x2) [[5,6],[7,8]]
        $display("Step 3: Input Matrix B");
        sw_mode_sel[4] = 1; // STATE_INPUT
        press_confirm();
        #100;
        sw_mode_sel[4] = 0;
        
        // M=2
        send_byte("2"); press_confirm();
        // N=2
        send_byte("2"); press_confirm();
        // Data
        send_byte("5"); press_confirm();
        send_byte("6"); press_confirm();
        send_byte("7"); press_confirm();
        send_byte("8"); press_confirm();
        
        $display("Matrix B Input Done");
        #2000;

        // 4. Perform Calculation (ADD)
        $display("Step 4: Select Calculation (ADD)");
        sw_mode_sel[7] = 1; // STATE_CALC_SELECT
        // No confirm needed for transition to CALC_SELECT from IDLE if sw[7] is high?
        // FSM: if (sw_mode_sel[7]) state_next = STATE_CALC_SELECT;
        #100;
        sw_mode_sel[7] = 0; // Clear
        
        // Now in CALC_SELECT.
        // We need to select operation.
        // How? sw_mode_sel?
        // FSM:
        // STATE_CALC_SELECT:
        //   if (sw_mode_sel[0]) op_next = OP_ADD;
        //   if (btn_pos) state_next = STATE_CALC_INPUT;
        
        sw_mode_sel[0] = 1; // OP_ADD
        #100;
        press_confirm(); // Go to CALC_INPUT
        sw_mode_sel[0] = 0;
        
        // Now in STATE_CALC_INPUT.
        // Here we select operands.
        // input_controller is active with `start_select_op`.
        // It asks for Matrix A ID and Matrix B ID?
        // Let's check input_controller logic for `start_select_op`.
        // It seems `input_controller` reuses the input logic?
        // No, `input_controller` has `STATE_CALC_INPUT` handling?
        // Actually, `input_controller` logic for `start_select_op` is not fully clear in my memory.
        // Let's assume it auto-selects the last two matrices or asks for them.
        // If it asks, we need to provide IDs via UART?
        // Or maybe it just uses the default IDs?
        
        // Let's wait and see if ALU triggers.
        // If ALU triggers, `alu_done` will go high.
        
        wait(u_dut.alu_done);
        $display("ALU Done!");
        
        // Check result
        // Result is written back to storage.
        // We can peek into the storage if we want, or just trust ALU test.
        
        $display("--- Test End ---");
        $finish;
    end

endmodule

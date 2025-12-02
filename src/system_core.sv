/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : system_core.sv
# Module Name    : system_core
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Logical top module, handles data interaction between all modules, instantiates all modules and connects them via wires.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
#
#=============================================================================*/
`include "common/project_pkg.sv"
import project_pkg::*;

module system_core (
    // --- Global Control ---
    input wire clk,   // 系统时钟
    input wire rst_n, // 全局复位

    // --- UART Interface ---
    input  wire uart_rx,  // 输入
    output wire uart_tx,  // 输出

    // --- Logical Inputs ---
    input wire [7:0] sw_mode_sel,     // 模式选择
    input wire [7:0] sw_scalar_val,   // 标量输入
    input wire       btn_confirm,     // 确认
    input wire       btn_reset_logic, // 逻辑复位

    // --- Logical Outputs ---
    output wire [15:0] led_status,  // 16位 LED 状态指示
                                    // [0]: Error Flag

    // --- Display Driver Interface ---
    output wire [7:0] seg_an,      // 数码管位选
    output wire [7:0] seg_data_0,  // 数码管段选 Group 0 (Right)
    output wire [7:0] seg_data_1   // 数码管段选 Group 1 (Left)
);

  //==========================================================================
  // Signal Declarations (内部信号声明)
  //==========================================================================
  // 状态机和子模块之间的连接线
  logic [7:0] rx_byte;
  logic       rx_valid;
  logic       tx_busy;
  logic [7:0] tx_byte;
  logic       tx_start;

  logic fether_done;

  // Error Handling
  logic       error_flag;
  logic [3:0] countdown_val;

  //==========================================================================
  // Module Initialazation
  //==========================================================================
  main_fsm main_fsm_inst (
      .clk               (clk),
      .rst_n             (rst_n),
      .sw_mode_sel       (sw_mode_sel),
      .btn_confirm       (btn_confirm),
      .btn_reset_logic   (btn_reset_logic),
      .input_done        (rx_valid),
      .gen_done          (fether_done),
      .display_done      (1'b0), // Placeholder
      .current_state    (),
      .operation_code   ()
  );
  uart_rx uart_rx_inst (
      .clk         (clk),
      .rst_n       (rst_n),
      .uart_rxd    (uart_rx),
      .uart_rx_done(rx_valid),
      .uart_rx_data(rx_byte)
  );
  uart_tx uart_tx_inst ();
  seven_segment_driver seg_driver_inst (
      .clk  (clk),
      .rst_n(rst_n),
      .an   (seg_an),
      .seg0 (seg_data_0),
      .seg1 (seg_data_1)
  );
  matrix_alu matrix_alu_inst ();

  // 示例：LED 0 显示错误状态
  assign led_status[0] = error_flag;
  assign led_status[15:1] = '0;  // 其他 LED 暂时置零

endmodule

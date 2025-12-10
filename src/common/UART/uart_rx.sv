/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : uart_rx.sv
# Module Name    : uart_rx
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Responsible for UART input (reception).
#
# References     :
#     Original code from Alientek (正点原子)
#     www.yuanzige.com
#     http://www.openedv.com/forum.php
#     https://zhengdianyuanzi.tmall.com
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |   [Your Name]  |   Initial creation
#
#=============================================================================*/

module uart_rx (
    input clk,   // System clock
    input rst_n, // System reset, active low

    input            uart_rxd,      // UART receive port
    output reg       uart_rx_done,  // UART receive complete signal
    output reg [7:0] uart_rx_data   // UART received data
);

  //parameter define
  parameter CLK_FREQ = 100_000_000;  // System clock frequency
  parameter UART_BPS = 115200;  // Serial baud rate
  localparam BAUD_CNT_MAX = CLK_FREQ/UART_BPS; // Count BPS_CNT times for system clock to get specified baud rate

  //reg define
  reg         uart_rxd_d0;
  reg         uart_rxd_d1;
  reg         uart_rxd_d2;
  reg         rx_flag;  // Receive process flag signal
  reg  [ 3:0] rx_cnt;  // Receive data counter
  reg  [15:0] baud_cnt;  // Baud rate counter
  reg  [ 7:0] rx_data_t;  // Receive data register

  //wire define
  wire        start_en;

  // Capture falling edge of receive port (start bit), get a pulse signal of one clock cycle
  assign start_en = uart_rxd_d2 & (~uart_rxd_d1) & (~rx_flag);

  // Synchronization processing for asynchronous signals
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart_rxd_d0 <= 1'b0;
      uart_rxd_d1 <= 1'b0;
      uart_rxd_d2 <= 1'b0;
    end else begin
      uart_rxd_d0 <= uart_rxd;
      uart_rxd_d1 <= uart_rxd_d0;
      uart_rxd_d2 <= uart_rxd_d1;
    end
  end

  // Assign value to receive flag
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_flag <= 1'b0;
    else if (start_en)  // Start bit detected
      rx_flag <= 1'b1;  // During reception, pull rx_flag high
    // At the middle of stop bit, i.e., reception process ends, pull rx_flag low
    else if ((rx_cnt == 4'd9) && (baud_cnt == BAUD_CNT_MAX / 2 - 1'b1)) rx_flag <= 1'b0;
    else rx_flag <= rx_flag;
  end

  // Baud rate counter assignment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) baud_cnt <= 16'd0;
    else if (rx_flag) begin  // During reception, baud rate counter (baud_cnt) cycles
      if (baud_cnt < BAUD_CNT_MAX - 1'b1) baud_cnt <= baud_cnt + 16'b1;
      else baud_cnt <= 16'd0;  // Clear counter after reaching one baud rate period
    end else baud_cnt <= 16'd0;  // Clear counter when reception process ends
  end

  // Assign value to receive data counter (rx_cnt)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_cnt <= 4'd0;
    else if (rx_flag) begin  // rx_cnt counts only during reception process
      if (baud_cnt == BAUD_CNT_MAX - 1'b1)  // When baud rate counter counts to one baud rate period
        rx_cnt <= rx_cnt + 1'b1;  // Receive data counter increments by 1
      else rx_cnt <= rx_cnt;
    end else rx_cnt <= 4'd0;  // Clear counter when reception process ends
  end

  // Register rxd port data based on rx_cnt
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_data_t <= 8'b0;
    else if (rx_flag) begin  // System is in reception process
      if(baud_cnt == BAUD_CNT_MAX/2 - 1'b1)
      begin  // Check if baud_cnt counts to the middle of data bit
        case (rx_cnt)
          4'd1: rx_data_t[0] <= uart_rxd_d2;  // Register data LSB
          4'd2: rx_data_t[1] <= uart_rxd_d2;
          4'd3: rx_data_t[2] <= uart_rxd_d2;
          4'd4: rx_data_t[3] <= uart_rxd_d2;
          4'd5: rx_data_t[4] <= uart_rxd_d2;
          4'd6: rx_data_t[5] <= uart_rxd_d2;
          4'd7: rx_data_t[6] <= uart_rxd_d2;
          4'd8: rx_data_t[7] <= uart_rxd_d2;  // Register data MSB
          default: ;
        endcase
      end else rx_data_t <= rx_data_t;
    end else rx_data_t <= 8'b0;
  end

  // Assign value to receive complete signal and received data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart_rx_done <= 1'b0;
      uart_rx_data <= 8'b0;
    end
    // When receive data counter counts to stop bit, and baud_cnt counts to the middle of stop bit
    else if (rx_cnt == 4'd9 && baud_cnt == BAUD_CNT_MAX / 2 - 1'b1) begin
      uart_rx_done <= 1'b1;  // Pull receive complete signal high
      uart_rx_data <= rx_data_t;  // Assign received data
    end else begin
      uart_rx_done <= 1'b0;
      uart_rx_data <= uart_rx_data;
    end
  end

endmodule

/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : seven_seg_display_driver.sv
# Module Name    : seven_seg_display_driver
# University     : SUSTech
#
# Create Date    : 2025-12-01
#
# Description    :
#     Handle button debouncing.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-01 | DraTelligence  |   Initial creation
#
#=============================================================================*/
`include "project_pkg.sv"
import project_pkg::*;

module seven_seg_display_driver (
    input wire         clk,           // 系统时钟
    input wire         rst_n,
    input code_t [7:0] display_data,  // 8个数字，MSB
    input wire   [7:0] blink_mask,    // 点亮掩码，1为点亮，0为关闭

    output reg [7:0] an,
    output reg [7:0] seg0,
    output reg [7:0] seg1
);

  // 扫描计数器，降到约600Hz
  reg [19:0] cnt;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 0;
    else cnt <= cnt + 1;
  end

  wire [1:0] scan_sel = cnt[19:18];

  // 译码
  function automatic [7:0] get_seg(input code_t num);
    case (num)
      CHAR_0: get_seg = 8'h3F;  // 0 0 1 1 1 1 1 1 ->  0
      CHAR_1: get_seg = 8'h06;  // 0 0 0 0 0 1 1 0 ->  1
      CHAR_2: get_seg = 8'h5B;  // 0 1 0 1 1 0 1 1 ->  2
      CHAR_3: get_seg = 8'h4F;  // 0 1 0 0 1 1 1 1 ->  3
      CHAR_4: get_seg = 8'h66;  // 0 1 1 0 0 1 1 0 ->  4
      CHAR_5: get_seg = 8'h6D;  // 0 1 1 0 1 1 0 1 ->  5
      CHAR_6: get_seg = 8'h7D;  // 0 1 1 1 1 1 0 1 ->  6
      CHAR_7: get_seg = 8'h07;  // 0 0 0 0 0 1 1 7 ->  7
      CHAR_8: get_seg = 8'h7F;  // 0 1 1 1 1 1 1 1 ->  8
      CHAR_9: get_seg = 8'h6F;  // 0 1 1 0 1 1 1 1 ->  9
      CHAR_A: get_seg = 8'h77;  // 0 1 1 1 0 1 1 7 ->  A (或者 8'h5F 显示 a)
      CHAR_B: get_seg = 8'h7C;  // 0 1 1 1 1 1 0 0 ->  b
      CHAR_C: get_seg = 8'h39;  // 0 0 1 1 1 0 0 1 ->  C
      CHAR_D: get_seg = 8'h5E;  // 0 1 0 1 1 1 1 0 ->  d
      CHAR_E: get_seg = 8'h79;  // 0 1 1 1 1 0 0 1 ->  E
      CHAR_F: get_seg = 8'h71;  // 0 1 1 1 0 0 0 1 ->  F
      CHAR_T: get_seg = 8'h78;  // t
      CHAR_J: get_seg = 8'h1E;  // J
      CHAR_R: get_seg = 8'h50;  // r
      CHAR_H: get_seg = 8'h76;  // H
      CHAR_P: get_seg = 8'h73;  // P
      CHAR_L: get_seg = 8'h38;  // L
      CHAR_U: get_seg = 8'h3E;  // U
      CHAR_S: get_seg = 8'h6D;  // S
      CHAR_N: get_seg = 8'h54;  // n
      CHAR_Y: get_seg = 8'h66;  // y
      CHAR_DASH: get_seg = 8'h40;  // -
      CHAR_UNDERSCORE: get_seg = 8'h08;  // _
      CHAR_BLK: get_seg = 8'h00;  // 空白
      default: get_seg = 8'h00;  // 全灭
    endcase
  endfunction

  // 并行输出
  always_comb begin
    //default
    an   = 8'b0000_0000;
    seg0 = 8'h00;
    seg1 = 8'h00;

    case (scan_sel)
      2'b00: begin
        an[0] = blink_mask[7];
        seg0  = get_seg(display_data[7]);
        an[4] = blink_mask[3];
        seg1  = get_seg(display_data[3]);
      end

      2'b01: begin
        an[1] = blink_mask[6];
        seg0  = get_seg(display_data[6]);
        an[5] = blink_mask[2];
        seg1  = get_seg(display_data[2]);
      end

      2'b10: begin
        an[2] = blink_mask[5];
        seg0  = get_seg(display_data[5]);
        an[6] = blink_mask[1];
        seg1  = get_seg(display_data[1]);
      end

      2'b11: begin
        an[3] = blink_mask[4];
        seg0  = get_seg(display_data[4]);
        an[7] = blink_mask[0];
        seg1  = get_seg(display_data[0]);
      end

      default: begin
        an   = 8'h00;
        seg0 = 8'h00;
        seg1 = 8'h00;
      end
    endcase
  end

endmodule

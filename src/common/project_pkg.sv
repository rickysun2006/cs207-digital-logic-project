/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : project_pkg.sv
# Module Name    : project_pkg
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Package containing global parameters, data types, and operation codes for the matrix calculator project.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-11-23 |  DraTelligence |   Initial creation
# v1.1  | 2025-12-01 |  DraTelligence |   Added code for seven-segment display characters
#
#=============================================================================*/

package project_pkg;

  //-------------------------------------------------------------------------
  // 硬件参数
  //-------------------------------------------------------------------------
  localparam int SYS_CLK_FREQ = 100_000_000;  // 系统时钟 100MHz
  localparam int BAUD_RATE = 11400;  // UART 波特率

  //-------------------------------------------------------------------------
  // 矩阵规格
  //-------------------------------------------------------------------------
  // 维度上限
  localparam int MAX_ROWS = 5;
  localparam int MAX_COLS = 5;

  // 索引位宽
  localparam int ROW_IDX_W = $clog2(MAX_ROWS + 1);
  localparam int COL_IDX_W = $clog2(MAX_COLS + 1);

  // 元素位宽
  // 考虑到负数和中间值，使用有符号 8 位
  localparam int DATA_WIDTH = 8;

  //-------------------------------------------------------------------------
  // 矩阵元素定义
  //-------------------------------------------------------------------------
  // 矩阵元素类型
  typedef logic signed [DATA_WIDTH-1:0] matrix_element_t;

  // 矩阵维度类型
  typedef logic [2:0] dim_t;

  // 矩阵整体类型
  typedef struct packed {
    // --- 控制信息 ---
    logic [ROW_IDX_W-1:0] rows;      // 3 bit, 最多支持8行
    logic [COL_IDX_W-1:0] cols;      // 3 bit, 最多支持8列
    logic                 is_valid;  // 1 bit, 标记这个位置是否为空

    // --- Payload ---
    // MAX_ROWS x MAX_COLS 的二维数组，每个元素 8 bit
    matrix_element_t [MAX_ROWS-1:0][MAX_COLS-1:0] cells;

  } matrix_t;  // 总位宽 = 3+3+1 + (25*8) = 207 bits

  //-------------------------------------------------------------------------
  // 矩阵运算类型枚举
  //-------------------------------------------------------------------------
  typedef enum logic [2:0] {
    OP_TRANSPOSE  = 3'd0,  // 矩阵转置 (T)
    OP_ADD        = 3'd1,  // 矩阵加法 (A)
    OP_SCALAR_MUL = 3'd2,  // 标量乘法 (B)
    OP_MAT_MUL    = 3'd3,  // 矩阵乘法 (C)
    OP_CONV       = 3'd4,  // 卷积运算 (J)
    OP_NONE       = 3'd7   // 无操作
  } op_code_t;

  //-------------------------------------------------------------------------
  // 数码管显示内容编码
  //-------------------------------------------------------------------------
  typedef logic [4:0] code_t;

  // --- 基本字符 ---
  localparam code_t CHAR_0 = 5'd0;
  localparam code_t CHAR_1 = 5'd1;
  localparam code_t CHAR_2 = 5'd2;
  localparam code_t CHAR_3 = 5'd3;
  localparam code_t CHAR_4 = 5'd4;
  localparam code_t CHAR_5 = 5'd5;
  localparam code_t CHAR_6 = 5'd6;
  localparam code_t CHAR_7 = 5'd7;
  localparam code_t CHAR_8 = 5'd8;
  localparam code_t CHAR_9 = 5'd9;
  localparam code_t CHAR_A = 5'd10;  // A (加法)
  localparam code_t CHAR_B = 5'd11;  // b (标量乘法)
  localparam code_t CHAR_C = 5'd12;  // C (矩阵乘法)
  localparam code_t CHAR_D = 5'd13;
  localparam code_t CHAR_E = 5'd14;  // E (Err 的 E)
  localparam code_t CHAR_F = 5'd15;

  // --- 扩展 ---
  localparam code_t CHAR_T = 5'd16;  // t (转置)
  localparam code_t CHAR_J = 5'd17;  // J (卷积)
  localparam code_t CHAR_R = 5'd18;  // r (Err 的 r)
  localparam code_t CHAR_H = 5'd19;  // -
  localparam code_t CHAR_BLK = 5'd31;  // Blank (黑屏)

endpackage

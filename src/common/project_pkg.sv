/*=============================================================================
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : matrix_pkg.sv
# Description    : 全局参数包。包含常量定义、数据类型和操作码。
#                  所有模块都应导入此包以确保参数一致性。
#=============================================================================*/

package project_pkg;

  //-------------------------------------------------------------------------
  // 1. 硬件参数
  //-------------------------------------------------------------------------
  localparam SYS_CLK_FREQ = 100_000_000; // 系统时钟 100MHz
  localparam BAUD_RATE    = 11400;        // UART 波特率

  //-------------------------------------------------------------------------
  // 2. 矩阵规格
  //-------------------------------------------------------------------------
  // 维度上限
  localparam MAX_ROWS = 5;
  localparam MAX_COLS = 5;

  // 索引位宽
  localparam ROW_IDX_W = $clog2(MAX_ROWS + 1);
  localparam COL_IDX_W = $clog2(MAX_COLS + 1);

  // 元素位宽
  // 考虑到负数和中间值，使用有符号 8 位
  localparam DATA_WIDTH = 8;

  //-------------------------------------------------------------------------
  // 3. 自定义类型定义 (Typedefs)
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
            logic       is_valid;  // 1 bit, 标记这个位置是否为空

            // --- Payload ---
            // MAX_ROWS x MAX_COLS 的二维数组，每个元素 8 bit
            matrix_element_t [MAX_ROWS-1:0][MAX_COLS-1:0] cells;

          } matrix_t; // 总位宽 = 3+3+1 + (25*8) = 207 bits

  //-------------------------------------------------------------------------
  // 4. 操作类型枚举
  //-------------------------------------------------------------------------
  // 对应题目中的运算类型
  typedef enum logic [2:0] {
            OP_TRANSPOSE   = 3'd0, // 矩阵转置 (T)
            OP_ADD         = 3'd1, // 矩阵加法 (A)
            OP_SCALAR_MUL  = 3'd2, // 标量乘法 (B)
            OP_MAT_MUL     = 3'd3, // 矩阵乘法 (C)
            OP_CONV        = 3'd4, // 卷积运算 (J)
            OP_NONE        = 3'd7  // 无操作
          } op_code_t;

  //-------------------------------------------------------------------------
  // 5. 系统主状态
  //-------------------------------------------------------------------------
  typedef enum logic [2:0] {
            STATE_IDLE,        // 主菜单
            STATE_INPUT,       // 1. 矩阵输入及存储
            STATE_GEN,         // 2. 矩阵生成
            STATE_DISPLAY,     // 3. 矩阵展示
            STATE_CALC_SELECT, // 4.1 选择运算类型
            STATE_CALC_INPUT,  // 4.2 选择运算数 (含倒计时错误处理)
            STATE_CALC_EXEC,   // 4.3 执行计算
            STATE_CALC_RESULT  // 4.4 显示结果
          } sys_state_t;

endpackage

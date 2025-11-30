/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : fpga_top.sv
# Module Name    : fpga_top
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Physical top module, responsible for clock signal input, etc.; instantiates Xilinx IP cores; handles physical button debouncing.
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


module fpga_top (
    // --- System Clock & Reset ---
    input  wire        clk,        // 板载 100MHz 时钟
    input  wire        rst_n,      // 板载复位按键, 低有效

    // --- UART Interface ---
    input  wire        uart_rx,    // uart接收
    output wire        uart_tx,    // uart发送

    // --- Switch Inputs ---
    input  wire [7:0]  sw,         // 8个拨码开关
    input  wire [7:0]  dip_sw,     // 8个DIP开关

    // --- Button Inputs ---
    // btn[0]:Right, [1]:Up, [2]:Down, [3]:Left, [4]:Center
    input  wire [4:0]  btn,        

    // --- LED Outputs ---
    output wire [15:0] led,        // 16个 LED 灯

    // --- 7-Segment Display ---
    output wire [7:0]  an,         // 8位 数码管位选 (Active Low)
    output wire [7:0]  seg0,       // 右侧4位 段选 (A~G, DP)
    output wire [7:0]  seg1        // 左侧4位 段选
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    wire        sys_clk;       // 系统主时钟
    wire        sys_clk_locked;// PLL 锁定信号
    wire        sys_rst_n;     // 全局复位
    wire [4:0]  btn_clean;     // 消抖后的按键信号

    //==========================================================================
    // Clock Generation
    //==========================================================================
    /*
    clk_wiz_0 u_clk_wiz (
        .clk_out1 (sys_clk),      // 输出时钟
        .resetn   (rst_n),        // 复位
        .locked   (sys_clk_locked),
        .clk_in1  (clk)           // 物理输入时钟
    );
    */
    // 临时直连
    assign sys_clk = clk;
    assign sys_clk_locked = 1'b1;

    assign sys_rst_n = rst_n & sys_clk_locked; 

    //==========================================================================
    // Button Debounce
    //==========================================================================
    generate
        for (genvar i = 0; i < 5; i = i + 1) begin : btn_debounce_gen
            button_debounce u_db (
                .clk(sys_clk), 
                .rst_n(sys_rst_n), 
                .btn_in(btn[i]), 
                .btn_out(btn_clean[i])
            );
            // 临时直连
            // assign btn_clean[i] = btn[i]; 
        end
    endgenerate

    //==========================================================================
    // System Core Instantiation
    //==========================================================================
    system_core u_core (
        // Global Signals
        .clk            (sys_clk),
        .rst_n          (sys_rst_n),

        // Communication
        .uart_rx        (uart_rx),
        .uart_tx        (uart_tx),

        // User Inputs (Clean Signals)
        .sw_mode_sel    (sw[7:5]),   // 假设高3位开关选模式
        .sw_scalar_val  (sw[3:0]),   // 假设低4位开关输标量 (或者用 dip_sw)
        .btn_confirm    (btn_clean[4]), // 中间按键确认
        .btn_reset_logic(btn_clean[1]), // 上键逻辑复位

        // User Outputs
        .led_status     (led),       // 将 Core 的状态映射到 LED
        .seg_an         (an),        // 数码管位选
        .seg_data_0     (seg0),      // 右段选
        .seg_data_1     (seg1)       // 左段选
    );

endmodule

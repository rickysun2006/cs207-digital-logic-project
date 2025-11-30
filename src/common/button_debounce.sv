/*=============================================================================
#
# Project Name   : CS207_Project_Matrix_Calculator
# File Name      : button_debounce.sv
# Module Name    : button_debounce
# University     : SUSTech
#
# Create Date    : 2025-11-23
#
# Description    :
#     Handle button debouncing.
#
# Revision History:
# -----------------------------------------------------------------------------
# Ver   |   Date     |   Author       |   Description
# -----------------------------------------------------------------------------
# v1.0  | 2025-12-01 |                |   Initial creation
#
#=============================================================================*/

module button_debounce (
    input  wire clk,          // System clock
    input  wire rst_n,       // Active low reset
    input  wire btn_in,      // Raw button input
    output reg  btn_out      // Debounced button output
  );

  // Parameters
  parameter DEBOUNCE_TIME = 1_000_000;

  // Internal signals
  reg [19:0] counter;
  reg btn_sync_0, btn_sync_1;

  // Synchronize button input to system clock
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      btn_sync_0 <= 1'b0;
      btn_sync_1 <= 1'b0;
    end
    else
    begin
      btn_sync_0 <= btn_in;
      btn_sync_1 <= btn_sync_0;
    end
  end

  // Debounce logic
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      counter <= 0;
      btn_out <= 1'b0;
    end
    else
    begin
      if (btn_sync_1 == btn_out)
      begin
        counter <= 0;
      end
      else
      begin
        counter <= counter + 1;
        if (counter >= DEBOUNCE_TIME)
        begin
          btn_out <= btn_sync_1;
          counter <= 0;
        end
      end
    end
  end

endmodule

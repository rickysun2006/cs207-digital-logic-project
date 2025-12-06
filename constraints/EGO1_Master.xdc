# =============================================================================
#      EGO1 FPGA Board Constraint File (XDC)
# =============================================================================

# ----------------------------------------------------------------------------
# System Clock (100MHz)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

# ----------------------------------------------------------------------------
# System Reset (S6 - RST Button)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ----------------------------------------------------------------------------
# Slide Switches (SW0 - SW7)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN R1 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]

set_property PACKAGE_PIN N4 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]

set_property PACKAGE_PIN M4 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]

set_property PACKAGE_PIN R2 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

set_property PACKAGE_PIN P2 [get_ports {sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]

set_property PACKAGE_PIN P3 [get_ports {sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]

set_property PACKAGE_PIN P4 [get_ports {sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]

set_property PACKAGE_PIN P5 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]

# ----------------------------------------------------------------------------
# DIP Switches (SW8 - SW15)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN T5 [get_ports {dip_sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[0]}]

set_property PACKAGE_PIN T3 [get_ports {dip_sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[1]}]

set_property PACKAGE_PIN R3 [get_ports {dip_sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[2]}]

set_property PACKAGE_PIN V4 [get_ports {dip_sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[3]}]

set_property PACKAGE_PIN V5 [get_ports {dip_sw[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[4]}]

set_property PACKAGE_PIN V2 [get_ports {dip_sw[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[5]}]

set_property PACKAGE_PIN U2 [get_ports {dip_sw[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[6]}]

set_property PACKAGE_PIN U3 [get_ports {dip_sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_sw[7]}]

# ----------------------------------------------------------------------------
# Push Buttons (S0 - S4)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN R11 [get_ports {btn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[0]}]

set_property PACKAGE_PIN R17 [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[1]}]

set_property PACKAGE_PIN R15 [get_ports {btn[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[2]}]

set_property PACKAGE_PIN V1 [get_ports {btn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[3]}]

set_property PACKAGE_PIN U4 [get_ports {btn[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[4]}]

# ----------------------------------------------------------------------------
# LEDs (LED0 - LED15)
# ----------------------------------------------------------------------------
# Group 1 (Right side 8 LEDs)
set_property PACKAGE_PIN K3 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN M1 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN L1 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN K6 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN J5 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN H5 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]

set_property PACKAGE_PIN H6 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]

set_property PACKAGE_PIN K1 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

# Group 2 (Left side 8 LEDs)
set_property PACKAGE_PIN K2 [get_ports {led[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[8]}]

set_property PACKAGE_PIN J2 [get_ports {led[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[9]}]

set_property PACKAGE_PIN J3 [get_ports {led[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[10]}]

set_property PACKAGE_PIN H4 [get_ports {led[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[11]}]

set_property PACKAGE_PIN J4 [get_ports {led[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[12]}]

set_property PACKAGE_PIN G3 [get_ports {led[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[13]}]

set_property PACKAGE_PIN G4 [get_ports {led[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[14]}]

set_property PACKAGE_PIN F6 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[15]}]

# ----------------------------------------------------------------------------
# 7-Segment Display
# ----------------------------------------------------------------------------
# --- Right 4 Digits (Group 0) Segments ---
set_property PACKAGE_PIN B4 [get_ports {seg0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[0]}]
set_property PACKAGE_PIN A4 [get_ports {seg0[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[1]}]
set_property PACKAGE_PIN A3 [get_ports {seg0[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[2]}]
set_property PACKAGE_PIN B1 [get_ports {seg0[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[3]}]
set_property PACKAGE_PIN A1 [get_ports {seg0[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[4]}]
set_property PACKAGE_PIN B3 [get_ports {seg0[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[5]}]
set_property PACKAGE_PIN B2 [get_ports {seg0[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[6]}]
set_property PACKAGE_PIN D5 [get_ports {seg0[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[7]}]

# --- Left 4 Digits (Group 1) Segments ---
set_property PACKAGE_PIN D4 [get_ports {seg1[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[0]}]
set_property PACKAGE_PIN E3 [get_ports {seg1[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[1]}]
set_property PACKAGE_PIN D3 [get_ports {seg1[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[2]}]
set_property PACKAGE_PIN F4 [get_ports {seg1[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[3]}]
set_property PACKAGE_PIN F3 [get_ports {seg1[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[4]}]
set_property PACKAGE_PIN E2 [get_ports {seg1[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[5]}]
set_property PACKAGE_PIN D2 [get_ports {seg1[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[6]}]
set_property PACKAGE_PIN H2 [get_ports {seg1[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg1[7]}]

# --- Anodes (Enables) ---
# Right Group (AN0 - AN3)
set_property PACKAGE_PIN G2 [get_ports {an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN C2 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN C1 [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN H1 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

# Left Group (AN4 - AN7)
set_property PACKAGE_PIN G1 [get_ports {an[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[4]}]
set_property PACKAGE_PIN F1 [get_ports {an[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[5]}]
set_property PACKAGE_PIN E1 [get_ports {an[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[6]}]
set_property PACKAGE_PIN G6 [get_ports {an[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[7]}]

# ----------------------------------------------------------------------------
# USB-UART Interface
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN N5 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN T4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# ----------------------------------------------------------------------------
# VGA Interface
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN F5 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN C6 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN B7 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]

set_property PACKAGE_PIN B6 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D8 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]

set_property PACKAGE_PIN C7 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN E6 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN E5 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN E7 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]

set_property PACKAGE_PIN D7 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]

set_property PACKAGE_PIN C4 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

# ----------------------------------------------------------------------------
# Audio PWM
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN T1 [get_ports audio_pwm]
set_property IOSTANDARD LVCMOS33 [get_ports audio_pwm]

set_property PACKAGE_PIN M6 [get_ports audio_sd]
set_property IOSTANDARD LVCMOS33 [get_ports audio_sd]

# ----------------------------------------------------------------------------
# Bluetooth (BLE-CC41-A)
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN L3 [get_ports bt_tx]
set_property IOSTANDARD LVCMOS33 [get_ports bt_tx]

set_property PACKAGE_PIN N2 [get_ports bt_rx]
set_property IOSTANDARD LVCMOS33 [get_ports bt_rx]
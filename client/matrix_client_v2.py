import flet as ft
import datetime
import serial.tools.list_ports
from modules.serial_manager import SerialManager
from modules.input_mode import InputMode
from modules.gen_mode import GenMode
from modules.display_mode import DisplayMode
from modules.calc_mode import CalcMode
from modules.ui_components import StyledCard

def main(page: ft.Page):
    page.title = "FPGA Matrix Controller v2"
    page.padding = 10
    page.window_width = 1200
    page.window_height = 800

    # Theme Configuration
    page.dark_theme = ft.Theme(
        color_scheme=ft.ColorScheme(
            background="#111827",       
            surface="#1f2937",          
            surface_variant="#374151", 
            primary="#6366f1",          
            on_primary="#ffffff",
            outline="#4b5563",
            outline_variant="#374151",
            shadow="#000000",
        )
    )
    page.theme_mode = ft.ThemeMode.DARK

    # --- Logging ---
    log_view = ft.ListView(expand=True, spacing=2, auto_scroll=True)
    
    def log(msg, type="info"):
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        color = ft.Colors.ON_SURFACE
        prefix = "INF"
        if type == "rx": 
            color = ft.Colors.CYAN
            prefix = "RX <"
        elif type == "tx": 
            color = ft.Colors.GREEN
            prefix = "TX >"
        elif type == "error": 
            color = ft.Colors.RED
            prefix = "ERR !"
        
        log_view.controls.append(
            ft.Text(
                spans=[
                    ft.TextSpan(f"[{timestamp}] ", style=ft.TextStyle(color=ft.Colors.OUTLINE)),
                    ft.TextSpan(f"{prefix} ", style=ft.TextStyle(color=color, weight=ft.FontWeight.BOLD)),
                    ft.TextSpan(msg, style=ft.TextStyle(color=ft.Colors.ON_SURFACE))
                ],
                font_family="Consolas", 
                size=12
            )
        )
        page.update()

    # --- Serial Manager ---
    def on_serial_data(line):
        log(f"{line}", "rx")
        process_line(line)

    def on_serial_status(connected, msg):
        color = "green" if connected else "red"
        status_text.value = "ONLINE" if connected else "OFFLINE"
        status_text.color = color
        status_detail.value = msg
        
        # Update dots
        appbar_status_dot.bgcolor = color
        dialog_status_dot.bgcolor = color
        
        connect_btn.visible = not connected
        disconnect_btn.visible = connected
        port_dropdown.disabled = connected
        baud_input.disabled = connected
        page.update()

    def on_serial_tx(msg):
        log(msg, "tx")

    serial_manager = SerialManager(on_serial_data, on_serial_status, on_serial_tx)

    # --- Global Config ---
    app_config = {
        "min_val": 0,
        "max_val": 9
    }

    # --- Modes ---
    input_mode = InputMode(serial_manager, app_config)
    gen_mode = GenMode(serial_manager)
    display_mode = DisplayMode(serial_manager)
    calc_mode = CalcMode(serial_manager)
    
    idle_content = ft.Container(
        content=ft.Column([
            ft.Icon(ft.Icons.HOURGLASS_EMPTY, size=60, color=ft.Colors.OUTLINE),
            ft.Text("Idle Mode", size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.OUTLINE),
            ft.Text("Waiting for FPGA command...", size=16, color=ft.Colors.OUTLINE_VARIANT)
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, alignment=ft.MainAxisAlignment.CENTER),
        alignment=ft.alignment.center
    )

    modes = {
        "ide": idle_content,
        "inp": input_mode,
        "gen": gen_mode,
        "dis": display_mode,
        "cal": calc_mode
    }
    
    current_mode_key = "ide"
    mode_container = ft.Container(
        content=idle_content, 
        expand=True, 
        padding=20, 
        bgcolor="surface",
        border_radius=12,
        shadow=ft.BoxShadow(
            spread_radius=0,
            blur_radius=10,
            color="#1A000000",
            offset=ft.Offset(0, 4),
        )
    )

    def switch_mode(new_mode):
        nonlocal current_mode_key
        if current_mode_key == new_mode:
            return
            
        if new_mode in modes:
            current_mode_key = new_mode
            mode_container.content = modes[new_mode]
            mode_label.value = f"Current Mode: {new_mode.upper()}"
            page.update()
            
            # Reset state if needed
            if new_mode == "dis":
                display_mode.parsing_table = False # Reset table parser
                display_mode.request_stats()       # Auto-refresh stats on entry

    def process_line(line):
        line = line.strip()
        # Update: Check for "mode-xxx" format
        if line.startswith("mode-"):
            new_mode = line.split("-")[-1]
            if new_mode in modes:
                log(f"Switching to mode: {new_mode}", "info")
                switch_mode(new_mode)
                return

        # Pass data to current active mode controller
        if current_mode_key == "inp":
            input_mode.handle_line(line)
        elif current_mode_key == "gen":
            gen_mode.handle_line(line)
        elif current_mode_key == "dis":
            display_mode.handle_line(line)
        elif current_mode_key == "cal":
            calc_mode.handle_line(line)

    # --- Sidebar ---
    # Header
    def toggle_theme(e):
        page.theme_mode = ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
        page.appbar.actions[3].icon = ft.Icons.DARK_MODE if page.theme_mode == ft.ThemeMode.LIGHT else ft.Icons.LIGHT_MODE
        page.update()

    # Connection Controls
    port_dropdown = ft.Dropdown(
        label="Port", 
        hint_text="Select Device", 
        text_size=14, 
        content_padding=10,
        border_color="transparent", 
        bgcolor="surfaceVariant",
        filled=True, 
        expand=True
    )
    baud_input = ft.TextField(
        label="Baud", value="115200", 
        text_size=14, 
        content_padding=10,
        border_color="transparent", 
        bgcolor="surfaceVariant",
        filled=True, 
        width=100
    )
    status_text = ft.Text("OFFLINE", color="red", weight=ft.FontWeight.BOLD, size=12)
    status_detail = ft.Text("Ready", size=10, color=ft.Colors.OUTLINE, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS)
    
    # Status Dots
    appbar_status_dot = ft.Container(width=8, height=8, border_radius=4, bgcolor="red")
    dialog_status_dot = ft.Container(width=10, height=10, border_radius=5, bgcolor="red")
    
    def refresh_ports(e):
        ports = serial_manager.get_ports()
        options = [ft.dropdown.Option(p) for p in ports]
        port_dropdown.options = options
        if options: port_dropdown.value = options[0].key
        page.update()

    connect_btn = ft.ElevatedButton(
        "Connect", icon=ft.Icons.USB, 
        style=ft.ButtonStyle(bgcolor=ft.Colors.GREEN, color="white", shape=ft.RoundedRectangleBorder(radius=8)),
        on_click=lambda e: serial_manager.connect(port_dropdown.value, int(baud_input.value)),
        width=1000
    )
    disconnect_btn = ft.ElevatedButton(
        "Disconnect", icon=ft.Icons.USB_OFF, visible=False,
        style=ft.ButtonStyle(bgcolor=ft.Colors.RED, color="white", shape=ft.RoundedRectangleBorder(radius=8)),
        on_click=lambda e: serial_manager.disconnect(),
        width=1000
    )

    # --- Layout Components ---
    
    # 1. Connection Dialog (Hidden by default)
    connection_dialog = ft.AlertDialog(
        title=ft.Text("Connection Settings"),
        content=ft.Container(
            width=400,
            content=ft.Column([
                ft.Row([
                    dialog_status_dot, 
                    status_text, 
                    ft.Container(expand=True), 
                    status_detail
                ]),
                ft.Divider(),
                ft.Row([port_dropdown, ft.IconButton(ft.Icons.REFRESH, on_click=refresh_ports, icon_color=ft.Colors.PRIMARY)]),
                baud_input,
                ft.Container(height=10),
                connect_btn,
                disconnect_btn
            ], tight=True)
        )
    )

    def open_connection_dialog(e):
        page.open(connection_dialog)

    # 2. Console Bottom Sheet (Hidden by default)
    console_bottom_sheet = ft.BottomSheet(
        ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Text("System Console", weight=ft.FontWeight.BOLD, size=16),
                    ft.Container(expand=True),
                    ft.IconButton(ft.Icons.DELETE_OUTLINE, tooltip="Clear Log", 
                                  on_click=lambda e: log_view.controls.clear() or page.update()),
                    ft.IconButton(ft.Icons.CLOSE, tooltip="Close", 
                                  on_click=lambda e: page.close(console_bottom_sheet))
                ]),
                ft.Divider(),
                ft.Container(content=log_view, expand=True, bgcolor="surface", border_radius=8, padding=10)
            ]),
            padding=20,
            height=400,
            bgcolor="surfaceVariant"
        )
    )

    def open_console(e):
        page.open(console_bottom_sheet)

    # 3. Settings Dialog
    min_val_input = ft.TextField(label="Min Value", value="0", width=100, text_align=ft.TextAlign.RIGHT)
    max_val_input = ft.TextField(label="Max Value", value="9", width=100, text_align=ft.TextAlign.RIGHT)

    def save_settings(e):
        try:
            mn = int(min_val_input.value)
            mx = int(max_val_input.value)
            if mn > mx:
                min_val_input.error_text = "Min > Max"
                min_val_input.update()
                return
            
            app_config["min_val"] = mn
            app_config["max_val"] = mx
            min_val_input.error_text = None
            page.close(settings_dialog)
            log(f"Settings updated: Range [{mn}, {mx}]", "info")
        except ValueError:
            min_val_input.error_text = "Invalid Number"
            min_val_input.update()

    settings_dialog = ft.AlertDialog(
        title=ft.Text("Global Settings"),
        content=ft.Container(
            height=150,
            content=ft.Column([
                ft.Text("Matrix Element Range Limit", weight=ft.FontWeight.BOLD),
                ft.Text("Configure the valid range for matrix elements. This is a client-side check only.", size=12, color="outline"),
                ft.Row([min_val_input, ft.Text("-"), max_val_input], alignment=ft.MainAxisAlignment.CENTER)
            ], spacing=20)
        ),
        actions=[
            ft.TextButton("Cancel", on_click=lambda e: page.close(settings_dialog)),
            ft.ElevatedButton("Save", on_click=save_settings)
        ],
    )

    def open_settings_dialog(e):
        min_val_input.value = str(app_config["min_val"])
        max_val_input.value = str(app_config["max_val"])
        min_val_input.error_text = None
        page.open(settings_dialog)

    # 4. AppBar (Top Navigation)
    page.appbar = ft.AppBar(
        leading=ft.Icon(ft.Icons.GRID_VIEW_ROUNDED, color=ft.Colors.PRIMARY, size=30),
        leading_width=50,
        title=ft.Column([
            ft.Text("FPGA Matrix Controller", weight=ft.FontWeight.BOLD, size=18),
            ft.Text("v2.0", color=ft.Colors.OUTLINE, size=12)
        ], spacing=0),
        center_title=False,
        bgcolor="surface",
        actions=[
            # Status Indicator
            ft.Container(
                content=ft.Row([
                    appbar_status_dot,
                    status_text
                ]),
                padding=ft.padding.symmetric(horizontal=10),
                border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
                border_radius=20,
                margin=ft.margin.only(right=10)
            ),
            # Action Buttons
            ft.IconButton(ft.Icons.SETTINGS_ETHERNET, tooltip="Connection", on_click=open_connection_dialog),
            ft.IconButton(ft.Icons.SETTINGS, tooltip="Settings", on_click=open_settings_dialog),
            ft.IconButton(ft.Icons.TERMINAL, tooltip="Console", on_click=open_console),
            ft.IconButton(ft.Icons.LIGHT_MODE, on_click=toggle_theme, icon_color=ft.Colors.PRIMARY),
            ft.Container(width=10)
        ]
    )

    # 4. Main Layout
    mode_label = ft.Text("Current Mode: IDLE", size=16, weight=ft.FontWeight.BOLD)
    
    page.add(
        ft.Container(
            content=ft.Column([
                ft.Container(content=mode_label, padding=ft.padding.only(bottom=5, left=5)),
                mode_container,
            ], expand=True),
            expand=True,
            padding=5
        )
    )
    
    refresh_ports(None)

    # Auto-connect logic
    def try_auto_connect():
        # Use detailed port info to filter
        ports = serial.tools.list_ports.comports()
        for port in ports:
            # Filter logic: Look for "USB" in description or HWID
            # This avoids connecting to built-in COM1/COM2 which are usually not the FPGA
            if "USB" not in port.description and "USB" not in port.hwid:
                continue

            log(f"Auto-connecting to {port.device} ({port.description})...", "info")
            if serial_manager.connect(port.device, 115200):
                return
        
        # Failed
        dlg = ft.AlertDialog(
            title=ft.Text("Auto-Connect Failed"),
            content=ft.Text("Could not auto-connect to any USB Serial device.\nPlease check connection or connect manually."),
            actions=[
                ft.TextButton("OK", on_click=lambda e: page.close(dlg))
            ],
        )
        page.open(dlg)

    try_auto_connect()

if __name__ == "__main__":
    ft.app(target=main)

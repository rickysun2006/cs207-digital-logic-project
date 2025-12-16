import flet as ft
import datetime
from modules.serial_manager import SerialManager
from modules.input_mode import InputMode
from modules.gen_mode import GenMode
from modules.display_mode import DisplayMode
from modules.calc_mode import CalcMode
from modules.ui_components import StyledCard

def main(page: ft.Page):
    page.title = "FPGA Matrix Controller v2"
    page.padding = 20
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
        status_text.value = "ONLINE" if connected else "OFFLINE"
        status_text.color = "green" if connected else "red"
        status_detail.value = msg
        connect_btn.visible = not connected
        disconnect_btn.visible = connected
        port_dropdown.disabled = connected
        baud_input.disabled = connected
        page.update()

    serial_manager = SerialManager(on_serial_data, on_serial_status)

    # --- Modes ---
    input_mode = InputMode(serial_manager)
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
        if new_mode in modes:
            current_mode_key = new_mode
            mode_container.content = modes[new_mode]
            mode_label.value = f"Current Mode: {new_mode.upper()}"
            
            # Update sidebar buttons state
            for key, btn in mode_buttons.items():
                btn.style = ft.ButtonStyle(
                    bgcolor=ft.Colors.PRIMARY if key == new_mode else "surfaceVariant",
                    color=ft.Colors.ON_PRIMARY if key == new_mode else ft.Colors.ON_SURFACE
                )

            page.update()
            
            # Reset state if needed
            if new_mode == "dis":
                display_mode.parsing_table = False # Reset table parser

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
        theme_btn.icon = ft.Icons.DARK_MODE if page.theme_mode == ft.ThemeMode.LIGHT else ft.Icons.LIGHT_MODE
        page.update()

    theme_btn = ft.IconButton(ft.Icons.LIGHT_MODE, on_click=toggle_theme, icon_color=ft.Colors.PRIMARY)

    sidebar_header = ft.Container(
        content=ft.Row([
            ft.Icon(ft.Icons.GRID_VIEW_ROUNDED, color=ft.Colors.PRIMARY, size=30),
            ft.Column([
                ft.Text("FPGA Matrix", weight=ft.FontWeight.BOLD, size=18),
                ft.Text("Controller v2.0", color=ft.Colors.OUTLINE, size=10)
            ], spacing=0),
            ft.Container(expand=True),
            theme_btn
        ]),
        padding=ft.padding.only(bottom=20)
    )

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
    
    def refresh_ports(e):
        ports = serial_manager.get_ports()
        options = [ft.dropdown.Option(p) for p in ports]
        options.append(ft.dropdown.Option("socket://localhost:7777", text="Simulator (TCP)"))
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

    connection_card = StyledCard(
        title="Connection", icon=ft.Icons.SETTINGS_ETHERNET,
        content=ft.Column([
            ft.Row([
                ft.Container(width=10, height=10, border_radius=5, bgcolor=status_text.color, content=status_text), # Hacky binding
                status_text, 
                ft.Container(expand=True), 
                status_detail
            ]),
            ft.Row([port_dropdown, ft.IconButton(ft.Icons.REFRESH, on_click=refresh_ports, icon_color=ft.Colors.PRIMARY)]),
            baud_input,
            ft.Container(height=5),
            connect_btn,
            disconnect_btn
        ])
    )

    # Manual Mode Switch (Debug)
    mode_buttons = {}
    mode_row_1 = []
    mode_row_2 = []
    
    for i, m in enumerate(["inp", "gen", "dis", "cal"]):
        btn = ft.ElevatedButton(
            m.upper(), 
            on_click=lambda e, mode=m: switch_mode(mode),
            style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=8), padding=10),
            expand=True
        )
        mode_buttons[m] = btn
        if i < 2: mode_row_1.append(btn)
        else: mode_row_2.append(btn)

    debug_card = StyledCard(
        title="Manual Override", icon=ft.Icons.BUG_REPORT,
        content=ft.Column([
            ft.Row(mode_row_1),
            ft.Row(mode_row_2)
        ])
    )

    sidebar = ft.Container(
        width=300,
        content=ft.Column([
            sidebar_header,
            connection_card,
            ft.Container(height=10),
            debug_card,
            ft.Container(expand=True),
            ft.Text("Designed with Flet", size=10, color=ft.Colors.OUTLINE, text_align=ft.TextAlign.CENTER)
        ])
    )

    # --- Layout ---
    mode_label = ft.Text("Current Mode: IDLE", size=20, weight=ft.FontWeight.BOLD)
    
    # Terminal
    terminal_header = ft.Container(
        padding=10, bgcolor="surfaceVariant", 
        border_radius=ft.border_radius.only(top_left=8, top_right=8),
        content=ft.Row([
            ft.Icon(ft.Icons.TERMINAL, size=14, color=ft.Colors.ON_SURFACE_VARIANT),
            ft.Text("System Console", size=12, color=ft.Colors.ON_SURFACE_VARIANT, weight=ft.FontWeight.BOLD),
            ft.Container(expand=True),
            ft.IconButton(ft.Icons.DELETE_OUTLINE, icon_size=16, icon_color=ft.Colors.ON_SURFACE_VARIANT, 
                          tooltip="Clear Log", on_click=lambda e: log_view.controls.clear() or page.update())
        ])
    )
    
    terminal_body = ft.Container(
        content=log_view,
        bgcolor="surface",
        expand=True,
        border_radius=ft.border_radius.only(bottom_left=8, bottom_right=8),
        padding=10,
        border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
    )

    page.add(
        ft.Row([
            sidebar,
            ft.VerticalDivider(width=1, color=ft.Colors.OUTLINE_VARIANT),
            ft.Container(
                content=ft.Column([
                    ft.Container(content=mode_label, padding=ft.padding.only(bottom=10)),
                    mode_container,
                    ft.Container(height=10),
                    ft.Container(
                        content=ft.Column([terminal_header, terminal_body], spacing=0),
                        height=200
                    )
                ], expand=True),
                expand=True,
                padding=10
            )
        ], expand=True)
    )
    
    refresh_ports(None)

if __name__ == "__main__":
    ft.app(target=main)

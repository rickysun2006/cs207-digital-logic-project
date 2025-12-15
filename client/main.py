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
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 10

    # --- Logging ---
    log_view = ft.ListView(expand=True, spacing=2, auto_scroll=True)
    
    def log(msg, type="info"):
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        color = ft.Colors.ON_SURFACE
        if type == "rx": color = ft.Colors.CYAN
        elif type == "tx": color = ft.Colors.GREEN
        elif type == "error": color = ft.Colors.RED
        
        log_view.controls.append(
            ft.Text(f"[{timestamp}] {msg}", color=color, font_family="Consolas", size=12)
        )
        page.update()

    # --- Serial Manager ---
    def on_serial_data(line):
        log(f"RX < {line}", "rx")
        process_line(line)

    def on_serial_status(connected, msg):
        status_text.value = "ONLINE" if connected else "OFFLINE"
        status_text.color = "green" if connected else "red"
        connect_btn.disabled = connected
        disconnect_btn.disabled = not connected
        page.update()

    serial_manager = SerialManager(on_serial_data, on_serial_status)

    # --- Modes ---
    input_mode = InputMode(serial_manager)
    gen_mode = GenMode(serial_manager)
    display_mode = DisplayMode(serial_manager)
    calc_mode = CalcMode(serial_manager)
    
    idle_content = ft.Center(
        ft.Column([
            ft.Icon(ft.Icons.HOURGLASS_EMPTY, size=50, color=ft.Colors.OUTLINE),
            ft.Text("Idle Mode - Waiting for FPGA...", size=20, color=ft.Colors.OUTLINE)
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
    )

    modes = {
        "ide": idle_content,
        "inp": input_mode,
        "gen": gen_mode,
        "dis": display_mode,
        "cal": calc_mode
    }
    
    current_mode_key = "ide"
    mode_container = ft.Container(content=idle_content, expand=True, padding=10, border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT), border_radius=10)

    def switch_mode(new_mode):
        nonlocal current_mode_key
        if new_mode in modes:
            current_mode_key = new_mode
            mode_container.content = modes[new_mode]
            mode_label.value = f"Current Mode: {new_mode.upper()}"
            page.update()
            
            # Reset state if needed
            if new_mode == "dis":
                display_mode.parsing_table = False # Reset table parser

    def process_line(line):
        line = line.strip()
        if line in ["ide", "inp", "gen", "dis", "cal"]:
            log(f"Switching to mode: {line}", "info")
            switch_mode(line)
        else:
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
    port_dropdown = ft.Dropdown(label="Port", width=100, text_size=12)
    baud_input = ft.TextField(label="Baud", value="115200", width=100, text_size=12)
    status_text = ft.Text("OFFLINE", color="red", weight=ft.FontWeight.BOLD)
    
    def refresh_ports(e):
        ports = serial_manager.get_ports()
        port_dropdown.options = [ft.dropdown.Option(p) for p in ports]
        if ports: port_dropdown.value = ports[0]
        page.update()

    connect_btn = ft.ElevatedButton("Connect", on_click=lambda e: serial_manager.connect(port_dropdown.value, int(baud_input.value)))
    disconnect_btn = ft.ElevatedButton("Disconnect", on_click=lambda e: serial_manager.disconnect(), disabled=True)

    sidebar = ft.Container(
        width=250,
        padding=10,
        bgcolor=ft.Colors.SURFACE_VARIANT,
        content=ft.Column([
            ft.Text("Connection", weight=ft.FontWeight.BOLD),
            port_dropdown,
            ft.IconButton(ft.Icons.REFRESH, on_click=refresh_ports),
            baud_input,
            ft.Row([connect_btn, disconnect_btn]),
            ft.Divider(),
            status_text,
            ft.Divider(),
            ft.Text("Manual Mode Switch (Debug):", size=12),
            ft.Row([
                ft.TextButton("INP", on_click=lambda e: switch_mode("inp")),
                ft.TextButton("GEN", on_click=lambda e: switch_mode("gen")),
            ]),
            ft.Row([
                ft.TextButton("DIS", on_click=lambda e: switch_mode("dis")),
                ft.TextButton("CAL", on_click=lambda e: switch_mode("cal")),
            ])
        ])
    )

    # --- Layout ---
    mode_label = ft.Text("Current Mode: IDLE", size=20, weight=ft.FontWeight.BOLD)
    
    page.add(
        ft.Row([
            sidebar,
            ft.VerticalDivider(width=1),
            ft.Column([
                mode_label,
                mode_container,
                ft.Text("System Log", weight=ft.FontWeight.BOLD),
                ft.Container(content=log_view, height=150, bgcolor=ft.Colors.BLACK12, border_radius=5, padding=5)
            ], expand=True)
        ], expand=True)
    )
    
    refresh_ports(None)

if __name__ == "__main__":
    ft.app(target=main)

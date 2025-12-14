import flet as ft
import serial
import serial.tools.list_ports
import time
import threading
import datetime

# ==============================================================================
# UI Styles & Components
# ==============================================================================

# 定义一些颜色常量，方便统一修改
COLOR_BG = "#111827"        # 深蓝黑背景
COLOR_SURFACE = "#1f2937"   # 卡片背景
COLOR_PRIMARY = "#6366f1"   # 靛蓝色主色调
COLOR_ACCENT = "#818cf8"    # 亮一点的靛蓝
COLOR_TEXT = "#f3f4f6"      # 主要文字颜色
COLOR_TEXT_DIM = "#9ca3af"  # 次要文字颜色
COLOR_TERMINAL = "#0f172a"  # 终端背景

# ==============================================================================
# Logic / Backend (逻辑保持完全不变)
# ==============================================================================
DEFAULT_BAUDRATE = 115200

class SerialManager:
    def __init__(self, on_data_received, on_status_changed):
        self.ser = None
        self.is_connected = False
        self.on_data_received = on_data_received
        self.on_status_changed = on_status_changed
        self.stop_event = threading.Event()
        self.read_thread = None

    def get_ports(self):
        return [port.device for port in serial.tools.list_ports.comports()]

    def connect(self, port, baudrate):
        try:
            self.ser = serial.Serial(port, baudrate, timeout=0.1)
            self.is_connected = True
            self.stop_event.clear()
            self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self.read_thread.start()
            self.on_status_changed(True, f"Connected to {port}")
            return True
        except Exception as e:
            self.on_status_changed(False, str(e))
            return False

    def disconnect(self):
        self.stop_event.set()
        if self.ser and self.ser.is_open:
            self.ser.close()
        self.is_connected = False
        self.on_status_changed(False, "Disconnected")

    def send_bytes(self, data: bytes):
        if self.ser and self.ser.is_open:
            self.ser.write(data)
            return True
        return False

    def _read_loop(self):
        while not self.stop_event.is_set():
            try:
                if self.ser and self.ser.in_waiting:
                    raw_data = self.ser.read(self.ser.in_waiting)
                    try:
                        text_data = raw_data.decode('utf-8', errors='replace')
                        self.on_data_received(text_data)
                    except:
                        pass
            except Exception as e:
                print(f"Serial Read Error: {e}")
                break
            time.sleep(0.01)

# ==============================================================================
# UI Components (改为使用动态主题颜色)
# ==============================================================================

class StyledCard(ft.Container):
    """统一风格的卡片容器"""
    def __init__(self, content, title=None, icon=None, expand=False):
        super().__init__()
        # 关键修改：使用 ft.Colors.SURFACE 代替写死的颜色，自动适配深浅模式
        self.bgcolor = ft.Colors.SURFACE
        self.border_radius = 12
        self.padding = 20
        self.expand = expand
        self.shadow = ft.BoxShadow(
            spread_radius=0,
            blur_radius=10,
            color="#1A000000", # 阴影也动态化
            offset=ft.Offset(0, 4),
        )
        
        header_controls = []
        if icon:
            header_controls.append(ft.Icon(icon, color=ft.Colors.PRIMARY, size=20))
        if title:
            header_controls.append(ft.Text(title, size=16, weight=ft.FontWeight.BOLD))
            
        inner_col = ft.Column(spacing=15)
        if header_controls:
            inner_col.controls.append(ft.Row(header_controls, alignment=ft.MainAxisAlignment.START))
            inner_col.controls.append(ft.Divider(height=1, color=ft.Colors.OUTLINE_VARIANT))
        
        inner_col.controls.append(content)
        self.content = inner_col

class MatrixInput(ft.Column):
    def __init__(self, on_send):
        super().__init__()
        self.on_send = on_send
        self.spacing = 20
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        
        self.rows_field = self._build_dim_field("Rows", "3")
        self.cols_field = self._build_dim_field("Cols", "3")
        
        self.grid_container = ft.Column(spacing=8, alignment=ft.MainAxisAlignment.CENTER)
        self.inputs = []

        self.controls = [
            ft.Container(
                content=ft.Row([
                    ft.Text("Dimensions:", color=ft.Colors.OUTLINE),
                    self.rows_field,
                    ft.Text("×", size=18, color=ft.Colors.OUTLINE),
                    self.cols_field
                ], alignment=ft.MainAxisAlignment.CENTER),
                padding=ft.padding.only(bottom=10)
            ),
            ft.Container(
                content=self.grid_container,
                padding=20,
                bgcolor="#0DFFFFFF", # 动态背景色
                border_radius=10,
                border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
                alignment=ft.alignment.center
            ),
            ft.ElevatedButton(
                "Send to FPGA", 
                icon=ft.Icons.SEND_ROUNDED, 
                on_click=self.send_data,
                style=ft.ButtonStyle(
                    bgcolor=ft.Colors.PRIMARY,
                    color=ft.Colors.ON_PRIMARY,
                    shape=ft.RoundedRectangleBorder(radius=8),
                    padding=20,
                ),
                width=200
            )
        ]
        self.update_grid(None)

    def _build_dim_field(self, label, val):
        return ft.TextField(
            label=label, value=val, width=70, 
            text_size=14, 
            content_padding=10, # 移除 height 参数，防止报错
            text_align=ft.TextAlign.CENTER,
            on_change=self.update_grid,
            border_color=ft.Colors.PRIMARY,
        )

    def update_grid(self, e):
        try:
            r = int(self.rows_field.value)
            c = int(self.cols_field.value)
            if r > 8 or c > 8: return
        except:
            return

        self.inputs = []
        grid_controls = []
        
        for i in range(r):
            row_inputs = []
            row_controls = []
            for j in range(c):
                tf = ft.TextField(
                    value="0", 
                    width=50, 
                    text_align=ft.TextAlign.CENTER,
                    text_size=14,
                    content_padding=10, # 移除 height
                    border_radius=4,
                    bgcolor=ft.Colors.SURFACE, # 动态背景
                    border_color=ft.Colors.OUTLINE,
                    focused_border_color=ft.Colors.PRIMARY,
                )
                row_inputs.append(tf)
                row_controls.append(tf)
            self.inputs.append(row_inputs)
            grid_controls.append(ft.Row(row_controls, alignment=ft.MainAxisAlignment.CENTER))
        
        self.grid_container.controls = grid_controls
        if self.page:
            self.update()

    def send_data(self, e):
        try:
            r = int(self.rows_field.value)
            c = int(self.cols_field.value)
            data = []
            for i in range(r):
                for j in range(c):
                    val = int(self.inputs[i][j].value)
                    data.append(val & 0xFF)
            self.on_send(r, c, data)
        except Exception as ex:
            if self.page:
                self.page.show_snack_bar(ft.SnackBar(content=ft.Text(f"Input Error: {str(ex)}"), bgcolor="red"))

class MatrixOutput(ft.Column):
    def __init__(self):
        super().__init__()
        self.spacing = 20
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        
        self.rows_val = ft.Text("-", size=20, weight=ft.FontWeight.BOLD)
        self.cols_val = ft.Text("-", size=20, weight=ft.FontWeight.BOLD)
        
        self.grid_container = ft.Column(spacing=8, alignment=ft.MainAxisAlignment.CENTER)
        
        self.controls = [
            ft.Container(
                content=ft.Row([
                    ft.Text("Received Dimensions:", color=ft.Colors.OUTLINE),
                    self.rows_val,
                    ft.Text("×", size=18, color=ft.Colors.OUTLINE),
                    self.cols_val
                ], alignment=ft.MainAxisAlignment.CENTER),
                padding=ft.padding.only(bottom=10)
            ),
            ft.Container(
                content=self.grid_container,
                padding=20,
                bgcolor="#0DFFFFFF",
                border_radius=10,
                border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
                alignment=ft.alignment.center
            )
        ]
        self.update_matrix(0, 0, [])

    def update_matrix(self, r, c, data):
        self.rows_val.value = str(r)
        self.cols_val.value = str(c)
        
        if r == 0 or c == 0:
            self.grid_container.controls = [ft.Text("Waiting for result...", color=ft.Colors.OUTLINE)]
        else:
            grid_controls = []
            idx = 0
            for i in range(r):
                row_controls = []
                for j in range(c):
                    val = data[idx] if idx < len(data) else 0
                    idx += 1
                    
                    # Color coding
                    bg_color = ft.Colors.SURFACE_VARIANT
                    if val > 0: bg_color = ft.Colors.INDIGO_900 if self.page and self.page.theme_mode == ft.ThemeMode.DARK else ft.Colors.INDIGO_100
                    if val < 0: bg_color = ft.Colors.RED_900 if self.page and self.page.theme_mode == ft.ThemeMode.DARK else ft.Colors.RED_100
                    
                    tf = ft.Container(
                        content=ft.Text(str(val), text_align=ft.TextAlign.CENTER, weight=ft.FontWeight.BOLD),
                        width=50, height=40,
                        alignment=ft.alignment.center,
                        border_radius=4,
                        bgcolor=bg_color,
                        border=ft.border.all(1, ft.Colors.OUTLINE)
                    )
                    row_controls.append(tf)
                grid_controls.append(ft.Row(row_controls, alignment=ft.MainAxisAlignment.CENTER))
            self.grid_container.controls = grid_controls
            
        if self.page:
            self.update()

# ==============================================================================
# Main Application
# ==============================================================================
def main(page: ft.Page):
    page.title = "FPGA Matrix Client"
    page.padding = 20
    page.window_width = 1000
    page.window_height = 800
    
    # 1. 配置深色主题 (和你之前的配色一致)
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
    
    # 2. 配置浅色主题 (清爽风格)
    page.theme = ft.Theme(
        color_scheme=ft.ColorScheme(
            background="#f3f4f6",       
            surface="#ffffff",          
            surface_variant="#e5e7eb",  
            primary="#4f46e5",          
            on_primary="#ffffff",
            outline="#d1d5db",
            outline_variant="#e5e7eb",
            shadow="#000000",
        )
    )
    
    # 默认模式
    page.theme_mode = ft.ThemeMode.DARK

    # --- Logs System ---
    log_view = ft.ListView(expand=True, spacing=2, auto_scroll=True)
    
    def log(msg, type="info"):
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        # 根据当前模式选择日志颜色，保证可见性
        is_dark = page.theme_mode == ft.ThemeMode.DARK
        
        if type == "rx":
            color = ft.Colors.CYAN_ACCENT if is_dark else ft.Colors.BLUE
            prefix = "RX <"
        elif type == "tx":
            color = ft.Colors.GREEN_ACCENT if is_dark else ft.Colors.GREEN
            prefix = "TX >"
        elif type == "error":
            color = ft.Colors.RED_ACCENT if is_dark else ft.Colors.RED
            prefix = "SYS !"
        else:
            color = ft.Colors.ON_SURFACE_VARIANT
            prefix = "INF *"
        
        log_view.controls.append(
            ft.Text(
                spans=[
                    ft.TextSpan(f"[{timestamp}] ", style=ft.TextStyle(color=ft.Colors.OUTLINE)),
                    ft.TextSpan(f"{prefix} ", style=ft.TextStyle(color=color, weight=ft.FontWeight.BOLD)),
                    ft.TextSpan(msg, style=ft.TextStyle(color=ft.Colors.ON_SURFACE))
                ],
                font_family="Consolas, monospace", 
                size=12, 
                selectable=True
            )
        )
        page.update()

    # --- Parser Logic ---
    rx_buffer = ""
    
    def process_rx_data(new_data):
        nonlocal rx_buffer
        rx_buffer += new_data
        if len(rx_buffer) > 20000: rx_buffer = rx_buffer[-10000:] # Prevent overflow
        
        # Tokenize
        tokens = rx_buffer.replace('|', ' ').split()
        nums = []
        for t in tokens:
            try:
                nums.append(int(t))
            except:
                pass
        
        # Search for header 170 (0xAA)
        found_idx = -1
        for i in range(len(nums) - 2):
            if nums[i] == 170:
                r = nums[i+1]
                c = nums[i+2]
                # Basic validation
                if r > 0 and c > 0 and r <= 8 and c <= 8:
                    # Check if we have enough data
                    if len(nums) >= i + 3 + r*c:
                        found_idx = i
        
        if found_idx != -1:
            i = found_idx
            r = nums[i+1]
            c = nums[i+2]
            data = nums[i+3 : i+3+r*c]
            matrix_output.update_matrix(r, c, data)

    # --- Serial Callbacks ---
    def on_serial_status(connected, msg):
        status_indicator.bgcolor = "green" if connected else "red"
        status_text.value = "ONLINE" if connected else "OFFLINE"
        status_text.color = "green" if connected else "red"
        status_detail.value = msg
        
        connect_btn.visible = not connected
        disconnect_btn.visible = connected
        
        # 连接状态改变时，禁用/启用输入
        port_dropdown.disabled = connected
        baud_input.disabled = connected
        
        page.update()

    def on_result_received(text_data):
        log(text_data.strip(), "rx")
        process_rx_data(text_data)

    serial_manager = SerialManager(on_result_received, on_serial_status)

    # --- Logic ---
    def connect_click(e):
        if not port_dropdown.value:
            log("No port selected", "error")
            return
        serial_manager.connect(port_dropdown.value, int(baud_input.value))

    def disconnect_click(e):
        serial_manager.disconnect()

    def refresh_ports(e):
        ports = serial_manager.get_ports()
        port_dropdown.options = [ft.dropdown.Option(p) for p in ports]
        if ports: port_dropdown.value = ports[0]
        page.update()
        log(f"Ports refreshed: {len(ports)} found")

    def send_matrix_payload(r, c, data_bytes):
        if not serial_manager.is_connected:
            page.show_snack_bar(ft.SnackBar(content=ft.Text("Please connect first!"), bgcolor="red"))
            return
        payload = bytearray([r, c]) + bytearray(data_bytes) + b'\r'
        serial_manager.send_bytes(payload)
        log(f"Matrix {r}x{c} sent ({len(data_bytes)} bytes)", "tx")

    def send_virtual_confirm(e):
        if serial_manager.send_bytes(b'\r'):
            log("Sent CR (\\r)", "tx")
        else:
            log("Cannot send: Disconnected", "error")

    # --- Theme Toggle ---
    def toggle_theme(e):
        page.theme_mode = ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
        theme_btn.icon = ft.Icons.DARK_MODE if page.theme_mode == ft.ThemeMode.LIGHT else ft.Icons.LIGHT_MODE
        theme_btn.tooltip = "Switch to Dark Mode" if page.theme_mode == ft.ThemeMode.LIGHT else "Switch to Light Mode"
        page.update()

    # --- Sidebar Controls (Left) ---
    status_indicator = ft.Container(width=10, height=10, border_radius=5, bgcolor="red")
    status_text = ft.Text("OFFLINE", weight=ft.FontWeight.BOLD, size=12, color="red")
    status_detail = ft.Text("Ready to connect", size=10, color=COLOR_TEXT_DIM, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS)

    # 修复 BUG: 移除了 height 参数
    port_dropdown = ft.Dropdown(
        label="Port", 
        hint_text="Select Device", 
        text_size=14, 
        content_padding=10,
        border_color="transparent", 
        bgcolor="surfaceVariant",
        filled=True, 
        expand=True
    )    # 修复 BUG: 移除了 height 参数
    baud_input = ft.TextField(
        label="Baud", value=str(DEFAULT_BAUDRATE), 
        text_size=14, 
        content_padding=10,
        border_color="transparent", 
        bgcolor="surfaceVariant",
        filled=True, 
        width=100,
        keyboard_type=ft.KeyboardType.NUMBER
    )

    connect_btn = ft.ElevatedButton(
        "Connect", icon=ft.Icons.USB, 
        style=ft.ButtonStyle(bgcolor=ft.Colors.GREEN, color="white", shape=ft.RoundedRectangleBorder(radius=8)),
        on_click=connect_click, width=1000
    )
    
    disconnect_btn = ft.ElevatedButton(
        "Disconnect", icon=ft.Icons.USB_OFF, visible=False,
        style=ft.ButtonStyle(bgcolor=ft.Colors.RED, color="white", shape=ft.RoundedRectangleBorder(radius=8)),
        on_click=disconnect_click, width=1000
    )

    theme_btn = ft.IconButton(
        icon=ft.Icons.LIGHT_MODE, 
        tooltip="Switch to Light Mode",
        on_click=toggle_theme,
        icon_color=ft.Colors.PRIMARY
    )

    # --- Main Content (Right) ---
    
    matrix_section = StyledCard(
        title="Matrix Input", icon=ft.Icons.APPS,
        content=MatrixInput(send_matrix_payload)
    )

    result_section = StyledCard(
        title="Matrix Output", icon=ft.Icons.APPS,
        content=MatrixOutput()
    )

    sidebar = ft.Container(
        width=450,
        content=ft.Column([
            # 1. Header (带主题切换)
            ft.Container(
                content=ft.Row([
                    ft.Icon(ft.Icons.GRID_VIEW_ROUNDED, color=ft.Colors.PRIMARY, size=30),
                    ft.Column([
                        ft.Text("FPGA Matrix", weight=ft.FontWeight.BOLD, size=18),
                        ft.Text("Controller v1.0", color=ft.Colors.OUTLINE, size=10)
                    ], spacing=0),
                    ft.Container(expand=True),
                    theme_btn # 切换按钮
                ]),
                padding=ft.padding.only(bottom=20)
            ),
            
            # 2. Connection Card
            StyledCard(
                title="Connection", icon=ft.Icons.SETTINGS_ETHERNET,
                content=ft.Column([
                    ft.Row([status_indicator, status_text, ft.Container(expand=True), status_detail]),
                    ft.Row([port_dropdown, ft.IconButton(ft.Icons.REFRESH, on_click=refresh_ports, icon_color=ft.Colors.PRIMARY)]),
                    baud_input,
                    ft.Container(height=5),
                    connect_btn,
                    disconnect_btn
                ])
            ),

            # 3. Quick Actions
            StyledCard(
                title="Tools", icon=ft.Icons.BUILD_CIRCLE,
                content=ft.Column([
                    ft.ElevatedButton("Send Confirm (\\r)", icon=ft.Icons.KEYBOARD_RETURN, on_click=send_virtual_confirm, width=1000),
                    ft.Text("Use this to manually trigger processing if auto-trigger fails.", size=10, color=ft.Colors.OUTLINE)
                ])
            ),

            # 4. Matrix Input
            matrix_section,
            
            ft.Container(expand=True),
            ft.Text("Designed with Flet", size=10, color=ft.Colors.OUTLINE, text_align=ft.TextAlign.CENTER)
        ], scroll=ft.ScrollMode.AUTO)
    )

    # Terminal/Log Area
    terminal_header = ft.Container(
        padding=10, bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST, 
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
        bgcolor=ft.Colors.SURFACE,
        expand=True,
        border_radius=ft.border_radius.only(bottom_left=8, bottom_right=8),
        padding=10,
        border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
    )

    # --- Tabs Layout ---
    tabs = ft.Tabs(
        selected_index=0,
        animation_duration=300,
        tabs=[
            ft.Tab(
                text="Dashboard",
                icon=ft.Icons.DASHBOARD,
                content=ft.Container(
                    content=ft.Column([
                        result_section,
                    ], scroll=ft.ScrollMode.AUTO, spacing=10),
                    padding=20
                )
            ),
            ft.Tab(
                text="System Logs",
                icon=ft.Icons.TERMINAL,
                content=ft.Container(
                    content=ft.Column([
                        terminal_header,
                        terminal_body
                    ], spacing=0, expand=True),
                    padding=20
                )
            ),
        ],
        expand=True,
    )

    page.add(
        ft.Row([
            sidebar,
            ft.VerticalDivider(width=1, color=ft.Colors.OUTLINE_VARIANT),
            tabs
        ], expand=True)
    )

    refresh_ports(None)

if __name__ == "__main__":
    ft.app(target=main)
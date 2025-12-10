import flet as ft
import serial
import serial.tools.list_ports
import time
import threading

# ==============================================================================
# Configuration & Constants
# ==============================================================================
DEFAULT_BAUDRATE = 115200

# ==============================================================================
# Serial Manager
# ==============================================================================
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
                    # Read all available bytes
                    raw_data = self.ser.read(self.ser.in_waiting)
                    try:
                        # Try to decode as UTF-8/ASCII
                        text_data = raw_data.decode('utf-8', errors='replace')
                        self.on_data_received(text_data)
                    except:
                        pass
            except Exception as e:
                print(f"Serial Read Error: {e}")
                break
            time.sleep(0.01)

# ==============================================================================
# UI Components
# ==============================================================================
class MatrixInput(ft.Container):
    def __init__(self, name, on_send):
        super().__init__()
        self.name = name
        self.on_send = on_send
        self.padding = 20
        
        self.rows_field = ft.TextField(label="Rows", value="3", width=100, on_change=self.update_grid)
        self.cols_field = ft.TextField(label="Cols", value="3", width=100, on_change=self.update_grid)
        self.grid_container = ft.Column()
        self.inputs = []

        self.content = ft.Column([
            ft.Text(f"Input Matrix {self.name}", size=20, weight=ft.FontWeight.BOLD),
            ft.Row([self.rows_field, self.cols_field]),
            ft.Divider(),
            self.grid_container,
            ft.ElevatedButton("Send to FPGA", icon="send", on_click=self.send_data)
        ])
        
        self.update_grid(None)

    def update_grid(self, e):
        try:
            r = int(self.rows_field.value)
            c = int(self.cols_field.value)
            if r > 5 or c > 5: return # Limit for UI
        except:
            return

        self.inputs = []
        grid_controls = []
        
        for i in range(r):
            row_inputs = []
            row_controls = []
            for j in range(c):
                tf = ft.TextField(value="0", width=60, text_align=ft.TextAlign.RIGHT)
                row_inputs.append(tf)
                row_controls.append(tf)
            self.inputs.append(row_inputs)
            grid_controls.append(ft.Row(row_controls))
        
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
                    # Send raw value directly (0-255)
                    # input_controller will take the lower 4 bits (0-15)
                    data.append(val & 0xFF)
            
            self.on_send(r, c, data)
        except Exception as ex:
            print(f"Error preparing data: {ex}")

# ==============================================================================
# Main Application
# ==============================================================================
def main(page: ft.Page):
    page.title = "FPGA Matrix Calculator Client"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.window_width = 1000
    page.window_height = 800

    # --- State ---
    log_view = ft.ListView(expand=True, spacing=10, auto_scroll=True)
    
    def log(msg, color="black"):
        log_view.controls.append(ft.Text(msg, color=color, font_family="Consolas"))
        log_view.update()

    # --- Serial Callbacks ---
    def on_serial_status(connected, msg):
        status_icon.name = "check_circle" if connected else "error"
        status_icon.color = "green" if connected else "red"
        status_text.value = msg
        connect_btn.disabled = connected
        disconnect_btn.disabled = not connected
        page.update()

    def on_result_received(text_data):
        # Append raw text to log
        log(text_data, "blue")
        
        # Try to parse matrix from text for visualization (Optional/Best Effort)
        # Expected format: "-123  45\n..."
        # This is complex to do robustly on partial reads, so we just show text for now.


    serial_manager = SerialManager(on_result_received, on_serial_status)

    # --- Actions ---
    def connect_click(e):
        port = port_dropdown.value
        if not port:
            log("Please select a port", "red")
            return
        serial_manager.connect(port, int(baud_dropdown.value))

    def disconnect_click(e):
        serial_manager.disconnect()

    def refresh_ports(e):
        ports = serial_manager.get_ports()
        port_dropdown.options = [ft.dropdown.Option(p) for p in ports]
        port_dropdown.value = ports[0] if ports else None
        page.update()

    def send_matrix_data(r, c, data_bytes):
        if not serial_manager.is_connected:
            log("Not connected!", "red")
            return
        
        # Protocol:
        # 1. Send Rows (Raw Byte)
        # 2. Send Cols (Raw Byte)
        # 3. Send Data Bytes (Raw Bytes)
        # 4. Send CR (\r) to confirm (Required by input_controller)
        
        # Construct payload with raw bytes
        # Note: input_controller takes low 4 bits of data, so 0-15 works directly.
        # matrix_gen takes full 8 bits for M/N/Count.
        payload = bytearray([r, c]) + bytearray(data_bytes) + b'\r'
        
        serial_manager.send_bytes(payload)
        log(f"Sent Matrix ({r}x{c}): {len(data_bytes)} bytes (Raw)", "green")

    def send_virtual_confirm(e):
        if serial_manager.send_bytes(b'\r'):
            log("Sent: Virtual Confirm (\\r)", "orange")

    # --- Layout ---
    
    # Header
    status_icon = ft.Icon(name="error", color="red")
    status_text = ft.Text("Disconnected")
    port_dropdown = ft.Dropdown(width=200, label="Port")
    baud_dropdown = ft.Dropdown(width=120, label="Baud", value=str(DEFAULT_BAUDRATE), options=[
        ft.dropdown.Option("9600"), ft.dropdown.Option("115200"), ft.dropdown.Option("11400")
    ])
    connect_btn = ft.ElevatedButton("Connect", on_click=connect_click)
    disconnect_btn = ft.ElevatedButton("Disconnect", on_click=disconnect_click, disabled=True)
    
    header = ft.Container(
        padding=10,
        bgcolor="surfaceVariant",
        content=ft.Row([
            ft.IconButton(icon="refresh", on_click=refresh_ports, tooltip="Refresh Ports"),
            port_dropdown,
            baud_dropdown,
            connect_btn,
            disconnect_btn,
            ft.VerticalDivider(),
            status_icon,
            status_text
        ])
    )

    # Input Area
    matrix_input = MatrixInput("A / B", send_matrix_data)
    
    # Result Area
    result_grid = ft.Column(alignment=ft.MainAxisAlignment.CENTER)
    result_container = ft.Container(
        expand=True,
        padding=20,
        bgcolor="white",
        border=ft.border.all(1, "outline"),
        border_radius=10,
        content=ft.Column([
            ft.Text("Result Matrix", size=20, weight=ft.FontWeight.BOLD),
            ft.Divider(),
            ft.Container(content=result_grid, expand=True, alignment=ft.alignment.center)
        ])
    )

    # Control Pad
    control_pad = ft.Container(
        padding=10,
        content=ft.Column([
            ft.Text("Quick Controls", weight=ft.FontWeight.BOLD),
            ft.ElevatedButton("Send Confirm (\\r)", on_click=send_virtual_confirm, width=200),
            ft.Text("Note: Ensure FPGA is in correct mode via switches.", size=12, color="grey")
        ])
    )

    # Main Layout
    page.add(
        header,
        ft.Row(
            expand=True,
            controls=[
                ft.Container(width=400, content=ft.Column([matrix_input, control_pad])),
                ft.VerticalDivider(width=1),
                ft.Column(expand=True, controls=[
                    result_container,
                    ft.Container(height=200, content=log_view, bgcolor="black12", padding=10, border_radius=5)
                ])
            ]
        )
    )
    
    refresh_ports(None)

if __name__ == "__main__":
    ft.app(target=main)

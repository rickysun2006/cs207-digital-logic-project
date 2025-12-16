import flet as ft
from .ui_components import StyledCard, MatrixInputGrid, MatrixDisplay

class InputMode(ft.Container):
    def __init__(self, serial_manager, config):
        super().__init__()
        self.serial = serial_manager
        self.config = config
        self.expand = True
        self.padding = 20
        
        # State
        self.current_rows = 3
        self.current_cols = 3
        self.expecting_response = False
        self.response_lines_left = 0
        self.collected_matrix_lines = []
        self.collected_id = ""

        # UI Components
        self.rows_input = ft.TextField(label="Rows", value="3", width=60, on_change=self.update_grid_dims)
        self.cols_input = ft.TextField(label="Cols", value="3", width=60, on_change=self.update_grid_dims)
        self.input_grid = MatrixInputGrid()
        self.input_grid.set_dimensions(3, 3)
        
        self.result_display = MatrixDisplay("Generated Matrix")
        self.result_id_display = ft.Text("ID: --", size=20, weight=ft.FontWeight.BOLD, color="primary")

        # Layout
        left_panel = StyledCard(
            title="Input Matrix", icon=ft.Icons.GRID_ON,
            content=ft.Column([
                ft.Row([self.rows_input, ft.Text("x"), self.cols_input], alignment=ft.MainAxisAlignment.CENTER),
                ft.Container(content=self.input_grid, padding=10, border=ft.border.all(1, "outlineVariant"), border_radius=8),
                ft.ElevatedButton(
                    "Send to FPGA", 
                    icon=ft.Icons.SEND, 
                    on_click=self.send_data,
                    style=ft.ButtonStyle(bgcolor="primary", color="onPrimary")
                )
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=20)
        )

        right_panel = StyledCard(
            title="Result from FPGA", icon=ft.Icons.OUTPUT,
            content=ft.Column([
                self.result_id_display,
                self.result_display
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=20)
        )

        self.content = ft.Row([
            ft.Container(content=left_panel, expand=True),
            ft.Container(content=right_panel, expand=True)
        ], expand=True, spacing=20)

    def update_grid_dims(self, e):
        try:
            r = int(self.rows_input.value)
            c = int(self.cols_input.value)
            if 1 <= r <= 5 and 1 <= c <= 5:
                self.current_rows = r
                self.current_cols = c
                self.input_grid.set_dimensions(r, c)
        except:
            pass

    def show_validation_error(self, msg):
        if not self.page: return
        dlg = ft.AlertDialog(
            title=ft.Text("输入错误"),
            content=ft.Text(msg),
            actions=[
                ft.TextButton("确定", on_click=lambda e: self.page.close(dlg))
            ],
        )
        self.page.open(dlg)

    def send_data(self, e):
        if not self.serial.is_connected:
            return
        
        # Reset styles
        self.rows_input.border_color = None
        self.cols_input.border_color = None
        for row in self.input_grid.inputs:
            for tf in row:
                tf.border_color = "outline"
        self.update()
        
        # Validation
        try:
            try:
                r = int(self.rows_input.value)
                c = int(self.cols_input.value)
            except ValueError:
                self.rows_input.border_color = "red"
                self.cols_input.border_color = "red"
                self.update()
                self.show_validation_error("请输入有效的维度数字")
                return

            if not (1 <= r <= 5 and 1 <= c <= 5):
                self.rows_input.border_color = "red"
                self.cols_input.border_color = "red"
                self.update()
                self.show_validation_error("矩阵维度必须在 1-5 之间")
                return
            
            # Validate grid values
            has_error = False
            values = []
            min_v = self.config["min_val"]
            max_v = self.config["max_val"]
            
            for row in self.input_grid.inputs:
                for tf in row:
                    try:
                        val = int(tf.value)
                        if not (min_v <= val <= max_v):
                            tf.border_color = "red"
                            has_error = True
                        values.append(val)
                    except ValueError:
                        tf.border_color = "red"
                        has_error = True
                        values.append(0)
            
            if has_error:
                self.update()
                self.show_validation_error(f"矩阵元素必须在 {min_v}-{max_v} 之间")
                return

        except ValueError:
             self.show_validation_error("请输入有效的数字")
             return
        
        # Format: m n v1 v2 ... (Binary)
        payload = [r, c] + values
        # Convert to bytes, handling potential negative numbers or overflows by masking
        payload_bytes = bytes([x & 0xFF for x in payload])
        self.serial.send_bytes(payload_bytes)
        
        # Prepare to receive response
        self.expecting_response = True
        self.response_lines_left = self.current_rows
        self.collected_matrix_lines = []
        self.collected_id = ""
        
        self.result_display.update_matrix("Waiting...")
        self.result_id_display.value = "ID: ??"
        self.update()

    def handle_line(self, line):
        """Called by main loop when a line is received in this mode"""
        if not self.expecting_response:
            return

        if not self.collected_id:
            # First line is ID
            self.collected_id = line.strip()
            self.result_id_display.value = f"ID: {self.collected_id}"
            if self.result_id_display.page:
                self.result_id_display.update()
        else:
            # Subsequent lines are matrix rows
            self.collected_matrix_lines.append(line)
            self.response_lines_left -= 1
            
            # Update display progressively
            full_text = "\n".join(self.collected_matrix_lines)
            self.result_display.update_matrix(full_text)
            
            if self.response_lines_left <= 0:
                self.expecting_response = False

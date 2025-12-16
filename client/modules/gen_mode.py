import flet as ft
from .ui_components import StyledCard, MatrixDisplay

class GenMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.expand = True
        self.padding = 20
        
        # State
        self.gen_m = 3
        self.gen_n = 3
        self.gen_k = 1
        self.matrices_to_receive = 0
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""

        # UI
        self.m_input = ft.TextField(label="Rows", value="3", width=60)
        self.n_input = ft.TextField(label="Cols", value="3", width=60)
        self.k_input = ft.TextField(label="Count", value="1", width=60)
        
        # Use a Flow layout (Row with wrap) inside a scrollable Column
        self.results_wrap = ft.Row(wrap=True, spacing=15, run_spacing=15, alignment=ft.MainAxisAlignment.START)
        self.results_scroll = ft.Column([self.results_wrap], scroll=ft.ScrollMode.AUTO, expand=True)

        self.content = ft.Column([
            StyledCard(
                title="Generation Parameters", icon=ft.Icons.SETTINGS,
                content=ft.Row([
                    self.m_input,
                    ft.Text("x"),
                    self.n_input,
                    ft.Text("Count:"),
                    self.k_input,
                    ft.ElevatedButton(
                        "Generate", 
                        icon=ft.Icons.PLAY_ARROW, 
                        on_click=self.send_gen_cmd,
                        style=ft.ButtonStyle(bgcolor="primary", color="onPrimary")
                    )
                ], alignment=ft.MainAxisAlignment.CENTER, spacing=20)
            ),
            ft.Container(height=10),
            StyledCard(
                title="Generated Results", icon=ft.Icons.GRID_VIEW,
                expand=True,
                content=ft.Container(content=self.results_scroll, expand=True, bgcolor="background", border_radius=8, padding=15)
            )
        ])

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

    def send_gen_cmd(self, e):
        if not self.serial.is_connected: return
        
        # Reset styles
        self.m_input.border_color = None
        self.n_input.border_color = None
        self.update()

        try:
            try:
                m = int(self.m_input.value)
                n = int(self.n_input.value)
                k = int(self.k_input.value)
            except ValueError:
                self.m_input.border_color = "red"
                self.n_input.border_color = "red"
                self.update()
                self.show_validation_error("请输入有效的数字")
                return
            
            if not (1 <= m <= 5 and 1 <= n <= 5):
                self.m_input.border_color = "red"
                self.n_input.border_color = "red"
                self.update()
                self.show_validation_error("矩阵维度必须在 1-5 之间")
                return
            
            self.gen_m = m
            self.gen_n = n
            self.gen_k = k
            
            # Send as binary bytes: m, n, k
            self.serial.send_bytes(bytes([m, n, k]))
            
            self.matrices_to_receive = k
            self.current_matrix_lines_left = m # Start expecting rows immediately
            self.current_matrix_buffer = []
            
            # Clear previous results
            self.results_wrap.controls.clear()
            if self.page:
                self.update()
            
        except ValueError:
            self.show_validation_error("请输入有效的数字")

    def handle_line(self, line):
        if self.matrices_to_receive <= 0:
            return

        # Directly collect matrix rows (No ID line)
        self.current_matrix_buffer.append(line)
        self.current_matrix_lines_left -= 1
        
        if self.current_matrix_lines_left == 0:
            # Matrix complete
            # Do not generate ID as per user request
            self.add_matrix_to_ui(self.current_matrix_buffer)
            
            self.matrices_to_receive -= 1
            self.current_matrix_buffer = []
            self.current_matrix_lines_left = self.gen_m
            
            if self.matrices_to_receive == 0:
                # Generation complete
                if self.page:
                    self.update()

    def add_matrix_to_ui(self, lines):
        text_block = "\n".join(lines)
        card = ft.Container(
            content=ft.Column([
                ft.Container(
                    content=ft.Text(text_block, font_family="Consolas", size=16, weight=ft.FontWeight.BOLD),
                    alignment=ft.alignment.center,
                    padding=10
                )
            ]),
            bgcolor="surfaceVariant",
            padding=5,
            border_radius=8,
            border=ft.border.all(1, "outlineVariant"),
            shadow=ft.BoxShadow(
                spread_radius=1,
                blur_radius=3,
                color="#4D000000", # 0.3 opacity black
                offset=ft.Offset(0, 2),
            )
        )
        self.results_wrap.controls.append(card)
        if self.page:
            self.update()

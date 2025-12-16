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
        
        self.results_list = ft.ListView(expand=True, spacing=10, auto_scroll=True)

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
                        style=ft.ButtonStyle(bgcolor=ft.Colors.PRIMARY, color=ft.Colors.ON_PRIMARY)
                    )
                ], alignment=ft.MainAxisAlignment.CENTER, spacing=20)
            ),
            ft.Container(height=10),
            StyledCard(
                title="Generated Results", icon=ft.Icons.LIST,
                expand=True,
                content=ft.Container(content=self.results_list, expand=True, bgcolor="background", border_radius=8, padding=10)
            )
        ])

    def send_gen_cmd(self, e):
        if not self.serial.is_connected: return
        try:
            m = int(self.m_input.value)
            n = int(self.n_input.value)
            k = int(self.k_input.value)
            
            self.gen_m = m
            self.gen_n = n
            self.gen_k = k
            
            msg = f"{m} {n} {k}"
            self.serial.send_string(msg)
            
            self.matrices_to_receive = k
            self.current_matrix_lines_left = 0 # Will be set when ID arrives
            self.results_list.controls.append(ft.Text(f"--- Requesting {k} matrices of {m}x{n} ---", italic=True))
            self.results_list.update()
            
        except ValueError:
            pass

    def handle_line(self, line):
        if self.matrices_to_receive <= 0:
            return

        if self.current_matrix_lines_left == 0:
            # This line is the ID
            self.current_id = line.strip()
            self.current_matrix_buffer = []
            self.current_matrix_lines_left = self.gen_m
        else:
            # This line is a matrix row
            self.current_matrix_buffer.append(line)
            self.current_matrix_lines_left -= 1
            
            if self.current_matrix_lines_left == 0:
                # Matrix complete
                self.add_matrix_to_ui(self.current_id, self.current_matrix_buffer)
                self.matrices_to_receive -= 1
                if self.matrices_to_receive == 0:
                    self.results_list.controls.append(ft.Text("--- Generation Complete ---", color="green"))
                    self.results_list.update()

    def add_matrix_to_ui(self, mid, lines):
        text_block = "\n".join(lines)
        card = ft.Container(
            content=ft.Column([
                ft.Text(f"Matrix ID: {mid}", weight=ft.FontWeight.BOLD),
                ft.Text(text_block, font_family="Consolas", size=14)
            ]),
            bgcolor="surface",
            padding=10,
            border_radius=5
        )
        self.results_list.controls.append(card)
        self.results_list.update()

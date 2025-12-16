import flet as ft
import re
from .ui_components import StyledCard

class DisplayMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.expand = True
        self.padding = 20
        
        # State
        self.table_lines = []
        self.parsing_table = False
        self.waiting_matrices_count = 0
        self.current_req_m = 0
        self.current_req_n = 0
        
        # Matrix parsing state
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""

        # UI
        self.stats_list = ft.ListView(expand=True, spacing=5)
        self.matrix_view = ft.ListView(expand=True, spacing=10, auto_scroll=True)
        
        left_col = StyledCard(
            title="Statistics", icon=ft.Icons.ANALYTICS,
            expand=True,
            content=ft.Column([
                # ft.ElevatedButton("Refresh Stats", icon=ft.Icons.REFRESH, on_click=self.request_stats, width=1000),
                ft.Container(content=self.stats_list, expand=True, bgcolor="background", border_radius=8, padding=5)
            ], expand=True)
        )
        
        right_col = StyledCard(
            title="Matrices", icon=ft.Icons.DATA_ARRAY,
            expand=True,
            content=ft.Container(content=self.matrix_view, expand=True, bgcolor="background", border_radius=8, padding=10)
        )

        self.content = ft.Row([left_col, right_col], expand=True, spacing=20)

    def request_stats(self, e=None):
        if self.serial.is_connected:
            self.serial.send_string("00")
            self.stats_list.controls.clear()
            self.parsing_table = True
            self.table_lines = []
            self.update()

    def request_matrices(self, m, n, count):
        if self.serial.is_connected:
            # Convert dimensions to Hex string (e.g. 10 -> "0A")
            # User requirement: "convert the matrix id entered by the user into hexadecimal"
            # Assuming 'matrix id' refers to the selection parameters m and n.
            msg = f"{m:02X} {n:02X}"
            self.serial.send_string(msg)
            
            self.matrix_view.controls.clear()
            self.matrix_view.controls.append(ft.Text(f"Fetching {count} matrices of size {m}x{n} (Sent: {msg})...", italic=True))
            self.matrix_view.update()
            
            self.waiting_matrices_count = count
            self.current_req_m = m
            self.current_req_n = n
            self.current_matrix_lines_left = 0

    def handle_line(self, line):
        # Check if it's a table line
        if "+----" in line:
            self.parsing_table = True
            return
        
        if self.parsing_table:
            # We are inside the table block
            # Check if it's a data line like "| 2 | 2 | 1 |"
            # Regex to match: | m | n | cnt |
            match = re.search(r'\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', line)
            if match:
                m, n, cnt = map(int, match.groups())
                self.add_stat_item(m, n, cnt)
            else:
                # If line doesn't match and doesn't look like table border, maybe table ended?
                # But for now we just parse what we can.
                pass
            return

        # If not parsing table, maybe we are receiving matrices?
        if self.waiting_matrices_count > 0:
            if self.current_matrix_lines_left == 0:
                # Expecting ID
                self.current_id = line.strip()
                self.current_matrix_buffer = []
                self.current_matrix_lines_left = self.current_req_m
            else:
                # Expecting Row
                self.current_matrix_buffer.append(line)
                self.current_matrix_lines_left -= 1
                
                if self.current_matrix_lines_left == 0:
                    # Matrix Done
                    self.add_matrix_card(self.current_id, self.current_matrix_buffer)
                    self.waiting_matrices_count -= 1
                    if self.waiting_matrices_count == 0:
                        self.matrix_view.controls.append(ft.Text("Done.", color="green"))
                        self.matrix_view.update()

    def add_stat_item(self, m, n, cnt):
        btn = ft.ElevatedButton(
            f"{m}x{n} (Count: {cnt})",
            on_click=lambda e: self.request_matrices(m, n, cnt)
        )
        self.stats_list.controls.append(btn)
        self.stats_list.update()

    def add_matrix_card(self, mid, lines):
        text_block = "\n".join(lines)
        card = ft.Container(
            content=ft.Column([
                ft.Text(f"ID: {mid}", weight=ft.FontWeight.BOLD),
                ft.Text(text_block, font_family="Consolas", size=14)
            ]),
            bgcolor=ft.Colors.SURFACE,
            padding=10,
            border_radius=5
        )
        self.matrix_view.controls.append(card)
        self.matrix_view.update()

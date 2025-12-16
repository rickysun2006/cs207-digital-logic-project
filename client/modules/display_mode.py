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
        
        # Use a Flow layout (Row with wrap) inside a scrollable Column for matrices
        self.matrix_wrap = ft.Row(wrap=True, spacing=15, run_spacing=15, alignment=ft.MainAxisAlignment.START)
        self.matrix_scroll = ft.Column([self.matrix_wrap], scroll=ft.ScrollMode.AUTO, expand=True)
        
        left_col = StyledCard(
            title="Statistics", icon=ft.Icons.ANALYTICS,
            expand=True,
            content=ft.Column([
                # ft.ElevatedButton("Refresh Stats", icon=ft.Icons.REFRESH, on_click=self.request_stats, width=1000),
                ft.Container(content=self.stats_list, expand=True, bgcolor="background", border_radius=8, padding=5)
            ], expand=True)
        )
        
        right_col = StyledCard(
            title="Matrices", icon=ft.Icons.GRID_VIEW,
            expand=True,
            content=ft.Container(content=self.matrix_scroll, expand=True, bgcolor="background", border_radius=8, padding=15)
        )

        self.content = ft.Row([left_col, right_col], expand=True, spacing=20)

    def request_stats(self, e=None):
        if self.serial.is_connected:
            # Send 0x00 0x00 as binary
            self.serial.send_bytes(bytes([0, 0]))
            self.stats_list.controls.clear()
            self.parsing_table = False
            self.table_lines = []
            self.update()

    def request_matrices(self, m, n, count):
        if self.serial.is_connected:
            # Send m, n as binary bytes
            self.serial.send_bytes(bytes([m, n]))
            
            self.matrix_wrap.controls.clear()
            if self.page:
                self.update()
            
            self.waiting_matrices_count = count
            self.current_req_m = m
            self.current_req_n = n
            self.current_matrix_lines_left = 0

    def handle_line(self, line):
        # Check if it's a table line
        if "+----" in line:
            if not self.parsing_table:
                # New table started, clear previous stats to prevent duplication
                self.stats_list.controls.clear()
                self.update()
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
                return
            else:
                # If line doesn't match and doesn't look like table border, table ended.
                # Stop parsing table and fall through to matrix parsing
                self.parsing_table = False

        # If not parsing table, maybe we are receiving matrices?
        if self.waiting_matrices_count > 0:
            if self.current_matrix_lines_left == 0:
                # Expecting ID
                if not line.strip(): return # Skip empty lines between matrices
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
                        if self.page:
                            self.update()

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
                ft.Container(
                    content=ft.Text(f"ID: {mid}", weight=ft.FontWeight.BOLD, size=12, color="primary"),
                    alignment=ft.alignment.center
                ),
                ft.Divider(height=1, color="outlineVariant"),
                ft.Container(
                    content=ft.Text(text_block, font_family="Consolas", size=16, weight=ft.FontWeight.BOLD),
                    alignment=ft.alignment.center,
                    padding=5
                )
            ], spacing=5),
            bgcolor="surfaceVariant",
            padding=10,
            border_radius=8,
            border=ft.border.all(1, "outlineVariant"),
            shadow=ft.BoxShadow(
                spread_radius=1,
                blur_radius=3,
                color="#4D000000",
                offset=ft.Offset(0, 2),
            )
        )
        self.matrix_wrap.controls.append(card)
        if self.page:
            self.update()

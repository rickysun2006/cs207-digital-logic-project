import flet as ft
import re
import time
from .ui_components import StyledCard, MatrixDisplay

class CalcMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.expand = True
        self.padding = 5
        
        # Constants
        self.OP_ADD = "Addition"
        self.OP_MUL = "Matrix Mul"
        self.OP_SCALAR = "Scalar Mul"
        self.OP_TRANS = "Transpose"
        self.OP_CONV = "Convolution"
        
        # State
        self.current_op = None
        self.state = "SELECT_OP" # SELECT_OP, WAIT_STATS_A, SELECT_DIM_A, WAIT_MATRICES_A, SELECT_MATRIX_A, ...
        
        self.matrix_a_dims = (0, 0) # (rows, cols)
        self.matrix_b_dims = (0, 0)
        
        self.stats_buffer = []
        self.parsing_table = False
        self.total_matrices_expected = 0
        self.current_matrices_found = 0
        
        self.matrices_to_receive = 0
        self.current_req_m = 0
        self.current_req_n = 0
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""
        
        self.echo_a_buffer = []
        self.echo_b_buffer = []
        self.echo_lines_left = 0
        
        self.result_buffer = []
        self.expected_result_rows = 0

        # UI Components
        self.op_dropdown = ft.Dropdown(
            label="Operation Type",
            options=[
                ft.dropdown.Option(self.OP_ADD),
                ft.dropdown.Option(self.OP_MUL),
                ft.dropdown.Option(self.OP_SCALAR),
                ft.dropdown.Option(self.OP_TRANS),
                ft.dropdown.Option(self.OP_CONV),
            ],
            width=200,
            on_change=self.on_op_changed
        )
        
        self.reset_btn = ft.ElevatedButton(
            "Reset", icon=ft.Icons.RESTART_ALT, 
            on_click=self.reset,
            style=ft.ButtonStyle(bgcolor="red", color="white")
        )
        
        self.status_text = ft.Text("Select an operation to start", size=16, color="outline")
        
        # Dynamic Content Area
        self.content_area = ft.Column(expand=True, scroll=ft.ScrollMode.AUTO)
        
        # Main Layout
        self.content = StyledCard(
            content=ft.Column([
                self.status_text,
                ft.Divider(),
                self.content_area
            ], expand=True),
            title="Calculation Workspace", 
            icon=ft.Icons.CALCULATE,
            expand=True,
            extra_header_controls=[
                self.op_dropdown,
                self.reset_btn
            ]
        )

    def reset(self, e=None):
        self.state = "SELECT_OP"
        self.current_op = None
        self.op_dropdown.value = None
        self.op_dropdown.disabled = False
        self.status_text.value = "Select an operation to start"
        self.content_area.controls.clear()
        self.update()

    def on_op_changed(self, e):
        if not self.op_dropdown.value: return
        
        self.current_op = self.op_dropdown.value
        self.op_dropdown.disabled = True
        
        # Reset stats counters
        self.total_matrices_expected = 0
        self.current_matrices_found = 0
        
        self.state = "WAIT_STATS_A"
        self.status_text.value = f"Mode: {self.current_op}. Waiting for Matrix A statistics from FPGA..."
        self.content_area.controls.clear()
        self.content_area.controls.append(
            ft.ProgressBar(width=None, color="primary", bgcolor="surfaceVariant")
        )
        self.update()

    def handle_line(self, line):
        if self.state == "SELECT_OP":
            return

        # --- Phase A: Select First Matrix ---
        if self.state == "WAIT_STATS_A":
            self.parse_stats(line, is_a=True)
        
        elif self.state == "WAIT_MATRICES_A":
            self.parse_matrices(line, is_a=True)
            
        # --- Phase B: Select Second Matrix (If needed) ---
        elif self.state == "WAIT_STATS_B":
            self.parse_stats(line, is_a=False)
            
        elif self.state == "WAIT_MATRICES_B":
            self.parse_matrices(line, is_a=False)
            
        # --- Phase C: Result ---
        elif self.state == "WAIT_ECHO_A":
            self.parse_echo(line, is_a=True)
            
        elif self.state == "WAIT_ECHO_B":
            self.parse_echo(line, is_a=False)
            
        elif self.state == "WAIT_RESULT":
            self.parse_result(line)

    # --- Parsing Logic ---

    def parse_stats(self, line, is_a):
        line = line.strip()
        if not line: return

        # Try to parse Total count if not in table
        if not self.parsing_table:
            # User specified: Plain number indicating total count
            if line.isdigit():
                try:
                    self.total_matrices_expected = int(line)
                    self.current_matrices_found = 0
                    return
                except:
                    pass

        # Detect table start or separator
        if "+----" in line:
            if not self.parsing_table:
                self.stats_buffer = []
                # Clear loading indicator
                self.content_area.controls.clear()
                
                # Special handling for Conv A: Don't show UI, just show loading
                if self.current_op == self.OP_CONV and is_a:
                    self.content_area.controls.append(ft.Text("Auto-selecting 3x3 Kernels...", italic=True))
                    self.update()
                else:
                    label = "Matrix A" if is_a else "Matrix B"
                    self.content_area.controls.append(ft.Text(f"Select Dimensions for {label}:", weight=ft.FontWeight.BOLD))
                    self.stats_grid = ft.Row(wrap=True, spacing=10)
                    self.content_area.controls.append(self.stats_grid)
                    self.update()
                self.parsing_table = True
            else:
                # It's a separator line. Check if we have found all matrices.
                if self.total_matrices_expected > 0 and self.current_matrices_found >= self.total_matrices_expected:
                    # This is likely the bottom border
                    self.parsing_table = False
                    
                    # Special Auto-Select for Convolution Kernel (3x3)
                    if is_a and self.current_op == self.OP_CONV:
                        self.request_matrices(3, 3, 99, is_a=True)
            return

        if self.parsing_table:
            # Regex: | m | n | cnt |
            match = re.search(r'\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', line)
            if match:
                m, n, cnt = map(int, match.groups())
                
                self.current_matrices_found += cnt
                
                # Filter logic for Matrix B
                valid = True
                if not is_a:
                    if self.current_op == self.OP_ADD:
                        if m != self.matrix_a_dims[0] or n != self.matrix_a_dims[1]: valid = False
                    elif self.current_op == self.OP_MUL:
                        if m != self.matrix_a_dims[1]: valid = False
                
                # Skip adding buttons for Conv A (we auto-select)
                if self.current_op == self.OP_CONV and is_a:
                    valid = False

                if valid:
                    self.add_dim_button(m, n, cnt, is_a)
                return

            # Ignore header rows containing text
            if re.search(r'\|\s*[a-zA-Z]', line):
                return

            # Fallback: If we reach here, it's not a separator, not data, not header -> End of Table
            # This handles cases where Total count wasn't found or logic failed
            self.parsing_table = False
            
            # Special Auto-Select for Convolution Kernel (3x3)
            if is_a and self.current_op == self.OP_CONV:
                # Auto-request 3x3 matrices
                self.request_matrices(3, 3, 99, is_a=True)

    def add_dim_button(self, m, n, cnt, is_a):
        btn = ft.ElevatedButton(
            f"{m}x{n} ({cnt})",
            on_click=lambda e: self.request_matrices(m, n, cnt, is_a)
        )
        self.stats_grid.controls.append(btn)
        self.update()

    def request_matrices(self, m, n, count, is_a):
        if not self.serial.is_connected: return
        
        # Send [m, n]
        self.serial.send_bytes(bytes([m, n]))
        
        # Update State
        self.state = "WAIT_MATRICES_A" if is_a else "WAIT_MATRICES_B"
        if is_a:
            self.matrix_a_dims = (m, n)
        else:
            self.matrix_b_dims = (m, n)
            
        # Update UI
        self.content_area.controls.clear()
        label = "Matrix A" if is_a else ("Kernel" if self.current_op == self.OP_CONV else "Matrix B")
        self.content_area.controls.append(ft.Text(f"Select {label} ({m}x{n}):", weight=ft.FontWeight.BOLD))
        self.matrix_wrap = ft.Row(wrap=True, spacing=15, run_spacing=15)
        self.content_area.controls.append(self.matrix_wrap)
        self.update()
        
        # Setup parsing
        self.matrices_to_receive = count # Note: For Conv auto-select, this might be wrong if we didn't parse stats. 
                                         # But we rely on "Done" or just parsing until user selects.
                                         # Actually, we need to know when to stop? 
                                         # DisplayMode uses count to show "Done". 
                                         # Here we just keep parsing.
        self.current_req_m = m
        self.current_req_n = n
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""

    def parse_matrices(self, line, is_a):
        # Logic similar to DisplayMode
        if self.current_matrix_lines_left == 0:
            # Expecting ID
            if not line.strip(): return
            self.current_id = line.strip()
            self.current_matrix_buffer = []
            self.current_matrix_lines_left = self.current_req_m
        else:
            self.current_matrix_buffer.append(line)
            self.current_matrix_lines_left -= 1
            
            if self.current_matrix_lines_left == 0:
                # Matrix Done
                self.add_matrix_card(self.current_id, self.current_matrix_buffer, is_a)
                # We don't strictly decrement count here because we might not know it for Conv auto-select
                # But it's fine.

    def add_matrix_card(self, mid, lines, is_a):
        # Parse ID from string "ID: 1" or just "1"? 
        # DisplayMode receives "ID: 1" or just "1"? 
        # In DisplayMode: `self.current_id = line.strip()`.
        # We need to extract the numeric ID to send back.
        # Assuming ID is just the number or "Matrix #1".
        # Let's try to extract digits.
        try:
            id_val = int(re.search(r'\d+', mid).group())
        except:
            id_val = 0 # Fallback

        text_block = "\n".join(lines)
        
        def on_select(e):
            self.select_matrix(id_val, is_a)

        card = ft.Container(
            content=ft.Column([
                ft.Container(
                    content=ft.Text(f"{mid}", weight=ft.FontWeight.BOLD, size=12, color="primary"),
                    alignment=ft.alignment.center
                ),
                ft.Divider(height=1, color="outlineVariant"),
                ft.Container(
                    content=ft.Text(text_block, font_family="Consolas", size=14, weight=ft.FontWeight.BOLD),
                    alignment=ft.alignment.center,
                    padding=5
                ),
                ft.Container(
                    content=ft.Text("SELECT", size=10, weight=ft.FontWeight.BOLD, color="onPrimary"),
                    bgcolor="primary", padding=5, border_radius=4,
                    alignment=ft.alignment.center
                )
            ], spacing=5),
            bgcolor="surfaceVariant",
            padding=10,
            border_radius=8,
            border=ft.border.all(1, "outlineVariant"),
            shadow=ft.BoxShadow(
                spread_radius=1, blur_radius=3, color="#4D000000", offset=ft.Offset(0, 2)
            ),
            on_click=on_select,
            animate_scale=ft.Animation(100, ft.AnimationCurve.EASE_OUT),
        )
        self.matrix_wrap.controls.append(card)
        self.update()

    def select_matrix(self, id_val, is_a):
        if not self.serial.is_connected: return
        
        # Send ID
        self.serial.send_bytes(bytes([id_val]))
        
        # Determine next state
        if is_a:
            if self.current_op in [self.OP_ADD, self.OP_MUL]:
                self.state = "WAIT_STATS_B"
                self.status_text.value = "Waiting for second operand statistics..."
                self.content_area.controls.clear()
                self.content_area.controls.append(ft.ProgressBar(width=None, color="primary", bgcolor="surfaceVariant"))
                self.update()
            else:
                # Scalar, Transpose, OR CONV -> Wait Echo A
                self.prepare_wait_echo()
        else:
            # B selected -> Wait Echo A (assuming FPGA echoes A then B)
            self.prepare_wait_echo()

    def prepare_wait_echo(self):
        self.state = "WAIT_ECHO_A"
        self.echo_a_buffer = []
        self.echo_b_buffer = []
        self.echo_lines_left = self.matrix_a_dims[0]
        self.echo_waiting_id = True
        
        self.status_text.value = "Receiving echo from FPGA..."
        self.content_area.controls.clear()
        self.content_area.controls.append(
            ft.Column([
                ft.ProgressBar(width=None, color="orange", bgcolor="surfaceVariant"),
                ft.Text("Reading echoed matrices...", italic=True)
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
        )
        self.update()

    def parse_echo(self, line, is_a):
        line = line.strip()
        if not line: return
        # Heuristic: Check if line has numbers (ignore headers like "Matrix A:")
        if not re.search(r'\d', line): return 

        if self.echo_waiting_id:
            self.echo_waiting_id = False
            return

        if is_a:
            self.echo_a_buffer.append(line)
            self.echo_lines_left -= 1
            if self.echo_lines_left <= 0:
                # Done with A
                if self.current_op in [self.OP_ADD, self.OP_MUL]:
                    # Move to B
                    self.state = "WAIT_ECHO_B"
                    self.echo_lines_left = self.matrix_b_dims[0]
                    self.echo_waiting_id = True
                else:
                    # Unary or Conv (A only) -> Done
                    self.show_pre_result_ui()
        else:
            # Parsing B
            self.echo_b_buffer.append(line)
            self.echo_lines_left -= 1
            if self.echo_lines_left <= 0:
                self.show_pre_result_ui()

    def send_confirm(self, e=None):
        if self.serial.is_connected:
            self.serial.send_bytes(bytes([0xFF]))

    def send_cancel(self, e=None):
        if self.serial.is_connected:
            self.serial.send_bytes(bytes([0xFE]))
        self.reset()

    def on_new_calc(self, e=None):
        self.send_confirm()
        self.reset()

    def show_pre_result_ui(self):
        self.state = "WAIT_RESULT"
        self.status_text.value = "Echo Received. Confirm to Calculate..."
        self.content_area.controls.clear()
        
        # Show Echoed Matrices
        echo_view = ft.Row(wrap=True, alignment=ft.MainAxisAlignment.CENTER, spacing=10)
        
        # Card A
        echo_view.controls.append(self.create_mini_matrix_card("Operand A", self.echo_a_buffer))
        
        # Op Symbol
        op_sym = "+" if self.current_op == self.OP_ADD else ("*" if self.current_op == self.OP_MUL else "->")
        echo_view.controls.append(ft.Text(op_sym, size=20, weight=ft.FontWeight.BOLD))
        
        # Card B (if exists)
        if self.echo_b_buffer:
            echo_view.controls.append(self.create_mini_matrix_card("Operand B", self.echo_b_buffer))
            
        echo_view.controls.append(ft.Text("=", size=20, weight=ft.FontWeight.BOLD))
        echo_view.controls.append(ft.Text("?", size=30, weight=ft.FontWeight.BOLD, color="outline"))

        self.content_area.controls.append(echo_view)
        self.content_area.controls.append(ft.Divider())
        
        # Action Buttons
        actions = ft.Row(
            [
                ft.ElevatedButton(
                    "Cancel", 
                    icon=ft.Icons.CANCEL, 
                    style=ft.ButtonStyle(bgcolor="red", color="white"),
                    on_click=self.send_cancel
                ),
                ft.ElevatedButton(
                    "Confirm & Calculate", 
                    icon=ft.Icons.CHECK_CIRCLE, 
                    style=ft.ButtonStyle(bgcolor="green", color="white"),
                    on_click=self.send_confirm
                )
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=20
        )
        self.content_area.controls.append(actions)
        self.update()
        
        # Prepare for result
        if self.current_op == self.OP_CONV:
            self.expected_result_rows = 8
        elif self.current_op == self.OP_TRANS:
            self.expected_result_rows = self.matrix_a_dims[1]
        elif self.current_op == self.OP_MUL:
            self.expected_result_rows = self.matrix_a_dims[0]
        else:
            self.expected_result_rows = self.matrix_a_dims[0]
            
        self.result_buffer = []

    def create_mini_matrix_card(self, title, lines):
        return ft.Container(
            content=ft.Column([
                ft.Text(title, size=10, color="outline"),
                ft.Text("\n".join(lines), font_family="Consolas", size=10)
            ]),
            bgcolor="surface", padding=10, border_radius=5, border=ft.border.all(1, "outlineVariant")
        )

    def prepare_wait_result(self):
        # Deprecated by show_pre_result_ui, but kept for safety if called elsewhere
        pass

    def parse_result(self, line):
        # Collect lines until we have enough rows
        # Note: Result lines might be empty or headers? 
        # Assuming raw matrix data lines.
        if not line.strip(): return
        
        self.result_buffer.append(line)
        
        if len(self.result_buffer) >= self.expected_result_rows:
            self.show_result()

    def show_result(self):
        self.state = "SHOW_RESULT"
        self.status_text.value = "Calculation Complete"
        self.content_area.controls.clear()
        
        # Final Result View
        result_view = ft.Row(wrap=True, alignment=ft.MainAxisAlignment.CENTER, vertical_alignment=ft.CrossAxisAlignment.CENTER, spacing=10)
        
        # Operand A
        result_view.controls.append(self.create_mini_matrix_card("Operand A", self.echo_a_buffer))
        
        # Op Symbol
        op_sym = "+" if self.current_op == self.OP_ADD else ("*" if self.current_op == self.OP_MUL else "->")
        result_view.controls.append(ft.Text(op_sym, size=20, weight=ft.FontWeight.BOLD))
        
        # Operand B (if exists)
        if self.echo_b_buffer:
            result_view.controls.append(self.create_mini_matrix_card("Operand B", self.echo_b_buffer))
            
        result_view.controls.append(ft.Text("=", size=20, weight=ft.FontWeight.BOLD))
        
        # Result Matrix (Large)
        font_size = 12 if self.current_op == self.OP_CONV else 16
        result_card = ft.Container(
            content=ft.Column([
                ft.Text("Result", size=12, color="green", weight=ft.FontWeight.BOLD),
                ft.Divider(),
                ft.Text("\n".join(self.result_buffer), font_family="Consolas", size=font_size, weight=ft.FontWeight.BOLD, selectable=True)
            ]),
            bgcolor="surfaceVariant",
            padding=20,
            border_radius=12,
            border=ft.border.all(2, "green"),
            shadow=ft.BoxShadow(spread_radius=2, blur_radius=10, color="#4D000000")
        )
        result_view.controls.append(result_card)
        
        self.content_area.controls.append(result_view)
        self.content_area.controls.append(ft.Container(height=20))
        self.content_area.controls.append(
            ft.ElevatedButton("New Calculation", on_click=self.on_new_calc, icon=ft.Icons.ADD)
        )
        self.update()
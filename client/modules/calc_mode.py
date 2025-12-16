import flet as ft
import re
import time
from .ui_components import StyledCard, MatrixDisplay
import re
import time
from .ui_components import StyledCard, MatrixDisplay

class CalcMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.expand = True
        self.padding = 20
        
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
        self.table_border_count = 0
        self.total_matrices_expected = 0
        self.total_matrices_found = 0
        
        self.matrices_to_receive = 0
        self.current_req_m = 0
        self.current_req_n = 0
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""
        
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
        self.content = ft.Column([
            StyledCard(
                content=ft.Row([
                    self.op_dropdown,
                    ft.Container(expand=True),
                    self.reset_btn
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                title="Calculation Setup", icon=ft.Icons.SETTINGS
            ),
            ft.Container(height=10),
            StyledCard(
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
        self.table_border_count = 0
        self.total_matrices_expected = 0
        self.total_matrices_found = 0
        
        self.matrices_to_receive = 0
        self.current_req_m = 0
        self.current_req_n = 0
        self.current_matrix_lines_left = 0
        self.current_matrix_buffer = []
        self.current_id = ""
        
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
        self.content = ft.Column([
            StyledCard(
                content=ft.Row([
                    self.op_dropdown,
                    ft.Container(expand=True),
                    self.reset_btn
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                title="Calculation Setup", icon=ft.Icons.SETTINGS
            ),
            ft.Container(height=10),
            StyledCard(
                content=ft.Column([
                    self.status_text,
                    ft.Divider(),
                    self.content_area
                ], expand=True),
                title="Workflow", icon=ft.Icons.WORK_HISTORY,
                    self.status_text,
                    ft.Divider(),
                    self.content_area
                ], expand=True),
                title="Workflow", icon=ft.Icons.WORK_HISTORY,
                expand=True
            )
        ], expand=True)

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
        self.state = "WAIT_STATS_A"
        self.status_text.value = f"Mode: {self.current_op}. Waiting for Matrix A statistics from FPGA..."
        self.content_area.controls.clear()
        self.content_area.controls.append(
            ft.ProgressBar(width=None, color="primary", bgcolor="surfaceVariant")
        )
        self.update()
        ], expand=True)

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
        elif self.state == "WAIT_RESULT":
            self.parse_result(line)

    # --- Parsing Logic ---

    def parse_stats(self, line, is_a):
        line = line.strip()
        if not line: return

        # Check for Total count
        # Example: "Total Matrices: 5" or "Total: 5"
        total_match = re.search(r'Total.*:\s*(\d+)', line, re.IGNORECASE)
        if total_match:
            self.total_matrices_expected = int(total_match.group(1))
            self.total_matrices_found = 0
            return

        # Detect table start or separator
        if "+----" in line:
            if not self.parsing_table:
                self.stats_buffer = []
                self.table_border_count = 1
                # Clear loading indicator
                self.content_area.controls.clear()
                
                # Special handling for Conv A: Don't show UI, just show loading
                if self.current_op == self.OP_CONV and is_a:
                    self.content_area.controls.append(ft.Text("Auto-selecting 3x3 Kernels...", italic=True))
                    self.stats_grid = None # No grid for Conv A
                    self.update()
                else:
                    label = "Matrix A" if is_a else "Matrix B"
                    self.content_area.controls.append(ft.Text(f"Select Dimensions for {label}:", weight=ft.FontWeight.BOLD))
                    self.stats_grid = ft.Row(wrap=True, spacing=10)
                    self.content_area.controls.append(self.stats_grid)
                    self.update()
            else:
                self.table_border_count += 1
                
                # Check if we are done based on total count
                # If we hit a border AND we have found all matrices, we are done.
                is_end_of_table = False
                if self.total_matrices_expected > 0:
                    if self.total_matrices_found >= self.total_matrices_expected:
                        is_end_of_table = True
                
                if is_end_of_table:
                    self.parsing_table = False
                    self.table_border_count = 0
                    self.total_matrices_expected = 0 # Reset
                    
                    # Special Auto-Select for Convolution Kernel (3x3)
                    if is_a and self.current_op == self.OP_CONV:
                        self.request_matrices(3, 3, 99, is_a=True)
            
            self.parsing_table = True
            return

        if self.parsing_table:
            # Regex: | m | n | cnt |
            match = re.search(r'\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', line)
            if match:
                m, n, cnt = map(int, match.groups())
                self.total_matrices_found += cnt
                
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

            # If we reach here, it's not a separator, not data, not header -> End of Table?
            # Usually we rely on the border to close it.
            pass

    def add_dim_button(self, m, n, cnt, is_a):
        if not self.stats_grid: return # Safety check
        
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
                # Scalar, Transpose, OR CONV -> Wait Result/Confirm
                self.prepare_confirmation()
        else:
            # B selected -> Wait Result
            self.prepare_confirmation()

    def prepare_confirmation(self):
        self.state = "WAIT_CONFIRM"
        self.status_text.value = "Operands Selected. Waiting for user confirmation..."
        self.content_area.controls.clear()
        
        def on_confirm_click(e):
            self.prepare_wait_result()

        self.content_area.controls.append(
            ft.Column([
                ft.Icon(ft.Icons.INFO_OUTLINE, size=40, color="orange"),
                ft.Text("FPGA is echoing selected matrices...", size=16, weight=ft.FontWeight.BOLD),
                ft.Text("1. Verify the matrices on the FPGA/Console.", size=14),
                ft.Text("2. Wait for the echo to finish.", size=14),
                ft.Text("3. Click 'Ready for Result' below.", size=14),
                ft.Text("4. THEN press 'Confirm' on the FPGA.", size=14, color="yellow"),
                ft.Container(height=20),
                ft.ElevatedButton(
                    "Ready for Result", 
                    icon=ft.Icons.CHECK, 
                    bgcolor="green", color="white",
                    on_click=on_confirm_click
                )
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=10)
        )
        self.update()

    def prepare_wait_result(self):
        self.state = "WAIT_RESULT"
        self.status_text.value = "Waiting for calculation result... (Press Confirm on FPGA)"
        self.content_area.controls.clear()
        self.content_area.controls.append(
            ft.Column([
                ft.ProgressBar(width=None, color="green", bgcolor="surfaceVariant"),
                ft.Text("Listening for result...", italic=True, text_align=ft.TextAlign.CENTER)
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
        )
        self.update()
        
        # Calculate expected result rows
        if self.current_op == self.OP_CONV:
            self.expected_result_rows = 8
        elif self.current_op == self.OP_TRANS:
            self.expected_result_rows = self.matrix_a_dims[1] # Cols become rows
        elif self.current_op == self.OP_MUL:
            self.expected_result_rows = self.matrix_a_dims[0] # A.rows
        else:
            self.expected_result_rows = self.matrix_a_dims[0]
            
        self.result_buffer = []

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
        
        text_block = "\n".join(self.result_buffer)
        
        # Special styling for Conv result (Large)
        font_size = 12 if self.current_op == self.OP_CONV else 16
        
        result_card = ft.Container(
            content=ft.Column([
                ft.Text("Result Matrix", size=20, weight=ft.FontWeight.BOLD, color="green"),
                ft.Divider(),
                ft.Text(text_block, font_family="Consolas", size=font_size, weight=ft.FontWeight.BOLD, selectable=True)
            ]),
            bgcolor="surfaceVariant",
            padding=20,
            border_radius=12,
            border=ft.border.all(2, "green"),
            shadow=ft.BoxShadow(spread_radius=2, blur_radius=10, color="#4D000000")
        )
        
        self.content_area.controls.append(result_card)
        self.content_area.controls.append(ft.Container(height=20))
        self.content_area.controls.append(
            ft.ElevatedButton("New Calculation", on_click=self.reset, icon=ft.Icons.ADD)
        )
        self.update()
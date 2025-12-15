import flet as ft

class StyledCard(ft.Container):
    """统一风格的卡片容器"""
    def __init__(self, content, title=None, icon=None, expand=False):
        super().__init__()
        self.bgcolor = ft.Colors.SURFACE
        self.border_radius = 12
        self.padding = 20
        self.expand = expand
        self.shadow = ft.BoxShadow(
            spread_radius=0,
            blur_radius=10,
            color="#1A000000",
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

class MatrixDisplay(ft.Column):
    """用于显示一个只读的矩阵"""
    def __init__(self, title="Matrix"):
        super().__init__()
        self.spacing = 10
        self.horizontal_alignment = ft.CrossAxisAlignment.CENTER
        self.title_text = ft.Text(title, weight=ft.FontWeight.BOLD, size=14)
        self.grid_container = ft.Column(spacing=5, alignment=ft.MainAxisAlignment.CENTER)
        
        self.controls = [
            self.title_text,
            ft.Container(
                content=self.grid_container,
                padding=10,
                bgcolor=ft.Colors.SURFACE_VARIANT,
                border_radius=8,
                alignment=ft.alignment.center
            )
        ]

    def update_matrix(self, matrix_data):
        """
        matrix_data: List of lists (rows) or 1D list.
        If 1D list, need dimensions. But here we assume the parser gives us a 2D structure 
        OR we just display what we get.
        The user requirement says: "data is a formatted matrix".
        If the FPGA sends pre-formatted text lines, we might just display them as text?
        "每个元素都是左对齐到3位" -> This suggests we receive text lines.
        Let's support both: raw text lines OR 2D array.
        """
        self.grid_container.controls.clear()
        
        if isinstance(matrix_data, str):
            # Display raw pre-formatted text
            self.grid_container.controls.append(
                ft.Text(matrix_data, font_family="Consolas", size=14)
            )
        elif isinstance(matrix_data, list):
            # Render grid
            for row in matrix_data:
                row_controls = []
                for val in row:
                    row_controls.append(
                        ft.Container(
                            content=ft.Text(str(val), text_align=ft.TextAlign.CENTER, size=12),
                            width=40, height=30,
                            alignment=ft.alignment.center,
                            bgcolor=ft.Colors.BACKGROUND,
                            border_radius=4
                        )
                    )
                self.grid_container.controls.append(ft.Row(row_controls, alignment=ft.MainAxisAlignment.CENTER))
        
        self.update()

class MatrixInputGrid(ft.Column):
    """用于输入的矩阵网格"""
    def __init__(self, on_change=None):
        super().__init__()
        self.spacing = 10
        self.inputs = [] # 2D list of TextFields
        self.grid_col = ft.Column(spacing=5)
        self.controls = [self.grid_col]
        self.on_change = on_change

    def set_dimensions(self, r, c):
        self.inputs = []
        self.grid_col.controls.clear()
        
        for i in range(r):
            row_inputs = []
            row_controls = []
            for j in range(c):
                tf = ft.TextField(
                    value="0", 
                    width=50, 
                    text_align=ft.TextAlign.CENTER,
                    text_size=14,
                    content_padding=10,
                    border_radius=4,
                    bgcolor=ft.Colors.SURFACE,
                    border_color=ft.Colors.OUTLINE,
                    focused_border_color=ft.Colors.PRIMARY,
                    on_change=self.on_change
                )
                row_inputs.append(tf)
                row_controls.append(tf)
            self.inputs.append(row_inputs)
            self.grid_col.controls.append(ft.Row(row_controls, alignment=ft.MainAxisAlignment.CENTER))
        self.update()

    def get_values(self):
        data = []
        for row in self.inputs:
            for tf in row:
                try:
                    data.append(int(tf.value))
                except:
                    data.append(0)
        return data

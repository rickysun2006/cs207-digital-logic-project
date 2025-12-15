import flet as ft

from .ui_components import StyledCard

class CalcMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.expand = True
        self.padding = 20
        
        self.content = StyledCard(
            title="Calculation Mode", icon=ft.Icons.CALCULATE,
            expand=True,
            content=ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.CONSTRUCTION, size=50, color=ft.Colors.OUTLINE),
                    ft.Text("Logic Pending", size=20, color=ft.Colors.OUTLINE)
                ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                alignment=ft.alignment.center,
                expand=True
            )
        )

    def handle_line(self, line):
        pass

import flet as ft

class CalcMode(ft.Container):
    def __init__(self, serial_manager):
        super().__init__()
        self.serial = serial_manager
        self.content = ft.Center(ft.Text("Calculation Mode - Logic Pending"))

    def handle_line(self, line):
        pass

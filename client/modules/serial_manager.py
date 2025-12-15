import serial
import serial.tools.list_ports
import threading
import time

class SerialManager:
    def __init__(self, on_data_received, on_status_changed):
        self.ser = None
        self.is_connected = False
        self.on_data_received = on_data_received
        self.on_status_changed = on_status_changed
        self.stop_event = threading.Event()
        self.read_thread = None
        self.buffer = ""

    def get_ports(self):
        return [port.device for port in serial.tools.list_ports.comports()]

    def connect(self, port, baudrate):
        try:
            if port.startswith("socket://"):
                self.ser = serial.serial_for_url(port, baudrate=baudrate, timeout=0.1)
            else:
                self.ser = serial.Serial(port, baudrate, timeout=0.1)
            
            self.is_connected = True
            self.stop_event.clear()
            self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self.read_thread.start()
            self.on_status_changed(True, f"Connected to {port}")
            return True
        except Exception as e:
            self.on_status_changed(False, str(e))
            return False

    def disconnect(self):
        self.stop_event.set()
        if self.ser and self.ser.is_open:
            self.ser.close()
        self.is_connected = False
        self.on_status_changed(False, "Disconnected")

    def send_bytes(self, data: bytes):
        if self.ser and self.ser.is_open:
            self.ser.write(data)
            return True
        return False

    def send_string(self, text: str):
        return self.send_bytes(text.encode('utf-8'))

    def _read_loop(self):
        while not self.stop_event.is_set():
            try:
                if self.ser and self.ser.in_waiting:
                    raw_data = self.ser.read(self.ser.in_waiting)
                    try:
                        text_data = raw_data.decode('utf-8', errors='replace')
                        self._process_buffer(text_data)
                    except:
                        pass
            except Exception as e:
                print(f"Serial Read Error: {e}")
                break
            time.sleep(0.01)

    def _process_buffer(self, new_data):
        self.buffer += new_data
        
        # Prevent overflow
        if len(self.buffer) > 10000:
            # If buffer gets too big, just dump it to avoid memory issues
            self.on_data_received(self.buffer)
            self.buffer = ""
            return

        while '\n' in self.buffer:
            line, self.buffer = self.buffer.split('\n', 1)
            line = line.strip()
            if line:
                self.on_data_received(line)

import serial
import serial.tools.list_ports
import threading
import time
import sys

def get_ports():
    return [port.device for port in serial.tools.list_ports.comports()]

def read_loop(ser):
    while ser.is_open:
        try:
            if ser.in_waiting:
                data = ser.read(ser.in_waiting)
                # Print as ASCII (replace non-printable)
                ascii_str = data.decode('utf-8', errors='replace').replace('\r', '\\r').replace('\n', '\\n')
                # Print as Hex
                hex_str = " ".join([f"{b:02X}" for b in data])
                
                print(f"\n[RX Raw] {hex_str}")
                print(f"[RX Str] {ascii_str}")
                print(">> ", end="", flush=True)
        except Exception as e:
            print(f"Read Error: {e}")
            break
        time.sleep(0.01)

def main():
    print("--- UART Console Simulator ---")
    ports = get_ports()
    if not ports:
        print("No ports found!")
        return

    print("Available ports:")
    for i, p in enumerate(ports):
        print(f"{i}: {p}")

    idx = input("Select port index: ")
    try:
        port = ports[int(idx)]
    except:
        print("Invalid selection")
        return

    baud = input("Baudrate (default 115200): ")
    if not baud: baud = 115200
    else: baud = int(baud)

    try:
        ser = serial.Serial(port, baud, timeout=0.1)
        print(f"Connected to {port} at {baud}")
    except Exception as e:
        print(f"Connection failed: {e}")
        return

    # Start read thread
    t = threading.Thread(target=read_loop, args=(ser,), daemon=True)
    t.start()

    print("Type message to send (press Ctrl+C to exit).")
    print("Prefix with 'HEX:' to send raw hex (e.g. HEX:AA BB)")
    print(">> ", end="", flush=True)

    try:
        while True:
            msg = input()
            if not msg: continue
            
            if msg.startswith("HEX:"):
                # Send Hex
                hex_part = msg[4:]
                try:
                    data = bytes.fromhex(hex_part)
                    ser.write(data)
                    print(f"[TX Hex] {data.hex().upper()}")
                except Exception as e:
                    print(f"Hex Error: {e}")
            else:
                # Send String
                # Auto append newline? The user didn't specify, but usually terminals do.
                # But our protocol might not want it. Let's send raw string.
                # If user wants newline, they can type it or we can add a mode.
                # For now, send raw string.
                ser.write(msg.encode('utf-8'))
                print(f"[TX Str] {msg}")
            
            print(">> ", end="", flush=True)

    except KeyboardInterrupt:
        print("\nExiting...")
        ser.close()

if __name__ == "__main__":
    main()

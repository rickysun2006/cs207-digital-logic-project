import socket
import threading
import time
import sys
import random

# Configuration
HOST = 'localhost'
PORT = 7777

def read_loop(conn):
    while True:
        try:
            data = conn.recv(1024)
            if not data:
                break
            
            ascii_str = data.decode('utf-8', errors='replace').replace('\r', '\\r').replace('\n', '\\n')
            hex_str = " ".join([f"{b:02X}" for b in data])
            
            print(f"\n[RX Raw] {hex_str}")
            print(f"[RX Str] {ascii_str}")
            print("FPGA> ", end="", flush=True)
        except Exception as e:
            print(f"Read Error: {e}")
            break

def send_str(conn, s):
    try:
        conn.sendall(s.encode('utf-8'))
        print(f"[TX] {s.strip()}")
    except:
        print("Send Error")

def generate_matrix_str(mid, r, c):
    lines = [f"{mid}"]
    for _ in range(r):
        row_vals = [random.randint(0, 99) for _ in range(c)]
        row_str = "".join([f"{v:<3}" for v in row_vals])
        lines.append(row_str)
    return "\n".join(lines) + "\n"

def print_help():
    print("\n--- FPGA Simulator Commands ---")
    print(" /mode <name>       : Send mode switch (ide, inp, gen, dis, cal)")
    print(" /stats             : Send dummy statistics table")
    print(" /mat <id> <r> <c>  : Send a random matrix of size r*c with id")
    print(" /raw <text>        : Send raw text")
    print(" HEX:<aa bb>        : Send raw hex bytes")
    print(" <text>             : Send raw text")
    print("-------------------------------")

def main():
    print(f"--- FPGA Console Simulator (TCP Mode) ---")
    print(f"Listening on {HOST}:{PORT}...")
    print("Please connect the client to: socket://localhost:7777")

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, PORT))
        s.listen()
        conn, addr = s.accept()
        with conn:
            print(f"Connected by {addr}")
            
            t = threading.Thread(target=read_loop, args=(conn,), daemon=True)
            t.start()

            print_help()
            print("FPGA> ", end="", flush=True)

            try:
                while True:
                    cmd = input()
                    if not cmd: continue
                    
                    if cmd.startswith("HEX:"):
                        try:
                            data = bytes.fromhex(cmd[4:])
                            conn.sendall(data)
                            print(f"[TX Hex] {data.hex().upper()}")
                        except:
                            print("Hex Error")
                    
                    elif cmd.startswith("/mode "):
                        mode = cmd.split()[1]
                        send_str(conn, mode + "\n")
                        
                    elif cmd.startswith("/stats"):
                        table = (
                            "+----+----+------+\n"
                            "|  m |  n |  cnt |\n"
                            "+----+----+------+\n"
                            "|  2 |  2 |    5 |\n"
                            "+----+----+------+\n"
                            "|  3 |  3 |    2 |\n"
                            "+----+----+------+\n"
                        )
                        send_str(conn, table)
                        
                    elif cmd.startswith("/mat "):
                        parts = cmd.split()
                        if len(parts) >= 4:
                            mid = parts[1]
                            r = int(parts[2])
                            c = int(parts[3])
                            msg = generate_matrix_str(mid, r, c)
                            send_str(conn, msg)
                        else:
                            print("Usage: /mat <id> <r> <c>")

                    elif cmd.startswith("/raw "):
                        send_str(conn, cmd[5:])
                        
                    else:
                        send_str(conn, cmd + "\n")
                    
                    print("FPGA> ", end="", flush=True)

            except KeyboardInterrupt:
                print("\nExiting...")

if __name__ == "__main__":
    main()

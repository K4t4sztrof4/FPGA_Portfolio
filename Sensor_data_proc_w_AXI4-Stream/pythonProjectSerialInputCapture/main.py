import serial
import csv
import time

# -------- CONFIG --------
PORT = "COM5"        # change to your port (e.g. COM5, COM6)
BAUD = 9600        # must match Arduino Serial.begin()
OUT_FILE = "ppg_data.csv"
TIMEOUT = 1          # seconds
# ------------------------

def main():
    ser = serial.Serial(PORT, BAUD, timeout=TIMEOUT)
    print(f"Opened {PORT} at {BAUD} baud")

    with open(OUT_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["ir"])  # header (optional)

        buffer = ""

        try:
            while True:
                data = ser.read(ser.in_waiting or 1).decode(errors="ignore")
                buffer += data

                # Split on commas
                while "," in buffer:
                    value, buffer = buffer.split(",", 1)

                    value = value.strip()
                    if value.isdigit():
                        writer.writerow([int(value)])
                        print(value)

        except KeyboardInterrupt:
            print("\nStopping capture")

    ser.close()
    print(f"Saved to {OUT_FILE}")

if __name__ == "__main__":
    main()

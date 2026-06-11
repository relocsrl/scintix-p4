# Scintix P4 — Hello World

> Target: **ESP32-P4** · Tested on **ESP-IDF v6.0.1**

The simplest possible starting point for the Scintix P4. It starts a FreeRTOS task that prints `Hello World!`, the chip/revision information and a reboot countdown to the console — a quick way to confirm that your toolchain, board and serial connection all work before moving on to the other examples.

This is the unmodified Espressif [`hello_world`](https://github.com/espressif/esp-idf/tree/release/v6.0/examples/get-started/hello_world) example, configured for the Scintix P4 (`esp32p4` target).

## Hardware required

* A Scintix P4 module.
* A USB-C cable for power and programming (standalone), **or** the module plugged into a CM4/CM5 carrier board.

## Console output

The console is printed over the standard ESP-IDF channel. On the Scintix P4 you have two physical options:

* **UART0** — exposed on the 6-pin programmer connector directly on the Scintix P4 board.
* **USB Serial/JTAG** — the module's native USB-C port, or a carrier's micro-USB/USB-C when the module is mounted on one (e.g. the Raspberry Pi CM4 carrier).

Select the active channel with `idf.py menuconfig` → *Component config* → *ESP System Settings* → *Channel for console output*.

## Build, flash and monitor

```
idf.py set-target esp32p4
idf.py -p PORT flash monitor
```

Replace `PORT` with your serial port (e.g. `COM5` on Windows, `/dev/ttyUSB0` on Linux). To exit the monitor, press `Ctrl-]`.

See the [ESP-IDF Getting Started Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32p4/get-started/index.html) for the full toolchain setup.

## Differences from the upstream Espressif example

None at the source level — only the build configuration targets `esp32p4`.

# Scintix P4 — Ethernet iperf (console over UART0)

> Target: **ESP32-P4** · Tested on **ESP-IDF v6.0.1**

Measures Ethernet throughput/bandwidth on the Scintix P4 using the [iperf](https://iperf.fr/) protocol, driven from an interactive console (REPL). Traffic goes through the Scintix P4 **on-board Ethernet PHY (Microchip KSZ8091RNACA)** — no external Ethernet board is needed, just an RJ45 connection on a carrier that routes the MAC/PHY pins.

This variant prints the console over **UART0**. A twin example, [`rm-cmp4_eth_iperf`](../rm-cmp4_eth_iperf), is identical but routes the console to USB Serial/JTAG — pick whichever matches your wiring.

It is based on the Espressif [Ethernet iperf](https://github.com/espressif/esp-idf/tree/release/v6.0/examples/ethernet/iperf) example.

## Console output

This example is configured to print the console trace over **UART0**, available through the **6-pin programmer header next to the ESP32-P4** (the board has a second 6-pin header next to the ESP32-C6, for the Wi-Fi firmware — see [which header is which](../../esp32c6_wifi_firmware/README.md#which-6-pin-header)). Use this variant when you are connected to the module's own programmer header rather than a carrier's USB port.

## Hardware required

* A Scintix P4 module on a CM4/CM5 carrier that exposes the on-board Ethernet (RJ45). *Tested on the Raspberry Pi CM4 IO board.*
* An [Espressif ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html) (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html), or any USB-to-UART adapter) on the 6-pin header next to the ESP32-P4 (for power/flash/monitor).
* A PC on the same network, with the `iperf` tool installed.

## Software tools preparation

Install **iperf 2.x** on the PC (iperf3 is not fully compatible):

* Debian/Ubuntu: `sudo apt-get install iperf`
* macOS: `brew install iperf` (Homebrew) or `sudo port install iperf` (MacPorts)
* Windows (MSYS2): binaries from [SourceForge](https://sourceforge.net/projects/iperf2/)

## Configure, build, flash

Optionally enable *Store command history in flash* under *Example Configuration* in `idf.py menuconfig` (the example ships with a FAT `storage` partition for this).

```
idf.py set-target esp32p4
idf.py -p PORT flash monitor
```

To exit the monitor, press `Ctrl-]`.

## Example output

### Uplink (ESP → PC)

* PC: `iperf -u -s -i 3`
* Scintix P4: `iperf -u -c PC_IP -i 3 -t 30`

```
mode=udp-client sip=192.168.2.156:5001, dip=192.168.2.160:5001, interval=3, time=30
    Interval           Bandwidth
   0-   3 sec       72.92 Mbits/sec
   ...
   0-  30 sec       73.52 Mbits/sec
```

### Downlink (PC → ESP)

* PC: `iperf -u -c ESP_IP -b 80M -t 30 -i 3`
* Scintix P4: `iperf -u -s -t 30 -i 3`

```
mode=udp-server sip=192.168.2.156:5001, dip=0.0.0.0:5001, interval=3, time=30
    Interval           Bandwidth
   0-   3 sec       79.36 Mbits/sec
   ...
   0-  30 sec       78.76 Mbits/sec
```

## Tips for higher bandwidth

1. A higher MCU clock yields higher bandwidth.
2. Move hot functions to IRAM with `IRAM_ATTR` (lwIP IRAM optimization is already enabled by default).
3. The iperf task priority can also matter.

## Differences from the upstream Espressif example

* Source code is **unchanged** from upstream (the stock UART REPL is used).
* Console stays on **UART0**, which is the ESP-IDF default on `esp32p4`, so no console override is needed. The only difference from [`rm-cmp4_eth_iperf`](../rm-cmp4_eth_iperf) is that this variant does **not** apply the USB Serial/JTAG override.

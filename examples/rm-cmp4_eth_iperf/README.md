# Scintix P4 — Ethernet iperf (console over USB Serial/JTAG)

> Target: **ESP32-P4** · Tested on **ESP-IDF v6.0.1**

Measures Ethernet throughput/bandwidth on the Scintix P4 using the [iperf](https://iperf.fr/) protocol, driven from an interactive console (REPL). Traffic goes through the Scintix P4 **on-board Ethernet PHY (Microchip KSZ8091RNACA)** — no external Ethernet board is needed, just an RJ45 connection on a carrier that routes the MAC/PHY pins.

This variant prints the console over **USB Serial/JTAG**. A twin example, [`rm-cmp4_eth_iperf_u0`](../rm-cmp4_eth_iperf_u0), is identical but routes the console to UART0 — pick whichever matches your wiring.

It is based on the Espressif [Ethernet iperf](https://github.com/espressif/esp-idf/tree/release/v6.0/examples/ethernet/iperf) example.

## Console output

This example is configured to print the console trace over **USB Serial/JTAG**. Because the Ethernet RJ45 requires a carrier, use the carrier's serial/JTAG port (on the Raspberry Pi CM4 carrier this is the micro-USB); the module's native USB-C exposes the same interface when it is reachable. The REPL is initialized on the USB Serial/JTAG controller accordingly (see *Differences* below).

## Hardware required

* A Scintix P4 module on a CM4/CM5 carrier that exposes the on-board Ethernet (RJ45). *Tested on the Raspberry Pi CM4 IO board.*
* A USB-C cable for power and programming.
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

* `main/ethernet_iperf_main.c`: the console REPL initialization is made **conditional** on the selected console channel, so the same source builds for either UART or USB Serial/JTAG:
  ```c
  #if CONFIG_ESP_CONSOLE_UART_DEFAULT || CONFIG_ESP_CONSOLE_UART_CUSTOM
      esp_console_dev_uart_config_t uart_config = ESP_CONSOLE_DEV_UART_CONFIG_DEFAULT();
      ESP_ERROR_CHECK(esp_console_new_repl_uart(&uart_config, &repl_config, &repl));
  #elif CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG
      esp_console_dev_usb_serial_jtag_config_t jtag_config = ESP_CONSOLE_DEV_USB_SERIAL_JTAG_CONFIG_DEFAULT();
      ESP_ERROR_CHECK(esp_console_new_repl_usb_serial_jtag(&jtag_config, &repl_config, &repl));
  #endif
  ```
* `sdkconfig.defaults`: console routed to USB Serial/JTAG (`CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y`).

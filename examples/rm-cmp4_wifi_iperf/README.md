# Scintix P4 — Wi-Fi iperf (console over USB Serial/JTAG)

> Target: **ESP32-P4** · Tested on **ESP-IDF v6.0.1**

Measures Wi-Fi throughput/bandwidth on the Scintix P4 using the [iperf](https://iperf.fr/) protocol, driven from an interactive console (REPL).

The ESP32-P4 has **no native Wi-Fi**: connectivity is provided by the on-board **ESP32-C6 companion**, reached transparently through [`esp_hosted`](https://components.espressif.com/components/espressif/esp_hosted) over SDIO. From the application's point of view the Wi-Fi API is the usual `esp_wifi` one — the two-chip plumbing is handled by `esp_wifi_remote` / `esp_hosted`.

This variant prints the console over **USB Serial/JTAG**. A twin example, [`rm-cmp4_wifi_iperf_u0`](../rm-cmp4_wifi_iperf_u0), is identical but routes the console to UART0.

It is based on the Espressif [Wi-Fi iperf](https://github.com/espressif/esp-idf/tree/release/v6.0/examples/wifi/iperf) example.

> **iperf version:** this example implements a subset of iperf and is compatible with **iperf 2.x** only. See the [iperf-cmd component](https://components.espressif.com/components/espressif/iperf-cmd) for details.

## Console output

This example is configured to print the console trace over **USB Serial/JTAG** — standalone, this is the module's native USB-C port; when mounted on a carrier whose serial/JTAG port is wired to the JTAG lines (e.g. the Raspberry Pi CM4 carrier's micro-USB), use that port instead.

## Hardware required

* A Scintix P4 module — **no carrier board is required for Wi-Fi**, which runs on the on-board ESP32-C6.
* A USB-C cable for power and programming.
* A Wi-Fi AP and a PC running `iperf` (2.x).

> If you'd rather use UART0 on the 6-pin programmer header next to the ESP32-P4, see the twin example [`rm-cmp4_wifi_iperf_u0`](../rm-cmp4_wifi_iperf_u0).

> **ESP32-C6 Wi-Fi firmware:** Wi-Fi here runs on the on-board ESP32-C6, which needs the esp_hosted *slave* firmware. Scintix P4 modules ship with it pre-flashed, so you normally don't need to do anything. If you start from a blank C6, the binaries and instructions are in [`esp32c6_wifi_firmware/`](../../esp32c6_wifi_firmware).

## Demo (station TCP TX)

```
# join an AP (DUT starts in station mode by default)
sta_connect <ssid> <password>

# on the AP side, run the iperf server
iperf -s -i 3

# on the Scintix P4, run the iperf client
iperf -c <server_ip> -i 3 -t 60
```

Use `wifi_mode ap` + `ap_set <ssid> <password>` to run the DUT as a soft-AP instead. Use `help` for the full command list. RX/TX and TCP/UDP variants follow the same pattern.

Example console output:

```
iperf> iperf -s -i 2
I (84810) IPERF: mode=tcp-server sip=0.0.0.0:5001, dip=0.0.0.0:5001, interval=2, time=30
Interval       Bandwidth
0.0- 2.0 sec  24.36 Mbits/sec
2.0- 4.0 sec  23.38 Mbits/sec
4.0- 6.0 sec  24.02 Mbits/sec
...
```

## Build, flash and monitor

```
idf.py set-target esp32p4
idf.py -p PORT flash monitor
```

To exit the monitor, press `Ctrl-]`.

## Differences from the upstream Espressif example

* `main/iperf_example_main.c`: registers the **external-coexistence** console command when enabled, so Wi-Fi/BT coexistence over the ESP32-C6 link can be exercised:
  ```c
  #if CONFIG_ESP_COEX_EXTERNAL_COEXIST_ENABLE
      register_cmd_extcoex();
  #endif
  ```
* `main/idf_component.yml`: adds the `esp-qa/coexist-cmd ~0.0.1` dependency that provides `register_cmd_extcoex()`.
* `sdkconfig.defaults`: console routed to USB Serial/JTAG (`CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y`).

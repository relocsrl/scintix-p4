# ESP32-C6 Wi-Fi co-processor firmware (Scintix P4)

> 🚀 **SCINTIX P4 is coming to Crowd Supply!** [**Follow our pre-launch page**](https://www.crowdsupply.com/reloc/scintix-p4) to be notified the moment the campaign goes live.
> 
The ESP32-P4 has no built-in Wi-Fi. On the Scintix P4, connectivity is provided by the on-board **ESP32-C6**, which acts as a radio co-processor for the P4 over SDIO ([`esp_hosted`](https://components.espressif.com/components/espressif/esp_hosted)). For this to work the C6 must run its own *network-adapter* (esp_hosted **slave**) firmware — this is **separate** from the ESP-IDF application you flash to the ESP32-P4.

> **Scintix P4 modules are shipped with this firmware already flashed on the C6, so in normal use you do _not_ need this procedure.** Use it only if you start from a blank C6, or want to restore or update the co-processor firmware.

This folder holds the prebuilt binaries. Every example in this repository that uses Wi-Fi relies on them being present on the C6: [`esp_brookesia_phone`](../examples/esp_brookesia_phone), [`esp_claw_agent`](../examples/esp_claw_agent), [`rm-cmp4_wifi_iperf`](../examples/rm-cmp4_wifi_iperf), [`rm-cmp4_wifi_iperf_u0`](../examples/rm-cmp4_wifi_iperf_u0).

Firmware build: `rm-cmp4_esp-slave-v000-c6-sdio4xEnp` (SDIO, 4-bit).

## What you need

* The **Espressif ESP-Prog 2** programmer —
  [ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html)
  (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html))
* `esptool` — bundled with ESP-IDF, or install standalone with `pip install esptool`.

## Which 6-pin header?

The Scintix P4 has **two** 6-pin programmer headers:

* one **next to the ESP32-P4** — used to flash and monitor the P4 application,
* one **next to the ESP32-C6** — used to flash the firmware in this folder.

Connect the ESP-Prog 2 (or ESP-Prog) to the header **next to the ESP32-C6**.

![Scintix P4 6-pin programmer headers — P4 header and C6 header](../images/SCINTIX-P4_programmer_headers.png?raw=true)

## Flash

With the ESP-Prog 2 connected to the **C6** header, identify its serial port (`COMx` on Windows, `/dev/ttyUSB0` on Linux/macOS) and run the following from this folder:

| File | Flash offset |
| ---- | ------------ |
| `bootloader.bin` | `0x0` |
| `partition-table.bin` | `0x8000` |
| `ota_data_initial.bin` | `0xd000` |
| `network_adapter.bin` | `0x10000` |

```
esptool --chip esp32c6 -p PORT -b 921600 --before default_reset --after hard_reset \
  write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m \
  0x0      bootloader.bin \
  0x8000   partition-table.bin \
  0xd000   ota_data_initial.bin \
  0x10000  network_adapter.bin
```

Replace `PORT` with the C6 programmer's serial port.

## Build it yourself

These binaries are a build of Espressif's esp_hosted **slave** firmware for the ESP32-C6. To build from source instead of using them, see [ESP-Hosted-MCU](https://github.com/espressif/esp-hosted-mcu) (the `slave/` project) and its [SDIO transport guide](https://github.com/espressif/esp-hosted-mcu/blob/main/docs/sdio.md) — this board uses SDIO in 4-bit mode.

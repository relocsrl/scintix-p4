# scintix-p4
**SCINTIX P4** is a compact compute module that brings real-time MCU performance into the Raspberry Pi CM4/CM5 carrier ecosystem. Every existing CM4/CM5 alternative on the market is built around an application processor running Linux; we took a different approach, fitting a real-time MCU into the same mechanical and electrical footprint — with the determinism, instant boot, and low power consumption MCU developers expect. To our knowledge, this makes SCINTIX P4 the first MCU-based compute module ever released in the CM4/CM5 form factor.

At its core is the **ESP32-P4**, Espressif's latest flagship MCU — a recently launched, fresh and powerful option for embedded developers. Dual-core RISC-V at 400 MHz with AI instruction extensions and a single-precision FPU, plus a dedicated low-power RISC-V core for always-on tasks. SCINTIX P4 pairs it with an ​**ESP32-C6​** companion for Wi-Fi 6, Bluetooth 5, and 802.15.4 (Zigbee / Thread / Matter), and adds an on-board Ethernet PHY, native MIPI-DSI and MIPI-CSI, 32 MB PSRAM, and 32 MB NOR flash.

![SCINTIX P4 board](images/SCINTIX-P4_carriers.png?raw=true)

Plugged into a CM4/CM5 carrier, SCINTIX P4 gives you immediate access to displays, cameras, Ethernet, USB, and all the peripherals the ESP32-P4 exposes — no custom hardware needed. Standalone, it runs powered and programmed over USB-C.

And when you are ready to move from prototype to product, the SoM comes with you. Because MCU, regulators, memory, wireless, and Ethernet are all on board, a custom carrier built around SCINTIX P4 can stay minimal — just the connectors and circuitry your application actually needs. Simpler design, easier certification, faster time to market.

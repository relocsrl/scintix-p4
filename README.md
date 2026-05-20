# SCINTIX P4
**SCINTIX P4** is a compact compute module that brings real-time MCU performance into the Raspberry Pi CM4/CM5 carrier ecosystem. Every existing CM4/CM5 alternative on the market is built around an application processor running Linux; we took a different approach, fitting a real-time MCU into the same mechanical and electrical footprint — with the determinism, instant boot, and low power consumption MCU developers expect. To our knowledge, this makes SCINTIX P4 the first MCU-based compute module ever released in the CM4/CM5 form factor.

At its core is the **ESP32-P4**, Espressif's latest flagship MCU — a recently launched, fresh and powerful option for embedded developers. Dual-core RISC-V at 400 MHz with AI instruction extensions and a single-precision FPU, plus a dedicated low-power RISC-V core for always-on tasks. SCINTIX P4 pairs it with an ​**ESP32-C6​** companion for Wi-Fi 6, Bluetooth 5, and 802.15.4 (Zigbee / Thread / Matter), and adds an on-board Ethernet PHY, native MIPI-DSI and MIPI-CSI, 32 MB PSRAM, and 32 MB NOR flash.

Board samples available — [contact us](mailto:info@reloc.it) for more information.

![SCINTIX P4 board](images/SCINTIX-P4_front_back.png?raw=true)

Plugged into a CM4/CM5 carrier, SCINTIX P4 gives you immediate access to displays, cameras, Ethernet, USB, and all the peripherals the ESP32-P4 exposes — no custom hardware needed. Standalone, it runs powered and programmed over USB-C.

And when you are ready to move from prototype to product, the SoM comes with you. Because MCU, regulators, memory, wireless, and Ethernet are all on board, a custom carrier built around SCINTIX P4 can stay minimal — just the connectors and circuitry your application actually needs. Simpler design, easier certification, faster time to market.

## Applications

SCINTIX P4 is designed for developers who need real-time MCU performance but don't want to redesign the hardware around their application. Typical use cases include rapid prototyping of IoT, robotics, and real-time embedded systems; display and camera-based HMI projects leveraging MIPI-DSI and MIPI-CSI; edge AI and sensor processing applications; and modular embedded systems that need the flexibility of a CM4/CM5 carrier with the deterministic behaviour of an MCU.

Unlike Linux-based compute modules, SCINTIX P4 runs bare-metal or RTOS firmware. This means instant boot, predictable latency, lower power consumption, and a simpler software stack — all the advantages of MCU-class development, combined with the rich peripheral set and ready-made carrier ecosystem of the Raspberry Pi compute module family.

![SCINTIX P4 mounted on different CM4/CM5 carriers](images/SCINTIX-P4_carriers.png?raw=true)

## Features & Specifications

- **SoC** – Espressif Systems ESP32-P4NRW32X
  - Dual-core RISC-V @ 400 MHz with AI instruction extensions and single-precision FPU
  - Single-core RISC-V LP (low-power) MCU @ up to 40 MHz
  - 2D Pixel Processing Accelerator (PPA)
  - H.264 and JPEG codecs support
  - 768 KB HP L2MEM, 32 KB LP SRAM, 8 KB TCM
  - 128 KB HP ROM, 16 KB LP ROM
- **Memory & Storage**
  - 32 MB PSRAM
  - 32 MB NOR flash
- **Display & Camera**
  - MIPI DSI (2-lane) via CMx connectors
  - MIPI CSI (2-lane) via CMx connectors
- **Networking**
  - On-board Ethernet (Microchip KSZ8091RNACA transceiver)
  - 2.4 GHz Wi-Fi 6, Bluetooth 5, and 802.15.4 (Zigbee / Thread / Matter) via ESP32-C6 companion (SDIO 4-lane + UART to ESP32-P4)
- **USB**
  - 1 × USB Type-C port for power and programming
  - USB 2.0 OTG (host) routed via CMx connectors
- **Expansion** – 40 × GPIO routed to CMx connectors
- **Power**
  - 5 V DC input via CMx connectors
  - 5 V DC input via on-board USB-C
- **Mechanical**
  - Dimensions: 55.0 × 40.0 × 5.0 mm (2.17 × 1.57 × 0.20 in); 8 mm (0.31 in) including 1.27 mm programming connectors
  - Weight: 8.2 g (0.29 oz)
  - Operating temperature: -20 to 70 °C (-4 to 158 °F)
  - Mounting: 2 × Hirose DF40C-100DP-0.4V(51) board-to-board connectors, compatible with Raspberry Pi CM4/CM5 carrier boards
- **Software**
  - Full compatibility with Espressif's ESP-IDF SDK
  - Arduino and PlatformIO support out of the box
  - Direct portability of Espressif's official demos, SDKs, and reference code

# Scintix P4 - ESP-Brookesia Phone Demo

> Target: **ESP32-P4 + ESP32-C6** · Tested on **ESP-IDF v5.5.4**
> 
> 🚀 **SCINTIX P4 is coming to Crowd Supply!** [**Follow our pre-launch page**](https://www.crowdsupply.com/reloc/scintix-p4) to be notified the moment the campaign goes live.
> 
This example, based on [ESP-Brookesia](https://github.com/espressif/esp-brookesia), demonstrates an Android-like phone interface with several built-in apps (launcher, calculator, camera with on-device AI detection, 2048, music player, settings, and an optional SD-card video player). It exercises the Scintix P4's **MIPI-DSI** display, **MIPI-CSI** camera, **I2S** audio and the **ESP32-C6** wireless co-processor at the same time, so it doubles as a stress test of the module's multimedia subsystem.

It is the most involved example in this repository: besides the wiring, it carries deliberate **adaptations for the Scintix P4 hardware and memory layout** (see [Adaptations](#adaptations-for-the-scintix-p4)). Read that section before reporting a crash — most boot/Camera-app failures on this board trace back to the heap configuration documented there.

## Target hardware

This example runs on the **Scintix P4** module (ESP32-P4 + ESP32-C6) mounted on a **Waveshare CM4-to-Pi4 adapter**, which carries the display and camera. It is **not** the reference ESP32-P4-Function-EV-Board, so the wiring differs accordingly (see below).

- **MCU**: ESP32-P4 rev. v3.1 (32 MB hex PSRAM @ 250 MHz, 32 MB flash).
- **Wireless co-processor**: ESP32-C6 connected over SDIO (4-bit, 40 MHz) via `esp_hosted` 2.12.
- **Carrier**: Waveshare CM4-to-Pi4 adapter, hosting the display and camera FPCs.
- **Display**: 7" 1024×600 MIPI-DSI panel driven by the EK79007 IC ([display driver datasheet](https://docs.espressif.com/projects/esp-dev-kits/en/latest/_static/esp32-p4-function-ev-board/camera_display_datasheet/display_driver_chip_EK79007AD_datasheet.pdf)), with its 32-pin FPC adapter board.
- **Camera**: MIPI-CSI module based on the SC2336 sensor (1280×720), with its 32-pin FPC adapter board.
- **Touch**: GT911 capacitive controller over I2C.

## Connections

Power and the two display control signals (backlight and reset) are taken from the Waveshare adapter's **40-pin GPIO header**; the display and camera data travel over the dedicated MIPI **FPC** connectors. On the reference ESP32-P4-Function-EV-Board these signals used `GPIO26`/`GPIO27` on the screen adapter board — on this carrier they map as follows:

| Signal          | Display adapter board | Scintix P4 (ESP32-P4) | Waveshare 40-pin header | Notes |
| --------------- | --------------------- | --------------------- | ----------------------- | ----- |
| Backlight / PWM | PWM                   | GPIO3                 | GPIO27                  | Display brightness control |
| LCD reset       | LCD_RST               | GPIO4                 | GPIO22                  |       |
| 5V              | 5V                    | —                     | 5V                      | From the 40-pin header |
| GND             | GND                   | —                     | GND                     | From the 40-pin header |

The **GT911 touch** controller shares the panel's I2C bus and is carried on the display FPC, so it needs no separate wiring on this carrier.

### FPC connections (display and camera)

- Connect the **display** FPC to the Waveshare **display** connector and the **camera** FPC to the **camera** connector.
- The FPCs are keyed and only fit one way: the side **without** contacts carries a **blue plastic stiffener**, and the mating connectors expose contacts on one side only. Insert each cable with the blue stripe facing the contactless side of the connector.

Power the board via the carrier (or the on-board USB-C). **Flash and view the serial console via the [Espressif ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html) (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html)) on the 6-pin header next to the ESP32-P4** (the board has a second 6-pin header next to the ESP32-C6, for the Wi-Fi firmware — see [which header is which](../../esp32c6_wifi_firmware/README.md#which-6-pin-header)). On the Waveshare carrier the USB-C is **power-only**; to use the module's native USB-C for flashing you'd have to detach the Scintix from the carrier first.

## ESP-IDF version

This example targets **ESP-IDF v5.5.x** (tested on v5.5.4). Follow the [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32p4/get-started/index.html) to set up the environment, and make sure you can [build your first project](https://docs.espressif.com/projects/esp-idf/en/latest/esp32p4/get-started/index.html#build-your-first-project) first.

## Configuration

### Optional: SD card and the Video Player app

To use an SD card and enable the **Video Player** app, run `idf.py menuconfig` and select *Example Configurations* → *Enable SD Card*.

Only **MJPEG** videos are supported. Place MJPEG files on the SD card; after insertion the Video Player app appears automatically. Convert a video with `ffmpeg`:

```
ffmpeg -i INPUT.mp4 -vcodec mjpeg -q:v 2 -vf "scale=1024:600" -acodec copy OUTPUT.mjpeg
```

## ESP32-C6 Wi-Fi firmware (usually pre-flashed)

Wi-Fi on the Scintix P4 is provided by the on-board **ESP32-C6**, which runs the esp_hosted *slave* firmware — separate from the Brookesia application you flash to the P4. **Scintix P4 modules ship with it pre-flashed, so you normally don't need to touch it.** If you start from a blank C6 (or want to restore/update it), the binaries and full flashing instructions are in [`esp32c6_wifi_firmware/`](../../esp32c6_wifi_firmware) — flash them with the [Espressif ESP-Prog 2](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog-2/index.html) (or the older [ESP-Prog](https://docs.espressif.com/projects/esp-dev-kits/en/latest/other/esp-prog/index.html)) on the 6-pin header **next to the ESP32-C6**.

## Build, flash and monitor

```
idf.py set-target esp32p4
idf.py -p PORT flash monitor
```

To exit the monitor, press `Ctrl-]`.

> If you change the heap paradigm described below, run `idf.py fullclean` before rebuilding — the linker layout and BSS section attributes are regenerated.

## Adaptations for the Scintix P4

The differences below are required for this hardware and to fix a runtime crash in the Camera app that affects all setups using current `esp-dl 3.1.0` together with `esp_hosted 2.12.x`.

### Heap configuration (critical)

The default `idf.py menuconfig` for a fresh P4 + esp_hosted 2.12 project sets `CONFIG_SPIRAM_USE_CAPS_ALLOC=y`. With that option, the standard C/C++ `malloc()`/`new` allocates **only from internal SRAM**; PSRAM is reachable only through explicit `heap_caps_malloc(..., MALLOC_CAP_SPIRAM)`. The new `esp_hosted` SDIO/RPC stack and the `esp-dl` C++ runtime (vectors of strings produced by `FbsModel::topological_sort`, per-tensor metadata, etc.) easily exceed the ~340 KiB of internal SRAM available after BSS/IRAM is loaded, producing `std::bad_alloc` when the Camera app builds the AI models.

This project must therefore use the alternative paradigm in `sdkconfig`:

```
# CONFIG_SPIRAM_USE_CAPS_ALLOC is not set
CONFIG_SPIRAM_USE_MALLOC=y
CONFIG_SPIRAM_MALLOC_ALWAYSINTERNAL=2048
CONFIG_SPIRAM_MALLOC_RESERVE_INTERNAL=32768
CONFIG_SPIRAM_ALLOW_BSS_SEG_EXTERNAL_MEMORY=y
```

With these settings `malloc()`/`new` transparently fall back to PSRAM for any request larger than 2 KiB, while keeping 32 KiB of internal RAM reserved for IRQ/DMA-safe allocations. The C++ STL overhead of `esp-dl` ends up in PSRAM and the crash disappears.

### Camera app: mutually-exclusive AI model loading

`Camera::run()` no longer eagerly instantiates both `PedestrianDetect` and `HumanFaceDetect`. The two detectors are loaded lazily by `camera_dectect_task` based on the active event-group bit (`CAMERA_EVENT_PED_DETECT` / `CAMERA_EVENT_HUMAN_DETECT`), and the inactive one is freed before the new one is loaded. This is required because `HumanFaceDetect` itself instantiates two sub-models (MSR + MNP) that must coexist; keeping the pedestrian model alive in parallel would cumulatively exhaust internal heap regardless of the heap mode above.

Implementation details:

- The switch between detectors happens in `ensure_detect_mode()` inside [components/apps/camera/Camera.cpp](components/apps/camera/Camera.cpp), invoked at the top of the detect-task loop.
- The mode-switch button only toggles the event-group bits — model load/unload runs on the detect task, which is pinned to core 1 and is allowed to block briefly (~1 s) without affecting LVGL or the video stream.

### `HEAP_DUMP` diagnostic macro

[Camera.cpp](components/apps/camera/Camera.cpp) defines a `HEAP_DUMP(stage)` macro that logs `INTERNAL` / `DMA` / `SPIRAM` free and largest-block sizes. It is called around each model load/unload and at camera entry, so memory pressure is visible at runtime in the serial log. Healthy values on this board after the changes above are roughly:

- `camera run() entry`: INTERNAL free ≈ 100 KiB, largest ≈ 40–50 KiB
- after `pedestrian` load: INTERNAL free ≈ 60 KiB
- after `humanface` (MSR+MNP) load: INTERNAL free ≈ 40–60 KiB
- PSRAM free: several MiB throughout

If you ever see INTERNAL `largest` drop near or below the size of a model's metadata block (~22 KiB), the heap has fragmented; the lazy-load logic should still recover by freeing the other detector.

### Known constraints

- The pedestrian (`Pico`) model consumes ~38 KiB of internal RAM and ~552 KiB of PSRAM for working tensors.
- Face detection requires both `MSR` and `MNP` to be resident in PSRAM during inference (they are chained in `MSRMNP::run`), so its peak footprint is higher than pedestrian's.
- Loading a model on a long-running session may fail due to internal-heap fragmentation rather than total size. The `HEAP_DUMP` traces above help distinguish the two failure modes.

### Board BSP — audio codec disabled (vendored component)

The upstream `espressif/esp32_p4_function_ev_board_noglib` BSP calls `assert(es8311_dev)` in `bsp_audio_codec_speaker_init()`. The Scintix P4 + Waveshare carrier has **no ES8311 codec**, so that assert aborts at boot and the screen stays black. To fix this, the BSP is **vendored** (a local, committed copy) with the audio-codec init disabled — it returns `NULL` gracefully instead of asserting.

- Local copy: [`../common_components/esp32_p4_function_ev_board_noglib`](../common_components/esp32_p4_function_ev_board_noglib)
- It is selected via `override_path` in [`../common_components/bsp_extra/idf_component.yml`](../common_components/bsp_extra/idf_component.yml), so the registry version is **not** downloaded.

> Because it's vendored, this BSP no longer auto-updates. To pull a newer upstream BSP, re-copy it and re-apply the audio change.

### Partition table

The example uses a 9 MB `factory` app partition and a 4 MB `storage` SPIFFS partition (see [partitions.csv](partitions.csv)) to hold the firmware, the bundled AI models and the SPIFFS assets (music, game sounds).

## Example output

On a successful boot you should see the launcher appear on the display, and a log similar to the (indicative) excerpt below — note the 32 MB PSRAM detection and the `esp_hosted` start that brings up the ESP32-C6 link:

```
I hex_psram: vendor id    : 0x0d (AP)
I hex_psram: density      : 0x07 (256 Mbit)
I esp_psram: Found 32MB PSRAM device
I esp_psram: Speed: 200MHz
I mmu_psram: .rodata xip on psram
I mmu_psram: .text xip on psram
I esp_psram: Adding pool of 22272K of PSRAM memory to heap allocator
I host_init: ESP Hosted : Host chip_ip[18]
I H_API: ESP-Hosted starting. Hosted_Tasks: prio:23, stack: 5120 RPC_task_stack: 5120
...
```

## Technical support and feedback

For questions about the Scintix P4 or this example, [contact Reloc](mailto:info@reloc.it). For the upstream framework, see the [ESP-Brookesia](https://github.com/espressif/esp-brookesia) repository.

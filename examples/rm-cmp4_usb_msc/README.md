# Scintix P4 — USB Mass Storage (host)

> Target: **ESP32-P4** · Tested on **ESP-IDF v6.0.1**

This example turns the Scintix P4 into a **USB host** and demonstrates the MSC (Mass Storage Class) driver against a USB flash drive. The ESP32-P4 USB 2.0 OTG controller is routed to the host port of the CM4/CM5 carrier, so a stock CM4 carrier board (or its USB hub) can be used directly.

On connection, the drive is mounted to the virtual filesystem and the example:

1. Prints the device descriptor and info (capacity, sector size and count, VID/PID…).
2. Lists all folders and files in the root directory.
3. Creates an `esp` subdirectory (if missing) and a `test.txt` file.
4. Runs read/write benchmarks by transferring 1 MB to a `dummy` file.

It is based on the Espressif [USB Host MSC](https://github.com/espressif/esp-idf/tree/release/v6.0/examples/peripherals/usb/host/msc) example, with small task-priority adjustments for hubbed carriers (see *Differences* below).

> **Note:** Only FAT-formatted drives are supported. exFAT/NTFS will not mount.

## Hardware required

* A Scintix P4 module on a CM4/CM5 carrier board with a USB host port. *Tested on the Raspberry Pi CM4 IO board.*
* A USB flash drive (FAT-formatted).
* A USB cable for power and programming.

## Console output

> **Use the UART0 6-pin programmer connector on the Scintix P4 for the debug trace.** The USB-to-serial interface exposed by the carrier board is **not** available while the USB Host driver is active, because the USB controller is busy driving the flash drive.

### USB reconnections

The example runs in a loop to demonstrate connect/reconnect handling. Short **GPIO0** to GND (usually the BOOT button) to deinitialize the whole USB Host stack.

## USB host limitations

### ESP32-P4
The ESP32-P4 USB 2.0 OTG controller supports **up to 16 bidirectional endpoints** in host mode. Since each MSC device typically needs **3 endpoints** (Control, BULK IN, BULK OUT) and a hub also consumes endpoints, the theoretical maximum is **4 connected MSC devices**.

For reference, ESP32-S2/S3 support only 8 endpoints (max 2 devices).

### Number of simultaneous devices
The number of simultaneously mounted MSC devices is determined by `CONFIG_FATFS_VOLUME_COUNT` (default **2**). Increase it via `idf.py menuconfig` → *Component config* → *FAT Filesystem support* → *Number of FATFS volumes*, keeping endpoint and memory constraints in mind.

## Build, flash and monitor

```
idf.py set-target esp32p4
idf.py -p PORT flash monitor
```

To exit the monitor, press `Ctrl-]`.

## Example output

```
I (323) example: Waiting for USB flash drive to be connected
I (3353) example: MSC device connected (usb_addr=3)
*** Device descriptor ***
bLength 18
bDescriptorType 1
bcdUSB 2.00
...
Device info:
         Capacity: 3839 MB
         Sector size: 512
         Sector count: 7864319
         PID: 0x1234
         VID: 0xABCD
         iProduct: UDisk
         iManufacturer: General
I (3763) example: Listing contents of /usb0
/usb0/SYSTEM~1
/usb0/ESP
I (3773) example: Read from file '/usb0/esp/test.txt': 'Hello World!'
I (3943) example: Write speed 7.16 MiB/s
I (4093) example: Read speed 7.16 MiB/s
I (4103) example: Example finished, you can disconnect the USB flash drive (or connect another USB flash drive)
```

## Differences from the upstream Espressif example

* `main/msc_example_main.c`: task priorities adjusted for hubbed CM4 carriers — `usb_task` raised from **2 → 5** and the MSC background task lowered from **5 → 4**. When a USB hub is present (as on the Raspberry Pi CM4 IO carrier board), the host event task must out-prioritize the MSC background task, otherwise downstream hub ports can fail enumeration during the port reset / chirp-detection phase.

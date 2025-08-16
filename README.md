# LCD\_CTRL

## Overview

`LCD_CTRL` is a Verilog module that controls image operations on an **8x8 grayscale image**.
It loads data from **IROM (Input ROM)**, applies image transformations (shift, rotate, mirror, max/min/average), and writes the processed result into **IRAM (Output RAM)**.

The module is controlled through a **command interface** and managed by a **finite state machine (FSM)**.

---

## Features

* **Image Size:** 8x8 pixels (64 entries, 8-bit grayscale each).
* **Supported Commands:**

  * `0000` : Write image to IRAM
  * `0001` : Shift Up
  * `0010` : Shift Down
  * `0011` : Shift Left
  * `0100` : Shift Right
  * `0101` : Maximum filter (2x2 block)
  * `0110` : Minimum filter (2x2 block)
  * `0111` : Average filter (2x2 block)
  * `1000` : Rotate Counter-Clockwise
  * `1001` : Rotate Clockwise
  * `1010` : Mirror along X-axis
  * `1011` : Mirror along Y-axis

---

## Port Description

| Signal          | Direction | Width | Description                                              |
| --------------- | --------- | ----- | -------------------------------------------------------- |
| **clk**         | Input     | 1     | System clock                                             |
| **reset**       | Input     | 1     | Asynchronous reset                                       |
| **cmd**         | Input     | 4     | Operation command                                        |
| **cmd\_valid**  | Input     | 1     | Indicates a valid command                                |
| **IROM\_Q**     | Input     | 8     | Data read from IROM                                      |
| **IROM\_rd**    | Output    | 1     | Read enable for IROM                                     |
| **IROM\_A**     | Output    | 6     | Address for IROM                                         |
| **IRAM\_valid** | Output    | 1     | Write enable for IRAM                                    |
| **IRAM\_D**     | Output    | 8     | Data written to IRAM                                     |
| **IRAM\_A**     | Output    | 6     | Address for IRAM                                         |
| **busy**        | Output    | 1     | High when the module is busy (read, calculate, or write) |
| **done**        | Output    | 1     | High when the entire image has been written to IRAM      |

---

## FSM States

| State     | Encoding | Description                                                     |
| --------- | -------- | --------------------------------------------------------------- |
| **READ**  | `2'd0`   | Sequentially read 64 pixels from IROM into buffer `image_data`. |
| **IDLE**  | `2'd1`   | Wait for valid command input.                                   |
| **CALC**  | `2'd2`   | Apply the operation (shift, rotate, mirror, max, min, avg).     |
| **WRITE** | `2'd3`   | Sequentially write processed image to IRAM.                     |

---

## Internal Design

* **Image Buffer:** `reg [7:0] image_data [63:0]`
  Stores the 8x8 image for processing.

* **Operation Point:**

  * `op_x`, `op_y` define the 2x2 block for operations.
  * Computed addresses: `addr_tl`, `addr_tr`, `addr_bl`, `addr_br`.

* **Busy/Done Handling:**

  * `busy = 1` during READ, CALC, WRITE phases.
  * `done = 1` once the last pixel is written to IRAM.

* **Optimizations (in improved version):**

  * **Shift operations** use left-shift (`<< 3`) instead of multiplication.
  * Cleaner **control logic** (IROM\_rd / IRAM\_valid / busy combined into one always block).
  * Simplified **arithmetic for max/min/avg**.

---

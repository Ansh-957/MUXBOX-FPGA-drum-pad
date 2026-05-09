# MUXBOX

A fully functional electronic drum pad and beat recorder built on a DE1-SoC FPGA in Verilog. 

> Custom 3D-Printed Hardware. Verilog RTL. Real-Time Audio Processing.

---

## Demo

[![MUXBOX Hardware Demo](https://github.com/user-attachments/assets/b4b7ccd6-2f27-4a57-bd26-1c2ecc1986fb)](https://youtube.com/shorts/_zl3c4PfeDY?feature=share)


---

## Repository Structure
* `/src` : Core Verilog source files for audio processing, memory management, and I/O.
* `/docs` : System block diagrams, FSM state charts, and the final project presentation.

---

## Overview

MUXBOX bridges physical mechanical design with low-level RTL. The system processes inputs from a custom 3D-printed drum pad interface, mixes audio signals in real time, and drives a DE1-SoC Audio CODEC. It features a fully integrated metronome, quadrature-decoded volume control, and a 16-second live beat recording system.

<img width="986" height="994" alt="image" src="https://github.com/user-attachments/assets/f67b2240-10bc-45c7-9a13-af0bc118b3a2" />



---

## Technical Highlights

**Memory Optimization:** Overcame the DE1-SoC's 397 M10K block limit by compressing audio data. Converted 12 drum samples from 32-bit stereo to 16-bit mono .mif files, allowing all ROM sounds to load without memory loss.

**State Machine & Beat Recording:** Engineered a 4-state Event Recorder FSM (IDLE, RECORDING, PLAYING, WAIT). The system logs pad strikes into a buffer using 30-bit timestamps and 12-bit pad state arrays, enabling precise 16-second beat capture, playback, and overwrite capabilities.

**Signal Integrity & Debouncing:** Implemented a 3-stage synchronizer using flip-flops synced to a 50MHz clock to filter mechanical bounce from the physical pushbuttons and ensure stable input logic.

**Rotary Encoder & I/O:** Designed a quadrature decoder for the volume knob, tracking clock and data (DT) phase shifts to determine rotational direction and update 31 distinct volume levels in real-time on the 7-segment display. 

**Metronome Generation:** Built a custom beat timing generator driven by the 50MHz clock, creating a 120 BPM square wave with an accented, higher-frequency first beat for accurate timing.

---

## Hardware Integration
<img width="1248" height="600" alt="image" src="https://github.com/user-attachments/assets/41831cb8-17dc-491e-8bb0-55a2ac582a2a" />

* **DE1-SoC FPGA** programmed entirely in Verilog HDL.
* **Custom Enclosure:** Designed in Fusion 360 and 3D printed to house the breadboard and tactile drum pads.
* **Breadboard Circuit:** Handles power distribution and routes the 12 sound pads, 5 action buttons, and rotary encoder to the FPGA via GPIO header pins.

---

## Authors

Ansh Shah · Eshaan Marocha

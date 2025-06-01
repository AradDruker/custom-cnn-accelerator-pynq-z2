# Custom CNN/DPU Accelerator on PYNQ‑Z2

> **B.Sc. Final Project  
> Arad Druker · Yonatan Glav**

Real‑time handwritten‑equation recognition and plotting, powered by a fully‑custom **FPGA Deep‑Learning Processing Unit (DPU)** implemented in VHDL and deployed on the **Xilinx PYNQ‑Z2** board.  
The project covers the full stack:

* Quantised LeNet‑5 CNN (int8)
* Synthesised accelerator IP with DMA, dual‑port BRAM and parallel compute blocks
* Flask‑based web front‑end that lets users draw an equation and instantly see the rendered plot
* Automated Python tool‑chain for model export, parameter packing and driver control

The system achieves **sub‑second end‑to‑end latency** and exceeds its accuracy target for both glyph‑level and string‑level recognition.

---

## 1 · Project Highlights

| Area | Completed Work |
|------|----------------|
| **Hardware** | • Two‑conv / two‑pool / two‑FC DPU written in VHDL<br>• 30× parallel MACs in first conv layer, 16×/30× MACs in FC layers<br>• AXI‑DMA streaming, dual‑port BRAM buffers, per‑layer FSM scheduling |
| **Software** | • PyTorch Quantisation‑Aware‑Training pipeline → int8 checkpoint<br>• Auto‑export of weights/bias/scales to JSON, split into 8‑bit chunks for BRAM load |
| **Web App** | • HTML5 Canvas + vanilla JS UI<br>• Flask server: OpenCV segmentation → FPGA OCR → SymPy/Matplotlib plot |
| **Testing** | • 10 k‑image synthetic workload for timing; multiple random batches for stability<br>• Continuous regression notebook; on‑board PYNQ comparisons to PyTorch reference |
| **Results** | • End‑to‑end “draw → plot” well **< 1 s** on Gigabit LAN<br>• Glyph and string accuracies above project specification |

---

## 2 · CNN Architecture Overview

![CNN flow](https://github.com/user-attachments/assets/8cc60e27-522d-4c58-bf37-56114e89f287)

| Layer | Feature Map | Size | Kernel Size | Padding | Stride | Activation |
|-------|-------------|------|-------------|---------|--------|------------|
| Input | Image | 1 | 28×28 | 2×2 | – | – |
| Convolution | 6 | 32×32 | 5×5 | – | 1 | ReLU |
| Max Pooling | 6 | 14×14 | 2×2 | – | 2 | – |
| Convolution | 16 | 10×10 | 5×5 | – | 1 | ReLU |
| Max Pooling | 16 | 5×5 | 2×2 | – | 2 | – |
| FC | – | 64 | – | – | 1 | ReLU |
| Output FC | – | 30 | – | – | – | – |

_All parameters are quantised to int8 and packed into on‑chip BRAM._

---

## 3 · Resource‑Utilisation Snapshot (post‑route)

| Resource | Used | Z‑020 Total | Util. % |
|----------|-----:|------------:|--------:|
| LUTs | 48 673 | 85 000 | 57 % |
| FFs  | 56 321 | 106 400 | 53 % |
| BRAM |  68 / 140 blocks | 4.9 Mb | 49 % |
| DSP  | 137 / 220 | — | 62 % |

---

## 4 · Performance vs CPU Baseline

| Platform | Avg. Inference / glyph | Speed‑up |
|----------|-----------------------:|---------:|
| PyTorch @ i7‑1185G7 | **23.4 ms** |
| PYNQ‑Z2 DPU (FPGA) | **0.74 ms** | **× 32** |

Dataset: 10 000 random MNIST‑style glyphs, Ethernet transfer + DMA included in FPGA timing.

---

## 5 · Key Lessons

* **Int8 quantisation** cut DSP usage by >30 % with negligible accuracy drop.  
* Careful **clock‑rate / parallelism trade‑offs** (lower Fclk but more MAC duplicates) gave the best throughput per LUT.  
* A thin **HTTP layer** around PYNQ made integration with the browser trivial and kept round‑trip latency low.

---

## 6 · Acknowledgements

Thanks to the EE department labs for hardware access and to Xilinx for the PYNQ platform.  
Special gratitude to Dr. Joel Ratsaby for guidance.

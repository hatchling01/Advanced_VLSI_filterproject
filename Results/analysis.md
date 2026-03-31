# FIR Filter Architecture Overview

## 1. Introduction

This document summarizes the **four implemented FIR filter architectures** used in the project:

1. **Serial FIR**
2. **L=2 reduced-complexity parallel FIR**
3. **L=3 reduced-complexity parallel FIR**
4. **Pipelined + L=3 FIR**

All four architectures implement the same 100-tap low-pass FIR filter:

\[
y[n] = \sum_{k=0}^{N-1} h[k]\,x[n-k], \qquad N = 100
\]

The four versions differ in how the convolution is scheduled across time and hardware.

The project workflow follows:
- MATLAB filter design
- Quantization to fixed-point (Q1.15)
- Hardware implementation in SystemVerilog
- FPGA synthesis and analysis in Vivado

---

## 2. Quantization and Coefficient Storage

### 2.1 Quantization format

- **16-bit signed fixed-point**
- **Q1.15 format**
- round-to-nearest with saturation

\[
h_q[k] = \text{round}(h[k]\cdot 2^{15})
\]

### 2.2 ROM implementation

- Implemented as **synchronous ROM**
- **1-cycle latency**

### 2.3 ROM usage

| Architecture | ROM Location |
|------------|-------------|
| Serial | External (top module) |
| L2 | Internal |
| L3 | Internal |
| Pipelined L3 | Internal |

---

## 3. Serial Architecture

### Key Metrics

- Cycles/output: **102**
- DSPs: **1**
- Lowest power and area
- Highest latency

### Discussion

The serial architecture acts as the baseline reference. It minimizes hardware by reusing a single MAC unit across all taps, resulting in extremely low resource usage and power consumption. However, this comes at the cost of throughput, since each output requires a full traversal of all 100 taps.

Interestingly, the serial design shows the **best timing slack**, because only one multiplication and addition occur per cycle. This means it is **not timing-limited but throughput-limited**, making it ideal for low-resource or low-rate applications but unsuitable for high-performance systems.

---

## 4. L=2 Parallel Architecture

### Key Metrics

- Cycles/output: **26**
- DSPs: **3**
- Moderate area increase
- ~4× throughput improvement over serial

### Discussion

The L=2 architecture introduces parallelism while keeping hardware growth controlled through reduced-complexity decomposition. Instead of naïvely doubling hardware, it uses algebraic restructuring to compute outputs efficiently.

Compared to the serial version:
- Throughput improves significantly
- Resource usage increases moderately
- Timing slack decreases slightly but remains safe

This makes L=2 a **well-balanced design**, offering a strong tradeoff between area and performance.

---

## 5. L=3 Parallel Architecture

### Key Metrics

- Cycles/output: **12**
- DSPs: **6**
- High throughput
- Increased resource usage

### Discussion

The L=3 architecture pushes parallelism further and achieves the **lowest cycles per output** among non-pipelined designs. The reduced-complexity approach avoids the full 9-subfilter cost, using only 6 paths instead.

However, this improvement introduces:
- Higher DSP and LUT usage
- More complex control logic
- Slightly tighter timing

Despite this, the design still meets timing constraints and provides a major throughput gain, making it highly efficient in terms of cycles per output.

---

## 6. Pipelined L=3 Architecture

### Key Metrics

- Cycles/output: **slightly > 12**
- DSPs: **6**
- Improved timing
- Slight latency increase

### Discussion

The pipelined L=3 architecture improves upon L=3 by **breaking the critical path** using additional registers. Unlike earlier architectures, the goal here is not reducing cycles, but improving **clock frequency capability**.

Key observations:
- Timing slack improves compared to L=3
- Area increases slightly due to registers
- Power remains similar
- Cycles/output slightly worsens

This highlights an important concept:  
👉 **Throughput = (cycles/output) × (clock frequency)**

Even though cycles/output is slightly worse, the higher achievable clock rate makes this the **best real-world high-performance design**.

---

## 7. Top Modules and Testbenches

### Top Modules

- `top_fir_filter_serial.sv`
- `top_fir_filter_L2.sv`
- `top_fir_filter_L3.sv`
- `top_fir_filter_pipelined_L3.sv`

### Testbenches

- Updated to instantiate **top modules**
- Use:
  - `ready` handshake
  - `data_out_valid`
  - proper wait loops
- Long simulation time required due to MAC iteration

---

## 8. Comparison Summary

| Architecture | Cycles/Output | DSPs | Area | Timing | Throughput |
|-------------|--------------|------|------|--------|-----------|
| Serial | 102 | 1 | Lowest | Best | Lowest |
| L2 | 26 | 3 | Moderate | Good | Medium |
| L3 | 12 | 6 | High | Tight | High |
| Pipelined L3 | ~13 | 6 | Slightly higher | Best among parallel | Highest |

### Discussion

The progression across architectures clearly shows the tradeoffs:

- **Serial → minimal hardware, poor speed**
- **L2 → balanced**
- **L3 → high efficiency in cycles**
- **Pipelined L3 → best practical performance**

This demonstrates how combining:
- parallelism (L2, L3)
- algebraic optimization (reduced complexity)
- pipelining

leads to progressively better implementations.

---

## 9. Results File

All synthesis and implementation results (timing, utilization, power, and schematics) are compiled in a **separate results file**, which includes:

- Timing reports (WNS, WHS)
- Resource utilization (LUTs, FFs, DSPs)
- Power estimates
- Implementation views

---

## 10. Final Note

This project demonstrates how FIR filters can be optimized in hardware through:

- **time-multiplexing (serial)**
- **parallel processing (L2, L3)**
- **pipelining (pipelined L3)**

The key takeaway is that **no single design is universally best** — the optimal choice depends on system requirements such as:

- area constraints
- power budget
- required throughput

Among all implementations, the **pipelined L3 architecture provides the best overall performance** for high-speed FPGA applications.
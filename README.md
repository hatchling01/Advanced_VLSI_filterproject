# FIR Filter Architecture Overview

## 1. Introduction

This document describes the complete **assignment-based flow** and the **four implemented FIR filter architectures** used in the project.

The work starts from **MATLAB**, where the 100-tap low-pass FIR filter is designed and analyzed, then proceeds through **coefficient quantization**, **SystemVerilog RTL implementation**, **simulation**, and **Vivado synthesis/implementation**.

The four implemented architectures are:

1. **Serial FIR**
2. **L=2 reduced-complexity parallel FIR**
3. **L=3 reduced-complexity parallel FIR**
4. **Pipelined + L=3 FIR**

All four architectures implement the same 100-tap low-pass FIR filter:

\[
y[n] = \sum_{k=0}^{N-1} h[k] \cdot x[n-k], \qquad N = 100
\]

They differ in **how the computation is scheduled across time and hardware**, trading off between resource usage, latency, cycles per output, and achievable throughput.

The coefficients are quantized to **16-bit signed fixed-point Q1.15 format** and stored in a SystemVerilog coefficient ROM generated from MATLAB-designed taps.

---

## 2. Assignment Flow: From MATLAB to FPGA

This assignment was completed using the following flow:

1. **MATLAB filter design**
   - Design the 100-tap low-pass FIR filter using the required passband, stopband, and attenuation specifications.
   - Verify the floating-point response in MATLAB.
   - Plot both the original floating-point and quantized responses.

2. **Coefficient export and quantization**
   - Export the MATLAB coefficients to CSV.
   - Quantize the coefficients into 16-bit fixed-point Q1.15 format using Python.
   - Generate the SystemVerilog ROM file `coeff_rom.sv`.

3. **RTL implementation**
   - Implement the four FIR architectures in SystemVerilog.

4. **Top-module integration**
   - Wrap each architecture in a synthesis-ready top module.

5. **Simulation and verification**
   - Use architecture-specific testbenches to verify impulse, zero, step, and signed-input behavior.

6. **Vivado synthesis / implementation**
   - Synthesize the designs, add timing constraints, and collect timing, utilization, and power information.

7. **Results collection**
   - Consolidate the measured outputs into a separate results file for easy comparison across architectures.

---

## 3. MATLAB Design Stage

The assignment begins with the **MATLAB FIR design**.

The low-pass FIR filter was designed using the given specifications:

- **100 taps**
- **passband edge = 0.2π rad/sample**
- **stopband edge = 0.23π rad/sample**
- **stopband attenuation = 80 dB**

The MATLAB flow performs the following tasks:

- designs the original floating-point FIR filter,
- extracts the filter coefficients,
- exports the coefficients to CSV,
- plots the original frequency response,
- applies Q1.15 quantization,
- and plots the quantized response overlaid with the original response.

This provides the software-level reference before hardware implementation.

---

## 4. Quantization and Coefficient Storage

### 4.1 Quantization format

The coefficients are quantized using:

- **16-bit signed fixed-point**
- **Q1.15 format**
- **round-to-nearest**
- **saturation**
- **two's-complement storage**

This means each coefficient is represented as:

- 1 sign bit
- 15 fractional bits

So the stored integer value is approximately:

\[
h_q[k] = \text{round}(h[k]\cdot 2^{15})
\]

and the hardware interprets the coefficients as Q1.15 values.

### 4.2 Coefficient ROM implementation

The quantized coefficients are embedded directly into `coeff_rom.sv` using an `initial` block. The ROM is implemented as a **synchronous registered-read ROM**, so there is a **1-cycle coefficient read latency**.

This 1-cycle ROM latency is explicitly accounted for in all implemented architectures.

### 4.3 ROM usage across the designs

The four architectures do **not** all use the ROM in exactly the same way:

- **Serial FIR**: the coefficient ROM is instantiated externally in `top_fir_filter_serial.sv`
- **L=2 FIR**: ROM instances are inside `fir_filter_L2.sv`
- **L=3 FIR**: ROM instances are inside `fir_filter_L3.sv`
- **Pipelined L=3 FIR**: coefficient handling is inside `fir_filter_pipelined_L3.sv`

Accordingly, the top-module structures are different across the designs.

---

## 5. Serial Architecture (`fir_filter_serial.sv`)

### 5.1 Concept

The serial architecture is the baseline implementation. It uses:

- one multiplier,
- one accumulator,
- one delay line containing the previous 100 samples,
- one coefficient read per cycle.

Only **one tap product** is processed per clock cycle.

### 5.2 Structure

At the top level, the serial implementation is split into:

- `top_fir_filter_serial.sv`
- `fir_filter_serial.sv`
- `coeff_rom.sv`

The top module connects the FIR core to the external coefficient ROM.

### 5.3 Operation

The serial filter uses a simple FSM:

- **S_IDLE**  
  Wait for `data_valid`. On assertion, shifts the new sample into the delay line, clears the accumulator, and starts the MAC counter.

- **S_MAC**  
  The tap counter steps through the coefficient addresses. Because the ROM is synchronous, the delay sample and coefficient are aligned through a pipeline register, and valid accumulation starts one cycle after the first ROM address is issued.

- **S_DONE**  
  The accumulated result is scaled back to Q1.15 by selecting the appropriate accumulator bits and asserting `data_out_valid`.

### 5.4 Timing

For `NUM_TAPS = 100`:

- one new sample accepted per block
- one output sample produced per block
- total latency = **100 MAC cycles + ROM/finish overhead**
- implemented design latency = **102 cycles per output**

### 5.5 Resource trend

This architecture uses the fewest arithmetic resources, but also has the lowest throughput.

---

## 6. L=2 Reduced-Complexity Parallel Architecture (`fir_filter_L2.sv`)

### 6.1 Concept

In the L=2 architecture, the filter accepts **two input samples per block** and produces **two output samples per block**.

Instead of computing all four naive polyphase subfilter products, the design uses a reduced-complexity formulation that requires only **three subfilter convolutions**.

### 6.2 Polyphase form

The filter is decomposed as:

\[
H(z)=H_0(z^2)+z^{-1}H_1(z^2)
\]

where:

- \(H_0\): even-indexed coefficients
- \(H_1\): odd-indexed coefficients

The input sequence is split into two streams:

- \(x_0[k]=x[2k]\)
- \(x_1[k]=x[2k+1]\)

### 6.3 Reduced-complexity computation

The implemented L=2 design computes:

- \(F_0 = H_0 * x_0\)
- \(F_1 = H_1 * x_1\)
- \(F_2 = (H_0+H_1) * (x_0+x_1)\)

Then combines them as:

\[
y_0[k] = F_0[k] + F_1[k-1]
\]

\[
y_1[k] = F_2[k] - F_0[k] - F_1[k]
\]

This saves one subfilter convolution relative to the naive 4-subfilter L=2 implementation.

### 6.4 Internal ROM organization

`fir_filter_L2.sv` contains **two internal ROM instances**:

- one for the even-indexed coefficient stream
- one for the odd-indexed coefficient stream

The ROMs are addressed with stride-2 patterns. The summed coefficient path \(H_0+H_1\) is formed combinationally.

### 6.5 Timing

For 100 taps:

- each subfilter length = 50 taps
- one block produces 2 outputs
- total block latency = **52 cycles**
- effective cycles per output = **26 cycles/output**

This gives an approximately 4x throughput improvement over the serial version in cycles/output terms.

---

## 7. L=3 Reduced-Complexity Parallel Architecture (`fir_filter_L3.sv`)

### 7.1 Concept

In the L=3 architecture, the filter accepts **three input samples per block** and produces **three output samples per block**.

A naive L=3 design would require 9 subfilter convolutions. The implemented design reduces this to **6 subfilter convolutions**.

### 7.2 Polyphase form

The filter is decomposed as:

\[
H(z)=H_0(z^3)+z^{-1}H_1(z^3)+z^{-2}H_2(z^3)
\]

with:

- \(H_0 = \{h[0], h[3], h[6], \dots\}\)
- \(H_1 = \{h[1], h[4], h[7], \dots\}\)
- \(H_2 = \{h[2], h[5], h[8], \dots\}\)

The input is split into:

- \(x_0[k]=x[3k]\)
- \(x_1[k]=x[3k+1]\)
- \(x_2[k]=x[3k+2]\)

### 7.3 Reduced-complexity computation

The six implemented subfilter paths are:

- \(P_0 = H_0 * x_0\)
- \(P_1 = H_1 * x_1\)
- \(P_2 = H_2 * x_2\)
- \(P_3 = (H_0+H_1) * (x_0+x_1)\)
- \(P_4 = (H_1+H_2) * (x_1+x_2)\)
- \(P_5 = (H_0+H_2) * (x_0+x_2)\)

Cross-terms are recovered by subtraction:

\[
H_0x_1 + H_1x_0 = P_3 - P_0 - P_1
\]

\[
H_1x_2 + H_2x_1 = P_4 - P_1 - P_2
\]

\[
H_0x_2 + H_2x_0 = P_5 - P_0 - P_2
\]

The final output equations use previous-block values where required by the \(z^{-1}\) terms.

### 7.4 Internal ROM organization

`fir_filter_L3.sv` contains **three internal ROM instances**, one for each stride-3 coefficient stream:

- ROM_A for indices \(3k\)
- ROM_B for indices \(3k+1\)
- ROM_C for indices \(3k+2\)

Because 100 is not divisible by 3, the last stride-3 access can go out of range for some branches. The implementation uses coefficient-valid gating so that invalid accesses contribute zero.

### 7.5 Timing

For 100 taps:

- subfilter length = \(\lceil 100/3 \rceil = 34\)
- one block produces 3 outputs
- total block latency = **36 cycles**
- effective cycles per output = **12 cycles/output**

This gives a large throughput improvement relative to both the serial and L=2 designs.

---

## 8. Pipelined + L=3 Architecture (`fir_filter_pipelined_L3.sv`)

### 8.1 Concept

This architecture starts from the reduced-complexity L=3 structure and then adds pipelining to shorten the critical path.

The purpose of pipelining here is **not** to change the number of outputs per block. Instead, it is used to improve the achievable clock frequency by splitting the multiply-accumulate path into more stages.

### 8.2 Main difference from non-pipelined L=3

In the non-pipelined L=3 version, the effective datapath is:

- ROM read + delay alignment
- multiply
- accumulate

In the pipelined L=3 version, additional registers are inserted so that the product is registered before the accumulation stage. This reduces the longest combinational path.

Conceptually:

- **L=3**: multiply and accumulation are part of the same effective timing path
- **Pipelined L=3**: multiplier output is registered, then accumulated on a later cycle

### 8.3 Top-level organization

The implementation uses:

- `top_fir_filter_pipelined_L3.sv`
- `fir_filter_pipelined_L3.sv`

The pipelined core behaves like the L=2 and L=3 designs in the final code organization: the top module is a wrapper around the FIR core and does not expose an external coefficient ROM interface.

### 8.4 Timing impact

The additional pipeline stage increases the block latency slightly, but reduces the critical path.

Relative to plain L=3:

- cycles per block are slightly larger
- cycles per output are slightly larger
- maximum achievable clock frequency is expected to be better

For the implemented design, the pipelined L=3 architecture is intended to provide the **highest throughput in samples/second**, even though its cycles/output figure is slightly worse than the non-pipelined L=3 version.

---

## 9. Top Modules and Testbenches

### 9.1 Top modules

Each architecture has a top module used for synthesis:

- `top_fir_filter_serial.sv`
- `top_fir_filter_L2.sv`
- `top_fir_filter_L3.sv`
- `top_fir_filter_pipelined_L3.sv`

The top modules serve as the implementation-level wrappers used in Vivado.

### 9.2 Testbenches

Each architecture also has a dedicated simulation testbench:

- `fir_filter_serial_tb.sv`
- `fir_filter_L2_tb.sv`
- `fir_filter_L3_tb.sv`
- `fir_filter_pipelined_L3_tb.sv`

The updated testbenches:

- instantiate the corresponding top module,
- apply representative impulse/zero/step-style test inputs,
- wait for `ready`,
- wait for `data_out_valid`,
- print transaction-level debug messages, and
- terminate cleanly with `$finish`.

This structure was important because the parallel architectures require long simulation runtimes due to their serialized per-tap MAC execution.

---

## 10. Vivado Flow, Timing, and Power

After RTL and testbench verification, each design is passed through the Vivado flow:

1. **Behavioral simulation**
2. **Synthesis**
3. **Implementation**
4. **Timing analysis**
5. **Power estimation**

A primary clock constraint is created for the top-level `clk` input using the Vivado timing-constraint flow.

This allows the project to compare:

- setup timing,
- hold timing,
- resource utilization,
- estimated power,
- and architectural tradeoffs.

---

## 11. Comparison Summary

### 11.1 Architectural comparison

| Architecture | Outputs per Block | Main Arithmetic Reuse | ROM Style | Approx. Cycles per Output |
|---|---:|---|---|---:|
| Serial | 1 | Full time reuse of 1 MAC | External ROM in top | 102 |
| L=2 reduced-complexity | 2 | 3 subfilter paths instead of 4 | Internal ROMs | 26 |
| L=3 reduced-complexity | 3 | 6 subfilter paths instead of 9 | Internal ROMs | 12 |
| Pipelined + L=3 | 3 | Same reduced-complexity structure, shorter critical path | Internal core handling | Slightly above 12 |

### 11.2 Design tradeoffs

- **Serial FIR**  
  Smallest hardware cost, simplest control, lowest throughput.

- **L=2 FIR**  
  Good improvement in throughput with moderate extra hardware.

- **L=3 FIR**  
  Strong throughput improvement using algebraic reduction of the naive 9-path design.

- **Pipelined L=3 FIR**  
  Best candidate for highest real clocked throughput, because it combines block-level parallelism with a shorter timing path.

---

## 12. Results File

In addition to the RTL, testbenches, and documentation, the repository also includes a **results file** that gathers the measured outputs from simulation and implementation.

This results file is intended to summarize items such as:

- functional verification observations,
- timing results,
- utilization results,
- power estimates,
- and architecture-to-architecture comparisons.

This makes it easier to compare the four designs side-by-side without searching through multiple Vivado reports.

---

## 13. File Structure

```text
rtl/
  coeff_rom.sv
  fir_filter_serial.sv
  fir_filter_L2.sv
  fir_filter_L3.sv
  fir_filter_pipelined_L3.sv
  top_fir_filter_serial.sv
  top_fir_filter_L2.sv
  top_fir_filter_L3.sv
  top_fir_filter_pipelined_L3.sv

tb/
  fir_filter_serial_tb.sv
  fir_filter_L2_tb.sv
  fir_filter_L3_tb.sv
  fir_filter_pipelined_L3_tb.sv

scripts/
  quantize_coeffs.py

coeffs/
  filter_taps.csv
  filter_taps_quantized_q15.csv

docs/
  architecture_overview.md

results/
  results.md
```

---

## 14. Final Note

The final codebase implements and validates four FIR architectures with a common 100-tap quantized coefficient set and Vivado-compatible top/testbench structure.

The main architectural progression is:

- start from the MATLAB-designed floating-point FIR filter,
- quantize the coefficients into Q1.15 fixed-point format,
- implement multiple hardware architectures,
- verify them in simulation,
- and compare them after FPGA synthesis / implementation.

This makes the project suitable for comparing **area, timing, power, and throughput** across multiple FIR implementation strategies on FPGA.

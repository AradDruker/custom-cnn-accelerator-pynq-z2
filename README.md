# Custom DPU on PYNQ Z2

## University Final Project

This project aims to design and implement a **Custom Deep Learning Processing Unit (DPU)** for the **PYNQ Z2** platform. The DPU is being developed to accelerate neural network inference by offloading computation-intensive tasks to the FPGA. This is a work in progress and serves as part of my final project for my degree in Electrical and Electronic Engineering.

## Key Features

- **Custom DPU Design**: Tailored for the PYNQ Z2 FPGA.
- **Integration with AXI Interface**: Ensuring seamless communication between the processing system and the FPGA fabric.
- **Neural Network Acceleration**: Focused on efficient inference for the lightweight neural network LeNet-5.
- **Support for Quantized Models**: Leveraging model quantization for reduced resource usage.

## Goals

1. Design a custom hardware module for matrix multiplication, convolution, and activation functions.
2. Implement AXI-based communication for efficient data transfer between Python code running on the ARM processor and the FPGA.
3. Evaluate the performance in terms of speedup and resource utilization compared to software-based implementations.

## Work in Progress

The project is currently in development. The following components are under active implementation:

### 1. **DPU Modules**

- **Matrix Multiplication Module**: A key component for neural network operations.
- **Convolutional Layer Module**: Supporting standard 2D convolution.
- **BRAM Integration**: Utilizing on-chip memory for intermediate storage to reduce latency.

### 2. **Software Integration**

- Using Python and PYNQ APIs to send data to and retrieve results from the FPGA.
- Developing a Python driver to manage AXI transactions.

### 3. **Quantized Model Compatibility**

- Exporting quantized weights from PyTorch and formatting them for FPGA consumption.
- Initial tests are being conducted using a quantized LeNet-5 model.

### 4. **Testing and Debugging**

- Using simulation tools to verify the VHDL implementation.
- Debugging AXI communication with test designs.

## Planned Milestones

1. **Hardware Design Completion**: Finalize the VHDL design for core DPU components.
2. **Software Integration**: Ensure seamless data transfer between Python and FPGA.
3. **Model Deployment**: Test a complete quantized neural network on the DPU.
4. **Performance Evaluation**: Measure latency, throughput, and resource utilization.
5. **Documentation and Final Presentation**: Prepare detailed documentation and present the results.

## Tools and Technologies

- **PYNQ Z2**: FPGA development board.

- **Vivado**: For FPGA design and synthesis.

- **Python**: For control and testing scripts.

- **PyTorch**: For model preparation and quantization.

- **Jupyter Notebooks**: For ease of use with PYNQ.

## Challenges

- Efficient implementation of complex neural network layers within limited FPGA resources.
- Achieving high throughput while maintaining low latency.
- Debugging AXI communication and ensuring correct data transfer.

## Future Enhancements

- Support for additional neural network layers such as pooling and batch normalization.

---

This README will be updated as the project progresses.


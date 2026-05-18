FROM vivado-base:2025.2
COPY Xilinx /opt/Xilinx
RUN ldconfig && rm -rf /var/lib/apt/lists/*
ENV XILINX_VIVADO=/opt/Xilinx/2025.2/Vivado
ENV PATH=$XILINX_VIVADO/bin:/opt/Xilinx/2025.2/Vitis/bin:$PATH

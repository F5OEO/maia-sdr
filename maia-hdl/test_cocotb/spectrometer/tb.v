//
// Copyright (C) 2026 Daniel Estevez <daniel@destevez.net>
//
// This file is part of maia-sdr
//
// SPDX-License-Identifier: MIT
//

`timescale 1ps/1ps

module tb
  (
   input wire         clk,
   input wire         rst,
   input wire         clk2x_clk,
   input wire         clk3x_clk,
   input wire [15:0]  re_in,
   input wire [15:0]  im_in,
   input wire         strobe_in,
   input wire [9:0]   number_integrations,
   input wire         abort,
   input wire         peak_detect,
   input wire [2:0]   fastlock_profile,
   output wire [1:0]  last_buffer,
   output wire        interrupt_out,
   output wire        end_fft,
   input wire         capture_start,
   input wire         capture_stop,
   output wire        capture_finished,
   output wire        capture_dropped_samples,
   output wire [31:0] capture_next_address,
   output wire [1:0]  iq_last_buffer,
   output wire        iq_interrupt_out,
   // Magnitude waterfall DMA (AXI3 write, 64-bit)
   output wire [31:0] DMA_AWADDR,
   output wire [1:0]  DMA_AWBURST,
   output wire [3:0]  DMA_AWCACHE,
   output wire [3:0]  DMA_AWLEN,
   output wire [1:0]  DMA_AWLOCK,
   output wire [2:0]  DMA_AWPROT,
   input wire         DMA_AWREADY,
   output wire [2:0]  DMA_AWSIZE,
   output wire        DMA_AWVALID,
   output wire        DMA_BREADY,
   input wire [1:0]   DMA_BRESP,
   input wire         DMA_BVALID,
   output wire [63:0] DMA_WDATA,
   output wire        DMA_WLAST,
   input wire         DMA_WREADY,
   output wire [7:0]  DMA_WSTRB,
   output wire        DMA_WVALID,
   // Raw capture DMA (AXI3 write, 64-bit)
   output wire [31:0] RAW_AWADDR,
   output wire [1:0]  RAW_AWBURST,
   output wire [3:0]  RAW_AWCACHE,
   output wire [3:0]  RAW_AWLEN,
   output wire [1:0]  RAW_AWLOCK,
   output wire [2:0]  RAW_AWPROT,
   input wire         RAW_AWREADY,
   output wire [2:0]  RAW_AWSIZE,
   output wire        RAW_AWVALID,
   output wire        RAW_BREADY,
   input wire [1:0]   RAW_BRESP,
   input wire         RAW_BVALID,
   output wire [63:0] RAW_WDATA,
   output wire        RAW_WLAST,
   input wire         RAW_WREADY,
   output wire [7:0]  RAW_WSTRB,
   output wire        RAW_WVALID,
   // Continuous I/Q waterfall DMA (AXI3 write, 32-bit)
   output wire [31:0] IQ_AWADDR,
   output wire [1:0]  IQ_AWBURST,
   output wire [3:0]  IQ_AWCACHE,
   output wire [3:0]  IQ_AWLEN,
   output wire [1:0]  IQ_AWLOCK,
   output wire [2:0]  IQ_AWPROT,
   input wire         IQ_AWREADY,
   output wire [2:0]  IQ_AWSIZE,
   output wire        IQ_AWVALID,
   output wire        IQ_BREADY,
   input wire [1:0]   IQ_BRESP,
   input wire         IQ_BVALID,
   output wire [31:0] IQ_WDATA,
   output wire        IQ_WLAST,
   input wire         IQ_WREADY,
   output wire [3:0]  IQ_WSTRB,
   output wire        IQ_WVALID,
   // These are used by cocotb's AXI4Slave helper (unused read channel)
   input wire         DMA_ARREADY,
   input wire         DMA_RVALID,
   input wire         DMA_RLAST,
   output wire        DMA_ARVALID,
   input wire         RAW_ARREADY,
   input wire         RAW_RVALID,
   input wire         RAW_RLAST,
   output wire        RAW_ARVALID,
   input wire         IQ_ARREADY,
   input wire         IQ_RVALID,
   input wire         IQ_RLAST,
   output wire        IQ_ARVALID
   );

   glbl glbl ();

   assign DMA_ARVALID = 1'b0;
   assign RAW_ARVALID = 1'b0;
   assign IQ_ARVALID = 1'b0;

   dut dut
     (.clk(clk), .rst(rst), .clk2x_clk(clk2x_clk), .clk3x_clk(clk3x_clk),
      .re_in(re_in), .im_in(im_in), .strobe_in(strobe_in),
      .number_integrations(number_integrations), .abort(abort),
      .peak_detect(peak_detect), .last_buffer(last_buffer),
      .interrupt_out(interrupt_out), .fastlock_profile(fastlock_profile),
      .end_fft(end_fft),
      .capture_start(capture_start), .capture_stop(capture_stop),
      .capture_finished(capture_finished),
      .capture_dropped_samples(capture_dropped_samples),
      .capture_next_address(capture_next_address),
      .iq_last_buffer(iq_last_buffer), .iq_interrupt_out(iq_interrupt_out),

      .dma_awaddr(DMA_AWADDR), .dma_awlen(DMA_AWLEN), .dma_awsize(DMA_AWSIZE),
      .dma_awburst(DMA_AWBURST), .dma_awcache(DMA_AWCACHE),
      .dma_awprot(DMA_AWPROT), .dma_awlock(DMA_AWLOCK),
      .dma_awvalid(DMA_AWVALID), .dma_awready(DMA_AWREADY),
      .dma_wdata(DMA_WDATA), .dma_wstrb(DMA_WSTRB), .dma_wlast(DMA_WLAST),
      .dma_wvalid(DMA_WVALID), .dma_wready(DMA_WREADY),
      .dma_bresp(DMA_BRESP), .dma_bvalid(DMA_BVALID), .dma_bready(DMA_BREADY),

      .dma_raw_awaddr(RAW_AWADDR), .dma_raw_awlen(RAW_AWLEN),
      .dma_raw_awsize(RAW_AWSIZE), .dma_raw_awburst(RAW_AWBURST),
      .dma_raw_awcache(RAW_AWCACHE), .dma_raw_awprot(RAW_AWPROT),
      .dma_raw_awlock(RAW_AWLOCK), .dma_raw_awvalid(RAW_AWVALID),
      .dma_raw_awready(RAW_AWREADY),
      .dma_raw_wdata(RAW_WDATA), .dma_raw_wstrb(RAW_WSTRB),
      .dma_raw_wlast(RAW_WLAST), .dma_raw_wvalid(RAW_WVALID),
      .dma_raw_wready(RAW_WREADY),
      .dma_raw_bresp(RAW_BRESP), .dma_raw_bvalid(RAW_BVALID),
      .dma_raw_bready(RAW_BREADY),

      .dma_iq_awaddr(IQ_AWADDR), .dma_iq_awlen(IQ_AWLEN),
      .dma_iq_awsize(IQ_AWSIZE), .dma_iq_awburst(IQ_AWBURST),
      .dma_iq_awcache(IQ_AWCACHE), .dma_iq_awprot(IQ_AWPROT),
      .dma_iq_awlock(IQ_AWLOCK), .dma_iq_awvalid(IQ_AWVALID),
      .dma_iq_awready(IQ_AWREADY),
      .dma_iq_wdata(IQ_WDATA), .dma_iq_wstrb(IQ_WSTRB),
      .dma_iq_wlast(IQ_WLAST), .dma_iq_wvalid(IQ_WVALID),
      .dma_iq_wready(IQ_WREADY),
      .dma_iq_bresp(IQ_BRESP), .dma_iq_bvalid(IQ_BVALID),
      .dma_iq_bready(IQ_BREADY)
      );

`ifdef COCOTB_SIM
   initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, dut);
   end
`endif
endmodule // tb

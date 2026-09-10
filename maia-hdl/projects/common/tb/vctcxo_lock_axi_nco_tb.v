`timescale 1ns/1ps

// Regression for the NCO shadow registers added to vctcxo_lock's AXI-Lite
// interface. This instantiates the register file only, so it runs quickly.

module vctcxo_lock_axi_nco_tb;
  reg clk = 0;
  reg resetn = 0;
  always #5 clk = ~clk;

  reg [5:0] awaddr = 0;
  reg [2:0] awprot = 0;
  reg awvalid = 0;
  wire awready;
  reg [31:0] wdata = 0;
  reg [3:0] wstrb = 4'hf;
  reg wvalid = 0;
  wire wready;
  wire [1:0] bresp;
  wire bvalid;
  reg bready = 1;
  reg [5:0] araddr = 0;
  reg [2:0] arprot = 0;
  reg arvalid = 0;
  wire arready;
  wire [31:0] rdata;
  wire [1:0] rresp;
  wire rvalid;
  reg rready = 1;

  wire [31:0] nco_rx_ftw;
  wire [31:0] nco_tx_ftw;
  wire [3:0] nco_control;
  wire dac_mode, dac_dither_dis;
  wire [15:0] dac_user_set_value, center_dac;
  wire [1:0] dac_ref_sel;
  wire [7:0] p_shift, i_shift;
  wire [31:0] lock_thresh;

  vctcxo_lock_v1_0_S00_AXI #(
    .C_S_AXI_ADDR_WIDTH(6)
  ) dut (
    .dac_mode(dac_mode),
    .dac_user_set_value(dac_user_set_value),
    .center_dac(center_dac),
    .dac_dyn_value(16'h1234),
    .dac_ref_sel(dac_ref_sel),
    .dac_dither_dis(dac_dither_dis),
    .p_shift(p_shift), .i_shift(i_shift), .lock_thresh(lock_thresh),
    .locked(1'b0), .ref_present(1'b1), .freq_error(32'hffff_ff7b),
    .nco_rx_ftw(nco_rx_ftw), .nco_tx_ftw(nco_tx_ftw),
    .nco_control(nco_control),
    .S_AXI_ACLK(clk), .S_AXI_ARESETN(resetn),
    .S_AXI_AWADDR(awaddr), .S_AXI_AWPROT(awprot),
    .S_AXI_AWVALID(awvalid), .S_AXI_AWREADY(awready),
    .S_AXI_WDATA(wdata), .S_AXI_WSTRB(wstrb),
    .S_AXI_WVALID(wvalid), .S_AXI_WREADY(wready),
    .S_AXI_BRESP(bresp), .S_AXI_BVALID(bvalid), .S_AXI_BREADY(bready),
    .S_AXI_ARADDR(araddr), .S_AXI_ARPROT(arprot),
    .S_AXI_ARVALID(arvalid), .S_AXI_ARREADY(arready),
    .S_AXI_RDATA(rdata), .S_AXI_RRESP(rresp),
    .S_AXI_RVALID(rvalid), .S_AXI_RREADY(rready)
  );

  task axi_write;
    input [5:0] addr;
    input [31:0] data;
    begin
      @(negedge clk);
      awaddr = addr; wdata = data; awvalid = 1'b1; wvalid = 1'b1;
      repeat (2) @(negedge clk);
      awvalid = 1'b0; wvalid = 1'b0;
      repeat (2) @(negedge clk);
    end
  endtask

  task axi_read_check;
    input [5:0] addr;
    input [31:0] expected;
    begin
      @(negedge clk);
      araddr = addr; arvalid = 1'b1;
      repeat (2) @(negedge clk);
      arvalid = 1'b0;
      @(posedge clk); #1;
      if (rdata !== expected)
        $fatal(1, "AXI read 0x%02x: got 0x%08x expected 0x%08x",
               addr, rdata, expected);
      @(negedge clk);
    end
  endtask

  initial begin
    repeat (4) @(posedge clk);
    resetn = 1'b1;
    repeat (2) @(posedge clk);

    if (nco_rx_ftw !== 0 || nco_tx_ftw !== 0 || nco_control !== 0)
      $fatal(1, "NCO reset defaults are not bypassed");

    axi_write(6'h20, 32'hff01_2345);
    axi_write(6'h24, 32'h00ab_cdef);
    axi_write(6'h28, 32'h0000_000d);

    if (nco_rx_ftw !== 32'hff01_2345 ||
        nco_tx_ftw !== 32'h00ab_cdef || nco_control !== 4'hd)
      $fatal(1, "NCO output registers do not match AXI writes");

    axi_read_check(6'h20, 32'hff01_2345);
    axi_read_check(6'h24, 32'h00ab_cdef);
    axi_read_check(6'h28, 32'h0000_000d);
    $display("VCTCXO LOCK NCO AXI TEST: PASS");
    $finish;
  end
endmodule

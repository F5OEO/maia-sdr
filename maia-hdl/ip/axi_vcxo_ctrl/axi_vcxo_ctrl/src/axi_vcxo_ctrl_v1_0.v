
`timescale 1 ns / 1 ps

	module axi_vcxo_ctrl #
	(
		// Users to add parameters here
		parameter DEVICE="LTC2630",

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here
		input  wire	 			CLK_40MHz_FPGA  ,
		// PPS or 10 MHz (need to choose from SW)
		input  wire             PPS_IN          ,
		input  wire             CLKIN_10MHz     ,
		input  wire             PPS_GPS         ,
		output wire             PPS_LED         ,
		output wire             PPS_LOCKED      ,
		output wire             REF_10M_LOCKED  ,
		output wire             CLK_40M_DAC_nSYNC,
		output wire             CLK_40M_DAC_SCLK ,
		output wire             CLK_40M_DAC_DIN ,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);


	wire  	[0:0]	dac_mode 			;
	wire 	[15:0]	dac_user_set_value	;
	wire 	[15:0]	dac_dyn_value 		;
	wire  	[1:0]	dac_ref_sel 		;
	wire 			dac_locked 			;

	wire 		clk_200M;
	wire 		clk_40M;
	wire 		plllck;
	wire 		ref_sync 	;
	wire 		ref_ext_pll_locked;
	wire 		ref_is_10M;
	wire 		ref_is_pps;
	wire [15:0]	dyn_dac_value	;


// Instantiation of Axi Bus Interface S00_AXI
	axi_vcxo_ctrl_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) axi_vcxo_ctrl_v1_0_S00_AXI_inst (
		.dac_mode(dac_mode) 			,
		.dac_user_set_value(dac_user_set_value)	,
		.dac_dyn_value(dyn_dac_value) 		,
		.dac_ref_sel(dac_ref_sel) 		,
		.dac_locked(ref_ext_pll_locked) 			,
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
	

	assign REF_10M_LOCKED = ref_ext_pll_locked & ref_is_10M;
	assign PPS_LOCKED = ref_ext_pll_locked & ref_is_pps;
	assign ref_sync = (dac_ref_sel==2'b00) ? CLKIN_10MHz :
					  (dac_ref_sel==2'b01) ? PPS_IN :
					  (dac_ref_sel==2'b10) ? PPS_GPS: 1'b0;
	assign PPS_LED = PPS_GPS;

	PLLE2_ADV #(.BANDWIDTH("OPTIMIZED"), .COMPENSATION("INTERNAL"),
		.DIVCLK_DIVIDE(1),
		.CLKFBOUT_MULT(30),
		.CLKOUT0_DIVIDE(6),
		.CLKOUT1_DIVIDE(30),
		.CLKIN1_PERIOD(25.0)
	)
	clkgen (
		.PWRDWN(1'b0), .RST(1'b0),
		.CLKIN1(CLK_40MHz_FPGA),
		.CLKOUT0(clk_200M),
		.CLKOUT1(clk_40M),
		.LOCKED(plllck)
	);

	b205_ref_pll#(
		.DEVICE(DEVICE )
	)u_b205_ref_pll(
		.reset      ( ~plllck    ),
		.clk        ( clk_200M   ),
		.refclk     ( clk_40M    ),
		.ref_x        ( ref_sync        ),
		.locked     ( ref_ext_pll_locked     ),
		.ref_is_10M ( ref_is_10M ),
		.ref_is_pps ( ref_is_pps ),
		.dac_mode   ( dac_mode   ),
		.dyn_dac    ( dyn_dac_value    ),
		.dac_dft    ( 16'd42580	),
		.dac_user_set_value(dac_user_set_value),
		.sclk       ( CLK_40M_DAC_SCLK       ),
		.mosi       ( CLK_40M_DAC_DIN       ),
		.sync_n     ( CLK_40M_DAC_nSYNC     )
	);


/* 	wire [127:0] probe0;
	assign probe0={
		dac_ref_sel,
		dac_user_set_value,
		plllck,
		ref_sync,
		ref_ext_pll_locked,
		ref_is_10M,
		ref_is_pps,
		dac_mode,
		dyn_dac_value
	};
	ila_0 your_instance_name (
		.clk(s00_axi_aclk), // input wire clk


		.probe0(probe0) // input wire [127:0] probe0
	);
 */
	// User logic ends

	endmodule

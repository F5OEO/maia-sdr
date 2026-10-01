// Modified by Christos Nikolaou (SV1EIA) 2026.
// Christos Nikolaou can be reached by email at : sv1eia@gmail.com
//
// Power-up: the full initialization sequence (init latch, function latch,
// R counter, N counter). Afterwards any change of ext_ref_en or mux_sel is
// applied by writing the function latch alone, so a locked loop is not
// disturbed by the counter reset that the initialization latch performs.
module ADF4001_init#
(
    parameter SPI_CLK_FREQ_MHZ = 5 
)(
//系统时钟复位
	input 				clk,
	input 				rst_n,
//1: charge pump active, VCTCXO locked to the 10 MHz on REFIN
//0: charge pump three-state, VCTCXO free-running at its mid-rail tune
	input 				ext_ref_en,
//MUXOUT selection: 0 R divider output, 1 digital lock detect, 2 DGND (LED off)
	input 		[1:0]	mux_sel,
	
//ADF4001接口
	output				SPI_LE,
	output				SPI_SCLK,
	output				SPI_MOSI,
//状态指示	
	output 	reg		    init_done = 1'b0,
//charge pump state actually written to the ADF4001
	output 	reg		    cp_active = 1'b0,
//MUXOUT selection actually written to the ADF4001
	output 	reg	[1:0]	mux_is = 2'd0
);

//SPI驱动
wire 			spi_wr_start;
wire 			spi_wr_done;
reg [23:0] 	    spi_wr_data = 24'd0;
reg 			spi_wr_en   = 1'b0;

ADF4001_spi_drive ADF4001_spi_drive_u(
    .clk				(clk),
    .rst_n				(rst_n),
	
    .wr_start			(spi_wr_start),
    .wr_done			(spi_wr_done),

    .wr_en				(spi_wr_en),
    .wr_data			(spi_wr_data),

    .spi_clk			(SPI_SCLK),
    .spi_csn			(SPI_LE),
    .spi_sdo			(SPI_MOSI)
);

//power-up values: there is no reset on this board (rst_n is tied high),
//the configuration bitstream sets them
reg	   [ 1:0]	reset_index = 2'd0;
reg	   [ 7:0]	index       = 8'd0;
reg	   [ 2:0]	state       = 3'd0;
reg    [31:0] 	delay_cnt   = 32'd0;
(* ASYNC_REG = "TRUE" *) reg [1:0] ext_ref_sync = 2'b00;
(* ASYNC_REG = "TRUE" *) reg [1:0] mux_sync0 = 2'b00;
(* ASYNC_REG = "TRUE" *) reg [1:0] mux_sync1 = 2'b00;
reg             cfg_ext  = 1'b0;
reg     [1:0]   cfg_mux  = 2'd0;
reg             single   = 1'b0;    //1: this sequence writes the function latch only

always @ (posedge clk) begin
    ext_ref_sync  <= {ext_ref_sync[0], ext_ref_en};
    mux_sync0 <= mux_sel;
    mux_sync1 <= mux_sync0;
end

//the whole sequence is written with the values sampled at its first word
wire            seq_first = (index == (single ? 8'd1 : 8'd0));
wire            ext_now   = seq_first ? ext_ref_sync[1]  : cfg_ext;
wire    [1:0]   mux_now   = seq_first ? mux_sync1 : cfg_mux;

    
always @ (posedge clk or negedge rst_n)begin
    if(!rst_n) begin 
        index       <= 0;       //索引置0
        init_done   <= 0;       //初始化完成信号置0
        state       <= 0;       //状态机置0
        delay_cnt   <= 0;       //延时计数
        spi_wr_en   <= 0;       //SPI写使能信号置0
        reset_index <= 0;
    end
    else 
        case (state)    
            3'd0    :   begin 
                            if(seq_first) begin
                                cfg_ext  <= ext_ref_sync[1];
                                cfg_mux  <= mux_sync1;
                            end
                            spi_wr_data <= ADF4001_lut(index, ext_now, mux_now);
                            spi_wr_en   <= 1'b0;	
                            state 		<= 3'd1;
            end  
            
            3'd1    :   begin 
                            spi_wr_en   <= 1'b1;	
                            state 		<= 3'd2;
                        end  

            3'd2    :   begin
                            if(spi_wr_start) begin 
                                state <= 3'd3;
                                spi_wr_en   <= 1'b0;
                            end
                        end
            3'd3    :   begin
                            if(spi_wr_done) begin 
                                state <= 3'd4;
                            end
                        end       
            3'd4    :   begin 
                            //power-up sequence: the original 2 ms between words;
                            //a single function latch write: 100 us is plenty, and
                            //MUXOUT (the LED) must not stay on the R divider longer
                            //than needed
                            if(delay_cnt <= (single ? SPI_CLK_FREQ_MHZ * 100 : SPI_CLK_FREQ_MHZ * 2000))
                                delay_cnt <= delay_cnt + 1;
                            else begin
                                delay_cnt <= 0;   
                                if(index == 8'd3 || single) begin
                                state <= 3'd5;
                                end
                                else begin
                                    state <= 3'd0;
                                    index <= index + 8'd1;
                                end
                            end
                        end                        
            3'd5    :   begin 
                            init_done   <= 1'b1;
                            cp_active   <= cfg_ext;
                            mux_is      <= cfg_mux;
                            //charge pump or MUXOUT selection changed:
                            //rewrite the function latch only
                            if(ext_ref_sync[1] != cfg_ext || mux_sync1 != cfg_mux) begin
                                init_done <= 1'b0;
                                single    <= 1'b1;
                                index     <= 8'd1;
                                state     <= 3'd0;
                            end
                        end
                        
            default :   state <= 3'd0;
            
        endcase
end
	

function [23:0] ADF4001_lut;
    input [7:0] index;              //输入索引
    input       ext;                //0: CP three-state (DB8)
    input [1:0] mux;                //0: R divider output, 1: lock detect, 2: DGND
    reg [23:0] ADF4001_lut_d;       //中间变量
    reg [23:0] fl;                  //function latch contents
    reg [23:0] mx;                  //MUXOUT field, DB6:4
    begin
        //DB20:15 = 111111 CP current max, DB14 = 0 lock detect 3 cycles,
        //DB7 = 1 PD polarity positive, DB6:4 MUXOUT: 100 R divider output,
        //001 digital lock detect, 111 DGND; DB8 = CP three-state when !ext
        case(mux)
            2'd1:    mx = 24'h00_0010;
            2'd2:    mx = 24'h00_0070;
            default: mx = 24'h00_0040;
        endcase
        fl = 24'h1F_8080 | mx | (ext ? 24'h0 : 24'h00_0100);
        case(index)
            8'd0:  ADF4001_lut_d = fl | 24'h00_0003;    //initialization latch
            8'd1:  ADF4001_lut_d = fl | 24'h00_0002;    //function latch
            8'd2:  ADF4001_lut_d = 24'h00_0004;         //R counter: R = 1
            8'd3:  ADF4001_lut_d = 24'h00_0401;         //N counter: N = 4
            default: ADF4001_lut_d = 24'h0;
        endcase   
        ADF4001_lut = ADF4001_lut_d;            //输出当前输出值
    end   
endfunction   
     
endmodule

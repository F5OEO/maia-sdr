//
// Copyright 2015 Ettus Research, a National Instruments Company
// Modified https://github.com/Shawn-McSorley
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//

`timescale 1ns / 1ps

// This code is intended for a dac5311 module (8-bit DAC). Though the data register should accompany the 12-bit version.
// Some notes from data sheet:
// 1. Max clock frequency of sclk is 20MHz when Vdd is 3.3V (see libre SDR schematic)
// 2. sclk always runs
// 3. See pg. 7 of data sheet for timing diagram. ~SYNC goes high. Data is clocked in on the next falling edge of sclk, after ~SYNC goes low.
// 4. 16 data bits are clocked in (16 sclk cycles afer ~SYNC goes low).
// 5. First two bits are operating mode. 00 is normal operation, 01 is 1kOhm to ground, 10 is 100kOhm to ground, 11 is high-z.
// 6. MSBs are clocked in first. Starting with operating mode, then 12-bit data. Rest is don't care.
// 7. ~SYNC must be low for at least 16 sclk cycles during write, otherwise data is ignored. 
// 8. ~SYNC must be high for at least 20ns before the next write. Falling edge of ~SYNC triggers write. 

// This code is a minor modification of ltc2630_spi.v by Ettus Research. 

module dacxx11_spi  (
    input   wire            clk,
    input   wire            rst,
    input   wire  [11:0]    data, // 12-bit data, 8 bits in MSBs
    output  reg             sclk,
    output  wire            mosi,
    output  reg             sync_n
);

//====================================================
//parameter define
//====================================================
localparam  IDLE        = 4'b0001;
localparam  SYNC_PRE    = 4'b0010;
localparam  DATA        = 4'b0100;
localparam  SYNC_END    = 4'b1000;

localparam NORMAL_OPERATION = 2'b00;
localparam K1KOHM_TO_GROUND = 2'b01;
localparam K100KOHM_TO_GROUND = 2'b10;
localparam HIGH_Z = 2'b11;

//====================================================
// internal signals and registers
//====================================================
reg     [3:0]   state;
reg     [4:0]   cnt_cycle   ;
reg     [5:0]   cnt_bit     ;
reg     [11:0]  last_data   ;
reg     [15:0]  data_shift  ;
wire            rising_edge ;
wire            falling_edge;

//----------------state------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        state <= IDLE;
    end
    else  begin
        case (state)
            IDLE : begin
                // detect a new data input, the dac value needs to be updated
                if (last_data != data) begin
                    state <= SYNC_PRE;
                end
            end

            SYNC_PRE : begin
                // The SYNC is low, start to update the value
                if (falling_edge) begin
                    state <= DATA;
                end
            end

            DATA : begin
                if (cnt_bit == 'd15 && falling_edge) begin
                    state <= SYNC_END;
                end
            end

            SYNC_END : begin
                if (rising_edge == 1'b1) begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

//----------------cnt_cycle------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        cnt_cycle <= 'd0;
    end
    else if (state == SYNC_PRE || state == DATA || state == SYNC_END) begin
        cnt_cycle <= cnt_cycle + 1'b1;
    end
    else  begin
        cnt_cycle <=  'd0;
    end
end

assign rising_edge = cnt_cycle==5'b10000; // Modified so that 200M clock is divided by 16 not 8.
assign falling_edge = cnt_cycle==5'b11111;

//----------------data_shift------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        data_shift <= 'd0;
    end
    else if (state == IDLE && (last_data != data)) begin
        data_shift <= {NORMAL_OPERATION, data};
    end
    else if (state == DATA && falling_edge) begin
        data_shift <=  {data_shift[14:0], 1'b0};
    end
end

//----------------cnt_bit------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        cnt_bit <= 'd0;
    end
    else if (state == DATA ) begin
        if (cnt_bit == 'd15 && falling_edge) begin
            cnt_bit <= 'd0;
        end
        else if(falling_edge)begin
            cnt_bit <= cnt_bit + 1'b1;
        end
    end
    else  begin
        cnt_bit <=  'd0;
    end
end

//----------------last_data------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        last_data <= 'd0;
    end
    else if (state == IDLE && (last_data != data)) begin
        last_data <= data;
    end
end

//-----------------sclk-----------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        sclk <= 1'b0;
    end
    else if (rising_edge == 1'b1) begin // removed state==DATA &&
        sclk <= 1'b1;
    end
    else if (falling_edge == 1'b1) begin // removed state==DATA &&
        sclk <=  1'b0;
    end
end

assign mosi = data_shift[15];

//----------------sync_n------------------
always @(posedge clk ) begin
    if (rst==1'b1) begin
        sync_n <= 1'b1;
    end
    else if (state == SYNC_PRE && falling_edge == 1'b1) begin
        sync_n <= 1'b0;
    end
    else if (state == SYNC_END && rising_edge == 1'b1) begin
        sync_n <=  1'b1;
    end
end


endmodule
`timescale 1ns/100ps

module sweeper_it (
    input  clk,       // Clock signal
    input  reset,     // Reset signal
    output reg  [13:0] gpio_o, // 14-bit counter gpio
    output reg  [2:0] profile_o // 3-bit counter
);

    reg [31:0] clk_count; // 32-bit clock counter
    reg [2:0] count; // 3-bit clock counter

    always @(posedge clk ) begin
        if (reset) begin
            clk_count <= 0;
            count <= 0;
            profile_o <= 0;
        end else begin
            count <= count + 1;
            gpio_o <= count << 9;
            profile_o <= count;
        end
        
    end

endmodule


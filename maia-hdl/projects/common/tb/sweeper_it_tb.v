`timescale 1ns/1ps
// Self-checking TB for sweeper_it: step_in is a level that rises once per
// integration (spectrometer nearly_end). Checks that
//  (1) the profile steps once per rising edge, not per clock while step_in is high,
//  (2) gpio_o only ever uses bits 11:9 (never bit 12 = EN_AGC) across the 7->0 wrap,
//  (3) profile_o is the count before the step (the profile of the finished spectrum),
//  (4) an asynchronous reset clears everything.
module sweeper_it_tb;
  reg clk=0, reset=1, step_in=0;
  wire [63:0] gpio_o; wire [2:0] profile_o;
  sweeper_it dut(.clk(clk),.reset(reset),.step_in(step_in),.gpio_o(gpio_o),.profile_o(profile_o));

  always #8 clk=~clk;

  integer errors=0, k, exp_count=0;
  always @(posedge clk) if (!reset && (gpio_o & ~64'h0E00) != 0) begin
    $display("ERROR: gpio_o=%h has bits outside 11:9", gpio_o); errors=errors+1;
  end

  initial begin
    repeat(3) @(posedge clk); #3 reset=0;
    repeat(4) @(posedge clk);
    if (gpio_o !== 0 || profile_o !== 0) begin $display("ERROR: not cleared after reset"); errors=errors+1; end
    for (k=0; k<20; k=k+1) begin
      @(negedge clk) step_in=1;
      repeat(10) @(negedge clk);           // level held for many clocks
      step_in=0;
      repeat(5) @(negedge clk);
      exp_count=(exp_count+1)%8;
      if (gpio_o !== ({61'd0,exp_count[2:0]} << 9) || profile_o !== (exp_count[2:0]-3'd1)) begin
        $display("ERROR step %0d: gpio_o=%h profile_o=%0d expected count %0d", k, gpio_o, profile_o, exp_count);
        errors=errors+1;
      end
    end
    #3 reset=1; #2;
    @(negedge clk);
    if (gpio_o !== 0 || profile_o !== 0) begin $display("ERROR: async reset did not clear"); errors=errors+1; end
    if (errors==0) $display("PASS: 20 steps, gpio_o confined to bits 11:9"); else $display("FAIL: %0d errors", errors);
    $finish;
  end
endmodule

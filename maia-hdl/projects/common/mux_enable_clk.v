module mux_enable (
    input wire clk,
    input wire ps_i0,
    input wire ps_q0,
    input wire ps_i1,
    input wire ps_q1,
    input wire sync,
    input wire sel,
    output reg out_i0,
    output reg out_q0,
    output reg out_i1,
    output reg out_q1
);

    always @(posedge clk) begin
        if (sel) begin
            out_i0 <= sync & ps_i0;
            out_q0 <= sync & ps_q0;
            out_i1 <= sync & ps_i1;
            out_q1 <= sync & ps_q1;
        end else begin
            out_i0 <= ps_i0;
            out_q0 <= ps_q0;
            out_i1 <= ps_i1;
            out_q1 <= ps_q1;
        end
    end

endmodule
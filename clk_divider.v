`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 08/15/2024 04:51:03 PM
// Design Name:
// Module Name: clk_divider
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module clk_divider(
    input clk_in,
    input [3:0] N_div,
    input clockEnable,
    input invert,

    output clk_out,
    output clk_out_reg
  );

  reg clk_int = 0;

  reg [1:0] count = 2'b00;

  assign clk_out = (clockEnable) ? ((N_div == 0) ? clk_in : clk_int) : 0;
  assign clk_out_reg = (invert) ? ~clk_out : clk_out;

  always @ (negedge clk_in)
  begin
    if (clockEnable)
    begin
      if (count == N_div - 1)
      begin
        count  = 0;
        clk_int <= ~clk_int;
      end
      else
      begin
        count = count + 1;
      end
    end
    else
    begin
      count = 0;
      clk_int = invert;
    end
  end
endmodule

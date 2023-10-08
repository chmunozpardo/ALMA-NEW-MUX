`define BUSY 1'b1
`define DONE 1'b0

module counter #
  (
    parameter WIDTH = 3
  )
  (
    input             CLK,
    input [WIDTH-1:0] dataIn,
    input             loadData,
    input             clockEnable,

    output            busy
  );

  reg [WIDTH-1:0] intData = 0;

  assign busy = intData ? `BUSY : `DONE;

  always @(posedge CLK)
    if (loadData)
      intData <= dataIn;
    else if (clockEnable && busy)
      intData <= intData - 1;

endmodule
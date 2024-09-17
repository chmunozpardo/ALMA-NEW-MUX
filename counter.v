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
  reg [WIDTH-1:0] dataSize = 0;

  assign busy = (intData == dataSize) ? `DONE : `BUSY;

  always @(posedge loadData)
  begin
    if (loadData)
    begin
      dataSize <= dataIn;
    end
  end

  always @(posedge CLK, negedge clockEnable)
  begin
    if (!clockEnable)
      intData <= 0;
    else if (intData < dataSize)
      intData <= intData + 1;
  end

endmodule

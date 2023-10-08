module shift_reg_out #
  (
    parameter WIDTH = 5
  )
  (
    input             CLK,
    input             loadData,
    input             clockEnable,
    input [WIDTH-1:0] dataIn,

    output reg        dataOut = 0
  );

  reg [WIDTH-1:0] intData = 0;

  always @(negedge CLK)
    if (loadData)
      begin
        intData = dataIn[WIDTH-1:0];
        dataOut = intData[WIDTH-1];
      end
    else if (clockEnable)
      begin
        intData = intData << 1;
        dataOut = intData[WIDTH-1];
      end
endmodule

module shift_reg_in #
  (
    parameter WIDTH = 5
  )
  (
    input CLK,
    input dataIn,
    input clockEnable,

    output reg [WIDTH-1:0] dataOut = 0
  );

  always @(posedge CLK)
    if (clockEnable)
      dataOut = {dataOut[WIDTH-2:0], dataIn};
    else
      dataOut = 0;
endmodule
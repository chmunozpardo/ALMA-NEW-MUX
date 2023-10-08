// Mux to connect to the correct port
// Port  0 -> B1.WCA
// Port  1 -> B1.BIAS
// Port  2 -> B2.WCA
// Port  3 -> B2.BIAS
// Port  4 -> B3.WCA
// Port  5 -> B3.BIAS
// Port  6 -> B4.WCA
// Port  7 -> B4.BIAS
// Port  8 -> B5.WCA
// Port  9 -> B5.BIAS
// Port 10 -> B6.WCA
// Port 11 -> B6.BIAS
// Port 12 -> B7.WCA
// Port 13 -> B7.BIAS
// Port 14 -> B8.WCA
// Port 15 -> B8.BIAS
// Port 16 -> B9.WCA
// Port 17 -> B9.BIAS
// Port 18 -> B10.WCA
// Port 19 -> B10.BIAS
// Port 20 -> POWER DISTRIBUTION
// Port 21 -> IF SWITCH
// Port 22 -> CRYOSTAT
// Port 23 -> LOPR
// Port 24 -> (SPARE)

`define ENABLE      1'b1
`define DISABLE     1'b0

`define WRITE       1'b1
`define READ        1'b0

module port_select #
  (
    parameter PORT_SIZE = 2
  )
  (
    input[4:0] sscPort,

    input      sscClk1,
    input      sscSync1,
    input      sscData1Out,
    output reg sscData1In,

    input [PORT_SIZE-1:0]      sscDataNIn,
    output reg [PORT_SIZE-1:0] sscClkN     = {PORT_SIZE{1'b1}},
    output reg [PORT_SIZE-1:0] sscSyncN    = {PORT_SIZE{1'b1}},
    output reg [PORT_SIZE-1:0] sscDataNOut = {PORT_SIZE{1'b0}}
  );

  // Combinatorial logic to connect sync lines
  always @*
  begin: syncLines
    sscSyncN = {PORT_SIZE{1'b1}};
    sscSyncN[sscPort] = sscSync1;
  end

  // Combinatorial logic to connect clk lines
  always @*
  begin: clkLines
    sscClkN = {PORT_SIZE{1'b1}};
    sscClkN[sscPort] = sscClk1;
  end

  // Combinatorial logic to connect data in lines
  always @*
  begin: dataInLines
    sscData1In = sscDataNIn[sscPort];
  end

  // Combinatorial logic to connect data out lines
  always @*
  begin: dataOutLines
    sscDataNOut = {PORT_SIZE{1'b1}};
    sscDataNOut[sscPort] = sscData1Out;
  end

endmodule

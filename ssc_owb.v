`timescale 1 ns / 1 ps

module ssc_owb #
  (
    // Users to add parameters here
    parameter PORT_SIZE = 25,

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Parameters of Axi Slave Bus Interface S_AXIL
    parameter integer C_S_AXIL_DATA_WIDTH = 32,
    parameter integer C_S_AXIL_ADDR_WIDTH = 10
  )
  (
    // Users to add ports here
    output wire [PORT_SIZE-1:0] sscSyncN,
    output wire [PORT_SIZE-1:0] sscClkN,

    inout wire [PORT_SIZE-1:0] sscDataN,

    inout wire OWB,
    output wire OWB_DIS_B,
    output wire sscTxRxControl_B,

    // User ports ends
    // Do not modify the ports beyond this line

    // Ports of Axi Slave Bus Interface S_AXIL
    input wire  s_axil_aclk,
    input wire  s_axil_aresetn,
    input wire [C_S_AXIL_ADDR_WIDTH-1 : 0] s_axil_awaddr,
    input wire [2 : 0] s_axil_awprot,
    input wire  s_axil_awvalid,
    output wire  s_axil_awready,
    input wire [C_S_AXIL_DATA_WIDTH-1 : 0] s_axil_wdata,
    input wire [(C_S_AXIL_DATA_WIDTH/8)-1 : 0] s_axil_wstrb,
    input wire  s_axil_wvalid,
    output wire  s_axil_wready,
    output wire [1 : 0] s_axil_bresp,
    output wire  s_axil_bvalid,
    input wire  s_axil_bready,
    input wire [C_S_AXIL_ADDR_WIDTH-1 : 0] s_axil_araddr,
    input wire [2 : 0] s_axil_arprot,
    input wire  s_axil_arvalid,
    output wire  s_axil_arready,
    output wire [C_S_AXIL_DATA_WIDTH-1 : 0] s_axil_rdata,
    output wire [1 : 0] s_axil_rresp,
    output wire  s_axil_rvalid,
    input wire  s_axil_rready
  );

  // Instantiation of Axi Bus Interface S_AXIL
  ssc_owb_S_AXIL # (
                   .C_S_AXI_DATA_WIDTH(C_S_AXIL_DATA_WIDTH),
                   .C_S_AXI_ADDR_WIDTH(C_S_AXIL_ADDR_WIDTH),
                   .PORT_SIZE(PORT_SIZE)
                 ) ssc_owb_S_AXIL_inst (
                   .S_AXI_ACLK(s_axil_aclk_buf),
                   .S_AXI_ARESETN(s_axil_aresetn),
                   .S_AXI_AWADDR(s_axil_awaddr),
                   .S_AXI_AWPROT(s_axil_awprot),
                   .S_AXI_AWVALID(s_axil_awvalid),
                   .S_AXI_AWREADY(s_axil_awready),
                   .S_AXI_WDATA(s_axil_wdata),
                   .S_AXI_WSTRB(s_axil_wstrb),
                   .S_AXI_WVALID(s_axil_wvalid),
                   .S_AXI_WREADY(s_axil_wready),
                   .S_AXI_BRESP(s_axil_bresp),
                   .S_AXI_BVALID(s_axil_bvalid),
                   .S_AXI_BREADY(s_axil_bready),
                   .S_AXI_ARADDR(s_axil_araddr),
                   .S_AXI_ARPROT(s_axil_arprot),
                   .S_AXI_ARVALID(s_axil_arvalid),
                   .S_AXI_ARREADY(s_axil_arready),
                   .S_AXI_RDATA(s_axil_rdata),
                   .S_AXI_RRESP(s_axil_rresp),
                   .S_AXI_RVALID(s_axil_rvalid),
                   .S_AXI_RREADY(s_axil_rready),
                   .CLK_50MHZ(clk_5mhz_buf),
                   .DQ_CONTROL(DQ_CONTROL),
                   .OWB_OUT(OWB_OUT),
                   .OWB_IN(OWB_IN),
                   .OWB_DIS(OWB_DIS),
                   .sscTxRxControl(sscTxRxControl),
                   .portDir(portDir),
                   .sscSync1(sscSync1),
                   .sscClk1(sscClk1),
                   .sscData1In(sscData1In),
                   .sscData1Out(sscData1Out)
                 );

  // Add user logic here

  wire [PORT_SIZE-1:0] portDir;
  wire [PORT_SIZE-1:0] sscSync1;
  wire [PORT_SIZE-1:0] sscClk1;

  wire [PORT_SIZE-1:0] sscData1In;
  wire [PORT_SIZE-1:0] sscData1Out;

  clk_10mhz clk_10mhz(
              .clk_out1(s_axil_aclk_buf), // Clock out ports
              .clk_out2(clk_5mhz_buf),    // Clock out ports
              .reset(!s_axil_aresetn),    // Status and control signals
              .locked(),
              .clk_in1(s_axil_aclk)       // Clock in ports
            );

  generate genvar i;
    for(i = 0; i < PORT_SIZE; i = i + 1)
    begin: port_generation

      OBUF # (
             .DRIVE(12),             // Specify the output drive strength
             .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
             .SLEW("SLOW")           // Specify the output slew rate
           ) OBUFDS_sync (
             .O(sscSyncN[i]),        // Diff_p output (connect directly to top-level port)
             .I(sscSync1[i])         // Buffer input
           );

      OBUF # (
             .DRIVE(12),             // Specify the output drive strength
             .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
             .SLEW("SLOW")           // Specify the output slew rate
           ) OBUFDS_clk (
             .O(sscClkN[i]),         // Diff_p output (connect directly to top-level port)
             .I(sscClk1[i])          // Buffer input
           );

      IOBUF # (
              .DRIVE(12),             // Specify the output drive strength
              .IBUF_LOW_PWR("FALSE"), // Low Power - "TRUE", High Performance = "FALSE"
              .IOSTANDARD("DEFAULT"), // Specify the I/O standard
              .SLEW("SLOW")           // Specify the output slew rate
            ) IOBUFDS_data (
              .O(sscData1In[i]),      // Buffer output
              .IO(sscDataN[i]),       // Diff_p inout (connect directly to top-level port)
              .I(sscData1Out[i]),     // Buffer input
              .T(~portDir[i])         // 3-state enable input, high=input, low=output
            );
    end
  endgenerate

  IOBUF # (
          .DRIVE(12),             // Specify the output drive strength
          .IBUF_LOW_PWR("FALSE"), // Low Power - "TRUE", High Performance = "FALSE"
          .IOSTANDARD("DEFAULT"), // Specify the I/O standard
          .SLEW("SLOW")           // Specify the output slew rate
        ) IOBUF_inst (
          .O(OWB_IN),             // Buffer output
          .IO(OWB),               // Buffer inout port (connect directly to top-level port)
          .I(OWB_OUT),            // Buffer input
          .T(DQ_CONTROL)          // 3-state enable input, high=input, low=output
        );

  OBUF # (
         .DRIVE(12),             // Specify the output drive strength
         .IOSTANDARD("DEFAULT"), // Specify the I/O standard
         .SLEW("SLOW")           // Specify the output slew rate
       ) IOBUF_dis_inst (
         .O(OWB_DIS_B),          // Buffer output
         .I(OWB_DIS)             // Buffer input
       );
  OBUF # (
         .DRIVE(12),             // Specify the output drive strength
         .IOSTANDARD("DEFAULT"), // Specify the I/O standard
         .SLEW("SLOW")           // Specify the output slew rate
       ) IOBUF_txrx_inst (
         .O(sscTxRxControl_B),   // Buffer output
         .I(sscTxRxControl)      // Buffer input
       );


  // User logic ends

endmodule

`timescale 1 ns / 1 ps

`define WRITE       1'b1
`define READ        1'b0

`define OWBBASE     10'h320
`define OWBStart    `OWBBASE
`define OWBEnable   (`OWBBASE + 8'h0E)
`define OWBEnd      (`OWBBASE + 8'h0F)
`define OWBReset    `OWBEnd

`define LOW         1'b0
`define HIGH        1'b1

`define ENABLE      1'b1
`define DISABLE     1'b0

module ssc_owb_S_AXIL #
  (
    // Users to add parameters here

    parameter integer PORT_SIZE  = 25,

    // User parameters ends
    // Do not modify the parameters beyond this line

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH  = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH  = 10
  )
  (
    // Users to add ports here
    input wire CLK_50MHZ,

    output wire [PORT_SIZE-1:0] portDir,
    output wire [PORT_SIZE-1:0] sscSync1,
    output wire [PORT_SIZE-1:0] sscClk1,

    input wire  [PORT_SIZE-1:0] sscData1In,
    output wire [PORT_SIZE-1:0] sscData1Out,

    input wire  OWB_IN,
    output wire OWB_OUT,
    output wire DQ_CONTROL,

    // User ports ends
    // Do not modify the ports beyond this line

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input wire  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output wire  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave)
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire  S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output wire  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input wire  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output wire  S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output wire  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire  S_AXI_RREADY
  );

  // AXI4LITE signals
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]   axi_awaddr;
  reg    axi_awready;
  reg    axi_wready;
  reg [1 : 0]   axi_bresp;
  reg    axi_bvalid;
  reg [C_S_AXI_ADDR_WIDTH-1 : 0]   axi_araddr;
  reg    axi_arready;
  reg [C_S_AXI_DATA_WIDTH-1 : 0]   axi_rdata;
  reg [1 : 0]   axi_rresp;
  reg    axi_rvalid;

  // Example-specific design signals
  // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
  // ADDR_LSB is used for addressing 32/64 bit registers/memories
  // ADDR_LSB = 2 for 32 bits (n downto 2)
  // ADDR_LSB = 3 for 64 bits (n downto 3)
  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 7;
  localparam integer ADDR_DIV = 3;
  //----------------------------------------------
  //-- Signals for user logic register space example
  //------------------------------------------------
  reg [C_S_AXI_DATA_WIDTH-1:0] statusReg        [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscLengthReg     [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscCommandReg    [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscWriteUpperReg [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscWriteLowerReg [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscReadUpperReg  [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscReadLowerReg  [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] sscClkDivider    [PORT_SIZE-1:0];
  reg [C_S_AXI_DATA_WIDTH-1:0] owmStatus;
  reg [C_S_AXI_DATA_WIDTH-1:0] owmAddress;
  reg [C_S_AXI_DATA_WIDTH-1:0] owmWriteReg;
  reg [C_S_AXI_DATA_WIDTH-1:0] owmReadReg;
  wire   slv_reg_rden;
  wire   slv_reg_wren;
  reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
  integer   byte_index;
  integer   port_index;
  reg   aw_en;

  wire [ADDR_DIV-1:0]                 ar_port_reg_bits;
  wire [OPT_MEM_ADDR_BITS-ADDR_DIV:0] ar_port_bits;
  wire [ADDR_DIV-1:0]                 aw_port_reg_bits;
  wire [OPT_MEM_ADDR_BITS-ADDR_DIV:0] aw_port_bits;

  // I/O Connections assignments

  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RDATA   = axi_rdata;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;
  // Implement axi_awready generation
  // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
  // de-asserted when reset is low.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end
    else
    begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
      begin
        // slave is ready to accept write address when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_awready <= 1'b1;
        aw_en <= 1'b0;
      end
      else if (S_AXI_BREADY && axi_bvalid)
      begin
        aw_en <= 1'b1;
        axi_awready <= 1'b0;
      end
      else
      begin
        axi_awready <= 1'b0;
      end
    end
  end

  // Implement axi_awaddr latching
  // This process is used to latch the address when both
  // S_AXI_AWVALID and S_AXI_WVALID are valid.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awaddr <= 0;
    end
    else
    begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
      begin
        // Write Address latching
        axi_awaddr <= S_AXI_AWADDR;
      end
    end
  end

  // Implement axi_wready generation
  // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is
  // de-asserted when reset is low.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end
    else
    begin
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
      begin
        // slave is ready to accept write data when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_wready <= 1'b1;
      end
      else
      begin
        axi_wready <= 1'b0;
      end
    end
  end

  // Implement memory mapped register select and write logic generation
  // The write data is accepted and written to memory mapped registers when
  // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
  // select byte enables of slave registers while writing.
  // These registers are cleared when reset (active low) is applied.
  // Slave register write enable is asserted when valid address and data are available
  // and the slave is ready to accept the write address and write data.
  assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
  assign aw_port_reg_bits[ADDR_DIV-1:0] = axi_awaddr[ADDR_LSB+ADDR_DIV-1:ADDR_LSB];
  assign aw_port_bits[OPT_MEM_ADDR_BITS-ADDR_DIV:0] = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB+ADDR_DIV];

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      for ( port_index = 0; port_index < PORT_SIZE; port_index = port_index+1 )
      begin
        statusReg[port_index] <= 0;
        sscLengthReg[port_index] <= 0;
        sscCommandReg[port_index] <= 0;
        sscWriteUpperReg[port_index] <= 0;
        sscWriteLowerReg[port_index] <= 0;
        sscClkDivider[port_index] <= 0;
      end
      owmAddress <= 0;
      owmWriteReg <= 0;
    end
    else
    begin
      if (slv_reg_wren)
      begin
        if (aw_port_bits == 0)
        begin
          case(aw_port_reg_bits)
            3'h0:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  owmStatus[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h1:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  owmAddress[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h2:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  owmWriteReg[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            default:
              ;
          endcase
        end
        else if(aw_port_bits <= PORT_SIZE)
        begin
          case(aw_port_reg_bits)
            3'h0:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  statusReg[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h1:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  sscLengthReg[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h2:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  sscCommandReg[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h3:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  sscClkDivider[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h4:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  sscWriteLowerReg[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            3'h5:
              for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                if ( S_AXI_WSTRB[byte_index] == 1 )
                begin
                  sscWriteUpperReg[aw_port_bits-1][(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                end
            default:
              ;
          endcase
        end
        else
        begin
          for ( port_index = 0; port_index <= (C_S_AXI_DATA_WIDTH/8)-1; port_index = port_index+1 )
          begin
            statusReg[port_index] <= 0;
            sscLengthReg[port_index] <= 0;
            sscCommandReg[port_index] <= 0;
            sscWriteUpperReg[port_index] <= 0;
            sscWriteLowerReg[port_index] <= 0;
            sscClkDivider[port_index] <= 0;
          end
          owmStatus <= owmStatus;
          owmAddress <= owmAddress;
          owmWriteReg <= owmWriteReg;
        end
      end
    end
  end

  // Implement write response logic generation
  // The write response and response valid signals are asserted by the slave
  // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.
  // This marks the acceptance of address and indicates the status of
  // write transaction.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_bvalid <= 0;
      axi_bresp  <= 2'b0;
    end
    else
    begin
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
      begin
        // indicates a valid write response is available
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0; // 'OKAY' response
      end                   // work error responses in future
      else
      begin
        if (S_AXI_BREADY && axi_bvalid)
          //check if bready is asserted while bvalid is high)
          //(there is a possibility that bready is always asserted high)
        begin
          axi_bvalid <= 1'b0;
        end
      end
    end
  end

  // Implement axi_arready generation
  // axi_arready is asserted for one S_AXI_ACLK clock cycle when
  // S_AXI_ARVALID is asserted. axi_awready is
  // de-asserted when reset (active low) is asserted.
  // The read address is also latched when S_AXI_ARVALID is
  // asserted. axi_araddr is reset to zero on reset assertion.

  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end
    else
    begin
      if (~axi_arready && S_AXI_ARVALID)
      begin
        // indicates that the slave has acceped the valid read address
        axi_arready <= 1'b1;
        // Read address latching
        axi_araddr  <= S_AXI_ARADDR;
      end
      else
      begin
        axi_arready <= 1'b0;
      end
    end
  end

  // Implement axi_arvalid generation
  // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  // S_AXI_ARVALID and axi_arready are asserted. The slave registers
  // data are available on the axi_rdata bus at this instance. The
  // assertion of axi_rvalid marks the validity of read data on the
  // bus and axi_rresp indicates the status of read transaction.axi_rvalid
  // is deasserted on reset (active low). axi_rresp and axi_rdata are
  // cleared to zero on reset (active low).
  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end
    else
    begin
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
      begin
        // Valid read data is available at the read data bus
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b0; // 'OKAY' response
      end
      else if (axi_rvalid && S_AXI_RREADY)
      begin
        // Read data is accepted by the master
        axi_rvalid <= 1'b0;
      end
    end
  end

  wire [PORT_SIZE-1:0] sscBusy;
  wire [47:0]          sscReadOut [PORT_SIZE-1:0];
  wire [47:0]          sscWriteReg [PORT_SIZE-1:0];

  reg  [PORT_SIZE-1:0] sscGo  = {PORT_SIZE{1'b0}};
  reg  [PORT_SIZE-1:0] sscDir = {PORT_SIZE{`WRITE}};

  wire [7:0] owmReadOut;
  wire       IORC = owmStatus[1];
  wire       IOWC = owmStatus[0];


  // Implement memory mapped register select and read logic generation
  // Slave register read enable is asserted when valid address is available
  // and the slave is ready to accept the read address.
  assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
  assign ar_port_reg_bits[ADDR_DIV-1:0] = axi_araddr[ADDR_LSB+ADDR_DIV-1:ADDR_LSB];
  assign ar_port_bits[OPT_MEM_ADDR_BITS-ADDR_DIV:0] = axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB+ADDR_DIV];
  always @(*)
  begin
    // Address decoding for reading registers
    if(ar_port_bits == 0)
    begin
      case(ar_port_reg_bits)
        3'h0:
          reg_data_out <= owmStatus;
        3'h1:
          reg_data_out <= owmAddress;
        3'h2:
          reg_data_out <= owmWriteReg;
        3'h3:
          reg_data_out <= owmReadOut;
        default:
          reg_data_out <= 0;
      endcase
    end
    else if(ar_port_bits <= PORT_SIZE)
    begin
      case(ar_port_reg_bits)
        3'h0:
          reg_data_out <= {{C_S_AXI_DATA_WIDTH - 3{1'b0}}, sscBusy[ar_port_bits-1], sscDir[ar_port_bits-1], sscGo[ar_port_bits-1]};
        3'h1:
          reg_data_out <= sscLengthReg[ar_port_bits-1];
        3'h2:
          reg_data_out <= sscCommandReg[ar_port_bits-1];
        3'h3:
          reg_data_out <= sscClkDivider[ar_port_bits-1];
        3'h4:
          reg_data_out <= sscWriteLowerReg[ar_port_bits-1];
        3'h5:
          reg_data_out <= sscWriteUpperReg[ar_port_bits-1];
        3'h6:
          reg_data_out <= sscReadLowerReg[ar_port_bits-1];
        3'h7:
          reg_data_out <= sscReadUpperReg[ar_port_bits-1];
        default:
          reg_data_out <= 0;
      endcase
    end
    else
    begin
      reg_data_out <= 0;
    end
  end

  // Output register or memory read data
  always @( posedge S_AXI_ACLK )
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_rdata  <= 0;
    end
    else
    begin
      // When there is a valid read address (S_AXI_ARVALID) with
      // acceptance of read address by the slave (axi_arready),
      // output the read dada
      if (slv_reg_rden)
      begin
        axi_rdata <= reg_data_out;     // register read data
      end
    end
  end

  // Add user logic here
  genvar i;
  generate
    for (i = 0; i < PORT_SIZE; i = i + 1)
    begin: ssc_read_generation
      always@(negedge sscBusy[i])
      begin
        sscReadLowerReg[i] <= sscReadOut[i][31:0];
        sscReadUpperReg[i] <= sscReadOut[i][47:32];
      end
    end
  endgenerate

  generate
    for (i = 0; i < PORT_SIZE; i = i + 1)
    begin: ssc_write_generation
      assign sscWriteReg[i] = {sscWriteUpperReg[i], sscWriteLowerReg[i]};
    end
  endgenerate

  always@(posedge S_AXI_ACLK)
  begin
    if ( S_AXI_ARESETN == 1'b0 )
    begin
      for (port_index = 0; port_index < PORT_SIZE; port_index = port_index + 1)
      begin
        sscGo[port_index]  <= 1'b0;
        sscDir[port_index] <= `WRITE;
      end
    end
    else
    begin
      for (port_index = 0; port_index < PORT_SIZE; port_index = port_index + 1)
      begin
        if (sscBusy[port_index])
          sscGo[port_index] <= 0;
      end
      if (slv_reg_wren)
      begin
        if((1 <= aw_port_bits) && (aw_port_bits <= PORT_SIZE))
        begin
          case(aw_port_reg_bits)
            3'h0:
              if (!sscBusy[aw_port_bits-1])
              begin
                sscGo[aw_port_bits-1] <= S_AXI_WDATA[0];
                sscDir[aw_port_bits-1] <= S_AXI_WDATA[1];
              end
            default:
              ;
          endcase
        end
      end
    end
  end

  generate genvar j;
    for(j = 0; j < PORT_SIZE; j = j + 1)
    begin: ssc_generation
      ssc_core ssc_core (
                 .CLK(CLK_50MHZ),

                 .sscDir(sscDir[j]),
                 .sscDataLength(sscLengthReg[j]),
                 .sscCommand(sscCommandReg[j]),
                 .sscClkDivider(sscClkDivider[j]),
                 .sscGo(sscGo[j]),

                 .portDir(portDir[j]),
                 .sscBusy(sscBusy[j]),
                 .sscSync1(sscSync1[j]),
                 .sscClk1(sscClk1[j]),

                 .sscDataIn(sscWriteReg[j]),
                 .sscDataOut(sscReadOut[j]),

                 .sscData1In(sscData1In[j]),
                 .sscData1Out(sscData1Out[j])
               );
    end
  endgenerate

  // A block of combinatorial logic to perform the chip select of the owb
  wire OWBLR, OWBUR;

  assign OWBLR = (owmAddress >= `OWBStart) ? `ENABLE : `DISABLE;
  assign OWBUR = (owmAddress <= `OWBEnd) ? `ENABLE : `DISABLE;
  assign OWBCSn = ~(OWBLR && OWBUR);

  // A block to take care of the reset of the module. The reset is activated
  // by performing a write to the endAddress.
  reg MR = `LOW;
  assign MRInt = ((~IOWC == `LOW) && (owmAddress == `OWBReset)) ? `ENABLE : `DISABLE;

  always @(posedge CLK_50MHZ)
  begin
    if(MRInt)
      MR <= `ENABLE;
    else
      MR <= `DISABLE;
  end

  one_wire_bus one_wire_bus (
                 .ADDRESS(owmAddress[2:0]),
                 .ADS_bar(`LOW),
                 .CLK(CLK_50MHZ),
                 .EN_bar(OWBCSn),
                 .MR(MR),
                 .RD_bar(~IORC),
                 .WR_bar(~IOWC),
                 .INTR(),
                 .STPZ(),
                 .DOUT(owmReadOut),
                 .DIN(owmWriteReg),
                 .DQ_CONTROL(DQ_CONTROL),
                 .OWB_IN(OWB_IN),
                 .OWB_OUT(OWB_OUT)
               );

  // User logic ends

endmodule

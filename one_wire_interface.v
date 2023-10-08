//--------------------------------------------------------------------------
//                                                                        --
//  OneWireMaster                                                         --
//   A synthesizable 1-wire master peripheral                             --
//   Copyright 1999-2005 Dallas Semiconductor Corporation                 --
//                                                                        --
//--------------------------------------------------------------------------
//                                                                        --
//  Purpose:  Provides timing and control of Dallas 1-wire bus            --
//            through a memory-mapped peripheral                          --
//  File:     one_wire_interface.v                                        --
//  Date:     February 1, 2005                                            --
//  Version:  v2.100                                                      --
//  Authors:  Rick Downs and Charles Hill,                                --
//            Dallas Semiconductor Corporation                            --
//                                                                        --
//  Note:     This source code is available for use without license.      --
//            Dallas Semiconductor is not responsible for the             --
//            functionality or utility of this product.                   --
//                                                                        --
//  REV:      Added BIT_CTL to COMMAND reg - GAG                          --
//            Added STPEN to COMMAND reg - GAG                            --
//            Combined CLK_DIV register bits into one block - GAG         --
//            Added CLK_EN to CLK_DIV reg - GAG                           --
//            Added CONTROL reg and moved appropriate bits into it - GAG  --
//            Added EN_FOW and changed dqz to FOW - GAG                   --
//            Added STP_SPLY - GAG                                        --
//            Significant changes to improve synthesis - English          --
//            Ported to Verilog - Sandelin                                --
//--------------------------------------------------------------------------

module one_wire_interface
  (
    input [2:0] ADDRESS,
    input [7:0] DIN,
    input       ADS_bar,
    input       clear_interrupts,
    input       DQ_IN,
    input       EN_bar,
    input       FSM_CLK,
    input       MR,
    input       OneWireIO_eq_Load,
    input       pdr,
    input       OW_LOW,   // ow bus low interrupt
    input       OW_SHORT, // ow bus shorted interrupt
    input       rbf,      // receive buffer full int
    input       RD_bar,
    input       reset_owr,
    input       rsrf,     // receive shift reg full int
    input       temt,
    input       WR_bar,
    input [7:0] rcvr_buffer,

    output       rbf_reset, // clear signal for rbf
    output       DDIR,
    output [7:0] DOUT,

    output reg       BIT_CTL           = 0, // enable signle bit outputs
    output reg       CLK_EN            = 0, // clock divider enable
    output reg       clr_activate_intr = 0,
    output reg       div_1             = 0, // divider select bit 1
    output reg       div_2             = 0, // divider select bit 2
    output reg       div_3             = 0, // divider select bit 3
    output reg       EN_FOW            = 0, // enable force OW functionality
    output reg       EOWL              = 0, // enable one wire bus low interrupt
    output reg       EOWSH             = 0, // enable one wire short interrupt
    output reg       epd               = 0, // enable presence detect interrupt
    output reg       erbf              = 0, // enable receive buffer full interrupt
    output reg       ersf              = 0, // enable receive shift register full int.
    output reg       etbe              = 0, // enable transmit buffer empty interrupt
    output reg       etmt              = 0, // enable transmit shift outputister empty int.
    output reg       FOW               = 0, // force OW value to opposite value
    output reg       ias               = 0, // INTR active state
    output reg       LLM               = 0, // long line mode enable
    output reg       OD                = 0, // enable overdrive
    output reg       owr               = 0,
    output reg       pd                = 0,
    output reg       PPM               = 0, // presence pulse masking enable
    output reg       pre_0             = 0, // prescaler select bit 0
    output reg       pre_1             = 0, // prescaler select bit 1
    output reg       sr_a              = 0,
    output reg       STP_SPLY          = 0, // enable strong pull up supply mode
    output reg       STPEN             = 0, // enable strong pull up output
    output reg       tbe               = 0,
    output reg [7:0] xmit_buffer       = 0  // transmit buffer
  );

  wire      read_op;
  wire      write_op;
  reg [2:0] sel_addr = 0;         // selected register address

  // command register
  wire [7:0] MD_REG = {4'b0, DQ_IN, FOW, sr_a, owr};

  reg xmit_buffer_full  = 0;
  reg set_activate_intr = 0;

  // Control register
  wire [7:0] CONTRL_REG = {1'b0, OD, BIT_CTL, STP_SPLY, STPEN, EN_FOW, PPM, LLM};

  // interrupt register
  wire [7:0] INT_REG = {OW_LOW, OW_SHORT, rsrf, rbf, temt, tbe, pdr, pd};

  // interrupt enable register
  wire [7:0] INTEN_REG = {EOWL, EOWSH, ersf, erbf, etmt, etbe, ias, epd};

  // clock divisor register
  wire [7:0] CLKDV_REG = {CLK_EN, 2'b0, div_3, div_2, div_1, pre_1, pre_0};

  //--------------------------------------------------------------------------
  //  read/write process
  //--------------------------------------------------------------------------

  assign read_op = ~EN_bar && ~MR && ~RD_bar && WR_bar;
  wire   read_op_n = ~read_op;

  assign write_op = ~EN_bar && ~MR && ~WR_bar && RD_bar;
  wire   write_op_n = ~write_op;

  always @(posedge MR or posedge WR_bar)
    if(MR)            // removed reset interrupt reg when chip not enabled
      begin
        EOWL        = 1'b0;
        EOWSH       = 1'b0;
        ersf        = 1'b0;
        erbf        = 1'b0;
        etmt        = 1'b0;
        etbe        = 1'b0;
        ias         = 1'b0;
        epd         = 1'b0;
        xmit_buffer = 0;
      end
    else
      if(!EN_bar && RD_bar)
        case(sel_addr)
          3'b001:
            xmit_buffer = DIN;
          3'b011:             //removed ias to hard wire active low - GAG
                              //added ias to remove hardwire - SKH
            begin
              EOWL  = DIN[7];
              EOWSH = DIN[6];
              ersf  = DIN[5];
              erbf  = DIN[4];
              etmt  = DIN[3];
              etbe  = DIN[2];
              ias   = DIN[1];
              epd   = DIN[0];
            end
        endcase

  assign DDIR = read_op;

  //
  // Modified DOUT to always drive the current register value out
  // based on the address value
  //
  assign DOUT =
    (sel_addr == 3'b000) ? {4'b0000, DQ_IN, FOW, sr_a, owr}:
    (sel_addr == 3'b001) ? rcvr_buffer:
    (sel_addr == 3'b010) ? {OW_LOW, OW_SHORT, rsrf, rbf, temt, tbe, pdr, pd}:
    (sel_addr == 3'b011) ? {EOWL, EOWSH, ersf, erbf, etmt, etbe, ias, epd}:
    (sel_addr == 3'b100) ? {CLK_EN, 2'b00, div_3, div_2, div_1, pre_1, pre_0}:
    (sel_addr == 3'b101) ? {1'b0, OD, BIT_CTL, STP_SPLY, STPEN, EN_FOW, PPM, LLM}:
    8'h00;


  //
  // Clock divisor register
  //
  // synopsys async_set_reset MR
  always @(posedge MR or posedge WR_bar)
    if(MR)
      begin
        pre_0  = 1'b0;
        pre_1  = 1'b0;
        div_1  = 1'b0;
        div_2  = 1'b0;
        div_3  = 1'b0;
        CLK_EN = 1'b0;
      end
    else
    if(!EN_bar && RD_bar)
      if(sel_addr == 3'b100)
        begin
          pre_0  = DIN[0];
          pre_1  = DIN[1];
          div_1  = DIN[2];
          div_2  = DIN[3];
          div_3  = DIN[4];
          CLK_EN = DIN[7];
        end

  wire CLR_OWR = MR || reset_owr;

  //
  // Command reg writes are handled in the next two sections
  // Bit 0 needs to be separate for the added clearing mechanism
  //
  always @(posedge CLR_OWR or posedge WR_bar)
    if(CLR_OWR)
      owr <= 1'b0;
    else
      if(EN_bar == 0 && RD_bar == 1 && sel_addr == 3'b000)
        owr <= DIN[0];

  //
  // Bits 1-7's write routine
  //
  always @(posedge MR or posedge WR_bar)
    if(MR)
      begin
        FOW  <= 1'b0;
        sr_a <= 1'b0;
      end
    else
      if(EN_bar == 0 && RD_bar == 1 && sel_addr == 3'b000)
        begin
            sr_a <= DIN[1];
            FOW  <= DIN[2];
        end

  //
  // The Control reg writes are handled here
  //
  always @(posedge MR or posedge WR_bar)
    if(MR)
      begin
        OD       <= 1'b0;
        BIT_CTL  <= 1'b0;
        STP_SPLY <= 1'b0;
        STPEN    <= 1'b0;
        EN_FOW   <= 1'b0;
        PPM      <= 1'b0;
        LLM      <= 1'b0;
      end
    else
      if(EN_bar == 0 && RD_bar == 1 && sel_addr == 3'b101)
        begin
          OD       <= DIN[6];
          BIT_CTL  <= DIN[5];
          STP_SPLY <= DIN[4];
          STPEN    <= DIN[3];
          EN_FOW   <= DIN[2];
          PPM      <= DIN[1];
          LLM      <= DIN[0];
        end


  //--------------------------------------------------------------------------
  //  Transparent address latch
  //--------------------------------------------------------------------------

  always @(ADS_bar or ADDRESS or EN_bar)
    if(!ADS_bar && !EN_bar)
      sel_addr = ADDRESS;

  //--------------------------------------------------------------------------
  // Interrupt flag register clearing (What is not handled in onewiremaster.v)
  //--------------------------------------------------------------------------

  wire acint_reset = MR || (clear_interrupts); // synchronized
                                               // set_activate_intr - SDS

  always @(posedge acint_reset or posedge RD_bar)
    if(acint_reset)
      clr_activate_intr <= 1'b0;
    else
      if(EN_bar == 0 && WR_bar == 1 && sel_addr == 3'b010)
        clr_activate_intr <= 1'b1;

  assign rbf_reset = (read_op && (sel_addr == 3'b001));

  always @(posedge MR or posedge FSM_CLK)
    if (MR)
      pd <= 1'b0;
    else if (reset_owr)
      pd <= 1'b1;
    else if (clr_activate_intr)  // This causes pd to wait for a clk to clear
      pd <= 1'b0;
    else
      pd <= pd;

  //
  // The following two blocks handle tbe
  // The lower is the psuedo asynch portion which is synched up
  //  in the upper section.
  //
  always @(posedge FSM_CLK or posedge MR)
    if (MR)
      tbe <= 1'b1;
    else
      tbe <= ~xmit_buffer_full;

  always @(posedge MR or posedge WR_bar or posedge OneWireIO_eq_Load)
    if(MR)
      xmit_buffer_full <= 1'b0;
    else if (OneWireIO_eq_Load)
      xmit_buffer_full <= 1'b0;
    else
      if(EN_bar == 0 && RD_bar == 1 && sel_addr == 3'b001)
        xmit_buffer_full <= 1'b1;

endmodule // one_wire_interface

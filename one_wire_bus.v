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
//  File:     OWM.v                                                       --
//  Date:     February 1, 2005                                            --
//  Version:  v2.100                                                      --
//  Authors:  Rick Downs and Charles Hill,                                --
//            Dallas Semiconductor Corporation                            --
//                                                                        --
//  Note:     This source code is available for use without license.      --
//            Dallas Semiconductor is not responsible for the             --
//            functionality or utility of this product.                   --
//                                                                        --
//  Rev:      Added Overdrive, Bit control, and strong pullup control     --
//            along with many other features described in the new spec    --
//            released version 2.0  9/5/01 - Greg Glennon                 --
//            Significant changes to improve synthesis - English          --
//            Ported to Verilog - Sandelin                                --
//--------------------------------------------------------------------------

module one_wire_bus
  (
    input [2:0]  ADDRESS, // SFR address
    input        ADS_bar, // address latch control (active low)
    input        CLK,     // system clock
    input        EN_bar,  // SFR access enable (active low)
    input        MR,      // master reset
    input        RD_bar,  // SFR read (active low)
    input        WR_bar,  // SFR write (active low)
    input [7:0]  DIN,

    output       INTR,    // one wire master interrupt
    output       STPZ,    // strong pullup (active low)
    output       DQ_CONTROL,
    output [7:0] DOUT,

    input        OWB_IN,   // OW pin
    output       OWB_OUT   // OW pin
  );

  wire [7:0] rcvr_buffer;
  wire [7:0] xmit_buffer;

  one_wire_io one_wire_io (
    .CLK(CLK),
    .DDIR(DDIR),
    .DQ_CONTROL(DQ_CONTROL),
    .MR(MR),
    .DQ_IN(DQ_IN),
    .OWB_IN(OWB_IN),
    .OWB_OUT(OWB_OUT)
  );

  clk_prescaler clk_prescaler (
    .CLK(CLK),
    .CLK_EN(CLK_EN),
    .div_1(div_1),
    .div_2(div_2),
    .div_3(div_3),
    .MR(MR),
    .pre_0(pre_0),
    .pre_1(pre_1),
    .clk_1us(clk_1us)
  );

  one_wire_interface one_wire_interface (
    .ADDRESS(ADDRESS),
    .ADS_bar(ADS_bar),
    .clear_interrupts(clear_interrupts),
    .DIN(DIN),
    .DQ_IN(DQ_IN),
    .EN_bar(EN_bar),
    .FSM_CLK(FSM_CLK),
    .MR(MR),
    .OneWireIO_eq_Load(OneWireIO_eq_Load),
    .pdr(pdr),
    .OW_LOW(OW_LOW),
    .OW_SHORT(OW_SHORT),
    .rbf(rbf),
    .rcvr_buffer(rcvr_buffer),
    .RD_bar(RD_bar),
    .reset_owr(reset_owr),
    .rsrf(rsrf),
    .temt(temt),
    .WR_bar(WR_bar),
    .BIT_CTL(BIT_CTL),
    .CLK_EN(CLK_EN),
    .clr_activate_intr(clr_activate_intr),
    .DDIR(DDIR),
    .div_1(div_1),
    .div_2(div_2),
    .div_3(div_3),
    .DOUT(DOUT),
    .EN_FOW(EN_FOW),
    .EOWL(EOWL),
    .EOWSH(EOWSH),
    .epd(epd),
    .erbf(erbf),
    .ersf(ersf),
    .etbe(etbe),
    .etmt(etmt),
    .FOW(FOW),
    .ias(ias),
    .LLM(LLM),
    .OD(OD),
    .owr(owr),
    .pd(pd),
    .PPM(PPM),
    .pre_0(pre_0),
    .pre_1(pre_1),
    .rbf_reset(rbf_reset),
    .sr_a(sr_a),
    .STP_SPLY(STP_SPLY),
    .STPEN(STPEN),
    .tbe(tbe),
    .xmit_buffer(xmit_buffer)
  );

  one_wire_master one_wire_master (
    .BIT_CTL(BIT_CTL),
    .clk_1us(clk_1us),
    .clr_activate_intr(clr_activate_intr),
    .DQ_IN(DQ_IN),
    .EN_FOW(EN_FOW),
    .EOWL(EOWL),
    .EOWSH(EOWSH),
    .epd(epd),
    .erbf(erbf),
    .ersf(ersf),
    .etbe(etbe),
    .etmt(etmt),
    .FOW(FOW),
    .ias(ias),
    .LLM(LLM),
    .MR(MR),
    .OD(OD),
    .owr(owr),
    .pd(pd),
    .PPM(PPM),
    .rbf_reset(rbf_reset),
    .sr_a(sr_a),
    .STP_SPLY(STP_SPLY),
    .STPEN(STPEN),
    .tbe(tbe),
    .xmit_buffer(xmit_buffer),
    .clear_interrupts(clear_interrupts),
    .DQ_CONTROL(DQ_CONTROL),
    .FSM_CLK(FSM_CLK),
    .INTR(INTR),
    .OneWireIO_eq_Load(OneWireIO_eq_Load),
    .OW_LOW(OW_LOW),
    .OW_SHORT(OW_SHORT),
    .pdr(pdr),
    .rbf(rbf),
    .rcvr_buffer(rcvr_buffer),
    .reset_owr(reset_owr),
    .rsrf(rsrf),
    .STPZ(STPZ),
    .temt(temt)
  );

endmodule
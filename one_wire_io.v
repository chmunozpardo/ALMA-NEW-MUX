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
//  File:     one_wire_io.v                                               --
//  Date:     February 1, 2005                                            --
//  Version:  v2.100                                                      --
//  Authors:  Rick Downs and Charles Hill,                                --
//            Dallas Semiconductor Corporation                            --
//                                                                        --
//  Note:     This source code is available for use without license.      --
//            Dallas Semiconductor is not responsible for the             --
//            functionality or utility of this product.                   --
//                                                                        --
//  Rev:      Significant changes to improve synthesis - English          --
//            Ported to Verilog - Sandelin                                --
//--------------------------------------------------------------------------

module one_wire_io
  (
    input      CLK,
    input      DDIR,
    input      DQ_CONTROL,
    input      MR,
    input      OWB_IN,

    output     OWB_OUT,
    output reg DQ_IN = 0
  );

  wire DQ = (DQ_CONTROL == 1) ? OWB_IN : OWB_OUT;
  assign OWB_OUT = 1'b0;

  //
  // Synchronize DQ_IN
  //
  always @(posedge MR or negedge CLK)
    if (MR)
      DQ_IN <= 1'b1;
    else
      DQ_IN <= DQ;
endmodule // one_wire_io

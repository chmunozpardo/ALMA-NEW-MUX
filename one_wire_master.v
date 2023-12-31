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
//  File:     OneWireMaster.v                                             --
//  Date:     February 1, 2005                                            --
//  Version:  v2.100                                                      --
//  Authors:  Rick Downs and Charles Hill,                                --
//            Dallas Semiconductor Corporation                            --
//                                                                        --
//  Note:     This source code is available for use without license.      --
//            Dallas Semiconductor is not responsible for the             --
//            functionality or utility of this product.                   --
//                                                                        --
//  REV:      Updated 1-Wire timings to match App Note 126 - SKH          --
//            Added in Async MR of DQ_CONTROL - GAG                       --
//            Changed WriteZero TimeSlotCnt to 60 instead of only 30 to   --
//            match OneWire Spec. - GAG                                   --
//            Added in bit control mode, left dqz for other function - GAG--
//            Added strong pullup enable signal - GAG                     --
//            Modified pd so it will not fire until the entire PD routine --
//            has completed - GAG                                         --
//            Added OW_LOW interrupt and OW_SHORT interrupt - GAG         --
//            Added PPM and LLM for long line situations - GAG            --
//            Changed logic for rsrf and rbf int flags - GAG              --
//            Significant changes to improve synthesis - English          --
//            Ported to Verilog - Sandelin                                --
//--------------------------------------------------------------------------

module one_wire_master
  (
    input       BIT_CTL,         // enable only single bit transmitions
    input       clk_1us,         // 1us reference clock
    input       clr_activate_intr,
    input       DQ_IN,           // OW data input
    input       EN_FOW,          // enable force OW functionality
    input       EOWL,            // enable One wire bus low interrupt
    input       EOWSH,           // enable One Wire bus short interrupt
    input       epd,             // enable presence detect interrupt
    input       erbf,            // enable receive buffer full interrupt
    input       ersf,            // enable receive shift register full int.
    input       etbe,            // enable transmit buffer empty interrupt
    input       etmt,            // enable transmit shift inputister empty int.
    input       FOW,             // Force OW value low
    input       ias,             // INTR active state
    input       LLM,             // long line mode enable
    input       MR,              // master reset
    input       OD,              // enable overdrive
    input       owr,             // one wire reset ???
    input       pd,              // presence detect interrupt
    input       PPM,             // presence pulse masking enable
    input       rbf_reset,       // clear for receive buffer full interrupt
    input       sr_a,            // search rom accelorator enable
    input       STP_SPLY,        // enable strong pull up supply mode
    input       STPEN,           // enable strong pull up output
    input       tbe,             // transmit buffer empty interrupt
    input [7:0] xmit_buffer,     // transmit buffer

    output           DQ_CONTROL,           // OW pulldown control
    output           FSM_CLK,              // state machine clk
    output           OneWireIO_eq_Load,
    output           STPZ,                 // Strong pullup control (active low)
    output reg       clear_interrupts = 0,
    output reg       INTR             = 0, // One wire master interrupt output signal
    output reg       OW_LOW           = 0, // One wire low interrupt
    output reg       OW_SHORT         = 0, // One wire short interrupt
    output reg       pdr              = 0, // presence detect result
    output reg       rbf              = 0, // receive buffer full int
    output reg       reset_owr        = 0, //
    output reg       rsrf             = 0, // receive shift reg full interrupt
    output reg       temt             = 0, // transmit shift reg empty interrupt
    output reg [7:0] rcvr_buffer      = 0  // receive register
  );

  //
  // Define the states
  //
  parameter [2:0] Idle       = 3'b000, // Idle
                  CheckOWR   = 3'b001, // Check for shorted OW
                  Reset_Low  = 3'b010, // Start reset
                  PD_Wait    = 3'b011, // release line for 1T
                  PD_Sample  = 3'b100, // sample line after slowest 1T over
                  Reset_High = 3'b101, // recover OW line level
                  PD_Force   = 3'b110, // mask the presence pulse
                  PD_Release = 3'b111; // recover OW line level

  parameter [4:0] IdleS       = 5'b00000, // Idle state
                  Load        = 5'b00001, // Load byte
                  CheckOW     = 5'b00010, // Check for shorted line
                  DQLOW       = 5'b00011, // Start of timeslot
                  WriteZero   = 5'b00100, // Write a zero to the 1-wire
                  WriteOne    = 5'b00101, // Write a one to the 1-wire
                  ReadBit     = 5'b00110, // Search Rom Accelerator read bit
                  FirstPassSR = 5'b00111, // Used by SRA
                  WriteBitSR  = 5'b01000, // Decide what bit value to write in SRA
                  WriteBit    = 5'b01001, // Writes the chosen bit in SRA
                  WaitTS      = 5'b01010, // Wait for end of time slot
                  IndexInc    = 5'b01011, // Increments bit index
                  UpdateBuff  = 5'b01100, // Updates states of rbf
                  ODWriteZero = 5'b01101, // Write a zero @ OD speed to OW
                  ODWriteOne  = 5'b01110, // Write a one @ OD speed to OW
                  ClrLowDone  = 5'b01111; // disable stpupz before pulldown


  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // micro-second count for bit transitions and sample
  parameter [6:0]                      // Standard speed
    bit_ts_writeone_high    = 7'b0000110, // release-1  @6 us
    bit_ts_writeone_high_ll = 7'b0001000, // rel-1-LLM  @8 us
    bit_ts_sample           = 7'b0001111, // sample     @15 us
    bit_ts_sample_ll        = 7'b0011000, // sample/llm @24 us
    bit_ts_writezero_high   = 7'b0111100, // release-0  @60 us
    bit_ts_end              = 7'b1000110, // end        @70 us
    bit_ts_end_ll           = 7'b1010000, // end        @80 us
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                                      // Overdrive speed
    // note that due to the state machine architecture, the
    // writeone_high_od and sample_od must be 1 and 2 us.
    // writezero_high_od and end_od are adjustable, so long
    // as writezero_high_od does not exceed a particular
    // 1-Wire device max low time.
    bit_ts_writeone_high_od  = 7'b0000001, // release-1 @1 us
    bit_ts_sample_od         = 7'b0000010, // sample    @2 us
    bit_ts_writezero_high_od = 7'b0001000, // release-0 @8 us
    bit_ts_end_od            = 7'b0001001; // end       @10 us

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // micro-second count for reset transitions
  parameter [10:0]                         // Standard speed
    reset_ts_release  = 11'b01001011000,   // release @600 us
    reset_ts_no_stpz  = 11'b01001100010,   // stpz=1  @610 us
    reset_ts_ppm      = 11'b01001101100,   // pp-mask @620 us
    reset_ts_sample   = 11'b01010011110,   // sample  @670 us
    reset_ts_llsample = 11'b01010101101,   // sample  @685 us
    reset_ts_ppm_end  = 11'b01010110010,   // ppm-end @690 us
    reset_ts_stpz     = 11'b01110110110,   // stpz    @950 us
    reset_ts_recover  = 11'b01111000000,   // recover @960 us
    reset_ts_end      = 11'b10000111000,   // end     @1080 us
                                           // Overdrive speed
    reset_ts_release_od = 11'b00001000110, // release @70 us
    reset_ts_no_stpz_od = 11'b00001001011, // stpz=1  @75 us
    reset_ts_sample_od  = 11'b00001001111, // sample  @79 us
    reset_ts_stpz_od    = 11'b00001101001, // stpz    @105 us
    reset_ts_recover_od = 11'b00001110011, // recover @115 us
    reset_ts_end_od     = 11'b00010000000; // end     @128 us
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  // interrupt register
  wire temt_ext;    // temt extended flag
  reg  set_rbf = 0; // set signal for rbf

  // interrupt enable register
  reg activate_intr         = 0;
  reg dly_clr_activate_intr = 0;

  reg SET_RSHRT  = 0; // set ow_short prior to ow reset
  reg SET_IOSHRT = 0; // set ow_short prior to tx a bit

  reg [7:0] xmit_shiftreg = 0; // transmit shift register
  reg [7:0] rcvr_shiftreg = 0; // receive shift register

  reg last_rcvr_bit  = 0; // active on index = 7 to begin shift to rbe
  reg byte_done      = 0;
  reg byte_done_flag = 0; // signals to stretch byte_done
  reg bdext1         = 0; // signals to stretch byte_done

  reg First    = 0;       // for Search ROM accelerator
  reg BitRead1 = 0;
  reg BitRead2 = 0;
  reg BitWrite = 0;

  reg [2:0] OneWireReset = 0;
  reg [4:0] OneWireIO    = 0;

  reg [3:0]  index       = 0;
  reg [6:0]  TimeSlotCnt = 0;
  reg [10:0] count       = 0;

  reg ROW          = 0;
  reg OD_DQH       = 0;
  reg PD_READ      = 0;
  reg LOW_DONE     = 0;
  reg DQ_IN_HIGH   = 0;
  reg DQ_CONTROL_F = 0;

  reg rbf_set      = 0;
  reg rsrf_reset   = 0;

  assign FSM_CLK = clk_1us;

  //
  //  1 wire control
  //
  assign DQ_CONTROL = MR ? 1'b1 : DQ_CONTROL_F;  //GAG added in asynch RESET

  always @(posedge FSM_CLK)                      //GAG added in ODWriteZero
    DQ_CONTROL_F <=
      ((EN_FOW == 1) && (FOW == 1)) ? 0:
      (OneWireReset == Reset_Low) ? 0:
      (OneWireReset == PD_Wait) ? 1:
      (OneWireReset == PD_Force) ? 0:
      (OneWireIO == DQLOW) ? 0:
      (OneWireIO == WriteZero) ? 0:
      (OneWireIO == ODWriteZero) ? 0:
      (OneWireIO == WriteBit) ? 0:
      1;

  assign OneWireIO_eq_Load = OneWireIO == Load;

  //
  // Strong Pullup control section - GAG
  // not pulling line low, not checking for pres detect, and
  // OW has recovered from read
  // SPLY is only for enabling STP when a slave requires high current
  //   and STP_SPLY is enabled
  //
  wire   SPLY = (STP_SPLY && (OneWireReset == Idle) && (OneWireIO == IdleS));
  assign STPZ = !(STPEN && DQ_CONTROL && DQ_IN_HIGH && (PD_READ || LOW_DONE || SPLY));

  always @(posedge MR or posedge FSM_CLK)
    if (MR)
      begin
        DQ_IN_HIGH <= 0;
        OD_DQH     <= 0;
      end
    else if (OD)
      if(DQ_IN && !DQ_IN_HIGH && !OD_DQH)
        begin
          DQ_IN_HIGH <= 1;
          OD_DQH     <= 1;
        end
      else if(OD_DQH && DQ_IN)
        DQ_IN_HIGH <= 0;
      else
        begin
          OD_DQH     <= 0;
          DQ_IN_HIGH <= 0;
        end
    else
      begin
        if(DQ_IN && !DQ_IN_HIGH)
          DQ_IN_HIGH <= 1;
        else if (DQ_IN && DQ_IN_HIGH)
          DQ_IN_HIGH <= DQ_IN_HIGH;
        else
          DQ_IN_HIGH <= 0;
      end

  //
  // Update receive buffer and the rsrf and rbf int flags
  //
  always @(posedge MR or posedge rbf_reset or posedge rbf_set)
    if (MR)
      rbf <= 0;
    else if (rbf_reset)  //note that rbf resets at the beginning of the RX buff read
      rbf <= 0;
    else
      rbf <= 1;

  always @(posedge MR or posedge FSM_CLK)
    if (MR)
      rsrf <= 1'b0;
    else
      if (last_rcvr_bit || BIT_CTL)
        begin
          if (OneWireIO == IndexInc)
            rsrf <= 1'b1;
          else if (rsrf_reset)
            rsrf <= 1'b0;
        end
      else if (rsrf_reset || (OneWireIO == DQLOW))
        rsrf <= 1'b0;

  always @(posedge FSM_CLK or posedge MR)
    if (MR)
      begin
        rcvr_buffer <= 0;
        rbf_set     <= 0;
      end
    else
      if (rsrf && !rbf)
        begin
          rcvr_buffer <= rcvr_shiftreg;
          rbf_set    <= 1'b1;
          rsrf_reset <= 1'b1;
        end
      else
        begin
          rbf_set <= 1'b0;
          if (!rsrf)
            rsrf_reset <= 1'b0;
        end

  //
  // Update OW shorted interrupt
  //
  always @(posedge MR or posedge FSM_CLK)
    if(MR)
      OW_SHORT <= 1'b0;
    else if (SET_RSHRT || SET_IOSHRT)
      OW_SHORT <= 1'b1;
    else if (clr_activate_intr)
      OW_SHORT <= 1'b0;
    else
      OW_SHORT <= OW_SHORT;

  //
  // Update OW bus low interrupt
  //
  always @(posedge MR or posedge FSM_CLK)
    if (MR)
      OW_LOW <= 0;
    else if (!DQ_IN && (OneWireReset == Idle) && (OneWireIO == IdleS))
      OW_LOW <= 1;
    else if (clr_activate_intr)
      OW_LOW <= 0;
    else
      OW_LOW <= OW_LOW;

  ///////////////////////////////////////////////////////////////
  // The following section handles the interrupt itself
  ///////////////////////////////////////////////////////////////

  //
  // Create clear interrupts
  //
  always @(posedge MR or posedge FSM_CLK)
    if (MR)
      clear_interrupts <= 1'b0;
    else
      clear_interrupts<=clr_activate_intr;

  wire acint_reset = MR || clr_activate_intr;

  //
  // Check for active interrupt
  //
  always @(posedge acint_reset or posedge FSM_CLK)
    if(acint_reset)
      activate_intr <= 1'b0;
    else
      case(1)
        pd && epd:
            activate_intr <= 1'b1;
        tbe && etbe && !temt:
            activate_intr <= 1'b1;
        temt_ext && etmt:
            activate_intr <= 1'b1;
        rbf && erbf:
            activate_intr <= 1'b1;
        rsrf && ersf:
            activate_intr <= 1'b1;
        OW_LOW && EOWL:
            activate_intr <= 1'b1;
        OW_SHORT && EOWSH:
            activate_intr <= 1'b1;
      endcase // case(1)

  //
  // Create INTR signal by checking for active interrupt and active
  // state of INTR
  //
  always @(activate_intr or ias)
    case({activate_intr,ias})
      2'b11: INTR <= 1'b1;
      2'b01: INTR <= 1'b0;
      2'b10: INTR <= 1'b1; // shughes - 8-16-04 - was 1'b0
      default: INTR <= 1'b0; // shughes - 8-16-04 - was 1'b1
    endcase // case({activate_intr,ias})



  //--------------------------------------------------------------------------
  //
  //  OneWireReset
  //
  //  this state machine performs the 1-wire reset and presence detect
  //  - Added OD for overdrive speed presence detect
  //  - Added PD_LOW bit for strong pullup control
  //
  //  Idle       : OW high - waiting to issue a PD
  //  CheckOWR   : OW high - checks for shorted OW line
  //  Reset_Low  : OW low - held down for GT8 OW osc periods
  //  PD_Wait    : OW high - released and waits for 1T
  //  PD_Sample  : OW high - checks to see if a slave is out there pulling
  //                         OW low for 4T
  //  Reset_High : OW high - slave, if any, release OW and host lets it recover
  //--------------------------------------------------------------------------

  always @(posedge FSM_CLK or posedge MR)
    if(MR) begin
      pdr          <= 1'b1;        // Added default state to conform to spec - SDS
      OneWireReset <= Idle;
      count        <= 0;
      PD_READ      <= 0;       // Added PD_READ - GAG
      reset_owr    <= 0;
      SET_RSHRT    <= 0;     //
      ROW          <= 0;
    end else if(!owr) begin
      count        <= 0;
      ROW          <= 0;
      reset_owr    <= 0;
      OneWireReset <= Idle;
    end else
        case(OneWireReset)
          Idle:
          begin
            if (ROW)
              reset_owr <= 1;
            else
              begin
                count        <= 0;
                SET_RSHRT    <= 0;
                reset_owr    <= 0;
                OneWireReset <= CheckOWR;
              end
          end
          CheckOWR:
          begin
            OneWireReset <= Reset_Low;
            if(!DQ_IN)
              SET_RSHRT <= 1;
          end

          Reset_Low:
          begin
            count <= count + 1;
            PD_READ <= 0;                // Added PD_READ - GAG
            // tRSTL - OD
            if(OD)                       // Added OD - GAG
              begin
                if(count == reset_ts_release_od)
                  begin
                    OneWireReset <= PD_Wait;
                    PD_READ <= 1;
                  end
              end
              // tRSTL - STD
            else if(count == reset_ts_release)
              begin
                OneWireReset <= PD_Wait;
                PD_READ      <= 1;
              end
          end
          PD_Wait:
          begin
            SET_RSHRT <= 0;
            count     <= count + 1;
            if(!DQ_IN & DQ_CONTROL_F)
                OneWireReset <= PD_Sample;
            else if(OD)
              begin
                // (tRSTL + pull-up time) - OD
                if(count==reset_ts_no_stpz_od)
                  // disables stp_sply
                  PD_READ <= 0;       // Be sure to turn off 4 MPD mode
                // tMSP - OD
                else if(count == reset_ts_sample_od)
                  OneWireReset <= PD_Sample;
              end
            // (tRSTL + pull-up time) - STD
            else if(count == reset_ts_no_stpz)
              // disables stp_sply
              PD_READ <= 0; // Be sure to turn off 4 MPD mode
            // tPPM1 - STD
            else if((count == reset_ts_ppm) && PPM)
              OneWireReset <= PD_Force;
            // tMSP - STD
            else if(count == reset_ts_llsample && !LLM)
              OneWireReset <= PD_Sample;
            else if(count == reset_ts_sample && LLM)
              OneWireReset <= PD_Sample;
          end
          PD_Sample:
          begin
            PD_READ <= 0;
            count <= count + 1;
            pdr <= DQ_IN;
            OneWireReset <= Reset_High;
          end
          Reset_High:
          begin
            count <= count + 1;
            if (OD)                      // Added OD - GAG
              begin
                if (count == reset_ts_stpz_od)
                  begin
                  if (DQ_IN)
                    PD_READ <= 1;
                  end
                else if (count == reset_ts_recover_od)
                  PD_READ <= 0;
                else if (count == reset_ts_end_od)
                  begin
                    PD_READ <= 0;
                    OneWireReset <= Idle;
                    ROW <= 1;
                  end
              end
            else
              begin
                if(count == reset_ts_stpz)
                  begin
                  if (DQ_IN)
                    PD_READ <= 1;
                  end
                else if (count == reset_ts_recover)
                  PD_READ <= 0;
                else if (count == reset_ts_end)
                  begin
                    PD_READ <= 0;
                    OneWireReset <= Idle;
                    ROW <= 1;
                  end
              end
          end
          PD_Force:
          begin
            count <= count + 1;
            // tPPM2
            if (count == reset_ts_ppm_end)
              OneWireReset <= PD_Release;
          end
          PD_Release:
          begin
            count <= count + 1;
            pdr <= 0;              //force valid result
            if(count == reset_ts_stpz)
              begin
              if (DQ_IN)
                PD_READ <= 1;
              end
            else if (count == reset_ts_recover)
              PD_READ <= 0;
            else if (count == reset_ts_end)
              begin
                PD_READ <= 0;
                OneWireReset <= Idle;
                ROW <= 1;
              end
          end
        endcase


  //--------------------------------------------------------------------------
  //
  //  OneWireIO
  //
  //  this state machine performs the 1-wire writing and reading
  //  - Added ODWriteZero and ODWriteOne for overdrive timing
  //
  //  IdleS       : Waiting for transmit byte to be loaded
  //  ClrLowDone  : Disables strong pullup before pulldown turns on
  //  Load        : Loads byte to shift reg
  //  CheckOW     : Checks for OW short
  //  DQLOW       : Starts time slot with OW = 0
  //  ODWriteZero : Completes write of 0 bit / read bit in OD speed
  //  ODWriteOne  : Completes write of 1 bit / read bit in OD speed
  //  WriteZero   : Completes write of 0 bit / read bit in standard speed
  //  WriteOne    : Completes write of 1 bit / read bit in standard speed
  //  ReadBit     : AutoSearchRom : Reads the first bit value
  //  FirstPassSR : AutoSearchRom : Decides to do another read or the write
  //  WriteBitSR  : AutoSearchRom : Determines the bit to write
  //  WriteBit    : AutoSearchRom : Writes the bit
  //  WatiTS      : Allows OW to recover for the remainder of the time slot
  //  IndexInc    : Increment the index to send out next bit (in byte)
  //  UpdateBuff  : Allows other signals to update following finished byte/bit
  //--------------------------------------------------------------------------

  // The following 2 registers are to stretch the temt signal to catch the
  // temt interrupt source - SDS

  always @(posedge MR or posedge FSM_CLK)
    if(MR)
      bdext1 <= 1'b0;
    else
      bdext1 <= byte_done;

  always @(posedge MR or posedge FSM_CLK)
    if(MR)
      byte_done_flag <= 1'b0;
    else
      byte_done_flag <= bdext1;

  assign temt_ext = temt && byte_done_flag;

  // The index variable has been decoded explicitly in this state machine
  // so that the code would compile on the Cypress warp compiler - SDS
  always @(posedge FSM_CLK or posedge MR)
    if(MR)
      begin
        index         <= 0;
        TimeSlotCnt   <= 0;
        temt          <= 1'b1;
        last_rcvr_bit <= 1'b0;
        rcvr_shiftreg <= 0;
        OneWireIO     <= IdleS;
        BitRead1      <= 0;
        BitRead2      <= 0;
        BitWrite      <= 0;
        First         <= 1'b0;
        byte_done     <= 1'b0;
        xmit_shiftreg <= 0;
        LOW_DONE      <= 0;
        SET_IOSHRT    <= 0;
      end
    else
      case(OneWireIO)
        // IdleS state clears variables and waits for something to be
        // deposited in the transmit buffer. When something is there,
        // the next state is Load.
        IdleS:
        begin
          byte_done     <= 1'b0;
          index         <= 0;
          last_rcvr_bit <= 1'b0;
          First         <= 1'b0;
          TimeSlotCnt   <= 0;
          LOW_DONE      <= 0;
          SET_IOSHRT    <= 0;
          temt          <= 1'b1;
          if(!tbe)
            begin
              if(STPEN)
                OneWireIO <= ClrLowDone;
              else
                OneWireIO <= Load;
            end
          else
            OneWireIO <= IdleS;
        end

        // New state added to be sure the strong pullup will be disabled
        // before the OW pulldown turns on
        ClrLowDone:
        begin
          LOW_DONE <= 0;
          if (!LOW_DONE)
            OneWireIO <= Load;
        end

        // Load transfers the transmit buffer to the transmit shift register,
        // then clears the transmit shift register empty interrupt. The next
        // state is then DQLOW.
        Load:
        begin
          xmit_shiftreg <= xmit_buffer;
          rcvr_shiftreg <= 0;
          temt          <= 1'b0;
          LOW_DONE      <= 0;
          OneWireIO     <= CheckOW;
        end

        // Checks OW value before sending out every bit to see if line
        // was forced low by some other means at an incorrect time
        CheckOW:
        begin
          OneWireIO <= DQLOW;
          //TimeSlotCnt <= TimeSlotCnt + 1;
          if (!DQ_IN)
            SET_IOSHRT <= 1;
        end

        // DQLOW pulls the DQ line low for 1us, beginning a timeslot.
        // If sr_a is 0, it is a normal write/read operation. If sr_a
        // is a 1, then you must go into Search ROM accelerator mode.
        // If OD is 1, the part is in overdrive and must perform
        // ODWrites instead of normal Writes while OD is 0.
        DQLOW:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          LOW_DONE <= 0;
          if (OD)
            begin
              if(!sr_a)
                begin
                  case(index)
                    0: OneWireIO <= (!xmit_shiftreg[0]) ? ODWriteZero : ODWriteOne;
                    1: OneWireIO <= (!xmit_shiftreg[1]) ? ODWriteZero : ODWriteOne;
                    2: OneWireIO <= (!xmit_shiftreg[2]) ? ODWriteZero : ODWriteOne;
                    3: OneWireIO <= (!xmit_shiftreg[3]) ? ODWriteZero : ODWriteOne;
                    4: OneWireIO <= (!xmit_shiftreg[4]) ? ODWriteZero : ODWriteOne;
                    5: OneWireIO <= (!xmit_shiftreg[5]) ? ODWriteZero : ODWriteOne;
                    6: OneWireIO <= (!xmit_shiftreg[6]) ? ODWriteZero : ODWriteOne;
                    7: OneWireIO <= (!xmit_shiftreg[7]) ? ODWriteZero : ODWriteOne;
                  endcase // case(index)
                end
              else         // Search Rom Accelerator mode
                OneWireIO <= ReadBit;
            end
            //end
          else
            if(((TimeSlotCnt==bit_ts_writeone_high) && !LLM) ||
                  ((TimeSlotCnt==bit_ts_writeone_high_ll) && LLM))
              begin
                if(!sr_a)                  // Normal write
                  case(index)
                    0: OneWireIO <= !xmit_shiftreg[0] ? ODWriteZero : ODWriteOne;
                    1: OneWireIO <= !xmit_shiftreg[1] ? ODWriteZero : ODWriteOne;
                    2: OneWireIO <= !xmit_shiftreg[2] ? ODWriteZero : ODWriteOne;
                    3: OneWireIO <= !xmit_shiftreg[3] ? ODWriteZero : ODWriteOne;
                    4: OneWireIO <= !xmit_shiftreg[4] ? ODWriteZero : ODWriteOne;
                    5: OneWireIO <= !xmit_shiftreg[5] ? ODWriteZero : ODWriteOne;
                    6: OneWireIO <= !xmit_shiftreg[6] ? ODWriteZero : ODWriteOne;
                    7: OneWireIO <= !xmit_shiftreg[7] ? ODWriteZero : ODWriteOne;
                  endcase // case(index)
                else         // Search Rom Accelerator mode
                    OneWireIO <= ReadBit;
              end
          end

        // WriteZero and WriteOne are identical, except for what they do to
        // DQ (assigned in concurrent assignments). They both read DQ after
        // 15us, then move on to wait for the end of the timeslot, unless
        // running in Long Line mode which extends the sample time out to 22
        WriteZero:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          if(((TimeSlotCnt==bit_ts_sample) && !sr_a && !LLM) ||
              ((TimeSlotCnt==bit_ts_sample_ll) && !sr_a &&  LLM))
            case(index)
              0: rcvr_shiftreg[0] <= DQ_IN;
              1: rcvr_shiftreg[1] <= DQ_IN;
              2: rcvr_shiftreg[2] <= DQ_IN;
              3: rcvr_shiftreg[3] <= DQ_IN;
              4: rcvr_shiftreg[4] <= DQ_IN;
              5: rcvr_shiftreg[5] <= DQ_IN;
              6: rcvr_shiftreg[6] <= DQ_IN;
              7: rcvr_shiftreg[7] <= DQ_IN;
            endcase
          if(TimeSlotCnt == bit_ts_writezero_high)            //62 7_25_01
            OneWireIO <= WaitTS;
          if(DQ_IN)
            LOW_DONE <= 1;
        end

        WriteOne:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          if(((TimeSlotCnt==bit_ts_sample) && !sr_a && !LLM) ||
              ((TimeSlotCnt==bit_ts_sample_ll) && !sr_a &&  LLM))
              case(index)
                0: rcvr_shiftreg[0] <= DQ_IN;
                1: rcvr_shiftreg[1] <= DQ_IN;
                2: rcvr_shiftreg[2] <= DQ_IN;
                3: rcvr_shiftreg[3] <= DQ_IN;
                4: rcvr_shiftreg[4] <= DQ_IN;
                5: rcvr_shiftreg[5] <= DQ_IN;
                6: rcvr_shiftreg[6] <= DQ_IN;
                7: rcvr_shiftreg[7] <= DQ_IN;
              endcase
          if(TimeSlotCnt == bit_ts_writezero_high)             //62 7_25_01
            OneWireIO <= WaitTS;
          if(DQ_IN)
            LOW_DONE <= 1;
        end

        // ADDED ODWRITE states here GAG
        // ODWriteZero and ODWriteOne are identical, except for what they
        // do to DQ (assigned in concurrent assignments). They both read
        // DQ after 3us, then move on to wait for the end of the timeslot.
        ODWriteZero:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          if((TimeSlotCnt == bit_ts_sample_od) && !sr_a)
            case(index)
              0: rcvr_shiftreg[0] <= DQ_IN;
              1: rcvr_shiftreg[1] <= DQ_IN;
              2: rcvr_shiftreg[2] <= DQ_IN;
              3: rcvr_shiftreg[3] <= DQ_IN;
              4: rcvr_shiftreg[4] <= DQ_IN;
              5: rcvr_shiftreg[5] <= DQ_IN;
              6: rcvr_shiftreg[6] <= DQ_IN;
              7: rcvr_shiftreg[7] <= DQ_IN;
            endcase
          if(TimeSlotCnt == bit_ts_writezero_high_od)
            OneWireIO <= WaitTS;
          if(DQ_IN)
            LOW_DONE <= 1;
        end

        ODWriteOne:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          if((TimeSlotCnt == bit_ts_sample_od) && !sr_a)
            case(index)
              0: rcvr_shiftreg[0] <= DQ_IN;
              1: rcvr_shiftreg[1] <= DQ_IN;
              2: rcvr_shiftreg[2] <= DQ_IN;
              3: rcvr_shiftreg[3] <= DQ_IN;
              4: rcvr_shiftreg[4] <= DQ_IN;
              5: rcvr_shiftreg[5] <= DQ_IN;
              6: rcvr_shiftreg[6] <= DQ_IN;
              7: rcvr_shiftreg[7] <= DQ_IN;
            endcase
          if(TimeSlotCnt == bit_ts_writezero_high_od)
            OneWireIO <= WaitTS;
          if(DQ_IN)
            LOW_DONE <= 1;
        end

        // ReadBit used by the SRA to do the required bit reads
        ReadBit:
          begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          if(DQ_IN)
            LOW_DONE <= 1;
          if(OD)
            begin
              if(TimeSlotCnt == bit_ts_sample_od)
                if(!First)
                  BitRead1 <= DQ_IN;
                else
                  BitRead2 <= DQ_IN;
              if(TimeSlotCnt == bit_ts_writezero_high_od)     //7 7_25_01
                OneWireIO <= FirstPassSR;
            end
          else
            begin
              if(((TimeSlotCnt == bit_ts_sample)&&!LLM) || ((TimeSlotCnt == bit_ts_sample_ll)&&LLM))
                  if(!First)
                    BitRead1 <= DQ_IN;
                  else
                    BitRead2 <= DQ_IN;
              if(TimeSlotCnt == bit_ts_writezero_high)
                OneWireIO <= FirstPassSR;
            end
          end

        // FirstPassSR decides whether to do another read or to do the
        // bit write.
        FirstPassSR:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          LOW_DONE <= 0;
          if(OD)
            begin
              if(TimeSlotCnt == bit_ts_end_od)
                begin
                  TimeSlotCnt <= 0;
                  if(!First)
                    begin
                      First     <= 1'b1;
                      OneWireIO <= DQLOW;
                    end
                  else
                    OneWireIO <= WriteBitSR;
                end
            end
          else
            begin
            if(((TimeSlotCnt==bit_ts_end) && !LLM) || ((TimeSlotCnt==bit_ts_end_ll) && LLM))
              begin
                TimeSlotCnt <= 0;
                if(!First)
                  begin
                    First     <= 1'b1;
                    OneWireIO <= DQLOW;
                  end
                else
                  OneWireIO <= WriteBitSR;
              end
        end
        end

        // WriteBitSR will now determine the bit necessary to write
        // for the Search ROM to proceed.
        WriteBitSR:
        begin
          case({BitRead1,BitRead2})
            2'b00:
            begin
              case(index)
                0:
                begin
                  BitWrite <= xmit_shiftreg[1];
                  rcvr_shiftreg[0] <= 1'b1;
                end
                1:
                begin
                  BitWrite <= xmit_shiftreg[2];
                  rcvr_shiftreg[1] <= 1'b1;
                end
                2:
                begin
                  BitWrite <= xmit_shiftreg[3];
                  rcvr_shiftreg[2] <= 1'b1;
                end
                3:
                begin
                  BitWrite <= xmit_shiftreg[4];
                  rcvr_shiftreg[3] <= 1'b1;
                end
                4:
                begin
                  BitWrite <= xmit_shiftreg[5];
                  rcvr_shiftreg[4] <= 1'b1;
                end
                5:
                begin
                  BitWrite <= xmit_shiftreg[6];
                  rcvr_shiftreg[5] <= 1'b1;
                end
                6:
                begin
                  BitWrite <= xmit_shiftreg[7];
                  rcvr_shiftreg[6] <= 1'b1;
                end
                7:
                begin
                  BitWrite <= xmit_shiftreg[0];
                  rcvr_shiftreg[7] <= 1'b1;
                end
              endcase
            end
            2'b01:
            begin
              BitWrite <= 1'b0;
              case(index)
                0: rcvr_shiftreg[0] <= 1'b0;
                1: rcvr_shiftreg[1] <= 1'b0;
                2: rcvr_shiftreg[2] <= 1'b0;
                3: rcvr_shiftreg[3] <= 1'b0;
                4: rcvr_shiftreg[4] <= 1'b0;
                5: rcvr_shiftreg[5] <= 1'b0;
                6: rcvr_shiftreg[6] <= 1'b0;
                7: rcvr_shiftreg[7] <= 1'b0;
              endcase
            end
            2'b10:
            begin
              BitWrite <= 1'b1;
              case(index)
                0: rcvr_shiftreg[0] <= 1'b0;
                1: rcvr_shiftreg[1] <= 1'b0;
                2: rcvr_shiftreg[2] <= 1'b0;
                3: rcvr_shiftreg[3] <= 1'b0;
                4: rcvr_shiftreg[4] <= 1'b0;
                5: rcvr_shiftreg[5] <= 1'b0;
                6: rcvr_shiftreg[6] <= 1'b0;
                7: rcvr_shiftreg[7] <= 1'b0;
              endcase
            end
            2'b11:
            begin
              BitWrite <= 1'b1;
              case(index)
                0: begin
                    rcvr_shiftreg[0] <= 1'b1;
                    rcvr_shiftreg[1] <= 1'b1;
                end
                1: begin
                    rcvr_shiftreg[1] <= 1'b1;
                    rcvr_shiftreg[2] <= 1'b1;
                end
                2: begin
                    rcvr_shiftreg[2] <= 1'b1;
                    rcvr_shiftreg[3] <= 1'b1;
                end
                3: begin
                    rcvr_shiftreg[3] <= 1'b1;
                    rcvr_shiftreg[4] <= 1'b1;
                end
                4: begin
                    rcvr_shiftreg[4] <= 1'b1;
                    rcvr_shiftreg[5] <= 1'b1;
                end
                5: begin
                    rcvr_shiftreg[5] <= 1'b1;
                    rcvr_shiftreg[6] <= 1'b1;
                end
                6: begin
                    rcvr_shiftreg[6] <= 1'b1;
                    rcvr_shiftreg[7] <= 1'b1;
                end
                7: begin
                    rcvr_shiftreg[7] <= 1'b1;
                    rcvr_shiftreg[0] <= 1'b1;
                end
              endcase
            end
          endcase // case({BitRead1,BitRead2})
          OneWireIO <= WriteBit;
        end

        // WriteBit actually writes the chosen bit to the One Wire bus.
        WriteBit:
        begin
          TimeSlotCnt <= TimeSlotCnt + 1;
          case(index)
            0: rcvr_shiftreg[1] <= BitWrite;
            1: rcvr_shiftreg[2] <= BitWrite;
            2: rcvr_shiftreg[3] <= BitWrite;
            3: rcvr_shiftreg[4] <= BitWrite;
            4: rcvr_shiftreg[5] <= BitWrite;
            5: rcvr_shiftreg[6] <= BitWrite;
            6: rcvr_shiftreg[7] <= BitWrite;
            7: rcvr_shiftreg[0] <= BitWrite;
          endcase
          if(!BitWrite)
            begin
              if(OD)
                OneWireIO <= ODWriteZero;
              else
                OneWireIO <= WriteZero;
            end
          else
            begin
              if(OD && (TimeSlotCnt == bit_ts_writeone_high_od))
                OneWireIO <= ODWriteOne;
              else if (!LLM && (TimeSlotCnt == bit_ts_writeone_high))  //5 7_25_01
                OneWireIO <= WriteOne;
              else if (LLM && (TimeSlotCnt == bit_ts_writeone_high_ll))
                OneWireIO <= WriteOne;
            end
        end

        // WaitTS waits until the timeslot is completed, 80us. When done with
        // that timeslot, the index will be incremented.
        WaitTS:
        begin
          SET_IOSHRT <= 0;
          TimeSlotCnt <= TimeSlotCnt + 1;
          if(OD)
            begin
            if(TimeSlotCnt == bit_ts_end_od)  //11 7_25_01
              OneWireIO <= IndexInc;
            end
          else
            if(((TimeSlotCnt == bit_ts_end) && !LLM) || ((TimeSlotCnt==bit_ts_end_ll) && LLM))
              OneWireIO <= IndexInc;
          if(DQ_IN)
            LOW_DONE <= 1;
        end

        // IndexInc incs the index by 1 if normal write, by 2 if in SRA
        IndexInc:
        begin
          if(!sr_a)
            index <= index + 1;
          else
            begin
              index <= index + 2;
              First <= 1'b0;
            end
          if(BIT_CTL || (index == 8-1 && !sr_a) || (index == 8-2 && sr_a))
            begin                             // Added BIT_CTL - GAG
              byte_done <= 1'b1;
              OneWireIO <= UpdateBuff;
            end
          else
            begin
              if((index == 7-1) && !sr_a)
                  last_rcvr_bit <= 1'b1;
              else
                if((index == 6-2) && sr_a)
                  last_rcvr_bit <= 1'b1;
              OneWireIO <= DQLOW;
              TimeSlotCnt <= 0;
            end

              LOW_DONE <= 0;
        end

        UpdateBuff:
        begin
          OneWireIO <= IdleS;
          if(DQ_IN && STP_SPLY)
            LOW_DONE <= 1;
        end
      endcase
endmodule

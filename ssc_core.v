// State machine to clock out the data

// A block of defines for the SSC state machine
`define statesNo            7
`define SSC_IDLE            7'b0000001
`define SSC_SEND_CMD        7'b0000010
`define SSC_LOAD_DATA_OUT   7'b0000100
`define SSC_SEND_DATA       7'b0001000
`define SSC_LOAD_DATA_IN    7'b0010000
`define SSC_READ_DATA       7'b0100000
`define SSC_READ_DATA_TX    7'b1000000

`define ENABLE      1'b1
`define DISABLE     1'b0

`define WRITE       1'b1
`define READ        1'b0

`define CMD         1'b1
`define DATA        1'b0

`define HIGH        1'b1
`define LOW         1'b0

`define LOAD        1'b1

`define BUSY        1'b1
`define DONE        1'b0

module ssc_core
  (
    input       CLK,
    input       sscDir,
    input [5:0] sscDataLength,
    input [4:0] sscCommand,
    input       sscGo,

    output     sscClk1,
    output reg portDir = `WRITE,
    output reg sscBusy = `DONE,
    output reg sscSync1 = `HIGH,

    input  sscData1In,
    output sscData1Out,

    input wire [47:0]  sscDataIn,
    output wire [47:0] sscDataOut
  );

  reg [`statesNo-1:0] currentState = `SSC_IDLE;

  reg  sscClk1Enable;

  reg  sscCmdCntLoad;
  reg  sscCmdCntEnable;
  wire sscCmdCntBusy;

  reg  sscCmdSRLoad;
  reg  sscCmdSREnable;
  wire sscCmdSROut;

  reg  sscDataCntLoad;
  reg  sscDataCntEnable;
  wire sscDataCntBusy;

  reg  sscDataSRLoad;
  reg  sscDataSROutEnable;
  wire sscDataSROut;

  reg  sscDataSRInEnable;
  reg  sscDataSelect;

  wire [47:0] intWSscData;

  // inout sscData1 port control
  assign sscData1Out = ((sscDataSelect == `CMD) ? sscCmdSROut : sscDataSROut);

  // Enable the SSC clock. The CLK is idle high.
  assign sscClk1 = sscClk1Enable ? CLK : `HIGH;

  // Realign the data for writing: when the data is stored in sscData it is right-align msb
  assign intWSscData = sscDataIn << (48 - sscDataLength);

  // State register block
  always @(negedge CLK)
  begin
    case(currentState)
      `SSC_IDLE:
      begin: idleState
        // Load command
        if (sscGo)
          begin: loadCommand
            // Signal that the SSC is busy
            sscBusy = `BUSY;

            // Sync line is active indicating the beginning of a transmission
            sscSync1 = `LOW;

            // The SSC clock is disable
            sscClk1Enable = `DISABLE;

            // The command counter is loading the data
            sscCmdCntLoad = `LOAD;
            sscCmdCntEnable = `DISABLE;

            // The command shift register is loading the data
            sscCmdSRLoad = `LOAD;
            sscCmdSREnable = `DISABLE;

            // The data counter is disable
            sscDataCntLoad = `DONE;
            sscDataCntEnable = `DISABLE;

            // The data out shift register is disable
            sscDataSRLoad = `DONE;
            sscDataSROutEnable = `DISABLE;

            // The data in shift register is disable
            sscDataSRInEnable = `DISABLE;

            // The direction is defaulted to WRITE
            portDir = `WRITE;
            // The selection between CMD and DATA for the output is dont'care
            // as bus is not enabled yet
            sscDataSelect = 1'bx;

            // Next state
            currentState = `SSC_SEND_CMD;
          end
        else
          begin: stayIdle
            // Signal that the SSC is idle
            sscBusy = `DONE;

            // Sync line is idle high
            sscSync1 = `HIGH;

            // The SSC clock is disable
            sscClk1Enable = `DISABLE;

            // The command counter is disable
            sscCmdCntLoad = `DONE;
            sscCmdCntEnable = `DISABLE;

            // The command shift register is disable
            sscCmdSRLoad = `DONE;
            sscCmdSREnable = `DISABLE;

            // The data counter is disable
            sscDataCntLoad = `DONE;
            sscDataCntEnable = `DISABLE;

            // The data out shift register is disable
            sscDataSRLoad = `DONE;
            sscDataSROutEnable = `DISABLE;

            // The data in shift register is disable
            sscDataSRInEnable = `DISABLE;

            // The direction is defaulted to WRITE
            portDir = `WRITE;
            // The selection between CMD and DATA for the output is dont'care
            // as bus is not enabled yet
            sscDataSelect = 1'bx;
          end
      end
      `SSC_SEND_CMD:
      begin: sendCommand
        // Signal that the SSC is busy
        sscBusy = `BUSY;

        // Sync line is active indicating the beginning of a transmission
        sscSync1 = `LOW;

        // The SSC clock is enable
        sscClk1Enable = `ENABLE;

        // The command counter register is enable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `ENABLE;

        // The command shift register is clocking the data
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `ENABLE;

        // The data counter is disable
        sscDataCntLoad = `DONE;
        sscDataCntEnable = `DISABLE;

        // The data out shift register is disable
        sscDataSRLoad = `DONE;
        sscDataSROutEnable = `DISABLE;

        // The data in shift register is disable
        sscDataSRInEnable = `DISABLE;

        // The direction is defaulted to WRITE
        portDir = `WRITE;
        // CMD is shifted out through sscData1
        sscDataSelect = `CMD;

        // Next state
        if (~sscCmdCntBusy)
          begin: doneWithCmd
            if (sscDataLength)
              currentState = (sscDir == `WRITE) ? `SSC_LOAD_DATA_OUT : `SSC_LOAD_DATA_IN;
            else
              currentState = `SSC_IDLE;
          end
      end
      `SSC_LOAD_DATA_OUT:
      begin: loadData
        // Signal that the SSC is busy
        sscBusy = `BUSY;

        // Sync line is active indicating the beginning of a transmission
        sscSync1 = `LOW;

        // The SSC clock is disable
        sscClk1Enable = `DISABLE;

        // The command counter is disable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `DISABLE;

        // The command shift register is disable
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `DISABLE;

        // The data counter is loading the data
        sscDataCntLoad = `LOAD;
        sscDataCntEnable = `DISABLE;

        // The data out shift register is loading the data
        sscDataSRLoad = `LOAD;
        sscDataSROutEnable = `DISABLE;

        // The data in shift register is disable
        sscDataSRInEnable = `DISABLE;

        // The direction is defaulted to WRITE
        portDir = `WRITE;
        // The selection between CMD and DATA for the output is dont'care
        // as bus is not enabled yet
        sscDataSelect = 1'bx;

        // Next state
        currentState = `SSC_SEND_DATA;
      end
      `SSC_SEND_DATA:
      begin: sendDataOut
        // Signal that the SSC is busy
        sscBusy = `BUSY;

        // Sync line is active indicating the beginning of a transmission
        sscSync1 = `LOW;

        // The SSC clock is enable
        sscClk1Enable = `ENABLE;

        // The command counter is disable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `DISABLE;

        // The command shift register is disable
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `DISABLE;

        // The data counter is enable
        sscDataCntLoad = `DONE;
        sscDataCntEnable = `ENABLE;

        // The data out shift register is clocking out the data
        sscDataSRLoad = `DONE;
        sscDataSROutEnable = `ENABLE;

        // The data in shift register is disable
        sscDataSRInEnable = `DISABLE;

        // The direction is defaulted to WRITE
        portDir = `WRITE;
        // DATA is shifted out through sscData1
        sscDataSelect = `DATA;

        // Next state
        if (~sscDataCntBusy)
          currentState = `SSC_IDLE;
      end
      `SSC_LOAD_DATA_IN:
      begin: loadDataIn
        // Signal that the SSC is busy
        sscBusy = `BUSY;

        // Sync line is active indicating the beginning of a transmission
        sscSync1 = `LOW;

        // The SSC clock is disable
        sscClk1Enable = `DISABLE;

        // The command counter is disable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `DISABLE;

        // The command shift register is disable
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `DISABLE;

        // The data counter is loading the data
        sscDataCntLoad = `LOAD;
        sscDataCntEnable = `DISABLE;

        // The data out shift register is disable
        sscDataSRLoad = `DONE;
        sscDataSROutEnable = `DISABLE;

        // The data in shift register is disable
        sscDataSRInEnable = `DISABLE;

        // Turn direction is defaulted to READ
        portDir = `READ;
        // The selection between CMD and DATA for the output is dont'care
        // as the bus used by the slave
        sscDataSelect = 1'bx;

        // Next state
        currentState = `SSC_READ_DATA;
      end
      `SSC_READ_DATA:
      begin: readDataIn
        // Signal that the SSC is busy
        sscBusy = `BUSY;

        // Sync line is active indicating the beginning of a transmission
        sscSync1 = `LOW;

        // The SSC clock is enable
        sscClk1Enable = `ENABLE;

        // The command counter is disable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `DISABLE;

        // The command shift register is disable
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `DISABLE;

        // The data counter is enable
        sscDataCntLoad = `DONE;
        sscDataCntEnable = `ENABLE;

        // The data out shift register is disable
        sscDataSRLoad = `DONE;
        sscDataSROutEnable = `DISABLE;

        // The data in shift register is clocking in the data
        sscDataSRInEnable = `ENABLE;

        // The direction is set to READ
        portDir = `READ;
        // The selection between CMD and DATA for the output is dont'care
        // as the bus used by the slave
        sscDataSelect = 1'bx;

        // Next state
        if (~sscDataCntBusy)
          currentState = `SSC_READ_DATA_TX;
      end
      `SSC_READ_DATA_TX:
      begin: readDataTx
        // Signal that the SSC is idle
        sscBusy = `DONE;

        // Sync line is idle high
        sscSync1 = `HIGH;

        // The SSC clock is disable
        sscClk1Enable = `DISABLE;

        // The command counter is disable
        sscCmdCntLoad = `DONE;
        sscCmdCntEnable = `DISABLE;

        // The command shift register is disable
        sscCmdSRLoad = `DONE;
        sscCmdSREnable = `DISABLE;

        // The data counter is disable
        sscDataCntLoad = `DONE;
        sscDataCntEnable = `DISABLE;

        // The data out shift register is disable
        sscDataSRLoad = `DONE;
        sscDataSROutEnable = `DISABLE;

        // The data in shift register is disable
        sscDataSRInEnable = `DISABLE;
        // The direction is defaulted to WRITE
        portDir = `WRITE;
        // The selection between CMD and DATA for the output is dont'care
        // as bus is not enabled yet
        sscDataSelect = 1'bx;

        // Next state
        currentState = `SSC_IDLE;
      end
      default:
      begin
        sscBusy = `DONE;
        sscSync1 = `HIGH;
        sscCmdCntLoad = `DONE;
        sscCmdSRLoad = `DONE;
        sscDataCntLoad = `DONE;
        sscDataSRLoad = `DONE;
        sscClk1Enable = `DISABLE;
        sscCmdCntEnable = `DISABLE;
        sscCmdSREnable = `DISABLE;
        sscDataCntEnable = `DISABLE;
        sscDataSROutEnable = `DISABLE;
        sscDataSRInEnable = `DISABLE;
        sscDataSelect = 1'bx;
        portDir = `WRITE;
        // Default to idle state
        currentState = `SSC_IDLE;
      end
    endcase
  end

  // instantiation of the command shift register
  shift_reg_out # (
    .WIDTH(5)
  ) CMD_SR_OUT (
    .CLK(CLK),
    .dataIn(sscCommand),
    .loadData(sscCmdSRLoad),
    .clockEnable(sscCmdSREnable),
    .dataOut(sscCmdSROut)
  );

  // instantiation of the command counter
  counter # (
    .WIDTH(3)
  ) CMD_CNT (
    .CLK(CLK),
    .dataIn(3'd5 - 3'd1),
    .loadData(sscCmdCntLoad),
    .clockEnable(sscCmdCntEnable),
    .busy(sscCmdCntBusy)
  );

  // instantiation of the data write shift register
  shift_reg_out # (
    .WIDTH(48)
  ) DATA_SR_OUT (
    .CLK(CLK),
    .dataIn(intWSscData),
    .loadData(sscDataSRLoad),
    .clockEnable(sscDataSROutEnable),
    .dataOut(sscDataSROut)
  );

  // instantiation of the data counter
  counter # (
    .WIDTH(6)
  ) DATA_CNT (
    .CLK(CLK),
    .dataIn(sscDataLength - 6'd1),
    .loadData(sscDataCntLoad),
    .clockEnable(sscDataCntEnable),
    .busy(sscDataCntBusy)
  );

  // instantiation of the data read shift register
  shift_reg_in # (
    .WIDTH(48)
  ) DATA_SR_IN (
    .CLK(CLK),
    .dataIn(sscData1In),
    .clockEnable(sscDataSRInEnable),
    .dataOut(sscDataOut)
  );
endmodule

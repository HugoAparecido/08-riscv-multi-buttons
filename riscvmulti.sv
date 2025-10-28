module riscvmulti (
    input         clk,
    input         reset,
    output [31:0] Address,
    output [31:0] WriteData,
    output        MemWrite,
    input  [31:0] ReadData
);

    reg [31:0] instr;
    reg [31:0] PC;

    // The state machine (make widths explicit)
    localparam [2:0] FETCH_INSTR = 3'd0;
    localparam [2:0] WAIT_INSTR  = 3'd1;
    localparam [2:0] FETCH_REGS  = 3'd2;
    localparam [2:0] EXECUTE     = 3'd3;
    localparam [2:0] LOAD        = 3'd4;
    localparam [2:0] WAIT_DATA   = 3'd5;
    localparam [2:0] STORE       = 3'd6;
    reg [2:0] state;

    // The 10 RISC-V instruction class decoders
    wire isALUreg  =  (instr[6:0] == 7'b0110011);
    wire isALUimm  =  (instr[6:0] == 7'b0010011);
    wire isBranch  =  (instr[6:0] == 7'b1100011);
    wire isJALR    =  (instr[6:0] == 7'b1100111);
    wire isJAL     =  (instr[6:0] == 7'b1101111);
    wire isAUIPC   =  (instr[6:0] == 7'b0010111);
    wire isLUI     =  (instr[6:0] == 7'b0110111);
    wire isLoad    =  (instr[6:0] == 7'b0000011);
    wire isStore   =  (instr[6:0] == 7'b0100011);
    wire isSYSTEM  =  (instr[6:0] == 7'b1110011);

    // immediates (combinational)
    wire [31:0] Uimm = { instr[31], instr[30:12], {12{1'b0}} };
    wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
    wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
    wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

    // register indices and funct fields
    wire [4:0] rs1Id_A1 = instr[19:15];
    wire [4:0] rs2Id_A2 = instr[24:20];
    wire [4:0] rdId_A3  = instr[11:7];
    wire [2:0] funct3   = instr[14:12];
    wire [6:0] funct7   = instr[31:25];

    // register bank
    reg [31:0] RegisterBank [0:31];
    reg [31:0] rs1;
    reg [31:0] rs2;

    // ALU inputs
    wire [31:0] SrcA = rs1;
    wire [31:0] SrcB = (isALUreg || isBranch) ? rs2 : Iimm;
    wire [4:0]  shamt = isALUreg ? rs2[4:0] : instr[24:20];

    // arithmetic helpers
    wire [31:0] aluPlus = SrcA + SrcB;
    wire [32:0] aluMinus = {1'b1, ~SrcB} + {1'b0, SrcA} + 33'b1;
    wire        LT  = (SrcA[31] ^ SrcB[31]) ? SrcA[31] : aluMinus[32];
    wire        LTU = aluMinus[32];
    wire        EQ  = (aluMinus[31:0] == 0);

    // shifter helpers
    function [31:0] flip32;
        input [31:0] x;
        integer i;
        begin
            for (i = 0; i < 32; i = i + 1)
                flip32[i] = x[31 - i];
        end
    endfunction
    wire [31:0] shifter_in = (funct3 == 3'b001) ? flip32(SrcA) : SrcA;
    wire [31:0] shifter    = $signed({instr[30] & SrcA[31], shifter_in}) >>> SrcB[4:0];
    wire [31:0] leftshift  = flip32(shifter);

    // ALU result: give a default to avoid latches/X
    reg [31:0] ALUResult;
    always @(*) begin
        ALUResult = 32'b0;
        case (funct3)
            3'b000: ALUResult = (funct7[5] & instr[5]) ? aluMinus[31:0] : aluPlus;
            3'b001: ALUResult = leftshift;
            3'b010: ALUResult = {31'b0, LT};
            3'b011: ALUResult = {31'b0, LTU};
            3'b100: ALUResult = (SrcA ^ SrcB);
            3'b101: ALUResult = shifter;
            3'b110: ALUResult = (SrcA | SrcB);
            3'b111: ALUResult = (SrcA & SrcB);
            default: ALUResult = 32'b0;
        endcase
    end

    // branch predicate
    reg takeBranch;
    always @(*) begin
        case (funct3)
            3'b000: takeBranch = EQ;
            3'b001: takeBranch = !EQ;
            3'b100: takeBranch = LT;
            3'b101: takeBranch = !LT;
            3'b110: takeBranch = LTU;
            3'b111: takeBranch = !LTU;
            default: takeBranch = 1'b0;
        endcase
    end

    // simulation:
    // address/pc helpers
    wire [31:0] PCplus4  = PC + 4;
    wire [31:0] PCTarget = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm);
    wire [31:0] PCNext = ((isBranch && takeBranch) || isJAL) ? PCTarget :
                        isJALR ? {aluPlus[31:1], 1'b0} :
                                 PCplus4;

    // Load/store address
    wire [31:0] LoadStoreAddress = rs1 + (isLoad ? Iimm : Simm);

    // Safe outputs:
    // During FETCH_INSTR and WAIT_INSTR we must drive Address = PC (to fetch the instruction).
    // Only when we are in LOAD/STORE states do we drive the data memory address to LoadStoreAddress.
    assign Address = (state == FETCH_INSTR || state == WAIT_INSTR) ? PC :
                     (state == LOAD || state == WAIT_DATA || state == STORE) ? LoadStoreAddress : 32'b0;

    assign MemWrite = ((state == STORE) && isStore);
    assign WriteData = rs2;

    // write-back predicate (combinational) - will be sampled at clock edge
    wire writeBackEn =
        ((state == EXECUTE) && ( (isALUreg || isALUimm || isJAL || isJALR || isAUIPC || isLUI) && (rdId_A3 != 5'b0) ))
        || ((state == WAIT_DATA) && isLoad && (rdId_A3 != 5'b0));

    wire [31:0] writeBackData =
        isLoad ? ReadData :
        (isALUreg || isALUimm) ? ALUResult :
        (isJAL || isJALR) ? PCplus4 :
        isAUIPC ? PCTarget :
        isLUI ? Uimm : 32'b0;

    // sequential logic
    integer i;
    always_ff @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
            state <= FETCH_INSTR;
            instr <= 32'b0;
            rs1 <= 32'b0;
            rs2 <= 32'b0;
            // initialize register file to zero to avoid X propagation from uninitialized values
            for (i = 0; i < 32; i = i + 1) RegisterBank[i] <= 32'b0;
        end else begin
            // write-back (sample combinational writeBackEn & writeBackData at clock edge)
            if (writeBackEn && (rdId_A3 != 5'b0)) begin
                RegisterBank[rdId_A3] <= writeBackData;
                $display("r%0d <= %h (%0d)", rdId_A3, writeBackData, $signed(writeBackData));
            end

            case (state)
                FETCH_INSTR: begin
                    // address already driven to PC by the continuous assign; we wait for memory response
                    state <= WAIT_INSTR;
                end
                WAIT_INSTR: begin
                    // capture the read instruction coming from memory
                    instr <= ReadData;
                    state <= FETCH_REGS;
                end
                FETCH_REGS: begin
                    // read register bank (x0 hardwired to zero)
                    rs1 <= (rs1Id_A1 != 5'b0) ? RegisterBank[rs1Id_A1] : 32'b0;
                    rs2 <= (rs2Id_A2 != 5'b0) ? RegisterBank[rs2Id_A2] : 32'b0;
                    state <= EXECUTE;
                end
                EXECUTE: begin
                    if (!isSYSTEM) begin
                        PC <= PCNext;
                    end
                    // go to proper next state depending on load/store
                    if (isLoad)    state <= LOAD;
                    else if (isStore) state <= STORE;
                    else state <= FETCH_INSTR;
                end
                LOAD: begin
                    // read data memory (address driven already)
                    state <= WAIT_DATA;
                end
                WAIT_DATA: begin
                    // at next clock edge write-back will happen (handled at top of block)
                    state <= FETCH_INSTR;
                end
                STORE: begin
                    // memwrite is asserted only in STORE state; then go to fetch
                    state <= FETCH_INSTR;
                end
                default: state <= FETCH_INSTR;
            endcase
        end
    end

endmodule

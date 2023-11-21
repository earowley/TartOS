const hw = @import("hardware");
const emmc = hw.emmc;
const res = emmc.EMMC.resource;

/// Possible errors when working with SD cards.
pub const SDCardError = error {
    NoCardDetected,
    UnsupportedVoltageRange,
    UnexpectedAppCommandState,
    CardController,
    ECCFailed,
    IllegalCommand,
    CRC,
    LockUnlockFailed,
    CardLocked,
    WriteProtectViolation,
    EraseParam,
    EraseSequence,
    BlockLength,
    Address,
    OutOfRange,
    Generic,
    UnknownCapacity,
};

/// Structure for working with SD cards and the EMMC controller.
pub const SDCard = struct {
    /// Block size in bytes.
    pub const block_size = 512;
    /// Block size in data register widths.
    pub const block_size_dw = block_size / @sizeOf(u32);
    cid: emmc.CID = .{},
    ocr: emmc.OCR = .{},
    csd: emmc.CSD = .{.standard_capacity = .{}},
    scr: emmc.SCR = .{},
    rca: u32 = 0,

    /// Reset the EMMC controller and initialize **the** SD card, if
    /// possible. Multiple SD cards not yet suppported.
    pub fn init() SDCardError!SDCard {
        // TODO: Don't hard code the dividers
        const init_div = 0x27BC86A / 400000;
        const op_div = 2;
        var result = SDCard{};
        res.resetHost();
        res.setSDClockDivider(init_div);
        res.powerOnSDClock();
        goIdleState();
        try checkVoltageRange();
        const ocr = try result.fetchOpCond();
        if (!ocr.v3233 and !ocr.v3334)
            return SDCardError.UnsupportedVoltageRange;
        result.ocr = ocr;
        result.cid = fetchCID();
        result.rca = try fetchRCA();
        result.csd = try result.fetchCSD();
        res.powerOffSDClock();
        res.setSDClockDivider(op_div);
        res.powerOnSDClock();
        try result.select();
        const scr = try result.fetchSCR();
        result.scr = scr;
        return result;
    }

    /// Reads block number `n` from the SD card.
    pub fn readBlock(self: SDCard, n: u32, buffer: *[block_size_dw]u32)
      void {
        const address = if (self.ocr.ccs) n else n << 9;
        const reads = block_size_dw;
        var blk: emmc.BlockSizeCount = @bitCast(res.block_size_count);
        blk.block_size = block_size;
        blk.block_count = 1;
        res.block_size_count = @bitCast(blk);
        res.arg1 = address;
        res.sendCommand(.read_single_block);
        for (0..reads) |idx| {
            const stat = res.status();
            if (!stat.data_busy) return;
            if (stat.read_available) {
                buffer[idx] = res.data;
                continue;
            }
            while (!res.status().read_available) {
                hw.arm.usleep(1);
            }
            buffer[idx] = res.data;
        }
    }

    fn checkR1(cs: emmc.CardStatus) SDCardError!void {
        if (!cs.err) return;
        if (cs.cc_err) return SDCardError.CardController;
        if (cs.card_ecc_failed) return SDCardError.ECCFailed;
        if (cs.illegal_command) return SDCardError.IllegalCommand;
        if (cs.com_crc_err) return SDCardError.CRC;
        if (cs.lock_unlock_failed) return SDCardError.LockUnlockFailed;
        if (cs.card_is_locked) return SDCardError.CardLocked;
        if (cs.wp_violation) return SDCardError.WriteProtectViolation;
        if (cs.erase_param) return SDCardError.EraseParam;
        if (cs.erase_seq_err) return SDCardError.EraseSequence;
        if (cs.block_len_err) return SDCardError.BlockLength;
        if (cs.address_err) return SDCardError.Address;
        if (cs.out_of_range) return SDCardError.OutOfRange;
        return SDCardError.Generic;
    }

    fn goIdleState() void {
        res.sendCommand(.go_idle_state);
    }

    fn checkVoltageRange() SDCardError!void {
        const arg = 0x1AA;
        res.arg1 = arg;
        res.sendCommand(.send_if_cond);
        return 
            if (res.resp[0] == arg)
                {}
            else if (res.resp[0] & 0xFF != 0xAA)
                SDCardError.NoCardDetected
            else
                SDCardError.UnsupportedVoltageRange;
    }

    fn fetchCID() emmc.CID {
        res.sendCommand(.all_send_cid);
        return @bitCast(res.resp);
    }

    fn fetchRCA() SDCardError!u32 {
        res.sendCommand(.send_relative_addr);
        const buf = res.resp[0];
        const rca = buf & 0xFFFF0000;
        const stat: emmc.CardStatus = @bitCast(
            (buf & 0x1FFF) | ((buf & 0xE000) << 6)
        );
        try checkR1(stat);
        return rca;
    }

    fn select(self: SDCard) SDCardError!void {
        res.arg1 = self.rca;
        res.sendCommand(.select_card);
        const stat: emmc.CardStatus = @bitCast(res.resp[0]);
        try checkR1(stat);
    }

    fn fetchOpCond(self: SDCard) SDCardError!emmc.OCR {
        const arg: emmc.SendOpCondArg = .{
            .voltage = 0xFF8000,
            .xpc = true,
            .hcs = true,
        };
        try self.prepareAppCommand();
        res.arg1 = @bitCast(arg);
        res.sendCommand(.app_sd_send_op_cond);
        return @bitCast(res.resp[0]);
    }

    fn fetchCSD(self: SDCard) SDCardError!emmc.CSD {
        res.arg1 = self.rca;
        res.sendCommand(.send_csd);
        const tmp: emmc.CSD = .{
            .standard_capacity = @bitCast(res.resp),
        };
        return switch(tmp.standard_capacity.kind) {
            .standard_capacity => tmp,
            .high_capacity => 
                .{.high_capacity = @bitCast(tmp.standard_capacity)},
            .ultra_capacity => 
                .{.ultra_capacity = @bitCast(tmp.standard_capacity)},
            else => SDCardError.UnknownCapacity,
        };
    }

    fn fetchSCR(self: SDCard) SDCardError!emmc.SCR {
        try self.prepareAppCommand();
        var blk: emmc.BlockSizeCount = @bitCast(res.block_size_count);
        blk.block_size = 8;
        blk.block_count = 1;
        res.block_size_count = @bitCast(blk);
        res.sendCommand(.app_send_scr);
        var result: u64 = 0;
        inline for (0..2) |idx| {
            while (!res.status().read_available) {
                hw.arm.waitCycles(100);
            }
            if (comptime idx == 0)
                result |= res.data
            else
                result |= @as(u64, res.data) << 32;
        }
        return @bitCast(result);
    }

    fn prepareAppCommand(self: SDCard) SDCardError!void {
        res.arg1 = self.rca;
        res.sendCommand(.use_app_cmd);
        const resp: emmc.CardStatus = @bitCast(res.resp[0]);
        if (!resp.app_cmd) return SDCardError.UnexpectedAppCommandState;
    }
};

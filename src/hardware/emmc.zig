const std = @import("std");
const c = @import("constants.zig");
const arm = @import("arm.zig");

const ctm_data = [_]CommandTransferMode{
    .{
        .index = .go_idle_state,
    },
    .{},
    .{
        .index = .all_send_cid,
        .response_type = .bits_136,
    },
    .{
        .index = .send_relative_addr,
        .response_type = .bits_48,
    },
    .{},
    .{}, // 5
    .{},
    .{
        .index = .select_card,
        .response_type = .bits_48_busy,
    },
    .{
        .index = .send_if_cond,
        .response_type = .bits_48,
    },
    .{
        .index = .send_csd,
        .response_type = .bits_136,
    },
    .{}, // 10
    .{},
    .{},
    .{},
    .{},
    .{}, // 15
    .{},
    .{
        .index = .read_single_block,
        .response_type = .bits_48,
        .command_is_data_tx = true,
        .data_tx_direction = .card_to_host,
    },
    .{},
    .{},
    .{}, // 20
    .{},
    .{},
    .{
        .index = .set_block_count,
        .response_type = .bits_48,
    },
    .{},
    .{}, // 25
    .{},
    .{},
    .{},
    .{},
    .{}, // 30
    .{},
    .{},
    .{},
    .{},
    .{}, // 35
    .{},
    .{},
    .{},
    .{},
    .{}, // 40
    .{},
    .{},
    .{},
    .{},
    .{}, // 45
    .{},
    .{},
    .{},
    .{},
    .{}, // 50
    .{},
    .{},
    .{},
    .{},
    .{
        .index = .use_app_cmd,
        .response_type = .bits_48,
    }, // 55
};

const app_ctm_data = [_]CommandTransferMode{
    .{},
    .{},
    .{},
    .{},
    .{},
    .{}, // 5
    .{},
    .{},
    .{},
    .{},
    .{}, // 10
    .{},
    .{},
    .{},
    .{},
    .{}, // 15
    .{},
    .{},
    .{},
    .{},
    .{}, // 20
    .{},
    .{},
    .{},
    .{},
    .{}, // 25
    .{},
    .{},
    .{},
    .{},
    .{}, // 30
    .{},
    .{},
    .{},
    .{},
    .{}, // 35
    .{},
    .{},
    .{},
    .{},
    .{}, // 40
    .{
        .index = .app_sd_send_op_cond,
        .response_type = .bits_48,
    },
    .{},
    .{},
    .{},
    .{}, // 45
    .{},
    .{},
    .{},
    .{},
    .{}, // 50
    .{
        .index = .app_send_scr,
        .response_type = .bits_48,
        .command_is_data_tx = true,
        .data_tx_direction = .card_to_host,
    },
};

/// Helper structure for EMMC hardware.
pub const EMMC = extern struct {
    /// Interface directly with the EMMC hardware. This structure
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0x300000);
    const Self = *volatile @This();
    const data_timeout_us = 10000;
    const stable_timeout_us = 100000;

    arg2: u32,
    block_size_count: u32,
    arg1: u32,
    command_transfer_mode: u32,
    resp: [4]u32,
    data: u32,
    f_status: u32,
    control0: u32,
    control1: u32,
    f_interrupt: u32,
    interrupt_mask: u32,
    interrupt_en: u32,
    control2: u32,
    rsvd0: [4]u32,
    force_interrupt_event: u32,
    rsvd1: [7]u32,
    boot_timeout: u32,
    debug: u32,
    rsvd2: [2]u32,
    ext_fifo_config: u32,
    ext_fifo_en: u32,
    tune_step: u32,
    tune_steps_sdr: u32,
    tune_steps_ddr: u32,
    rsvd3: [23]u32,
    spi_interrupt_support: u32,
    rsvd4: [2]u32,
    slot_interrupt_status: u32,

    comptime {std.debug.assert(@sizeOf(EMMC) == 0x100);}

    /// Read the status regitser bitfield.
    pub fn status(self: Self) Status {
        return @bitCast(self.f_status);
    }

    /// Read the interrupt pending register bitfield.
    pub fn interrupt(self: Self) Interrupt {
        return @bitCast(self.f_interrupt);
    }

    /// Read the interrupt mask register bitfield.
    pub fn interruptMask(self: Self) Interrupt {
        return @bitCast(self.interrupt_mask);
    }

    /// Read the interrupt enable register bitfield.
    pub fn interruptEn(self: Self) Interrupt {
        return @bitCast(self.interrupt_en);
    }

    /// Read the slot interrupt status register bitfield.
    pub fn slotInterruptStatus(self: Self) SlotInterruptStatus {
        return @bitCast(self.slot_interrupt_status);
    }

    /// Power off the SD clock. It is valid to call this function if
    /// the clock is already powered off.
    pub fn powerOffSDClock(self: Self) void {
        var ctl1: Control1 = @bitCast(self.control1);
        if (!ctl1.sd_clock_en) return;
        var stat = self.status();
        var us: usize = 0;
        while (
            stat.command_busy and
            stat.data_busy and
            us < data_timeout_us
        ) : (stat = self.status()) {
            arm.usleep(1);
            us += 1;
        }
        ctl1.sd_clock_en = false;
        self.control1 = @bitCast(ctl1);
    }

    /// Power on the SD clock. It is valid to call this function if
    /// the clock is already powered on. This function tries to wait
    /// for the SD clock to become stable, but does not guarantee
    /// stability on return.
    pub fn powerOnSDClock(self: Self) void {
        var ctl1: Control1 = @bitCast(self.control1);
        if (ctl1.sd_clock_en) return;
        ctl1.sd_clock_en = true;
        self.control1 = @bitCast(ctl1);
        arm.usleep(1);
        ctl1 = @bitCast(self.control1);
        var us: usize = 1;

        while (!ctl1.sd_clock_stable and us < stable_timeout_us) :
          (ctl1 = @bitCast(self.control1)) {
            arm.usleep(1);
            us += 1;
        }
    }

    /// Reset the host controller and set default control settings.
    pub fn resetHost(self: Self) void {
        var ctl1 = Control1{};
        ctl1.reset_host = true;
        self.control0 = 0;
        self.control1 = @bitCast(ctl1);
        var us: usize = 0;
        while (ctl1.reset_host and us < stable_timeout_us) :
          (ctl1 = @bitCast(self.control1)) {
            arm.usleep(1);
            us += 1;
        }
        ctl1.emmc_clock_en = true;
        ctl1.timeout_exp = 0xE;
        self.control1 = @bitCast(ctl1);
    }

    /// Set the SD clock divider value. Requires host versions 3 or
    /// later. It is the caller's responsibility to ensure the SD
    /// clock has been stopped before calling this function.
    pub fn setSDClockDivider(self: Self, div: u10) void {
        var ctl1: Control1 = @bitCast(self.control1);
        std.debug.assert(
            !ctl1.sd_clock_en and
            !self.status().command_busy and
            !self.status().data_busy and
            self.slotInterruptStatus().sd_version >= 2);
        ctl1.clock_divider_lsb = @intCast(div & 0xFF);
        ctl1.clock_divider_msb = @intCast(div >> 8);
    }

    /// Waits for any in-flight commands to complete, and then sends
    /// the command specified by `index`. It is the caller's
    /// responsibility to interpret the values of any response
    /// registers.
    pub fn sendCommand(self: Self, comptime index: CommandIndex) void {
        self.waitCommand();
        const arg: u32 = @bitCast(
            if (comptime isAppCommand(index))
                app_ctm_data[@intFromEnum(index)]
            else
                ctm_data[@intFromEnum(index)]
        );
        self.command_transfer_mode = arg;
    }

    fn waitCommand(self: Self) void {
        while(self.status().command_busy) {}
    }
};

/// Block size count register bitfield.
pub const BlockSizeCount = packed struct(u32) {
    block_size: u10 = 0,
    rsvd0: u6 = 0,
    block_count: u16 = 0,
};

/// Auto command selection.
pub const AutoCmdSel = enum(u2) {
    none,
    cmd12,
    cmd23,
    rsvd,
};

/// Command data directions.
pub const DataDirectionSel = enum(u1) {
    host_to_card,
    card_to_host,
};

/// Command block types.
pub const BlockTypeSel = enum(u1) {
    single_block,
    multi_block,
};

/// Command response types.
pub const ResponseTypeSel = enum(u2) {
    no_response,
    bits_136,
    bits_48,
    bits_48_busy,
};

/// Command type selections.
pub const CommandTypeSel = enum(u2) {
    normal,
    pause,
    start,
    abort,
};

/// All possible command indices. Includes regular and APP commands.
/// APP commands are parsed at compile-time and must start with "app".
pub const CommandIndex = enum(u6) {
    go_idle_state,
    rsvd0,
    all_send_cid,
    send_relative_addr,
    rsvd3,
    rsvd4,
    rsvd5,
    select_card,
    send_if_cond,
    send_csd,
    read_single_block = 17,
    set_block_count = 23,
    app_sd_send_op_cond = 41,
    app_send_scr = 51,
    use_app_cmd = 55,
};

/// Command transfer mode register bitfield.
pub const CommandTransferMode = packed struct(u32) {
    rsvd0: u1 = 0,
    block_count_en: bool = false,
    auto_command_en: AutoCmdSel = .none,
    data_tx_direction: DataDirectionSel = .host_to_card,
    block_type: BlockTypeSel = .single_block,
    rsvd1: u10 = 0,
    response_type: ResponseTypeSel = .no_response,
    rsvd2: u1 = 0,
    crc_check_en: bool = false,
    index_check_en: bool = false,
    command_is_data_tx: bool = false,
    command_type: CommandTypeSel = .normal,
    index: CommandIndex = .go_idle_state,
    rsvd3: u2 = 0,
};

/// Status register bitfield.
pub const Status = packed struct(u32) {
    command_busy: bool = false,
    data_busy: bool = false,
    data_active: bool = false,
    rsvd: u5 = 0,
    write_available: bool = false,
    read_available: bool = false,
    rsvd1: u10 = 0,
    data_level0: u4 = 0xF,
    cmd_level: u1 = 1,
    data_level1: u4 = 0xF,
    rsvd2: u3 = 0,
};

/// Control0 register bitfield.
pub const Control0 = packed struct(u32) {
    rsvd0: u1 = 0,
    quad_data_en: bool = false,
    high_speed_en: bool = false,
    rsvd1: u2 = 0,
    oct_data_en: bool = false,
    rsvd2: u10 = 0,
    gap_stop_en: bool = false,
    gap_restart_en: bool = false,
    read_wait_en: bool = false,
    gap_interrupt_en: bool = false,
    spi_mode_en: bool = false,
    boot_mode_access_en: bool = false,
    alt_boot_mode_access_en: bool = false,
    rsvd3: u9 = 0,
};

/// Clock selections.
pub const ClockGenSel = enum(u1) {
    divided,
    programmable,
};

/// Control1 register bitfield.
pub const Control1 = packed struct(u32) {
    emmc_clock_en: bool = false,
    sd_clock_stable: bool = false,
    sd_clock_en: bool = false,
    rsvd0: u2 = 0,
    clockgen: ClockGenSel = .divided,
    clock_divider_msb: u2 = 0,
    clock_divider_lsb: u8 = 0,
    timeout_exp: u4 = 0,
    rsvd1: u4 = 0,
    reset_host: bool = false,
    reset_command_handler: bool = false,
    reset_data_handler: bool = false,
    rsvd2: u5 = 0,
};

/// Interrupt register bitfield.
pub const Interrupt = packed struct(u32) {
    command_done: bool = false,
    data_done: bool = false,
    block_gap: bool = false,
    rsvd0: u1 = 0,
    write_ready: bool = false,
    read_ready: bool = false,
    rsvd1: u2 = 0,
    card: bool = false,
    rsvd2: u3 = 0,
    retune: bool = false,
    boot_ack: bool = false,
    end_boot: bool = false,
    err: bool = false,
    command_timeout: bool = false,
    crc_err: bool = false,
    command_end_err: bool = false,
    command_ndx_err: bool = false,
    data_timeout: bool = false,
    data_crc_err: bool = false,
    data_end_err: bool = false,
    rsvd3: u1 = 0,
    auto_cmd_err: bool = false,
    rsvd4: u7 = 0,
};

/// Speed mode selections.
pub const SpeedModeSel = enum(u3) {
    sdr12,
    sdr25,
    sdr50,
    sdr104,
    ddr50,
};

/// Control2 register bitfield.
pub const Control2 = packed struct(u32) {
    auto_not_executed: bool = false,
    auto_timeout: bool = false,
    auto_crc_err: bool = false,
    auto_end_err: bool = false,
    auto_ndx_err: bool = false,
    rsvd0: u2 = 0,
    auto_cmd12_err: bool = false,
    rsvd1: u8 = 0,
    sd_speed_mode: SpeedModeSel = .sdr12,
    rsvd2: u3 = 0,
    tune_sd_clock: bool = false,
    sd_clock_tuned: bool = false,
    rsvd3: u8 = 0,
};

/// Slot interrupt status register bitfield.
pub const SlotInterruptStatus = packed struct(u32) {
    slot_status: u8,
    rsvd0: u8,
    sd_version: u8,
    vendor: u8,
};

/// Card states.
pub const CardState = enum(u4) {
    idle,
    ready,
    ident,
    stby,
    tran,
    data,
    rcv,
    prg,
    dis,
    _,
};

/// CardStatus register bitfield from bits_48 response types.
pub const CardStatus = packed struct(u32) {
    rsvd0: u3 = 0,
    ake_seq_err: bool = false,
    rsvd1: u1 = 0,
    app_cmd: bool = false,
    fx_event: bool = false,
    rsvd2: u1 = 0,
    ready_for_data: bool = false,
    current_state: CardState = .idle,
    erase_reset: bool = false,
    card_ecc_disabled: bool = false,
    wp_erase_skip: bool = false,
    csd_overwrite: bool = false,
    rsvd3: u2 = 0,
    err: bool = false,
    cc_err: bool = false,
    card_ecc_failed: bool = false,
    illegal_command: bool = false,
    com_crc_err: bool = false,
    lock_unlock_failed: bool = false,
    card_is_locked: bool = false,
    wp_violation: bool = false,
    erase_param: bool = false,
    erase_seq_err: bool = false,
    block_len_err:bool = false,
    address_err: bool = false,
    out_of_range: bool = false,
};

/// Argument register for the SEND_OP_COND command.
pub const SendOpCondArg = packed struct(u32) {
    voltage: u24 = 0,
    s18r: bool = false,
    rsvd0: u3 = 0,
    xpc: bool = false,
    rsvd1: u1 = 0,
    hcs: bool = false,
    rsvd2: u1 = 0,
};

/// OCR register bitfield.
pub const OCR = packed struct(u32) {
    rsvd0: u15 = 0,
    v2728: bool = false,
    v2829: bool = false,
    v2930: bool = false,
    v3031: bool = false,
    v3132: bool = false,
    v3233: bool = false,
    v3334: bool = false,
    v3435: bool = false,
    v3536: bool = false,
    s18a: bool = false,
    rsvd1: u2 = 0,
    co2t: bool = false,
    rsvd2: u1 = 0,
    uhs2: bool = false,
    ccs: bool = false,
    pwrup: bool = false,
};

/// CID register bitfield.
pub const CID = extern struct {
    crc: u8 = 0,
    date: [2]u8 = .{0, 0},
    serial_number: [4]u8 = .{0, 0, 0, 0},
    revision: u8 = 0,
    name: [5]u8 = .{0, 0, 0, 0, 0},
    oem: [2]u8 = .{0, 0},
    manufacturer: u8 = 0,
};

/// File formats.
pub const FileFormat = enum(u2) {
    hard_disk,
    floppy,
    universal,
    unknown,
};

/// Types of CSD.
pub const CSDKind = enum(u2) {
    standard_capacity,
    high_capacity,
    ultra_capacity,
    reserved,
};

/// Union for each possible CSD kind.
pub const CSD = union(CSDKind) {
    standard_capacity: packed struct {
        crc: u8 = 0,
        rsvd0: u1 = 0,
        wr_prot_upc: bool = false,
        file_format: FileFormat = .hard_disk,
        tmp_wr_prot: bool = false,
        prm_wr_prot: bool = false,
        copy: bool = false,
        file_format_group: u1 = 0,
        rsvd1: u5 = 0,
        partial_block_wr: bool = false,
        max_wr_block_len: u4 = 0,
        wr_speed_factor: u3 = 0,
        rsvd2: u2 = 0,
        wp_group_en: bool = false,
        wp_group_size: u7 = 0,
        sector_size: u7 = 0,
        erase_block_en: bool = false,
        size_mult: u3 = 0,
        vdd_wr_curr_max: u3 = 0,
        vdd_wr_curr_min: u3 = 0,
        vdd_rd_curr_max: u3 = 0,
        vdd_rd_curr_min: u3 = 0,
        size: u12 = 0,
        rsvd3: u2 = 0,
        dsr: bool = false,
        rd_blk_misalign: bool = false,
        wr_blk_misalign: bool = false,
        rd_blk_partial: bool = false,
        rd_blk_len: u4 = 0,
        ccc: u12 = 0,
        transfer_rate: u8 = 0,
        nsac: u8 = 0,
        taac: u8 = 0,
        rsvd4: u6 = 0,
        kind: CSDKind = .standard_capacity,
    },
    high_capacity: packed struct {
        crc: u8 = 0,
        rsvd0: u1 = 0,
        wr_prot_upc: bool = false,
        file_format: FileFormat = .hard_disk,
        tmp_wr_prot: bool = false,
        prm_wr_prot: bool = false,
        copy: bool = false,
        file_format_group: u1 = 0,
        rsvd1: u5 = 0,
        partial_block_wr: bool = false,
        max_wr_block_len: u4 = 0,
        wr_speed_factor: u3 = 0,
        rsvd2: u2 = 0,
        wp_group_en: bool = false,
        wp_group_size: u7 = 0,
        sector_size: u7 = 0,
        erase_block_en: bool = false,
        rsvd3: u1 = 0,
        size: u22 = 0,
        rsvd4: u6 = 0,
        dsr: bool = false,
        rd_blk_misalign: bool = false,
        wr_blk_misalign: bool = false,
        rd_blk_partial: bool = false,
        rd_blk_len: u4 = 0,
        ccc: u12 = 0,
        transfer_rate: u8 = 0,
        nsac: u8 = 0,
        taac: u8 = 0,
        rsvd5: u6 = 0,
        kind: CSDKind = .high_capacity,
    },
    ultra_capacity: packed struct {
        crc: u8 = 0,
        rsvd0: u1 = 0,
        wr_prot_upc: bool = false,
        file_format: FileFormat = .hard_disk,
        tmp_wr_prot: bool = false,
        prm_wr_prot: bool = false,
        copy: bool = false,
        file_format_group: u1 = 0,
        rsvd1: u5 = 0,
        partial_block_wr: bool = false,
        max_wr_block_len: u4 = 0,
        wr_speed_factor: u3 = 0,
        rsvd2: u2 = 0,
        wp_group_en: bool = false,
        wp_group_size: u7 = 0,
        sector_size: u7 = 0,
        erase_block_en: bool = false,
        rsvd3: u1 = 0,
        size: u28 = 0,
        dsr: bool = false,
        rd_blk_misalign: bool = false,
        wr_blk_misalign: bool = false,
        rd_blk_partial: bool = false,
        rd_blk_len: u4 = 0,
        ccc: u12 = 0,
        transfer_rate: u8 = 0,
        nsac: u8 = 0,
        taac: u8 = 0,
        rsvd5: u6 = 0,
        kind: CSDKind = .ultra_capacity,
    },
    reserved: [128]u8,
};

/// SCR register bitfield.
pub const SCR = packed struct(u64) {
    rsvd0: u32 = 0,
    command_support: u5 = 0,
    rsvd1: u1 = 0,
    spec_x: u4 = 0,
    spec_v4: bool = false,
    ext_security: u4 = 0,
    spec_v3: bool = false,
    bus_width: u4 = 0,
    cprm_security: u3 = 0,
    dsae: bool = false,
    spec: u4 = 0,
    scr_kind: u4 = 0,
};

fn isAppCommand(comptime tag: CommandIndex) bool {
    return std.mem.startsWith(u8, @tagName(tag), "app");
}

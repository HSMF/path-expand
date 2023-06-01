const std = @import("std");
const allocator = std.heap.page_allocator;
const print = std.debug.print;

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

const OpenedDir = struct {
    dir: std.fs.IterableDir,
    base: []const u8,
};

const Args = struct {
    path_var: std.ArrayList([]const u8),
    flags: Flags,
};

const Flags = struct {
    display_full: bool = false,
    list: bool = false,
    help: bool = false,
    short: bool = false,
    suffix: bool = false,
    display_file_types: DisplayFileType = .{},
};

/// Which file types to display. By default, {file, sym_link} are enabled
const DisplayFileType = struct {
    block_device: bool = false,
    character_device: bool = false,
    directory: bool = false,
    named_pipe: bool = false,
    sym_link: bool = true,
    file: bool = true,
    unix_domain_socket: bool = false,
    whiteout: bool = false,
    door: bool = false,
    event_port: bool = false,
    unknown: bool = false,

    const Self = @This();
    const Kind = std.fs.IterableDir.Entry.Kind;
    fn shouldDisplay(self: *const Self, kind: Kind) bool {
        switch (kind) {
            Kind.BlockDevice => return self.block_device,
            Kind.CharacterDevice => return self.character_device,
            Kind.Directory => return self.directory,
            Kind.NamedPipe => return self.named_pipe,
            Kind.SymLink => return self.sym_link,
            Kind.File => return self.file,
            Kind.UnixDomainSocket => return self.unix_domain_socket,
            Kind.Whiteout => return self.whiteout,
            Kind.Door => return self.door,
            Kind.EventPort => return self.event_port,
            Kind.Unknown => return self.unknown,
        }
    }
};

fn matches_short(arg: []const u8, s: u8) bool {
    if (arg.len != 2) return false;
    if (arg[0] != '-') return false;
    if (arg[1] != s) return false;
    return true;
}

fn matches_long(arg: []const u8, long: []const u8) bool {
    if (arg.len < 2) return false;
    if (arg[0] != '-') return false;
    if (arg[1] != '-') return false;
    return eql(arg[2..arg.len], long);
}

fn matches_flag(arg: []const u8, short: ?u8, long: ?[]const u8) bool {
    if (short) |s| {
        if (matches_short(arg, s)) return true;
    }

    if (long) |l| {
        if (matches_long(arg, l)) return true;
    }

    return false;
}

fn parseArgs(args: [][:0]const u8) !?Args {
    var flags: Flags = .{};
    var i: usize = 1;
    var path_var = std.ArrayList([]const u8).init(allocator);

    while (i < args.len) : (i += 1) {
        const arg = std.mem.span(args[i]);
        if (matches_flag(arg, 'l', "list")) {
            flags.list = true;
            continue;
        }

        if (matches_flag(arg, 'h', "help")) {
            flags.help = true;
            continue;
        }

        if (matches_flag(arg, 's', "short")) {
            flags.short = true;
            continue;
        }

        if (matches_flag(arg, 'F', "classify")) {
            flags.suffix = true;
            continue;
        }

        if (matches_flag(arg, 't', "type")) {
            i += 1;
            if (i == args.len) {
                return null;
            }

            const typ = std.mem.span(args[i]);
            if (eql(typ, "b")) {
                flags.display_file_types.block_device = true;
                continue;
            }
            if (eql(typ, "c")) {
                flags.display_file_types.character_device = true;
                continue;
            }
            if (eql(typ, "d")) {
                flags.display_file_types.directory = true;
                continue;
            }
            if (eql(typ, "f")) {
                flags.display_file_types.file = true;
                continue;
            }
            if (eql(typ, "l")) {
                flags.display_file_types.sym_link = true;
                continue;
            }
            if (eql(typ, "p")) {
                flags.display_file_types.named_pipe = true;
                continue;
            }
            if (eql(typ, "s")) {
                flags.display_file_types.unix_domain_socket = true;
                continue;
            }
            return null;
        }

        if (matches_flag(arg, 'n', "no-type")) {
            i += 1;
            if (i == args.len) {
                return null;
            }

            const typ = std.mem.span(args[i]);
            if (eql(typ, "b")) {
                flags.display_file_types.block_device = false;
                continue;
            }
            if (eql(typ, "c")) {
                flags.display_file_types.character_device = false;
                continue;
            }
            if (eql(typ, "d")) {
                flags.display_file_types.directory = false;
                continue;
            }
            if (eql(typ, "f")) {
                flags.display_file_types.file = false;
                continue;
            }
            if (eql(typ, "l")) {
                flags.display_file_types.sym_link = false;
                continue;
            }
            if (eql(typ, "p")) {
                flags.display_file_types.named_pipe = false;
                continue;
            }
            if (eql(typ, "s")) {
                flags.display_file_types.unix_domain_socket = false;
                continue;
            }
            return null;
        }

        if (eql(arg, "--")) {
            // parse literally afterwards
            i += 1;
            break;
        }

        if (arg.len == 0) {
            continue;
        }
        try path_var.append(arg);
    }
    for (args[i..args.len]) |arg| {
        if (arg.len == 0) {
            continue;
        }
        try path_var.append(arg);
    }

    return .{ .flags = flags, .path_var = path_var };
}

pub fn openDirNormalized(path: []const u8, flags: std.fs.Dir.OpenDirOptions, buf: []u8) !OpenedDir {
    if (path.len == 0) {
        std.os.abort();
    }

    if (path.len >= 2 and path[0] == '~' and path[1] == '/') {
        // expand $HOME
        const home = std.os.getenv("HOME") orelse std.os.abort();
        // var buf = try allocator.alloc(u8, home.len + path.len - 1);
        // defer allocator.free(buf);

        @memcpy(buf.ptr, home.ptr, home.len);
        @memcpy(buf.ptr + home.len, path.ptr + 1, path.len - 1);
        const base = buf[0 .. home.len + path.len - 1];

        return .{ .dir = try std.fs.openIterableDirAbsolute(base, flags), .base = base };
    }

    if (path[0] == '/') {
        return .{ .dir = try std.fs.openIterableDirAbsolute(path, flags), .base = path };
    }

    return .{ .dir = try std.fs.cwd().openIterableDir(path, flags), .base = try std.fs.cwd().realpath(path, buf) };
}

fn suffix(kind: std.fs.IterableDir.Entry.Kind) []const u8 {
    switch (kind) {
        std.fs.IterableDir.Entry.Kind.SymLink => {
            return "@";
        },
        std.fs.IterableDir.Entry.Kind.File => {
            return "";
        },
        std.fs.IterableDir.Entry.Kind.Unknown => {
            return "?";
        },
        std.fs.IterableDir.Entry.Kind.Directory => {
            return "/";
        },
        else => {
            return "?";
        },
    }
}

fn printEntry(writer: anytype, base: []const u8, entry: std.fs.IterableDir.Entry, dir: std.fs.Dir, buf: []u8, flags: Flags) !void {
    if (!flags.display_file_types.shouldDisplay(entry.kind)) {
        return;
    }
    const suff = if (flags.suffix) suffix(entry.kind) else "";
    if (flags.short) {
        try writer.print("{s}{s}\n", .{ entry.name, suff });
        return;
    }

    switch (entry.kind) {
        std.fs.IterableDir.Entry.Kind.SymLink => {
            const realpath = dir.realpath(entry.name, buf) catch {
                try writer.print("{s}{s}: {s}/{s} -> ?\n", .{ entry.name, suff, base, entry.name });
                return;
            };
            try writer.print("{s}{s}: {s}/{s} -> {s}\n", .{ entry.name, suff, base, entry.name, realpath });
            return;
        },
        else => {},
    }

    try writer.print("{s}{s}: {s}/{s}\n", .{ entry.name, suff, base, entry.name });
}

fn printPath(stdout: anytype, pathvar: []const u8, flags: Flags) !void {
    var parts = std.mem.split(u8, pathvar, ":");

    var path_buf = try allocator.alloc(u8, 4096);
    defer allocator.free(path_buf);

    var basepath_buf = try allocator.alloc(u8, 4096);
    defer allocator.free(basepath_buf);

    while (parts.next()) |path| {
        var dir = openDirNormalized(path, .{}, basepath_buf) catch continue;
        defer dir.dir.close();
        var walker = dir.dir.iterate();
        while (try walker.next()) |entry| {
            try printEntry(stdout, dir.base, entry, dir.dir.dir, path_buf, flags);
        }
    }
}

fn printHelp(progname: []const u8) void {
    print("Usage: {s} [-lh] <PATH>...\n\n", .{progname});
    print("  <PATH>...              Colon (':') separated list of paths\n\n", .{});
    print("  -h, --help             Show this message\n", .{});
    // print("  -l, --list             List all resolved files\n", .{});
    print("  -s, --short            Print only the names\n", .{});
    print("  -F, --classify         Display type indicator by file names\n", .{});
    print("  -t, --type <type>      Include the file type in the output\n", .{});
    print("  -n, --no-type <type>   Exclude the file type in the output\n", .{});
    print("                         Possible values for <type> are:\n", .{});
    print("                           b: Block Device\n", .{});
    print("                           c: Character Device\n", .{});
    print("                           d: Directory\n", .{});
    print("                           f: File\n", .{});
    print("                           l: Symbolic Link\n", .{});
    print("                           p: Named Pipe\n", .{});
    print("                           s: Unix Domain Socket\n", .{});
}

pub fn main() !void {
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args = try parseArgs(argv) orelse {
        printHelp(std.mem.span(argv[0]));
        std.os.exit(1);
    };
    if (args.flags.help) {
        printHelp(std.mem.span(argv[0]));
        std.os.exit(0);
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    if (args.path_var.items.len == 0) {
        // print("No path argument was supplied\n", .{});
        const path = std.os.getenv("PATH") orelse "";
        try printPath(stdout, path, args.flags);
    }
    for (args.path_var.items) |path| {
        try printPath(stdout, path, args.flags);
    }

    try bw.flush();
}

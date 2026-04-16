const std = @import("std");

const version: std.SemanticVersion = .{ .major = 2, .minor = 44, .patch = 0 };

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("binutils", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pie", "Produce Position Independent Code");

    // Plugins have a dependency on the install prefix so they have been disabled by default in this port.
    const enable_plugins = b.option(bool, "plugins", "Enable plugins") orelse false;

    const libsframe_config_header = b.addConfigHeader(.{}, .{
        .HAVE_BYTESWAP_H = if (target.result.os.tag == .linux or target.result.os.tag == .wasi) true else null,
        .HAVE_DECL_BSWAP_16 = target.result.os.tag == .linux or target.result.os.tag == .wasi,
        .HAVE_DECL_BSWAP_32 = target.result.os.tag == .linux or target.result.os.tag == .wasi,
        .HAVE_DECL_BSWAP_64 = target.result.os.tag == .linux or target.result.os.tag == .wasi,
        .HAVE_DLFCN_H = if (target.result.os.tag != .windows) true else null,
        .HAVE_ENDIAN_H = if (target.result.os.tag == .linux or target.result.os.tag == .wasi) true else null,
        .HAVE_GETPAGESIZE = if (target.result.os.tag != .windows) true else null,
        .HAVE_INTTYPES_H = true,
        .HAVE_MEMORY_H = true,
        .HAVE_MMAP = if (target.result.os.tag == .linux) true else null,
        .HAVE_STDINT_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_SYS_PARAM_H = true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_UNISTD_H = true,
        .LT_OBJDIR = ".libs/", // What the hell is this?
        .PACKAGE = "libsframe",
        .PACKAGE_BUGREPORT = "",
        .PACKAGE_NAME = "libsframe",
        .PACKAGE_STRING = b.fmt("libsframe {f}", .{version}),
        .PACKAGE_TARNAME = "libsframe",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = b.fmt("{f}", .{version}),
        .STDC_HEADERS = true,
        .VERSION = b.fmt("{f}", .{version}),
    });

    const libsframe = b.addLibrary(.{
        .linkage = linkage,
        .name = "sframe",
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });
    b.installArtifact(libsframe);
    libsframe.installHeader(upstream.path("include/sframe.h"), "sframe.h");
    libsframe.installHeader(upstream.path("include/sframe-api.h"), "sframe-api.h");
    libsframe.installHeader(upstream.path("include/ansidecl.h"), "ansidecl.h");
    libsframe.setVersionScript(upstream.path("libsframe/libsframe.ver"));
    libsframe.root_module.addConfigHeader(libsframe_config_header);
    libsframe.root_module.addIncludePath(upstream.path("libsframe"));
    libsframe.root_module.addIncludePath(upstream.path("include"));
    libsframe.root_module.addIncludePath(upstream.path("libctf"));
    libsframe.root_module.addCSourceFiles(.{
        .root = upstream.path("libsframe"),
        .files = &.{
            "sframe.c",
            "sframe-dump.c",
            "sframe-error.c",
        },
    });

    const libiberty_config_header = b.addConfigHeader(.{
        .style = .{ .autoconf_undef = upstream.path("libiberty/config.in") },
    }, .{
        .AC_APPLE_UNIVERSAL_BUILD = null,
        .CRAY_STACKSEG_END = null,
        .HAVE_ALLOCA_H = switch (target.result.os.tag) {
            .linux, .macos, .wasi => true,
            .freebsd, .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_ASPRINTF = true,
        .HAVE_ATEXIT = true,
        .HAVE_BASENAME = true,
        .HAVE_BCMP = true,
        .HAVE_BCOPY = true,
        .HAVE_BSEARCH = true,
        .HAVE_BZERO = true,
        .HAVE_CALLOC = true,
        .HAVE_CANONICALIZE_FILE_NAME = switch (target.result.os.tag) {
            .linux => if (target.result.isGnuLibC()) true else null,
            .macos => null,
            .wasi => null,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_CLOCK = true,
        .HAVE_DECL_ASPRINTF = true,
        .HAVE_DECL_BASENAME = true,
        .HAVE_DECL_CALLOC = true,
        .HAVE_DECL_FFS = true,
        .HAVE_DECL_GETENV = true,
        .HAVE_DECL_GETOPT = true,
        .HAVE_DECL_MALLOC = true,
        .HAVE_DECL_REALLOC = true,
        .HAVE_DECL_SBRK = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_DECL_SNPRINTF = true,
        .HAVE_DECL_STRNLEN = true,
        .HAVE_DECL_STRTOL = true,
        .HAVE_DECL_STRTOLL = true,
        .HAVE_DECL_STRTOUL = true,
        .HAVE_DECL_STRTOULL = true,
        .HAVE_DECL_STRVERSCMP = switch (target.result.os.tag) {
            .linux => true,
            .macos => false,
            .wasi => true,
            .freebsd => true,
            .netbsd => false,
            else => @panic("unsupported OS"),
        },
        .HAVE_DECL_VASPRINTF = true,
        .HAVE_DECL_VSNPRINTF = true,
        .HAVE_DUP3 = if (target.result.isMuslLibC() or (target.result.isGnuLibC() and target.result.os.version_range.linux.glibc.order(.{ .major = 2, .minor = 9, .patch = 0 }) != .lt)) true else null,
        .HAVE_FCNTL_H = true,
        .HAVE_FFS = true,
        .HAVE_FORK = if (target.result.os.tag == .wasi) null else true,
        .HAVE_GETCWD = true,
        .HAVE_GETPAGESIZE = true,
        .HAVE_GETRLIMIT = if (target.result.os.tag == .wasi) null else true,
        .HAVE_GETRUSAGE = true,
        .HAVE_GETSYSINFO = null,
        .HAVE_GETTIMEOFDAY = true,
        .HAVE_INDEX = true,
        .HAVE_INSQUE = true,
        .HAVE_INTPTR_T = true,
        .HAVE_INTTYPES_H = true,
        .HAVE_LIBGEN_H = true,
        .HAVE_LIMITS_H = true,
        .HAVE_LONG_LONG = true,
        .HAVE_MACHINE_HAL_SYSINFO_H = null,
        .HAVE_MALLOC_H = if (target.result.os.tag == .macos) null else true,
        .HAVE_MEMCHR = true,
        .HAVE_MEMCMP = true,
        .HAVE_MEMCPY = true,
        .HAVE_MEMMEM = true,
        .HAVE_MEMMOVE = true,
        .HAVE_MEMORY_H = true,
        .HAVE_MEMRCHR = if (target.result.os.tag == .macos) null else true,
        .HAVE_MEMSET = true,
        .HAVE_MKSTEMPS = switch (target.result.os.tag) {
            .wasi => null,
            .linux => if (target.result.abi.isMusl() or (target.result.abi.isGnu() and target.result.os.version_range.linux.glibc.order(.{ .major = 2, .minor = 11, .patch = 0 }) != .lt)) true else null,
            else => true,
        },
        .HAVE_MMAP = if (target.result.os.tag == .linux) null else true,
        .HAVE_ON_EXIT = if (target.result.isGnuLibC()) true else null,
        .HAVE_PIPE2 = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_POSIX_SPAWN = if (target.result.os.tag == .wasi) null else true,
        .HAVE_POSIX_SPAWNP = if (target.result.os.tag == .wasi) null else true,
        .HAVE_PROCESS_H = null,
        .HAVE_PSIGNAL = true,
        .HAVE_PSTAT_GETDYNAMIC = null,
        .HAVE_PSTAT_GETSTATIC = null,
        .HAVE_PUTENV = true,
        .HAVE_RANDOM = true,
        .HAVE_REALPATH = true,
        .HAVE_RENAME = true,
        .HAVE_RINDEX = true,
        .HAVE_SBRK = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_SETENV = true,
        .HAVE_SETPROCTITLE = switch (target.result.os.tag) {
            .linux => null,
            .macos => null,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SETRLIMIT = if (target.result.os.tag == .wasi) null else true,
        .HAVE_SIGSETMASK = switch (target.result.os.tag) {
            .linux => target.result.isGnuLibC(),
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SNPRINTF = true,
        .HAVE_SPAWNVE = null,
        .HAVE_SPAWNVPE = null,
        .HAVE_SPAWN_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STDIO_EXT_H = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_STDLIB_H = true,
        .HAVE_STPCPY = true,
        .HAVE_STPNCPY = true,
        .HAVE_STRCASECMP = true,
        .HAVE_STRCHR = true,
        .HAVE_STRDUP = true,
        .HAVE_STRERROR = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_STRNCASECMP = true,
        .HAVE_STRNDUP = true,
        .HAVE_STRNLEN = true,
        .HAVE_STRRCHR = true,
        .HAVE_STRSIGNAL = true,
        .HAVE_STRSTR = true,
        .HAVE_STRTOD = true,
        .HAVE_STRTOL = true,
        .HAVE_STRTOLL = true,
        .HAVE_STRTOUL = true,
        .HAVE_STRTOULL = true,
        .HAVE_STRVERSCMP = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => true,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYSCONF = true,
        .HAVE_SYSCTL = switch (target.result.os.tag) {
            .linux => if (target.result.isGnuLibC()) true else null,
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYSMP = null,
        .HAVE_SYS_ERRLIST = switch (target.result.os.tag) {
            .linux => if (target.result.isGnuLibC()) true else null,
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_FILE_H = true,
        .HAVE_SYS_MMAN_H = if (target.result.os.tag == .wasi) null else true,
        .HAVE_SYS_NERR = switch (target.result.os.tag) {
            .linux => if (target.result.isGnuLibC()) true else null,
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_PARAM_H = true,
        .HAVE_SYS_PRCTL_H = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_PSTAT_H = null,
        .HAVE_SYS_RESOURCE_H = if (target.result.os.tag == .wasi) null else true,
        .HAVE_SYS_SIGLIST = switch (target.result.os.tag) {
            .linux => if (target.result.isGnuLibC()) true else null,
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_SYSCTL_H = switch (target.result.os.tag) {
            .linux => null,
            .macos => true,
            .wasi => null,
            .freebsd => true,
            .netbsd => true,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_SYSINFO_H = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .HAVE_SYS_SYSMP_H = null,
        .HAVE_SYS_SYSTEMCFG_H = null,
        .HAVE_SYS_TABLE_H = null,
        .HAVE_SYS_TIME_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_SYS_WAIT_H = if (target.result.os.tag == .wasi) null else true,
        .HAVE_TABLE = null,
        .HAVE_TIMES = true,
        .HAVE_TIME_H = true,
        .HAVE_TMPNAM = if (target.result.os.tag == .wasi) null else true,
        .HAVE_UINTPTR_T = true,
        .HAVE_UNISTD_H = true,
        .HAVE_VASPRINTF = true,
        .HAVE_VFORK = if (target.result.os.tag == .wasi) null else true,
        .HAVE_VFORK_H = null,
        .HAVE_VFPRINTF = true,
        .HAVE_VPRINTF = true,
        .HAVE_VSPRINTF = true,
        .HAVE_WAIT3 = if (target.result.os.tag == .wasi) null else true,
        .HAVE_WAIT4 = if (target.result.os.tag == .wasi) null else true,
        .HAVE_WAITPID = if (target.result.os.tag == .wasi) null else true,
        .HAVE_WORKING_FORK = if (target.result.os.tag == .wasi) null else true,
        .HAVE_WORKING_VFORK = if (target.result.os.tag == .wasi) null else true,
        .HAVE_X86_SHA1_HW_SUPPORT = if (target.result.cpu.arch.isX86() and
            std.Target.x86.featureSetHas(target.result.cpu.features, .sha) and
            std.Target.x86.featureSetHas(target.result.cpu.features, .sse4_1)) true else null,
        .HAVE__DOPRNT = null,
        .HAVE__SYSTEM_CONFIGURATION = null,
        .HAVE___FSETLOCKING = switch (target.result.os.tag) {
            .linux => true,
            .macos => null,
            .wasi => true,
            .freebsd => null,
            .netbsd => null,
            else => @panic("unsupported OS"),
        },
        .NEED_DECLARATION_CANONICALIZE_FILE_NAME = if (target.result.isGnuLibC()) null else true,
        .NEED_DECLARATION_ERRNO = null,
        .NO_MINUS_C_MINUS_O = null,
        .PACKAGE_BUGREPORT = "",
        .PACKAGE_NAME = "",
        .PACKAGE_STRING = "",
        .PACKAGE_TARNAME = "",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = "",
        .SIZEOF_INT = target.result.cTypeByteSize(.int),
        .SIZEOF_LONG = target.result.cTypeByteSize(.long),
        .SIZEOF_LONG_LONG = target.result.cTypeByteSize(.longlong),
        .SIZEOF_SIZE_T = target.result.ptrBitWidth() / 8,
        .STACK_DIRECTION = @as(i64, if (target.result.os.tag == .linux) -1 else 0),
        .STDC_HEADERS = true,
        .TIME_WITH_SYS_TIME = true,
        .UNSIGNED_64BIT_TYPE = .uint64_t,
        ._ALL_SOURCE = true,
        ._GNU_SOURCE = true,
        ._POSIX_PTHREAD_SEMANTICS = true,
        ._TANDEM_SOURCE = true,
        .__EXTENSIONS__ = true,
        .WORDS_BIGENDIAN = if (target.result.cpu.arch.endian() == .big) @as(i64, 1) else null,
        ._FILE_OFFSET_BITS = null,
        ._LARGE_FILES = null,
        ._MINIX = null,
        ._POSIX_1_SOURCE = null,
        ._POSIX_SOURCE = null,
        .@"const" = null,
        .@"inline" = null,
        .intptr_t = null,
        .pid_t = null,
        .ssize_t = null,
        .uintptr_t = null,
        // .vfork
    });
    if (target.result.os.tag == .wasi) {
        libiberty_config_header.addValues(.{ .vfork = .fork });
    } else {
        libiberty_config_header.addValues(.{ .vfork = null });
    }

    const libbfd_config_header = b.addConfigHeader(.{
        .style = .{ .autoconf_undef = upstream.path("bfd/config.in") },
    }, .{
        .AC_APPLE_UNIVERSAL_BUILD = null,
        .CORE_HEADER = @as(?[]const u8, switch (target.result.os.tag) {
            .linux => switch (target.result.cpu.arch) {
                .x86_64 => "hosts/x86-64linux.h",
                else => null,
            },
            else => null,
        }),
        .DEFAULT_LD_Z_SEPARATE_CODE = if (target.result.os.tag == .linux) true else false,
        .ENABLE_CHECKING = null,
        .ENABLE_NLS = if (target.result.os.tag == .linux) true else null,
        .HAVE_CFLOCALECOPYPREFERREDLANGUAGES = null,
        .HAVE_CFPREFERENCESCOPYAPPVALUE = null,
        .HAVE_DCGETTEXT = if (target.result.os.tag == .linux) true else null,
        .HAVE_DECL_ASPRINTF = true,
        .HAVE_DECL_BASENAME = target.result.isGnuLibC(),
        .HAVE_DECL_FFS = true,
        .HAVE_DECL_FOPEN64 = target.result.os.tag == .wasi or target.result.isGnuLibC(),
        .HAVE_DECL_FSEEKO = true,
        .HAVE_DECL_FSEEKO64 = target.result.os.tag == .wasi or target.result.isGnuLibC(),
        .HAVE_DECL_FTELLO = true,
        .HAVE_DECL_FTELLO64 = target.result.os.tag == .wasi or target.result.isGnuLibC(),
        .HAVE_DECL_STPCPY = true,
        .HAVE_DECL_STRNLEN = true,
        .HAVE_DECL_VASPRINTF = true,
        .HAVE_DECL____LC_CODEPAGE_FUNC = false,
        .HAVE_DLFCN_H = true,
        .HAVE_FCNTL = true,
        .HAVE_FCNTL_H = true,
        .HAVE_FDOPEN = true,
        .HAVE_FILENO = true,
        .HAVE_FLS = if (target.result.os.tag.isBSD()) true else null,
        .HAVE_FOPEN64 = if (target.result.os.tag == .wasi or target.result.isGnuLibC()) true else null,
        .HAVE_FSEEKO = true,
        .HAVE_FSEEKO64 = if (target.result.os.tag == .wasi or target.result.isGnuLibC()) true else null,
        .HAVE_FTELLO = true,
        .HAVE_FTELLO64 = if (target.result.os.tag == .wasi or target.result.isGnuLibC()) true else null,
        .HAVE_GETGID = if (target.result.os.tag == .wasi) null else true,
        .HAVE_GETPAGESIZE = true,
        .HAVE_GETRLIMIT = if (target.result.os.tag == .wasi) null else true,
        .HAVE_GETTEXT = if (target.result.os.tag == .linux) true else null,
        .HAVE_GETUID = if (target.result.os.tag == .wasi) null else true,
        .HAVE_HIDDEN = true,
        .HAVE_ICONV = switch (target.result.os.tag) {
            .wasi, .freebsd, .netbsd => true,
            else => null,
        },
        .HAVE_INTTYPES_H = true,
        .HAVE_LWPSTATUS_T = null,
        .HAVE_LWPSTATUS_T_PR_CONTEXT = null,
        .HAVE_LWPSTATUS_T_PR_FPREG = null,
        .HAVE_LWPSTATUS_T_PR_REG = null,
        .HAVE_LWPXSTATUS_T = null,
        .HAVE_MADVISE = if (target.result.os.tag == .wasi) null else true,
        .HAVE_MEMORY_H = true,
        .HAVE_MMAP = if (target.result.os.tag == .linux) true else null,
        .HAVE_MPROTECT = if (target.result.os.tag == .wasi) null else true,
        .HAVE_PRPSINFO32_T = if (target.result.os.tag == .freebsd) true else null,
        .HAVE_PRPSINFO32_T_PR_PID = if (target.result.os.tag == .freebsd) true else null,
        .HAVE_PRPSINFO_T = if (target.result.os.tag == .linux or target.result.os.tag == .freebsd) true else null,
        .HAVE_PRPSINFO_T_PR_PID = if (target.result.os.tag == .linux or target.result.os.tag == .freebsd) true else null,
        .HAVE_PRSTATUS32_T = if (target.result.os.tag == .freebsd) true else null,
        .HAVE_PRSTATUS32_T_PR_WHO = null,
        .HAVE_PRSTATUS_T = if (target.result.os.tag == .linux or target.result.os.tag == .freebsd) true else null,
        .HAVE_PRSTATUS_T_PR_WHO = null,
        .HAVE_PSINFO32_T = null,
        .HAVE_PSINFO32_T_PR_PID = null,
        .HAVE_PSINFO_T = null,
        .HAVE_PSINFO_T_PR_PID = null,
        .HAVE_PSTATUS32_T = null,
        .HAVE_PSTATUS_T = null,
        .HAVE_PXSTATUS_T = null,
        .HAVE_STDINT_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_ST_C_IMPL = null,
        .HAVE_SYSCONF = true,
        .HAVE_SYS_FILE_H = true,
        .HAVE_SYS_PARAM_H = true,
        .HAVE_SYS_PROCFS_H = if (target.result.os.tag == .linux or target.result.os.tag == .freebsd) true else null,
        .HAVE_SYS_RESOURCE_H = if (target.result.os.tag == .wasi) null else true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_UNISTD_H = true,
        .HAVE_WIN32_PSTATUS_T = null,
        .HAVE_WINDOWS_H = null,
        .HAVE_ZSTD = true,
        .LT_OBJDIR = ".libs/", // What the hell is this?
        .PACKAGE = "bfd",
        .PACKAGE_BUGREPORT = "",
        .PACKAGE_NAME = "bfd",
        .PACKAGE_STRING = b.fmt("bfd {f}", .{version}),
        .PACKAGE_TARNAME = "bfd",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = b.fmt("{f}", .{version}),
        .SIZEOF_INT = target.result.cTypeByteSize(.int),
        .SIZEOF_LONG = target.result.cTypeByteSize(.long),
        .SIZEOF_LONG_LONG = target.result.cTypeByteSize(.longlong),
        .SIZEOF_OFF_T = 8,
        .SIZEOF_VOID_P = target.result.ptrBitWidth() / 8,
        .STDC_HEADERS = true,
        .TLS = ._Thread_local,
        .TRAD_HEADER = null,
        .USE_64_BIT_ARCHIVE = null,
        .USE_BINARY_FOPEN = null,
        .USE_MINGW64_LEADING_UNDERSCORES = null,
        .USE_MMAP = if (target.result.os.tag == .linux) true else null,
        .USE_SECUREPLT = true,
        ._ALL_SOURCE = true,
        ._GNU_SOURCE = true,
        ._POSIX_PTHREAD_SEMANTICS = true,
        ._TANDEM_SOURCE = true,
        .__EXTENSIONS__ = true,
        .VERSION = b.fmt("{f}", .{version}),
        .WORDS_BIGENDIAN = if (target.result.cpu.arch.endian() == .big) @as(i64, 1) else null,
        ._FILE_OFFSET_BITS = null,
        ._LARGE_FILES = null,
        ._MINIX = null,
        ._POSIX_1_SOURCE = null,
        ._POSIX_SOURCE = null,
        ._STRUCTURED_PROC = true,
    });

    const iberty = b.addLibrary(.{
        .linkage = linkage,
        .name = "iberty",
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });
    // b.installArtifact(iberty);
    iberty.installHeader(upstream.path("include/ansidecl.h"), "ansidecl.h");
    iberty.installHeader(upstream.path("include/demangle.h"), "demangle.h");
    iberty.installHeader(upstream.path("include/dyn-string.h"), "dyn-string.h");
    iberty.installHeader(upstream.path("include/fibheap.h"), "fibheap.h");
    iberty.installHeader(upstream.path("include/floatformat.h"), "floatformat.h");
    iberty.installHeader(upstream.path("include/hashtab.h"), "hashtab.h");
    iberty.installHeader(upstream.path("include/libiberty.h"), "libiberty.h");
    iberty.installHeader(upstream.path("include/objalloc.h"), "objalloc.h");
    iberty.installHeader(upstream.path("include/partition.h"), "partition.h");
    iberty.installHeader(upstream.path("include/safe-ctype.h"), "safe-ctype.h");
    iberty.installHeader(upstream.path("include/sort.h"), "sort.h");
    iberty.installHeader(upstream.path("include/splay-tree.h"), "splay-tree.h");
    iberty.installHeader(upstream.path("include/timeval-utils.h"), "timeval-utils.h");
    iberty.root_module.addConfigHeader(libiberty_config_header);
    iberty.root_module.addCMacro("HAVE_CONFIG_H", "1");
    iberty.root_module.addCMacro("_GNU_SOURCE", "1");
    iberty.root_module.addIncludePath(upstream.path("libiberty"));
    iberty.root_module.addIncludePath(upstream.path("include"));
    iberty.root_module.addCSourceFiles(.{
        .root = upstream.path("libiberty"),
        // TODO figure out which files to include exactly
        .files = &.{
            "alloca.c",
            "argv.c",
            // "asprintf.c",
            // "atexit.c",
            // "basename.c",
            // "bcmp.c",
            // "bcopy.c",
            // "bsearch.c",
            "bsearch_r.c",
            // "bzero.c",
            // "calloc.c",
            // "choose-temp.c",
            // "clock.c",
            "concat.c",
            "cp-demangle.c",
            "cp-demint.c",
            "cplus-dem.c",
            "crc32.c",
            "d-demangle.c",
            "dwarfnames.c",
            "dyn-string.c",
            "fdmatch.c",
            // "ffs.c",
            "fibheap.c",
            "filedescriptor.c",
            "filename_cmp.c",
            "floatformat.c",
            "fnmatch.c",
            "fopen_unlocked.c",
            // "getcwd.c",
            // "getopt.c",
            // "getopt1.c",
            // "getpagesize.c",
            "getpwd.c",
            "getruntime.c",
            // "gettimeofday.c",
            "hashtab.c",
            "hex.c",
            // "index.c",
            // "insque.c",
            "lbasename.c",
            "lrealpath.c",
            "make-relative-prefix.c",
            "make-temp-file.c",
            "md5.c",
            // "memchr.c",
            // "memcmp.c",
            // "memcpy.c",
            // "memmem.c",
            // "memmove.c",
            "mempcpy.c",
            // "memset.c",
            // "mkstemps.c",
            "objalloc.c",
            "obstack.c",
            "partition.c",
            "pexecute.c",
            "pex-common.c",
            // "pex-djgpp.c",
            // "pex-msdos.c",
            "pex-one.c",
            // if (target.result.os.tag == .windows) "pex-win32.c" else "pex-unix.c",
            "physmem.c",
            // "putenv.c",
            // "random.c",
            "regex.c",
            // "rename.c",
            // "rindex.c",
            "rust-demangle.c",
            "safe-ctype.c",
            // "setenv.c",
            "setproctitle.c",
            "sha1.c",
            // "sigsetmask.c",
            "simple-object.c",
            "simple-object-coff.c",
            "simple-object-elf.c",
            "simple-object-mach-o.c",
            "simple-object-xcoff.c",
            // "snprintf.c",
            "sort.c",
            "spaces.c",
            "splay-tree.c",
            "stack-limit.c",
            // "stpcpy.c",
            // "stpncpy.c",
            // "strcasecmp.c",
            // "strchr.c",
            // "strdup.c",
            // "strerror.c",
            // "strncasecmp.c",
            "strncmp.c",
            // "strrchr.c",
            // "strsignal.c",
            // "strstr.c",
            // "strtod.c",
            // "strtol.c",
            // "strtoll.c",
            // "strtoul.c",
            // "strtoull.c",
            // "strndup.c",
            // "strnlen.c",
            // "strverscmp.c",
            "timeval-utils.c",
            // "tmpnam.c",
            "unlink-if-ordinary.c",
            // "vasprintf.c",
            "vfork.c",
            // "vfprintf.c",
            // "vprintf.c",
            // "vprintf-support.c",
            // "vsnprintf.c",
            // "vsprintf.c",
            // "waitpid.c",
            "xasprintf.c",
            "xatexit.c",
            "xexit.c",
            "xmalloc.c",
            "xmemdup.c",
            "xstrdup.c",
            "xstrerror.c",
            "xstrndup.c",
            "xvasprintf.c",
        },
    });

    const bfd_header = b.addConfigHeader(.{
        .style = .{ .autoconf_at = upstream.path("bfd/bfd-in2.h") },
        .include_path = "bfd.h",
    }, .{
        .supports_plugins = @intFromBool(enable_plugins),
        .wordsize = target.result.ptrBitWidth(),
        .bfd_default_target_size = target.result.ptrBitWidth(),
        .bfd_file_ptr = "int64_t",
        .bfd_ufile_ptr = "uint64_t",
    });

    const bfdver_header = b.addConfigHeader(.{
        .style = .{ .autoconf_at = upstream.path("bfd/version.h") },
        .include_path = "bfdver.h",
    }, .{
        .bfd_version = 244000000,
        .bfd_version_package = "\"(GNU Binutils) \"",
        .bfd_version_string = "\"2.44.0.20250215\"",
        .report_bugs_to = "\"<https://sourceware.org/bugzilla/>\"",
    });

    const bfd = b.addLibrary(.{
        .linkage = linkage,
        .name = "bfd",
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });
    b.installArtifact(bfd);
    bfd.installConfigHeader(bfd_header);
    bfd.installHeader(upstream.path("include/bfdlink.h"), "bfdlink.h");
    bfd.installHeader(upstream.path("include/ansidecl.h"), "ansidecl.h");
    bfd.installHeader(upstream.path("include/symcat.h"), "symcat.h");
    bfd.installHeader(upstream.path("include/diagnostics.h"), "diagnostics.h");
    bfd.root_module.addConfigHeader(libbfd_config_header);
    bfd.root_module.addCMacro("HAVE_CONFIG_H", "1");
    bfd.root_module.addCMacro("DEBUGDIR", b.fmt("\"{s}\"", .{b.pathJoin(&.{ b.install_prefix, "lib", "debug" })}));
    bfd.root_module.linkLibrary(iberty);
    bfd.root_module.linkLibrary(libsframe);
    bfd.root_module.addIncludePath(upstream.path("bfd"));
    bfd.root_module.addIncludePath(upstream.path("include"));
    bfd.root_module.addConfigHeader(bfd_header);
    bfd.root_module.addConfigHeader(bfdver_header);
    bfd.root_module.addIncludePath(b.path("include")); // targmatch.h, this file could be avoided by porting targmatch.sed
    if (enable_plugins) {
        bfd.installHeader(upstream.path("include/plugin-api.h"), "plugin-api.h");
        bfd.root_module.addCSourceFile(.{ .file = upstream.path("bfd/plugin.c") });
        bfd.root_module.addCMacro("LIBDIR", b.fmt("\"{s}\"", .{b.lib_dir}));
        bfd.root_module.addCMacro("BINDIR", b.fmt("\"{s}\"", .{b.exe_dir}));
    }
    bfd.root_module.addCSourceFiles(.{
        .root = upstream.path("bfd"),
        .files = &.{
            "archive.c",
            "bfd.c",
            "bfdio.c",
            "cache.c",
            "coff-bfd.c",
            "compress.c",
            "corefile.c",
            "elf-properties.c",
            "format.c",
            "hash.c",
            "libbfd.c",
            "linker.c",
            "merge.c",
            "opncls.c",
            "reloc.c",
            "section.c",
            "simple.c",
            "stab-syms.c",
            "stabs.c",
            "syms.c",
            "binary.c",
            "ihex.c",
            "srec.c",
            "tekhex.c",
            "verilog.c",

            "archive64.c",
        },
    });

    if (b.systemIntegrationOption("zlib", .{})) {
        bfd.root_module.linkSystemLibrary("z", .{});
    } else if (b.lazyDependency("zlib", .{
        .target = target,
        .optimize = optimize,
    })) |zlib_dependency| {
        bfd.root_module.linkLibrary(zlib_dependency.artifact("z"));
    }

    if (b.systemIntegrationOption("zstd", .{})) {
        bfd.root_module.linkSystemLibrary("zstd", .{});
    } else if (b.lazyDependency("zstd", .{
        .target = target,
        .optimize = optimize,
    })) |zstd_dependency| {
        bfd.root_module.linkLibrary(zstd_dependency.artifact("zstd"));
    }

    const default_vector: []const u8, const select_vectors: []const []const u8, const select_architectures: []const []const u8 = switch (target.result.cpu.arch) {
        .x86_64 => switch (target.result.os.tag) {
            .windows => .{
                "x86_64_elf64_vec",
                &.{ "i386_elf32_vec", "iamcu_elf32_vec", "x86_64_elf32_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .macos => .{
                "x86_64_mach_o_vec",
                &.{ "i386_mach_o_vec", "mach_o_le_vec", "mach_o_be_vec", "mach_o_fat_vec", "pef_vec", "pef_xlib_vec", "sym_vec" },
                &.{ "bfd_i386_arch", "bfd_powerpc_arch", "bfd_rs6000_arch" },
            },
            .linux => .{
                "x86_64_elf64_vec",
                &.{ "i386_elf32_vec", "iamcu_elf32_vec", "x86_64_elf32_vec", "i386_pei_vec", "x86_64_pe_vec", "x86_64_pei_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .freebsd => .{
                "x86_64_elf64_fbsd_vec",
                &.{ "i386_elf32_fbsd_vec", "iamcu_elf32_vec", "i386_coff_vec", "i386_pei_vec", "x86_64_pe_vec", "x86_64_pei_vec", "i386_elf32_vec", "x86_64_elf64_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .netbsd => .{
                "x86_64_elf64_vec",
                &.{ "i386_elf32_vec", "iamcu_elf32_vec", "i386_coff_vec", "i386_pei_vec", "x86_64_pe_vec", "x86_64_pei_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
        },
        .x86 => switch (target.result.os.tag) {
            .windows => .{
                "i386_elf32_vec",
                &.{ "iamcu_elf32_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .linux => .{
                "i386_elf32_vec",
                &.{ "iamcu_elf32_vec", "i386_pei_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .freebsd => .{
                "i386_elf32_fbsd_vec",
                &.{ "i386_elf32_vec", "iamcu_elf32_vec", "i386_pei_vec", "i386_coff_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            .netbsd => .{
                "i386_elf32_vec",
                &.{ "iamcu_elf32_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_i386_arch", "bfd_iamcu_arch" },
            },
            else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
        },
        .aarch64 => switch (target.result.os.tag) {
            .windows => .{
                "aarch64_elf64_le_vec",
                &.{ "aarch64_elf64_be_vec", "aarch64_elf32_le_vec", "aarch64_elf32_be_vec", "arm_elf32_le_vec", "arm_elf32_be_vec", "aarch64_pei_le_vec", "aarch64_pe_le_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_aarch64_arch", "bfd_arm_arch" },
            },
            .macos => .{
                "x86_64_mach_o_vec",
                &.{ "i386_mach_o_vec", "mach_o_le_vec", "mach_o_be_vec", "mach_o_fat_vec", "pef_vec", "pef_xlib_vec", "sym_vec" },
                &.{ "bfd_aarch64_arch", "bfd_arm_arch", "bfd_i386_arch", "bfd_powerpc_arch", "bfd_rs6000_arch" },
            },
            .linux => .{
                "x86_64_elf64_vec",
                &.{ "i386_elf32_vec", "iamcu_elf32_vec", "x86_64_elf32_vec", "i386_pei_vec", "x86_64_pe_vec", "x86_64_pei_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_aarch64_arch", "bfd_arm_arch" },
            },
            .freebsd => .{
                "aarch64_elf64_le_vec",
                &.{ "aarch64_elf64_be_vec", "arm_elf32_le_vec", "arm_elf32_be_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_aarch64_arch", "bfd_arm_arch" },
            },
            .netbsd => .{
                "aarch64_elf64_le_vec",
                &.{ "aarch64_elf64_be_vec", "aarch64_elf32_le_vec", "aarch64_elf32_be_vec", "arm_elf32_le_vec", "arm_elf32_be_vec", "aarch64_pei_le_vec", "aarch64_pe_le_vec", "elf64_le_vec", "elf64_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{ "bfd_aarch64_arch", "bfd_arm_arch" },
            },
            else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
        },
        .arm => switch (target.result.os.tag) {
            .linux => .{
                "arm_elf32_le_vec",
                &.{ "arm_elf32_fdpic_le_vec", "arm_elf32_be_vec", "arm_elf32_fdpic_be_vec", "elf32_le_vec", "elf32_be_vec" },
                &.{"bfd_arm_arch"},
            },
            else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
        },
        .wasm32 => switch (target.result.os.tag) {
            .wasi => .{
                "wasm_vec",
                &.{ "elf32_le_vec", "elf32_be_vec" },
                &.{"bfd_wasm32_arch"},
            },
            else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
        },
        else => std.debug.panic("TODO '{s}-{s}'", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }),
    };

    const find_replace_exe = b.addExecutable(.{
        .name = "find-replace",
        .root_module = b.createModule(.{
            .root_source_file = b.path("find_replace.zig"),
            .target = b.graph.host,
        }),
    });

    const generated_header_files: []const std.Build.LazyPath = &.{
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-target.h"), "elf32-target.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-target.h"), "elf64-target.h", "NN", "64"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-aarch64.h"), "elf32-aarch64.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-aarch64.h"), "elf64-aarch64.h", "NN", "64"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-ia64.h"), "elf32-ia64.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-ia64.h"), "elf64-ia64.h", "NN", "64"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-kvx.h"), "elf32-kvx.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-kvx.h"), "elf64-kvx.h", "NN", "64"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-loongarch.h"), "elf32-loongarch.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-loongarch.h"), "elf64-loongarch.h", "NN", "64"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-riscv.h"), "elf32-riscv.h", "NN", "32"),
        runFindReplace(b, find_replace_exe, upstream.path("bfd/elfxx-riscv.h"), "elf64-riscv.h", "NN", "64"),
    };

    for (generated_header_files) |header_file| {
        // TODO only include the headers that are actually needed
        bfd.root_module.addIncludePath(header_file.dirname());
    }

    const generated_sources = std.StaticStringMap(std.Build.LazyPath).init(&[_]struct { []const u8, std.Build.LazyPath }{
        .{ "peigen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "peigen.c", "XX", "pe") },
        .{ "pepigen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "pepigen.c", "XX", "pep") },
        .{ "pex64igen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "pex64igen.c", "XX", "pex64") },
        .{ "pe-aarch64igen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "pe-aarch64igen.c", "XX", "peAArch64") },
        .{ "pe-loongarch64igen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "pe-loongarch64igen.c", "XX", "peLoongArch64") },
        .{ "pe-riscv64igen.c", runFindReplace(b, find_replace_exe, upstream.path("bfd/peXXigen.c"), "pe-riscv64igen.c", "XX", "peRiscV64") },
    }, b.allocator) catch @panic("OOM");

    for (std.mem.concat(b.allocator, []const u8, &.{ &.{default_vector}, select_vectors }) catch @panic("OOM")) |target_vector| {
        const files = select_vector_sources.get(target_vector) orelse std.debug.panic("missing sources for '{s}'", .{target_vector});
        var files_without_generated = std.ArrayListUnmanaged([]const u8).initCapacity(b.allocator, files.len) catch @panic("OOM");

        for (files) |file| {
            if (generated_sources.get(file)) |generated_file| {
                bfd.root_module.addCSourceFile(.{ .file = generated_file });
            } else {
                files_without_generated.appendAssumeCapacity(file);
            }
        }

        bfd.root_module.addCSourceFiles(.{
            .root = upstream.path("bfd"),
            .files = files_without_generated.items,
        });
    }

    for (select_architectures) |select_architecture| {
        var arch_source = select_architecture;
        arch_source = std.mem.replaceOwned(u8, b.allocator, arch_source, "bfd_", "cpu-") catch @panic("OOM");
        arch_source = std.mem.replaceOwned(u8, b.allocator, arch_source, "_arch", ".c") catch @panic("OOM");
        arch_source = std.mem.replaceOwned(u8, b.allocator, arch_source, "mn10200", "m10200") catch @panic("OOM");
        arch_source = std.mem.replaceOwned(u8, b.allocator, arch_source, "mn10300", "m10300") catch @panic("OOM");
        bfd.root_module.addCSourceFile(.{ .file = upstream.path(b.pathJoin(&.{ "bfd", arch_source })) });
    }

    {
        bfd.root_module.addCMacro(b.fmt("HAVE_{s}", .{default_vector}), "1");
        for (select_vectors) |select_vector| {
            bfd.root_module.addCMacro(b.fmt("HAVE_{s}", .{select_vector}), "1");
        }

        bfd.root_module.addCSourceFiles(.{
            .root = upstream.path("bfd"),
            .files = &.{
                "targets.c",
                "archures.c",
            },
            .flags = &.{
                b.fmt("-DDEFAULT_VECTOR={s}", .{default_vector}),
                if (select_vectors.len == 0) "-DSELECT_VECS=''" else b.fmt("-DSELECT_VECS=&{s},&{s}", .{ default_vector, std.mem.join(b.allocator, ",&", select_vectors) catch @panic("OOM") }),
                if (select_architectures.len == 0) "-DSELECT_ARCHITECTURES=''" else b.fmt("-DSELECT_ARCHITECTURES=&{s}", .{std.mem.join(b.allocator, ",&", select_architectures) catch @panic("OOM")}),
            },
        });
    }

    const opcodes_config_header = b.addConfigHeader(.{
        .style = .{ .autoconf_undef = upstream.path("opcodes/config.in") },
    }, .{
        .ENABLE_CHECKING = null,
        .ENABLE_NLS = if (target.result.os.tag == .linux) true else null,
        .HAVE_CFLOCALECOPYPREFERREDLANGUAGES = null,
        .HAVE_CFPREFERENCESCOPYAPPVALUE = null,
        .HAVE_DCGETTEXT = if (target.result.os.tag == .linux) true else null,
        .HAVE_DECL_BASENAME = target.result.isGnuLibC(),
        .HAVE_DECL_STPCPY = true,
        .HAVE_DLFCN_H = true,
        .HAVE_GETTEXT = if (target.result.os.tag == .linux) true else null,
        .HAVE_ICONV = switch (target.result.os.tag) {
            .wasi, .freebsd, .netbsd => true,
            else => null,
        },
        .HAVE_INTTYPES_H = true,
        .HAVE_MEMORY_H = true,
        .HAVE_SIGSETJMP = if (target.result.os.tag == .wasi) null else true,
        .HAVE_STDINT_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRINGS_H = true,
        .HAVE_STRING_H = true,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_UNISTD_H = true,
        .LT_OBJDIR = ".libs/", // What the hell is this?
        .PACKAGE = "opcodes",
        .PACKAGE_BUGREPORT = "",
        .PACKAGE_NAME = "opcodes",
        .PACKAGE_STRING = b.fmt("opcodes {f}", .{version}),
        .PACKAGE_TARNAME = "opcodes",
        .PACKAGE_URL = "",
        .PACKAGE_VERSION = b.fmt("{f}", .{version}),
        .STDC_HEADERS = true,
        ._ALL_SOURCE = true,
        ._GNU_SOURCE = true,
        ._POSIX_PTHREAD_SEMANTICS = true,
        ._TANDEM_SOURCE = true,
        .__EXTENSIONS__ = true,
        .VERSION = b.fmt("{f}", .{version}),
        ._MINIX = null,
        ._POSIX_1_SOURCE = null,
        ._POSIX_SOURCE = null,
    });

    const libopcodes = b.addLibrary(.{
        .linkage = linkage,
        .name = "opcodes",
        .version = version,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .pic = pic,
            .link_libc = true,
        }),
    });
    b.installArtifact(libopcodes);
    libopcodes.root_module.addConfigHeader(opcodes_config_header);
    libopcodes.installHeader(upstream.path("include/dis-asm.h"), "dis-asm.h");
    libopcodes.root_module.addCMacro("HAVE_CONFIG_H", "1");
    libopcodes.root_module.addIncludePath(upstream.path("opcodes"));
    libopcodes.root_module.addIncludePath(upstream.path("bfd"));
    libopcodes.root_module.addIncludePath(upstream.path("include"));
    libopcodes.root_module.addConfigHeader(bfd_header);
    libopcodes.root_module.addCSourceFiles(.{
        .root = upstream.path("opcodes"),
        .files = &.{ "dis-buf.c", "dis-init.c" },
    });

    var opcodes_arch_defines: std.ArrayListUnmanaged([]const u8) = .empty;

    for (select_architectures) |select_architecture| {
        var arch_define = select_architecture;
        arch_define = std.mem.replaceOwned(u8, b.allocator, arch_define, "bfd_", "") catch @panic("OOM");
        arch_define = std.mem.replaceOwned(u8, b.allocator, arch_define, "_arch", "") catch @panic("OOM");
        opcodes_arch_defines.append(b.allocator, b.fmt("-D{s}=1", .{arch_define})) catch @panic("OOM");

        libopcodes.root_module.addCSourceFiles(.{
            .root = upstream.path("opcodes"),
            .files = opcodes_target_sources.get(select_architecture) orelse std.debug.panic("missing target sources for '{s}'", .{select_architecture}),
        });
    }

    libopcodes.root_module.addCSourceFile(.{
        .file = upstream.path("opcodes/disassemble.c"),
        .flags = opcodes_arch_defines.items,
    });
}

fn runFindReplace(b: *std.Build, find_replace_exe: *std.Build.Step.Compile, input: std.Build.LazyPath, output_filename: []const u8, needle: []const u8, replacement: []const u8) std.Build.LazyPath {
    const run_find_replace = b.addRunArtifact(find_replace_exe);

    run_find_replace.addFileArg(input);
    const output = run_find_replace.addOutputFileArg(output_filename);
    run_find_replace.addArg(needle);
    run_find_replace.addArg(replacement);
    return output;
}

const elf_sources: []const []const u8 = &.{
    "elf.c",
    "elflink.c",
    "elf-attrs.c",
    "elf-strtab.c",
    "elf-eh-frame.c",
    "elf-sframe.c",
    "dwarf1.c",
    "dwarf2.c",
};

const elfxx_x86_sources: []const []const u8 = &.{
    "elfxx-x86.c",
    "elf-ifunc.c",
    "elf-vxworks.c",
};

const coffgen_sources: []const []const u8 = &.{ "coffgen.c", "dwarf2.c" };
const coff_sources: []const []const u8 = [_][]const u8{"cofflink.c"} ++ coffgen_sources;
const ecoff_sources: []const []const u8 = [_][]const u8{"ecofflink.c"} ++ coffgen_sources;
const xcoff_sources: []const []const u8 = [_][]const u8{"xcofflink.c"} ++ coffgen_sources;

const select_vector_sources = std.StaticStringMap([]const []const u8).initComptime(&.{
    .{ "aarch64_elf32_be_vec", &[_][]const u8{ "elf32-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf32.c" } ++ elf_sources },
    .{ "aarch64_elf32_le_vec", &[_][]const u8{ "elf32-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf32.c" } ++ elf_sources },
    .{ "aarch64_elf64_be_vec", &[_][]const u8{ "elf64-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf64.c" } ++ elf_sources },
    .{ "aarch64_elf64_be_cloudabi_vec", &[_][]const u8{ "elf64-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf64.c" } ++ elf_sources },
    .{ "aarch64_elf64_le_vec", &[_][]const u8{ "elf64-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf64.c" } ++ elf_sources },
    .{ "aarch64_elf64_le_cloudabi_vec", &[_][]const u8{ "elf64-aarch64.c", "elfxx-aarch64.c", "elf-ifunc", "elf64.c" } ++ elf_sources },
    .{ "aarch64_mach_o_vec", &[_][]const u8{"mach-o-aarch64.c"} },
    .{ "aarch64_pei_le_vec", &[_][]const u8{ "pei-aarch64.c", "pe-aarch64ige.c" } ++ coff_sources },
    .{ "aarch64_pe_le_vec", &[_][]const u8{ "pe-aarch64.c", "pe-aarch64ige.c" } ++ coff_sources },
    .{ "alpha_ecoff_le_vec", &[_][]const u8{ "coff-alpha.c", "ecof.c" } ++ ecoff_sources },
    .{ "alpha_elf64_vec", &[_][]const u8{ "elf64-alpha.c", "elf64.c" } ++ elf_sources },
    .{ "alpha_elf64_fbsd_vec", &[_][]const u8{ "elf64-alpha.c", "elf64.c" } ++ elf_sources },
    .{ "alpha_vms_vec", &[_][]const u8{ "vms-alpha.c", "vms-misc", "vms-lib.c" } },
    .{ "alpha_vms_lib_txt_vec", &[_][]const u8{ "vms-lib.c", "vms-misc.c" } },
    .{ "am33_elf32_linux_vec", &[_][]const u8{ "elf32-am33lin.c", "elf32.c" } ++ elf_sources },
    .{ "amdgcn_elf64_le_vec", &[_][]const u8{ "elf64-amdgcn.c", "elf64.c" } ++ elf_sources },
    .{ "aout0_be_vec", &[_][]const u8{ "aout.c", "aout32.c" } },
    .{ "aout64_vec", &[_][]const u8{ "demo64.c", "aout64.c" } },
    .{ "aout_vec", &[_][]const u8{ "host-aou.c", "aout32.c" } },
    .{ "arc_elf32_be_vec", &[_][]const u8{ "elf32-arc.c", "elf32.c" } ++ elf_sources },
    .{ "arc_elf32_le_vec", &[_][]const u8{ "elf32-arc.c", "elf32.c" } ++ elf_sources },
    .{ "arm_elf32_be_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_le_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_fdpic_be_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_fdpic_le_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_nacl_be_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_nacl_le_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_vxworks_be_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_elf32_vxworks_le_vec", &[_][]const u8{ "elf32-arm.c", "elf32.c", "elf-nac.c", "elf-vxwork.c" } ++ elf_sources },
    .{ "arm_pe_be_vec", &[_][]const u8{ "pe-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pe_le_vec", &[_][]const u8{ "pe-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pe_wince_be_vec", &[_][]const u8{ "pe-arm-wince.c", "pe-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pe_wince_le_vec", &[_][]const u8{ "pe-arm-wince.c", "pe-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pei_be_vec", &[_][]const u8{ "pei-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pei_le_vec", &[_][]const u8{ "pei-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pei_wince_be_vec", &[_][]const u8{ "pei-arm-wince.c", "pei-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_pei_wince_le_vec", &[_][]const u8{ "pei-arm-wince.c", "pei-arm.c", "peigen.c" } ++ coff_sources },
    .{ "arm_mach_o_vec", &[_][]const u8{"mach-o-arm.c"} },
    .{ "avr_elf32_vec", &[_][]const u8{ "elf32-avr.c", "elf32.c" } ++ elf_sources },
    .{ "bfin_elf32_vec", &[_][]const u8{ "elf32-bfin.c", "elf32.c" } ++ elf_sources },
    .{ "bfin_elf32_fdpic_vec", &[_][]const u8{ "elf32-bfin.c", "elf32.c" } ++ elf_sources },
    .{ "cr16_elf32_vec", &[_][]const u8{ "elf32-cr16.c", "elf32.c" } ++ elf_sources },
    .{ "cris_aout_vec", &[_][]const u8{"aout-cris.c"} },
    .{ "cris_elf32_vec", &[_][]const u8{ "elf32-cris.c", "elf32.c" } ++ elf_sources },
    .{ "cris_elf32_us_vec", &[_][]const u8{ "elf32-cris.c", "elf32.c" } ++ elf_sources },
    .{ "crx_elf32_vec", &[_][]const u8{ "elf32-crx.c", "elf32.c" } ++ elf_sources },
    .{ "csky_elf32_be_vec", &[_][]const u8{ "elf32-csk.c", "elf32.c" } ++ elf_sources },
    .{ "csky_elf32_le_vec", &[_][]const u8{ "elf32-csk.c", "elf32.c" } ++ elf_sources },
    .{ "d10v_elf32_vec", &[_][]const u8{ "elf32-d10v.c", "elf32.c" } ++ elf_sources },
    .{ "d30v_elf32_vec", &[_][]const u8{ "elf32-d30v.c", "elf32.c" } ++ elf_sources },
    .{ "dlx_elf32_be_vec", &[_][]const u8{ "elf32-dlx.c", "elf32.c" } ++ elf_sources },
    .{ "elf32_be_vec", &[_][]const u8{ "elf32-gen.c", "elf32.c" } ++ elf_sources },
    .{ "elf32_le_vec", &[_][]const u8{ "elf32-gen.c", "elf32.c" } ++ elf_sources },
    .{ "elf64_be_vec", &[_][]const u8{ "elf64-gen.c", "elf64.c" } ++ elf_sources },
    .{ "elf64_le_vec", &[_][]const u8{ "elf64-gen.c", "elf64.c" } ++ elf_sources },
    .{ "bpf_elf64_le_vec", &[_][]const u8{ "elf64-bpf.c", "elf64.c" } ++ elf_sources },
    .{ "bpf_elf64_be_vec", &[_][]const u8{ "elf64-bpf.c", "elf64.c" } ++ elf_sources },
    .{ "epiphany_elf32_vec", &[_][]const u8{ "elf32-epiphany.c", "elf32.c" } ++ elf_sources },
    .{ "fr30_elf32_vec", &[_][]const u8{ "elf32-fr30.c", "elf32.c" } ++ elf_sources },
    .{ "frv_elf32_vec", &[_][]const u8{ "elf32-frv.c", "elf32.c" } ++ elf_sources },
    .{ "frv_elf32_fdpic_vec", &[_][]const u8{ "elf32-frv.c", "elf32.c" } ++ elf_sources },
    .{ "h8300_elf32_vec", &[_][]const u8{ "elf32-h8300.c", "elf32.c" } ++ elf_sources },
    .{ "h8300_elf32_linux_vec", &[_][]const u8{ "elf32-h8300.c", "elf32.c" } ++ elf_sources },
    .{ "hppa_elf32_vec", &[_][]const u8{ "elf32-hppa.c", "elf32.c" } ++ elf_sources },
    .{ "hppa_elf32_linux_vec", &[_][]const u8{ "elf32-hppa.c", "elf32.c" } ++ elf_sources },
    .{ "hppa_elf32_nbsd_vec", &[_][]const u8{ "elf32-hppa.c", "elf32.c" } ++ elf_sources },
    .{ "hppa_elf64_vec", &[_][]const u8{ "elf64-hppa.c", "elf64.c" } ++ elf_sources },
    .{ "hppa_elf64_linux_vec", &[_][]const u8{ "elf64-hppa.c", "elf64.c" } ++ elf_sources },
    .{ "hppa_som_vec", &[_][]const u8{"som.c"} },
    .{ "i386_aout_vec", &[_][]const u8{ "i386aout.c", "aout32.c" } },
    .{ "i386_aout_bsd_vec", &[_][]const u8{ "i386bsd.c", "aout32.c" } },
    .{ "i386_aout_lynx_vec", &[_][]const u8{ "i386lynx.c", "lynx-cor.c", "aout32.c" } },
    .{ "i386_coff_vec", &[_][]const u8{"coff-i386.c"} ++ coff_sources },
    .{ "i386_coff_go32_vec", &[_][]const u8{"coff-go32.c"} ++ coff_sources },
    .{ "i386_coff_go32stubbed_vec", &[_][]const u8{"coff-stgo32.c"} ++ coff_sources },
    .{ "i386_coff_lynx_vec", &[_][]const u8{ "cf-i386lynx.c", "lynx-cor.c" } ++ coff_sources },
    .{ "i386_elf32_vec", &[_][]const u8{ "elf32-i386.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "i386_elf32_fbsd_vec", &[_][]const u8{ "elf32-i386.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "i386_elf32_sol2_vec", &[_][]const u8{ "elf32-i386.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "i386_elf32_vxworks_vec", &[_][]const u8{ "elf32-i386.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "i386_mach_o_vec", &[_][]const u8{"mach-o-i386.c"} },
    .{ "i386_msdos_vec", &[_][]const u8{"i386msdos.c"} },
    .{ "i386_pe_vec", &[_][]const u8{ "pe-i386.c", "peigen.c" } ++ coff_sources },
    .{ "i386_pe_big_vec", &[_][]const u8{ "pe-i386.c", "peigen.c" } ++ coff_sources },
    .{ "i386_pei_vec", &[_][]const u8{ "pei-i386.c", "peigen.c" } ++ coff_sources },
    .{ "iamcu_elf32_vec", &[_][]const u8{ "elf32-i386.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "ia64_elf32_be_vec", &[_][]const u8{ "elf32-ia64.c", "elfxx-ia64.c", "elf32.c" } ++ elf_sources },
    .{ "ia64_elf32_hpux_be_vec", &[_][]const u8{ "elf32-ia64.c", "elfxx-ia64.c", "elf32.c" } ++ elf_sources },
    .{ "ia64_elf64_be_vec", &[_][]const u8{ "elf64-ia64.c", "elfxx-ia64.c", "elf64.c" } ++ elf_sources },
    .{ "ia64_elf64_le_vec", &[_][]const u8{ "elf64-ia64.c", "elfxx-ia64.c", "elf64.c" } ++ elf_sources },
    .{ "ia64_elf64_hpux_be_vec", &[_][]const u8{ "elf64-ia64.c", "elfxx-ia64.c", "elf64.c" } ++ elf_sources },
    .{ "ia64_elf64_vms_vec", &[_][]const u8{ "elf64-ia64-vm.c", "elf64-ia64.c", "elfxx-ia64.c", "elf64.c", "vms-li.c", "vms-misc.c" } ++ elf_sources },
    .{ "ia64_pei_vec", &[_][]const u8{ "pei-ia64.c", "pepige.c" } ++ coff_sources },
    .{ "ip2k_elf32_vec", &[_][]const u8{ "elf32-ip2.c", "elf32.c" } ++ elf_sources },
    .{ "iq2000_elf32_vec", &[_][]const u8{ "elf32-iq200.c", "elf32.c" } ++ elf_sources },
    .{ "kvx_elf32_vec", &[_][]const u8{ "elf32-kvx.c", "elfxx-kv.c", "elf32.c", "$elf $ipa" } },
    .{ "kvx_elf64_vec", &[_][]const u8{ "elf64-kvx.c", "elfxx-kv.c", "elf64.c", "$elf $ipa" } },
    .{ "lm32_elf32_vec", &[_][]const u8{ "elf32-lm32.c", "elf32.c" } ++ elf_sources },
    .{ "lm32_elf32_fdpic_vec", &[_][]const u8{ "elf32-lm32.c", "elf32.c" } ++ elf_sources },
    .{ "loongarch_elf32_vec", &[_][]const u8{ "elf32-loongarch.c", "elfxx-loongarch.c", "elf32.c", "elf-ifunc.c" } ++ elf_sources },
    .{ "loongarch_elf64_vec", &[_][]const u8{ "elf64-loongarch.c", "elf64.c", "elfxx-loongarch.c", "elf32.c", "elf-ifunc.c" } ++ elf_sources },
    .{ "loongarch64_pei_vec", &[_][]const u8{ "pei-loongarch64.c", "pe-loongarch64igen.c" } ++ coff_sources },
    .{ "m32c_elf32_vec", &[_][]const u8{ "elf32-m32c", "elf32.c" } ++ elf_sources },
    .{ "m32r_elf32_vec", &[_][]const u8{ "elf32-m32.c", "elf32.c" } ++ elf_sources },
    .{ "m32r_elf32_le_vec", &[_][]const u8{ "elf32-m32.c", "elf32.c" } ++ elf_sources },
    .{ "m32r_elf32_linux_vec", &[_][]const u8{ "elf32-m32.c", "elf32.c" } ++ elf_sources },
    .{ "m32r_elf32_linux_le_vec", &[_][]const u8{ "elf32-m32.c", "elf32.c" } ++ elf_sources },
    .{ "m68hc11_elf32_vec", &[_][]const u8{ "elf32-m68hc11.c", "elf32-m68hc1x.c", "elf32.c" } ++ elf_sources },
    .{ "m68hc12_elf32_vec", &[_][]const u8{ "elf32-m68hc12.c", "elf32-m68hc1x.c", "elf32.c" } ++ elf_sources },
    .{ "m68k_elf32_vec", &[_][]const u8{ "elf32-m68k.c", "elf32.c" } ++ elf_sources },
    .{ "s12z_elf32_vec", &[_][]const u8{ "elf32-s12z.c", "elf32.c" } ++ elf_sources },
    .{ "mach_o_be_vec", &[_][]const u8{ "mach-o.c", "dwarf2.c" } },
    .{ "mach_o_le_vec", &[_][]const u8{ "mach-o.c", "dwarf2.c" } },
    .{ "mach_o_fat_vec", &[_][]const u8{ "mach-o.c", "dwarf2.c" } },
    .{ "mcore_elf32_be_vec", &[_][]const u8{ "elf32-mcore.c", "elf32.c" } ++ elf_sources },
    .{ "mcore_elf32_le_vec", &[_][]const u8{ "elf32-mcore.c", "elf32.c" } ++ elf_sources },
    .{ "mcore_pe_be_vec", &[_][]const u8{ "pe-mcore.c", "peigen.c" } ++ coff_sources },
    .{ "mcore_pe_le_vec", &[_][]const u8{ "pe-mcore.c", "peigen.c" } ++ coff_sources },
    .{ "mcore_pei_be_vec", &[_][]const u8{ "pei-mcore.c", "peigen.c" } ++ coff_sources },
    .{ "mcore_pei_le_vec", &[_][]const u8{ "pei-mcore.c", "peigen.c" } ++ coff_sources },
    .{ "mep_elf32_vec", &[_][]const u8{ "elf32-mep.c", "elf32.c" } ++ elf_sources },
    .{ "mep_elf32_le_vec", &[_][]const u8{ "elf32-mep.c", "elf32.c" } ++ elf_sources },
    .{ "metag_elf32_vec", &[_][]const u8{ "elf32-meta.c", "elf32.c" } ++ elf_sources },
    .{ "microblaze_elf32_vec", &[_][]const u8{ "elf32-microblaz.c", "elf32.c" } ++ elf_sources },
    .{ "microblaze_elf32_le_vec", &[_][]const u8{ "elf32-microblaz.c", "elf32.c" } ++ elf_sources },
    .{ "mips_ecoff_be_vec", &[_][]const u8{ "coff-mips.c", "ecoff.c" } ++ ecoff_sources },
    .{ "mips_ecoff_le_vec", &[_][]const u8{ "coff-mips.c", "ecoff.c" } ++ ecoff_sources },
    .{ "mips_ecoff_bele_vec", &[_][]const u8{ "coff-mips.c", "ecoff.c" } ++ ecoff_sources },
    .{ "mips_elf32_be_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_le_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_n_be_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_n_le_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_ntrad_be_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_ntrad_le_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_ntradfbsd_be_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_ntradfbsd_le_vec", &[_][]const u8{ "elfn32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_trad_be_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_trad_le_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_tradfbsd_be_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_tradfbsd_le_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_vxworks_be_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf32_vxworks_le_vec", &[_][]const u8{ "elf32-mips.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_be_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_le_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_trad_be_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_trad_le_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_tradfbsd_be_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mips_elf64_tradfbsd_le_vec", &[_][]const u8{ "elf64-mips.c", "elf64.c", "elfxx-mips.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources ++ ecoff_sources },
    .{ "mmix_elf64_vec", &[_][]const u8{ "elf64-mmix.c", "elf64.c" } ++ elf_sources },
    .{ "mmix_mmo_vec", &[_][]const u8{"mmo.c"} },
    .{ "mn10200_elf32_vec", &[_][]const u8{ "elf-m10200.c", "elf32.c" } ++ elf_sources },
    .{ "mn10300_elf32_vec", &[_][]const u8{ "elf-m10300.c", "elf32.c" } ++ elf_sources },
    .{ "moxie_elf32_be_vec", &[_][]const u8{ "elf32-moxie.c", "elf32.c" } ++ elf_sources },
    .{ "moxie_elf32_le_vec", &[_][]const u8{ "elf32-moxie.c", "elf32.c" } ++ elf_sources },
    .{ "msp430_elf32_vec", &[_][]const u8{ "elf32-msp430.c", "elf32.c" } ++ elf_sources },
    .{ "msp430_elf32_ti_vec", &[_][]const u8{ "elf32-msp430.c", "elf32.c" } ++ elf_sources },
    .{ "mt_elf32_vec", &[_][]const u8{ "elf32-mt.c", "elf32.c" } ++ elf_sources },
    .{ "nds32_elf32_be_vec", &[_][]const u8{ "elf32-nds32.c", "elf32.c" } ++ elf_sources },
    .{ "nds32_elf32_le_vec", &[_][]const u8{ "elf32-nds32.c", "elf32.c" } ++ elf_sources },
    .{ "nds32_elf32_linux_be_vec", &[_][]const u8{ "elf32-nds32.c", "elf32.c" } ++ elf_sources },
    .{ "nds32_elf32_linux_le_vec", &[_][]const u8{ "elf32-nds32.c", "elf32.c" } ++ elf_sources },
    .{ "nfp_elf64_vec", &[_][]const u8{ "elf64-nfp.c", "elf64.c" } ++ elf_sources },
    .{ "ns32k_aout_pc532mach_vec", &[_][]const u8{ "pc532-mach.c", "aout-ns32k.c" } },
    .{ "ns32k_aout_pc532nbsd_vec", &[_][]const u8{ "ns32knetbsd.c", "aout-ns32k.c" } },
    .{ "or1k_elf32_vec", &[_][]const u8{ "elf32-or1k.c", "elf32.c" } ++ elf_sources },
    .{ "pdb_vec", &[_][]const u8{"pdb.c"} },
    .{ "pdp11_aout_vec", &[_][]const u8{"pdp11.c"} },
    .{ "pef_vec", &[_][]const u8{"pef.c"} },
    .{ "pef_xlib_vec", &[_][]const u8{"pef.c"} },
    .{ "pj_elf32_vec", &[_][]const u8{ "elf32-pj.c", "elf32.c" } ++ elf_sources },
    .{ "pj_elf32_le_vec", &[_][]const u8{ "elf32-pj.c", "elf32.c" } ++ elf_sources },
    .{ "powerpc_boot_vec", &[_][]const u8{"ppcboot.c"} },
    .{ "powerpc_elf32_vec", &[_][]const u8{ "elf32-ppc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "powerpc_elf32_le_vec", &[_][]const u8{ "elf32-ppc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "powerpc_elf32_fbsd_vec", &[_][]const u8{ "elf32-ppc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "powerpc_elf32_vxworks_vec", &[_][]const u8{ "elf32-ppc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "powerpc_elf64_vec", &[_][]const u8{ "elf64-ppc.c", "elf64-ge.c", "elf64.c" } ++ elf_sources },
    .{ "powerpc_elf64_le_vec", &[_][]const u8{ "elf64-ppc.c", "elf64-ge.c", "elf64.c" } ++ elf_sources },
    .{ "powerpc_elf64_fbsd_vec", &[_][]const u8{ "elf64-ppc.c", "elf64-ge.c", "elf64.c" } ++ elf_sources },
    .{ "powerpc_elf64_fbsd_le_vec", &[_][]const u8{ "elf64-ppc.c", "elf64-ge.c", "elf64.c" } ++ elf_sources },
    .{ "powerpc_xcoff_vec", &[_][]const u8{"coff-rs6000.c"} ++ xcoff_sources },
    .{ "pru_elf32_vec", &[_][]const u8{ "elf32-pru.c", "elf32.c" } ++ elf_sources },
    .{ "riscv_elf32_vec", &[_][]const u8{ "elf32-riscv.c", "elfxx-riscv.c", "elf-ifunc.c", "elf32.c" } ++ elf_sources },
    .{ "riscv_elf64_vec", &[_][]const u8{ "elf64-riscv.c", "elf64.c", "elfxx-riscv.c", "elf-ifunc.c", "elf32.c" } ++ elf_sources },
    .{ "riscv_elf32_be_vec", &[_][]const u8{ "elf32-riscv.c", "elfxx-riscv.c", "elf-ifunc.c", "elf32.c" } ++ elf_sources },
    .{ "riscv_elf64_be_vec", &[_][]const u8{ "elf64-riscv.c", "elf64.c", "elfxx-riscv.c", "elf-ifunc.c", "elf32.c" } ++ elf_sources },
    .{ "riscv64_pei_vec", &[_][]const u8{ "pei-riscv64.c", "pe-riscv64ige.c" } ++ coff_sources },
    .{ "rl78_elf32_vec", &[_][]const u8{ "elf32-rl78.c", "elf32.c" } ++ elf_sources },
    .{ "rs6000_xcoff64_vec", &[_][]const u8{ "coff64-rs6000.c", "aix5ppc-core.c" } ++ xcoff_sources },
    .{ "rs6000_xcoff64_aix_vec", &[_][]const u8{ "coff64-rs6000.c", "aix5ppc-core.c" } ++ xcoff_sources },
    .{ "rs6000_xcoff_vec", &[_][]const u8{"coff-rs6000.c"} ++ xcoff_sources },
    .{ "rx_elf32_be_vec", &[_][]const u8{ "elf32-rx.c", "elf32.c" } ++ elf_sources },
    .{ "rx_elf32_be_ns_vec", &[_][]const u8{ "elf32-rx.c", "elf32.c" } ++ elf_sources },
    .{ "rx_elf32_le_vec", &[_][]const u8{ "elf32-rx.c", "elf32.c" } ++ elf_sources },
    .{ "rx_elf32_linux_le_vec", &[_][]const u8{ "elf32-rx.c", "elf32.c" } ++ elf_sources },
    .{ "s390_elf32_vec", &[_][]const u8{ "elf32-s390.c", "elf32.c" } ++ elf_sources },
    .{ "s390_elf64_vec", &[_][]const u8{ "elf64-s390.c", "elf64.c" } ++ elf_sources },
    .{ "score_elf32_be_vec", &[_][]const u8{ "elf32-score.c", "elf32-score.c", "elf32.c", "elf64.c" } ++ elf_sources },
    .{ "score_elf32_le_vec", &[_][]const u8{ "elf32-score.c", "elf32-score.c", "elf32.c", "elf64.c" } ++ elf_sources },
    .{ "sh_coff_vec", &[_][]const u8{"coff-sh.c"} ++ coff_sources },
    .{ "sh_coff_le_vec", &[_][]const u8{"coff-sh.c"} ++ coff_sources },
    .{ "sh_coff_small_vec", &[_][]const u8{"coff-sh.c"} ++ coff_sources },
    .{ "sh_coff_small_le_vec", &[_][]const u8{"coff-sh.c"} ++ coff_sources },
    .{ "sh_elf32_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_le_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_fdpic_be_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_fdpic_le_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_linux_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_linux_be_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_nbsd_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_nbsd_le_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_vxworks_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_elf32_vxworks_le_vec", &[_][]const u8{ "elf32-sh.c", "elf-vxwork.c", "elf32.c", "coff-sh.c" } ++ elf_sources ++ coff_sources },
    .{ "sh_pe_le_vec", &[_][]const u8{ "pe-sh.c", "coff-sh.c", "peigen.c" } ++ coff_sources },
    .{ "sh_pei_le_vec", &[_][]const u8{ "pei-sh.c", "coff-sh.c", "peigen.c" } ++ coff_sources },
    .{ "sparc_elf32_vec", &[_][]const u8{ "elf32-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "sparc_elf32_sol2_vec", &[_][]const u8{ "elf32-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "sparc_elf32_vxworks_vec", &[_][]const u8{ "elf32-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf32.c" } ++ elf_sources },
    .{ "sparc_elf64_vec", &[_][]const u8{ "elf64-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf64.c" } ++ elf_sources },
    .{ "sparc_elf64_fbsd_vec", &[_][]const u8{ "elf64-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf64.c" } ++ elf_sources },
    .{ "sparc_elf64_sol2_vec", &[_][]const u8{ "elf64-sparc.c", "elfxx-sparc.c", "elf-vxwork.c", "elf64.c" } ++ elf_sources },
    .{ "spu_elf32_vec", &[_][]const u8{ "elf32-sp.c", "elf32.c" } ++ elf_sources },
    .{ "sym_vec", &[_][]const u8{"xsym.c"} },
    .{ "tic30_coff_vec", &[_][]const u8{"coff-tic30.c"} ++ coffgen_sources },
    .{ "tic4x_coff0_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic4x_coff0_beh_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic4x_coff1_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic4x_coff1_beh_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic4x_coff2_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic4x_coff2_beh_vec", &[_][]const u8{"coff-tic40.c"} ++ coffgen_sources },
    .{ "tic54x_coff0_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic54x_coff0_beh_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic54x_coff1_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic54x_coff1_beh_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic54x_coff2_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic54x_coff2_beh_vec", &[_][]const u8{"coff-tic54x.c"} ++ coffgen_sources },
    .{ "tic6x_elf32_be_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tic6x_elf32_le_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tic6x_elf32_c6000_be_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tic6x_elf32_c6000_le_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tic6x_elf32_linux_be_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tic6x_elf32_linux_le_vec", &[_][]const u8{ "elf32-tic6x.c", "elf32.c" } ++ elf_sources },
    .{ "tilegx_elf32_be_vec", &[_][]const u8{ "elf32-tilegx.c", "elfxx-tilegx.c", "elf32.c" } ++ elf_sources },
    .{ "tilegx_elf32_le_vec", &[_][]const u8{ "elf32-tilegx.c", "elfxx-tilegx.c", "elf32.c" } ++ elf_sources },
    .{ "tilegx_elf64_be_vec", &[_][]const u8{ "elf64-tilegx.c", "elfxx-tilegx.c", "elf64.c" } ++ elf_sources },
    .{ "tilegx_elf64_le_vec", &[_][]const u8{ "elf64-tilegx.c", "elfxx-tilegx.c", "elf64.c" } ++ elf_sources },
    .{ "tilepro_elf32_vec", &[_][]const u8{ "elf32-tilepro.c", "elf32.c" } ++ elf_sources },
    .{ "v800_elf32_vec", &[_][]const u8{ "elf32-v850.c", "elf32.c" } ++ elf_sources },
    .{ "v850_elf32_vec", &[_][]const u8{ "elf32-v850.c", "elf32.c" } ++ elf_sources },
    .{ "vax_aout_1knbsd_vec", &[_][]const u8{ "vax1knetbsd.c", "aout32.c" } },
    .{ "vax_aout_nbsd_vec", &[_][]const u8{ "vaxnetbsd.c", "aout32.c" } },
    .{ "vax_elf32_vec", &[_][]const u8{ "elf32-vax.c", "elf32.c" } ++ elf_sources },
    .{ "ft32_elf32_vec", &[_][]const u8{ "elf32-ft32.c", "elf32.c" } ++ elf_sources },
    .{ "visium_elf32_vec", &[_][]const u8{ "elf32-visiu.c", "elf32.c" } ++ elf_sources },
    .{ "wasm_vec", &[_][]const u8{"wasm-module.c"} },
    .{ "wasm32_elf32_vec", &[_][]const u8{ "elf32-wasm32.c", "elf32.c" } ++ elf_sources },
    .{ "x86_64_coff_vec", &[_][]const u8{"coff-x86_64.c"} ++ coff_sources },
    .{ "x86_64_elf32_vec", &[_][]const u8{ "elf64-x86-64.c", "elf64.c", "elf32.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "x86_64_elf64_vec", &[_][]const u8{ "elf64-x86-64.c", "elf64.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "x86_64_elf64_cloudabi_vec", &[_][]const u8{ "elf64-x86-64.c", "elf64.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "x86_64_elf64_fbsd_vec", &[_][]const u8{ "elf64-x86-64.c", "elf64.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "x86_64_elf64_sol2_vec", &[_][]const u8{ "elf64-x86-64.c", "elf64.c" } ++ elf_sources ++ elfxx_x86_sources },
    .{ "x86_64_mach_o_vec", &[_][]const u8{"mach-o-x86-64.c"} },
    .{ "x86_64_pe_vec", &[_][]const u8{ "pe-x86_64.c", "pex64igen.c" } ++ coff_sources },
    .{ "x86_64_pe_big_vec", &[_][]const u8{ "pe-x86_64.c", "pex64igen.c" } ++ coff_sources },
    .{ "x86_64_pei_vec", &[_][]const u8{ "pei-x86_64.c", "pex64igen.c" } ++ coff_sources },
    .{ "xgate_elf32_vec", &[_][]const u8{ "elf32-xgate.c", "elf32.c" } ++ elf_sources },
    .{ "xstormy16_elf32_vec", &[_][]const u8{ "elf32-xstormy16.c", "elf32.c" } ++ elf_sources },
    .{ "xtensa_elf32_be_vec", &[_][]const u8{ "xtensa-dynconfig.c", "xtensa-isa.c", "xtensa-module.c", "elf32-xtensa.c", "elf32.c" } ++ elf_sources },
    .{ "xtensa_elf32_le_vec", &[_][]const u8{ "xtensa-dynconfig.c", "xtensa-isa.c", "xtensa-module.c", "elf32-xtensa.c", "elf32.c" } ++ elf_sources },
    .{ "z80_coff_vec", &[_][]const u8{ "coff-z80.c", "reloc16.c" } ++ coffgen_sources },
    .{ "z80_elf32_vec", &[_][]const u8{ "elf32-z80.c", "elf32.c" } ++ elf_sources },
    .{ "z8k_coff_vec", &[_][]const u8{ "coff-z80.c", "reloc16.c" } ++ coff_sources },
    .{ "srec_vec", &[_][]const u8{"srec.c"} },
    .{ "symbolsrec_vec", &[_][]const u8{"srec.c"} },
    .{ "tekhex_vec", &[_][]const u8{"tekhex.c"} },
    .{ "core_cisco_be_vec", &[_][]const u8{"cisco-core.c"} },
    .{ "core_cisco_le_vec", &[_][]const u8{"cisco-core.c"} },
});

const opcodes_cgen_sources: []const []const u8 = &.{
    "cgen-opc.c",
    "cgen-asm.c",
    "cgen-dis.c",
    "cgen-bitset.c",
};

const opcodes_target_sources = std.StaticStringMap([]const []const u8).initComptime(&.{
    .{ "bfd_aarch64_arch", &[_][]const u8{ "aarch64-asm.c", "aarch64-dis.c", "aarch64-opc.c", "aarch64-asm-2.c", "aarch64-dis-2.c", "aarch64-opc-2.c" } },
    .{ "bfd_alpha_arch", &[_][]const u8{ "alpha-dis.c", "alpha-opc.c" } },
    .{ "bfd_amdgcn_arch", &[_][]const u8{} },
    .{ "bfd_arc_arch", &[_][]const u8{ "arc-dis.c", "arc-opc.c", "arc-ext.c" } },
    .{ "bfd_arm_arch", &[_][]const u8{"arm-dis.c"} },
    .{ "bfd_avr_arch", &[_][]const u8{"avr-dis.c"} },
    .{ "bfd_bfin_arch", &[_][]const u8{"bfin-dis.c"} },
    .{ "bfd_cr16_arch", &[_][]const u8{ "cr16-dis.c", "cr16-opc.c" } },
    .{ "bfd_cris_arch", &[_][]const u8{ "cris-desc.c", "cris-dis.c", "cris-opc.c", "cgen-bitset.c" } },
    .{ "bfd_crx_arch", &[_][]const u8{ "crx-dis.c", "crx-opc.c" } },
    .{ "bfd_csky_arch", &[_][]const u8{"csky-dis.c"} },
    .{ "bfd_d10v_arch", &[_][]const u8{ "d10v-dis.c", "d10v-opc.c" } },
    .{ "bfd_d30v_arch", &[_][]const u8{ "d30v-dis.c", "d30v-opc.c" } },
    .{ "bfd_dlx_arch", &[_][]const u8{"dlx-dis.c"} },
    .{ "bfd_fr30_arch", &[_][]const u8{ "fr30-asm.c", "fr30-desc.c", "fr30-dis.c", "fr30-ibld.c", "fr30-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_frv_arch", &[_][]const u8{ "frv-asm.c", "frv-desc.c", "frv-dis.c", "frv-ibld.c", "frv-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_ft32_arch", &[_][]const u8{ "ft32-opc.c", "ft32-dis.c" } },
    .{ "bfd_moxie_arch", &[_][]const u8{ "moxie-dis.c", "moxie-opc.c" } },
    .{ "bfd_h8300_arch", &[_][]const u8{"h8300-dis.c"} },
    .{ "bfd_hppa_arch", &[_][]const u8{"hppa-dis.c"} },
    .{ "bfd_i386_arch", &[_][]const u8{"i386-dis.c"} },
    .{ "bfd_iamcu_arch", &[_][]const u8{"i386-dis.c"} },
    .{ "bfd_ia64_arch", &[_][]const u8{ "ia64-dis.c", "ia64-opc.c" } },
    .{ "bfd_ip2k_arch", &[_][]const u8{ "ip2k-asm.c", "ip2k-desc.c", "ip2k-dis.c", "ip2k-ibld.c", "ip2k-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_epiphany_arch", &[_][]const u8{ "epiphany-asm.c", "epiphany-desc.c", "epiphany-dis.c", "epiphany-ibld.c", "epiphany-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_iq2000_arch", &[_][]const u8{ "iq2000-asm.c", "iq2000-desc.c", "iq2000-dis.c", "iq2000-ibld.c", "iq2000-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_kvx_arch", &[_][]const u8{ "kvx-opc.c", "kvx-dis.c" } },
    .{ "bfd_lm32_arch", &[_][]const u8{ "lm32-asm.c", "lm32-desc.c", "lm32-dis.c", "lm32-ibld.c", "lm32-opc.c", "lm32-opinst.c" } ++ opcodes_cgen_sources },
    .{ "bfd_m32c_arch", &[_][]const u8{ "m32c-asm.c", "m32c-desc.c", "m32c-dis.c", "m32c-ibld.c", "m32c-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_m32r_arch", &[_][]const u8{ "m32r-asm.c", "m32r-desc.c", "m32r-dis.c", "m32r-ibld.c", "m32r-opc.c", "m32r-opinst.c" } ++ opcodes_cgen_sources },
    .{ "bfd_m68hc11_arch", &[_][]const u8{ "m68hc11-dis.c", "m68hc11-opc.c" } },
    .{ "bfd_m68hc12_arch", &[_][]const u8{ "m68hc11-dis.c", "m68hc11-opc.c" } },
    .{ "bfd_m9s12x_arch", &[_][]const u8{ "m68hc11-dis.c", "m68hc11-opc.c" } },
    .{ "bfd_m9s12xg_arch", &[_][]const u8{ "m68hc11-dis.c", "m68hc11-opc.c" } },
    .{ "bfd_s12z_arch", &[_][]const u8{ "s12z-dis.c", "s12z-opc.c" } },
    .{ "bfd_m68k_arch", &[_][]const u8{ "m68k-dis.c", "m68k-opc.c" } },
    .{ "bfd_mcore_arch", &[_][]const u8{"mcore-dis.c"} },
    .{ "bfd_mep_arch", &[_][]const u8{ "mep-asm.c", "mep-desc.c", "mep-dis.c", "mep-ibld.c", "mep-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_metag_arch", &[_][]const u8{"metag-dis.c"} },
    .{ "bfd_microblaze_arch", &[_][]const u8{"microblaze-dis.c"} },
    .{ "bfd_mips_arch", &[_][]const u8{ "mips-dis.c", "mips-opc.c", "mips16-opc.c", "micromips-opc.c" } },
    .{ "bfd_mmix_arch", &[_][]const u8{ "mmix-dis.c", "mmix-opc.c" } },
    .{ "bfd_mn10200_arch", &[_][]const u8{ "m10200-dis.c", "m10200-opc.c" } },
    .{ "bfd_mn10300_arch", &[_][]const u8{ "m10300-dis.c", "m10300-opc.c" } },
    .{ "bfd_mt_arch", &[_][]const u8{ "mt-asm.c", "mt-desc.c", "mt-dis.c", "mt-ibld.c", "mt-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_msp430_arch", &[_][]const u8{ "msp430-dis.c", "msp430-decode.c" } },
    .{ "bfd_nds32_arch", &[_][]const u8{ "nds32-asm.c", "nds32-dis.c" } },
    .{ "bfd_nfp_arch", &[_][]const u8{"nfp-dis.c"} },
    .{ "bfd_ns32k_arch", &[_][]const u8{"ns32k-dis.c"} },
    .{ "bfd_or1k_arch", &[_][]const u8{ "or1k-asm.c", "or1k-desc.c", "or1k-dis.c", "or1k-ibld.c", "or1k-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_pdp11_arch", &[_][]const u8{ "pdp11-dis.c", "pdp11-opc.c" } },
    .{ "bfd_pj_arch", &[_][]const u8{ "pj-dis.c", "pj-opc.c" } },
    .{ "bfd_powerpc_arch", &[_][]const u8{ "ppc-dis.c", "ppc-opc.c" } },
    .{ "bfd_powerpc_64_arch", &[_][]const u8{ "ppc-dis.c", "ppc-opc.c" } },
    .{ "bfd_pru_arch", &[_][]const u8{ "pru-dis.c", "pru-opc.c" } },
    .{ "bfd_pyramid_arch", &[_][]const u8{} },
    .{ "bfd_romp_arch", &[_][]const u8{} },
    .{ "bfd_riscv_arch", &[_][]const u8{ "riscv-dis.c", "riscv-opc.c" } },
    .{ "bfd_rs6000_arch", &[_][]const u8{ "ppc-dis.c", "ppc-opc.c" } },
    .{ "bfd_rl78_arch", &[_][]const u8{ "rl78-dis.c", "rl78-decode.c" } },
    .{ "bfd_rx_arch", &[_][]const u8{ "rx-dis.c", "rx-decode.c" } },
    .{ "bfd_s390_arch", &[_][]const u8{ "s390-dis.c", "s390-opc.c" } },
    .{ "bfd_score_arch", &[_][]const u8{ "score-dis.c", "score7-dis.c" } },
    .{ "bfd_sh_arch", &[_][]const u8{ "sh-dis.c", "cgen-bitset.c" } },
    .{ "bfd_sparc_arch", &[_][]const u8{ "sparc-dis.c", "sparc-opc.c" } },
    .{ "bfd_spu_arch", &[_][]const u8{ "spu-dis.c", "spu-opc.c" } },
    .{ "bfd_tic30_arch", &[_][]const u8{"tic30-dis.c"} },
    .{ "bfd_tic4x_arch", &[_][]const u8{"tic4x-dis.c"} },
    .{ "bfd_tic54x_arch", &[_][]const u8{ "tic54x-dis.c", "tic54x-opc.c" } },
    .{ "bfd_tic6x_arch", &[_][]const u8{"tic6x-dis.c"} },
    .{ "bfd_tilegx_arch", &[_][]const u8{ "tilegx-dis.c", "tilegx-opc.c" } },
    .{ "bfd_tilepro_arch", &[_][]const u8{ "tilepro-dis.c", "tilepro-opc.c" } },
    .{ "bfd_v850_arch", &[_][]const u8{ "v850-opc.c", "v850-dis.c" } },
    .{ "bfd_v850e_arch", &[_][]const u8{ "v850-opc.c", "v850-dis.c" } },
    .{ "bfd_v850ea_arch", &[_][]const u8{ "v850-opc.c", "v850-dis.c" } },
    .{ "bfd_v850_rh850_arch", &[_][]const u8{ "v850-opc.c", "v850-dis.c" } },
    .{ "bfd_vax_arch", &[_][]const u8{"vax-dis.c"} },
    .{ "bfd_visium_arch", &[_][]const u8{ "visium-dis.c", "visium-opc.c" } },
    .{ "bfd_wasm32_arch", &[_][]const u8{"wasm32-dis.c"} },
    .{ "bfd_xgate_arch", &[_][]const u8{ "xgate-dis.c", "xgate-opc.c" } },
    .{ "bfd_xstormy16_arch", &[_][]const u8{ "xstormy16-asm.c", "xstormy16-desc.c", "xstormy16-dis.c", "xstormy16-ibld.c", "xstormy16-opc.c" } ++ opcodes_cgen_sources },
    .{ "bfd_xtensa_arch", &[_][]const u8{"xtensa-dis.c"} },
    .{ "bfd_z80_arch", &[_][]const u8{"z80-dis.c"} },
    .{ "bfd_z8k_arch", &[_][]const u8{"z8k-dis.c"} },
    .{ "bfd_bpf_arch", &[_][]const u8{ "bpf-dis.c", "bpf-opc.c" } },
    .{ "bfd_loongarch_arch", &[_][]const u8{ "loongarch-dis.c", "loongarch-opc.c", "loongarch-coder.c" } },
});

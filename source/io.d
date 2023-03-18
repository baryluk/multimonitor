import types;
import util;
import time;

/*
root@debian:~# iotop -b -o
Total DISK READ:         0.00 B/s | Total DISK WRITE:         0.00 B/s
Current DISK READ:       0.00 B/s | Current DISK WRITE:       0.00 B/s
    TID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN      IO    COMMAND
1001380 be/4 root        4.76 M/s    0.00 B/s  0.00 % 16.74 % find /
1000686 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.01 % [kworker/5:2-events]
1000462 be/4 root        0.00 B/s    0.00 B/s  0.00 %  0.01 % [kworker/22:1-events_freezable_power_]
*/

/*
$ sudo cat /proc/1/io
rchar: 120475434414
wchar: 20625238506
syscr: 36196670
syscw: 9632679
read_bytes: 1242071040
write_bytes: 0
cancelled_write_bytes: 0
*/


// Can be done using CONFIG_TASK_DELAY_ACCT, CONFIG_TASK_IO_ACCOUNTING, CONFIG_TASKSTATS and CONFIG_VM_EVENT_COUNTERS
// and possibly using cgroups too.

/*
/proc/vmstat

pgpgin
pgpgout
pswpin
pswpout
*/

struct VmStat {
  MyMonoTime timestamp;

  uint64 pgpgin, pgpgout;  // In blocks, 1024 bytes on all current kernels.
  uint64 pswpin, pswpout;  // In pages.
}

enum IoStuff {
  none,
  min,
  med,
  max,
}

class VmStatReader {
 public:
  this(const IoStuff mode) {
    import core.sys.posix.fcntl : open, O_RDONLY;

    vmstat_fd_ = open("/proc/vmstat", O_RDONLY);
    assert(vmstat_fd_ >= 0, "Can't open vmstat file");

    mode_ = mode;
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(vmstat_fd_);
  }

  VmStat read() @nogc nothrow {
    char[8192] buf = void;

    import core.stdc.errno : errno, ESRCH;
    import core.sys.posix.sys.types : ssize_t, off_t;
version (SimpleSeekPlusRead) {
    import core.sys.posix.unistd : read, lseek;
    import core.stdc.stdio : SEEK_SET;
    lseek(vmstat_fd_, cast(off_t)0, SEEK_SET);
    auto t1 = MyMonoTime.currTime();
    // TODO(baryluk): What happens exactly if the process dies while we keep open their stat file?
    const ssize_t vmstat_read_ret = read(vmstat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length));
    const int vmstat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();
    if (vmstat_read_ret == -1 && vmstat_read_errno0 == ESRCH) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return VmStat();
    }
} else {
    import core.sys.posix.unistd : pread;
    auto t1 = MyMonoTime.currTime();
    const ssize_t vmstat_read_ret = pread(vmstat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length), cast(off_t)(0));
    const int vmstat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();

    if (vmstat_read_ret == -1 && vmstat_read_errno0 == ESRCH) {
      return VmStat();
    }
    if (vmstat_read_ret < 0) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return VmStat();
    }
}


    const string vmstat_data = cast(const(string))(buf[0 .. vmstat_read_ret]);

    import std.algorithm.searching : findSplit;
    // import std.string : split;
    import std.algorithm.iteration : splitter;
    import std.conv : to;

    dchar[8192] data = void;
    assert(vmstat_data.length <= 8192);
    for (int i = 0; i < vmstat_data.length; i++) {
      data[i] = vmstat_data[i];
    }

    auto splitted = data[0 .. vmstat_data.length].splitter(cast(dchar)('\n'));

    VmStat r;  // Initialize r, just in case we don't find proper fields in the vmstat file.
    // Note, the pgpg* and pswp* stuff might not be tracked by kernel, because
    // it requires CONFIG_VM_EVENT_COUNTERS || CONFIG_MEMCG in kernel,
    // and these things can be disabled in expert mode.

    r.timestamp = time_avg(t1, t2);

    foreach (ref line; splitted) {
      if (line.length == 0 || line[0] != 'p') {  // Microptimization.
        continue;
      }

      import std.algorithm.searching : startsWith;

      // pgpgin and pgpgout values are in KiB (1024 bytes) already from kernel.
      // They are tracked internally as sectors (512 bytes always),
      // not blocks (1024 bytes) or pages (4096 / 8192 / ... ).
      // Instead sectors (512 bytes) are turned into KiB units,
      // I.e. 20 sectors, is 10 KiB units.
      //
      // For details check vmstat_start function at
      // https://github.com/torvalds/linux/blob/master/mm/vmstat.c#L1751
      //
      // In the past these values were in "blocks", which on some older
      // kernels could have been 512 bytes, or 4096 bytes, depending on
      // IO devices, etc. Now all blocks are 1024 bytes, independent
      // of actual IO device sector storage or transfer sizes.

      if (line.startsWith("pgpgin "d)) {
        r.pgpgin = line["pgpgin "d.length .. $].qto!uint64;
        continue;
      }
      if (line.startsWith("pgpgout "d)) {
        r.pgpgout = line["pgpgout "d.length .. $].qto!uint64;
        continue;
      }

      // pswpin and pswpout are in pages.
      //
      // For details check lru_cache_add_inactive_or_unevictable function
      // calling count_vm_events at
      // https://github.com/torvalds/linux/blob/master/mm/swap.c#L494
      // These counters are per-CPU, then aggregated in /proc/vmstat
      // by simple sum.


      if (line.startsWith("pswpin "d)) {
        r.pswpin = line["pswpin "d.length .. $].qto!uint64;
        continue;
      }
      if (line.startsWith("pswpout "d)) {
        r.pswpout = line["pswpout "d.length .. $].qto!uint64;
        continue;
      }
      // If we need more in the future, a mixin to de-duplicate code,
      // or a perfect hash function to speed things up, could be a
      // good idea.
    }

    return r;
  }

  string[] header(bool human_friendly) const {
    string[] ret;
    if (human_friendly) {
      ret ~= ["%11s|RDkB/s|Read from disk (excluding swapping) in KiB/s",
              "%11s|WRkB/s|Written to disk (excluding swapping) in KiB/s"];
    } else {
      ret ~= ["%6s|RDkB/s|Read from disk (excluding swapping) in KiB/s",
              "%6s|WRkB/s|Written to disk (excluding swapping) in KiB/s"];
    }
    if (mode_ == IoStuff.max) {
      if (human_friendly) {
        // We give less width to swap bandwidth, because it really unlikely
        // we will be swapping gigabytes per second.
        ret ~= ["%10s|SWAPRDkB/s|Swap read from disk in KiB/s",
                "%10s|SWAPWRkB/s|Swap write to disk in KiB/s"];
      } else {
        ret ~= ["%4s|SWRD|Swap read from disk in KiB/s",
                "%4s|SWWR|Swap write to disk in KiB/s"];
      }
    }
    return ret;
  }

  import std.array : Appender;

  // static
  void format(ref Appender!(char[]) appender, const ref VmStat prev, const ref VmStat next, bool human_friendly) {
    import time : TickPerSecond;
    // static
    //const ticks_per_second = TickPerSecond();

    const wall_clock_time_difference_sec = (next.timestamp - prev.timestamp).total!"nsecs" * 1.0e-9;

    const double pgpgin_rate_kBps = (next.pgpgin - prev.pgpgin) / wall_clock_time_difference_sec;
    const double pgpgout_rate_kBps = (next.pgpgout - prev.pgpgout) / wall_clock_time_difference_sec;

    import std.format : formattedWrite;
    if (human_friendly) {
      // We do display KB/s here, because when one has many columns,
      // having them there makes it easier to know what is what,
      // without needing to reference header somewhere behind.
      // We don't display KiB/s, while more correct, it just wastes
      // extra character, and usually it is not big super important.
      appender.formattedWrite!"%7.0fKB/s %7.0fKB/s"(
          pgpgin_rate_kBps, pgpgout_rate_kBps);
    } else {
      // For non-human consumption, we use more narrow columns by default,
      // they will expand if needed, at the expense of uglier look
      // (jagged and not aligned). But that is fine.
      appender.formattedWrite!"%6.0f %6.0f"(
          pgpgin_rate_kBps, pgpgout_rate_kBps);
    }
    if (mode_ == IoStuff.max) {
      // static
      const size_t page_size_kb = (){
        import core.sys.posix.unistd : sysconf, _SC_PAGESIZE;
        // It should be fine. Smallest page size ever used was 4KiB,
        // always power of two, and unlikely for this to ever change.
        return cast(size_t)(sysconf(_SC_PAGESIZE)) / 1024;
      }();
      assert(page_size_kb > 0);
      // debug assert(page_size_kb * 1024 == cast(size_t)(sysconf(_SC_PAGESIZE)));

      const double pswpin_rate_kBps = 1.0 * page_size_kb * (next.pswpin - prev.pswpin) / wall_clock_time_difference_sec;
      const double pswpout_rate_kBps = 1.0 * page_size_kb * (next.pswpout - prev.pswpout) / wall_clock_time_difference_sec;

      appender.put(' ');
      if (human_friendly) {
        appender.formattedWrite!"%6.0fKB/s %6.0fKB/s"(
            pswpin_rate_kBps, pswpout_rate_kBps);
      } else {
        appender.formattedWrite!"%4.0f %4.0f"(
            pswpin_rate_kBps, pswpout_rate_kBps);
      }
    }
  }

 private:
  const int vmstat_fd_;
  const IoStuff mode_;
}

import types;
import util;
import time;

struct NetStat {
  MyMonoTime timestamp;

  uint64 recv_packets, send_packets;
  uint64 recv_multicast, send_multicast;
  uint64 recv_broadcast, send_broadcast;

  uint64 recv_bytes, send_bytes;

  uint64 recv_errors, send_errors;
  uint64 recv_drops, send_drops;
}

enum NetStuff {
  none,
  min,  // Just bytes*
  med,  // Also pkt*
  max,  // Extras: errors, multicast, broadcasts, etc.
}

// Not to be confused with `netstat` or /proc/net/netstat (TCP and IP stats).
class NetStatReader {
 public:
  this(const NetStuff mode) {
    import core.sys.posix.fcntl : open, O_RDONLY;

    netstat_fd_ = open("/proc/net/dev", O_RDONLY);
    assert(netstat_fd_ >= 0, "Can't open vmstat file");

    mode_ = mode;
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(netstat_fd_);
  }

  NetStat read() @nogc nothrow {
    char[8192] buf = void;

    import core.stdc.errno : errno, ESRCH;
    import core.sys.posix.sys.types : ssize_t, off_t;
version (SimpleSeekPlusRead) {
    import core.sys.posix.unistd : read, lseek;
    import core.stdc.stdio : SEEK_SET;
    lseek(netstat_fd_, cast(off_t)0, SEEK_SET);
    auto t1 = MyMonoTime.currTime();
    // TODO(baryluk): What happens exactly if the process dies while we keep open their stat file?
    const ssize_t netstat_read_ret = read(netstat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length));
    const int netstat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();
    if (netstat_read_ret == -1 && netstat_read_errno0 == ESRCH) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return netstat();
    }
} else {
    import core.sys.posix.unistd : pread;
    auto t1 = MyMonoTime.currTime();
    const ssize_t netstat_read_ret = pread(netstat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length), cast(off_t)(0));
    const int netstat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();

    if (netstat_read_ret == -1 && netstat_read_errno0 == ESRCH) {
      return NetStat();
    }
    if (netstat_read_ret < 0) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return NetStat();
    }
}


    const string netstat_data = cast(const(string))(buf[0 .. netstat_read_ret]);

    import std.algorithm.searching : findSplit;
    // import std.string : split;
    import std.algorithm.iteration : splitter;
    import std.conv : to;

    dchar[8192] data = void;
    assert(netstat_data.length <= 8192);
    for (int i = 0; i < netstat_data.length; i++) {
      data[i] = netstat_data[i];
    }

    auto splitted = data[0 .. netstat_data.length].splitter('\n');

    NetStat r;  // Initialize r, just in case we don't find interfaces, and such.

    r.timestamp = time_avg(t1, t2);

/*
$ cat /proc/net/dev
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 92034874 1148196    0    0    0     0          0         0 92034874 1148196    0    0    0     0       0          0
enp10s0: 293850561259 237080554    0    0    0     0          0    651442 46962792256 134255089    0    0    0     0       0          0
docker0: 2054157   38018    0    0    0     0          0         0 158187258  105142    0    0    0     0       0          0
lxcbr0:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
*/


    int line_count = 0;
    foreach (ref line; splitted) {
      line_count++;
      if (line_count <= 2) {  // Skip "Inter-", " face ".
         continue;
      }
      if (line.length == 0) {
        continue;
      }

      //auto splitted_line1 = line.findSplit(cast(dchar)(':'));
      auto splitted_line1 = line.findSplit(":"d);
      auto interface_name = splitted_line1[0];

      import std.string : strip;

      // Lets make "lo" boring and not include it in total.
      if (interface_name.strip == "lo"d) {
        continue;
      }

      auto splitted_line2 = splitted_line1[2].splitter(' ');
      int column_count = 0;
      foreach (ref column; splitted_line2) {
        const stripped_column = column.strip;
        if (stripped_column.length == 0) {
          continue;
        }
        column_count++;
        const uint64 value = stripped_column.qto!uint64;
        switch (column_count) {
          // Receive
          case 1: r.recv_bytes += value; break;
          case 2: r.recv_packets += value; break;
          case 3: r.recv_errors += value; break;
          case 4: r.recv_drops += value; break;
          // case 5: r.recv_fifo += value; break;
          // case 6: r.recv_frame_errors += value; break;
          // case 7: r.recv_compressed += value; break;
          case 8: r.recv_multicast += value; break;

          // Transmit
          case 9: r.send_bytes += value; break;
          case 10: r.send_packets += value; break;
          case 11: r.send_errors += value; break;
          case 12: r.send_drops += value; break;
          // case 13: r.send_fifo += value; break;
          // case 14: r.send_collissions += value; break;
          // case 15: r.send_carrier_error += value; break;
          // case 16: r.send_compressed += value; break;

          default: break;
        }
      }

//      import std.algorithm.searching : startsWith;

    }

    return r;
  }

  string[] header(bool human_friendly) const {
    string[] ret;
    if (human_friendly) {
      ret ~= ["%11s|NET↓kB/s|Received (\"downloaded\"/downlink) from network in KB/s",
              "%11s|NET↑kB/s|Sent (\"uploaded\"/uplink) to network in KiB/s"];
    } else {
      ret ~= ["%6s|NETDNkB/s|Received (\"downloaded\"/downlink) from network in KB/s",
              "%6s|NETUPkB/s|Sent (\"uploaded\"/uplink) to network in KiB/s"];
    }
    if (mode_ >= NetStuff.med) {
      if (human_friendly) {
        ret ~= ["%10s|NET↓Kpps|Received (downlink) from network in kilo-packets/s",
                "%10s|NET↑Kpps|Sent (uplink) to network in kilo-packets/s"];
      } else {
        ret ~= ["%6s|NETDNKpps|Received (downlink) from network in kilo-packets/s",
                "%6s|NETUPKpps|Sent (uplink) to network in kilo-packets/s"];
      }
    }
    if (mode_ >= NetStuff.max) {
       ret ~= ["%6s|ERR↓pps|Receive (downlink) errors from network in packets/s",
               "%6s|ERR↑pps|Send (uplink) errors to network in packets/s"];
       ret ~= ["%6s|DRP↓pps|Receive (downlink) drops from network in packets/s",
               "%6s|DRP↑pps|Send (uplink) drops to network in packets/s"];
    }
    return ret;
  }

  import std.array : Appender;

  // static
  void format(ref Appender!(char[]) appender, const ref NetStat prev, const ref NetStat next, bool human_friendly) {
    import time : TickPerSecond;
    // static
    //const ticks_per_second = TickPerSecond();

    const wall_clock_time_difference_sec = (next.timestamp - prev.timestamp).total!"nsecs" * 1.0e-9;

    const double downlink_rate_kBps = (next.recv_bytes - prev.recv_bytes) / wall_clock_time_difference_sec / 1000;
    const double uplink_rate_kBps = (next.send_bytes - prev.send_bytes) / wall_clock_time_difference_sec / 1000;

//    import std.stdio;
//    writefln!"%s %s"(prev, next);

    import std.format : formattedWrite;
    if (human_friendly) {
      // We do display KB/s here, because when one has many columns,
      // having them there makes it easier to know what is what,
      // without needing to reference header somewhere behind.
      appender.formattedWrite!"%7.0fKB/s %7.0fKB/s"(
          downlink_rate_kBps, uplink_rate_kBps);
    } else {
      // For non-human consumption, we use more narrow columns by default,
      // they will expand if needed, at the expense of uglier look
      // (jagged and not aligned). But that is fine.
      appender.formattedWrite!"%6.0f %6.0f"(
          downlink_rate_kBps, uplink_rate_kBps);
    }
    if (mode_ >= NetStuff.med) {
      const double downlink_rate_kpps = (next.recv_packets - prev.recv_packets) / wall_clock_time_difference_sec / 1000;
      const double uplink_rate_kpps = (next.send_packets - prev.send_packets) / wall_clock_time_difference_sec / 1000;

      appender.put(' ');
      if (human_friendly) {
        appender.formattedWrite!"%6.1fKpps %6.1fKpps"(
            downlink_rate_kpps, uplink_rate_kpps);
      } else {
        appender.formattedWrite!"%4.0f %4.0f"(
            downlink_rate_kpps, uplink_rate_kpps);
      }
    }
    if (mode_ >= NetStuff.max) {
      const double downlink_error_rate_pps = (next.recv_errors - prev.recv_errors) / wall_clock_time_difference_sec;
      const double uplink_error_rate_kpps = (next.send_errors - prev.send_errors) / wall_clock_time_difference_sec;
      const double downlink_drop_rate_pps = (next.recv_drops - prev.recv_drops) / wall_clock_time_difference_sec;
      const double uplink_drop_rate_kpps = (next.send_drops - prev.send_drops) / wall_clock_time_difference_sec;

      appender.put(' ');
      if (human_friendly) {
        appender.formattedWrite!"%5.0feps %5.0feps %5.0fdps %5.0fdps"(
            downlink_error_rate_pps, uplink_error_rate_kpps,
            downlink_drop_rate_pps, uplink_drop_rate_kpps);
      } else {
        appender.formattedWrite!"%3.0f %3.0f %3.0f %3.0f"(
            downlink_error_rate_pps, uplink_error_rate_kpps,
            downlink_drop_rate_pps, uplink_drop_rate_kpps);
      }
    }
  }

 private:
  const int netstat_fd_;
  const NetStuff mode_;
}

import types;
import util;
import time;

/*
$ cat /proc/loadavg
0.00 0.09 0.46 1/675 1027942
$

       /proc/loadavg
              The first three fields in this file are load average figures giving the number of jobs in the run queue (state R) or waiting for disk I/O (state D) averaged over 1, 5, and 15  minutes.   They
              are  the  same as the load average numbers given by uptime(1) and other programs.  The fourth field consists of two numbers separated by a slash (/).  The first of these is the number of cur‐
              rently runnable kernel scheduling entities (processes, threads).  The value after the slash is the number of kernel scheduling entities that currently exist on the system.  The fifth field is
              the PID of the process that was most recently created on the system.
*/

enum LoadAvgStuff {
  none,
  min,
  med,
  max,
}

struct LoadAvgStat {
  MyMonoTime timestamp;

  float loadavg1min;
  float loadavg5min;
  float loadavg15min;

  int runnable_count;
  int tasks_count;

  int forks_count;  // Note: Can wrap around.
}

class LoadAvgReader {
 public:
  this(const LoadAvgStuff mode) {
    import core.sys.posix.fcntl : open, O_RDONLY;

    loadavg_fd_ = open("/proc/loadavg", O_RDONLY);
    assert(loadavg_fd_ >= 0, "Can't open loadavg file");

    mode_ = mode;
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(loadavg_fd_);
  }

  LoadAvgStat read() @nogc nothrow {
    char[4096] buf = void;

    import core.stdc.errno : errno, ESRCH;
    import core.sys.posix.sys.types : ssize_t, off_t;
version (SimpleSeekPlusRead) {
    import core.sys.posix.unistd : read, lseek;
    import core.stdc.stdio : SEEK_SET;
    lseek(loadavg_fd_, cast(off_t)0, SEEK_SET);
    auto t1 = MyMonoTime.currTime();
    const ssize_t loadavg_read_ret = read(loadavg_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length));
    const int loadavg_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();
    if (loadavg_read_ret == -1 && loadavg_read_errno0 == ESRCH) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return LoadAvgStat();
    }
} else {
    import core.sys.posix.unistd : pread;
    auto t1 = MyMonoTime.currTime();
    const ssize_t loadavg_read_ret = pread(loadavg_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length), cast(off_t)(0));
    const int loadavg_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();

    if (loadavg_read_ret == -1 && loadavg_read_errno0 == ESRCH) {
      return LoadAvgStat();
    }
    if (loadavg_read_ret < 0) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return LoadAvgStat();
    }
}

    const string loadavg_data = cast(const(string))(buf[0 .. loadavg_read_ret]);

    import std.algorithm.searching : findSplit;
    import std.algorithm.iteration : splitter;
    import std.conv : to;

    dchar[4096] data = void;
    assert(loadavg_data.length <= 4096);
    for (int i = 0; i < loadavg_data.length; i++) {
      data[i] = loadavg_data[i];
    }

    auto splitted = data[0 .. loadavg_data.length].splitter(cast(dchar)(' '));

    LoadAvgStat r;
    r.timestamp = time_avg(t1, t2);

    r.loadavg1min = splitted.popy().qtof!float;  // 1
    r.loadavg5min = splitted.popy().qtof!float;  // 2
    r.loadavg15min = splitted.popy().qtof!float;  // 3
    {
      auto runnables = splitted.popy();  // 4
      auto runnables_splitted = runnables.splitter(cast(dchar)('/'));
      r.runnable_count = runnables_splitted.popy().qto!int;
      r.tasks_count = runnables_splitted.popy().qto!int;
    }
    {
      auto last_field = splitted.popy();
      // Strip the new line character at the end.
      r.forks_count = last_field[0 .. $-1].qto!int;  // 5
    }

    return r;
  }

  string[] header(bool human_friendly) const {
    string[] ret;
    if (human_friendly) {
      ret ~= ["%6s|LDAVG1|Load average 1-minute"];
    } else {
      ret ~= ["%4s|LDAVG1|Load average 1-minute"];
    }
    if (mode_ == LoadAvgStuff.max) {
      if (human_friendly) {
      ret ~= ["%6s|LDAVG5|Load average 5-minute",
              "%8s|RUNNABLE|Number of runnable scheduling entities (processes, threads) in the system",
              "%8s|TASKS|Number of all scheduling entities (processes, threads) in the system",
              "%6s|FORKS|Estimated number of forks (new processes / PIDs) since previous report / line"];
      } else {
      ret ~= ["%4s|LDAVG5|Load average 5-minute",
              "%4s|RUNNABLE|Number of runnable scheduling entities (processes, threads) in the system",
              "%4s|TASKS|Number of all scheduling entities (processes, threads) in the system",
              "%1s|FORKS|Estimated number of forks (new processes / PIDs) since previous report / line"];
      }
    }
    return ret;
  }

  import std.array : Appender;

  // static
  void format(ref Appender!(char[]) appender, const ref LoadAvgStat prev, const ref LoadAvgStat next, bool human_friendly) {
    // const wall_clock_time_difference_sec = (next.timestamp - prev.timestamp).total!"nsecs" * 1.0e-9;

    import std.format : formattedWrite;
    if (human_friendly) {
      appender.formattedWrite!"%6.2f"(next.loadavg1min);
      if (mode_ == LoadAvgStuff.max) {
        appender.formattedWrite!" %6.2f %8d %8d %6d"(next.loadavg5min, next.runnable_count, next.tasks_count, next.forks_count - prev.forks_count);
      }
    } else {
      // For non-human consumption, we use more narrow columns by default,
      // they will expand if needed, at the expense of uglier look
      // (jagged and not aligned). But that is fine.
      appender.formattedWrite!"%.2f"(next.loadavg1min);
      if (mode_ == LoadAvgStuff.max) {
        appender.formattedWrite!" %.2f %d %d %d"(next.loadavg5min, next.runnable_count, next.tasks_count, next.forks_count - prev.forks_count);
      }
    }
  }

 private:
  const int loadavg_fd_;
  const LoadAvgStuff mode_;
}

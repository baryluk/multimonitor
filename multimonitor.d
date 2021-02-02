module multimonitor;

//version = NoAutodecodeStrings;

//import std.range : take;
//import std.array : array;

import types;
import util;
import time;
import hwmon;
import gpu : GpuStuff, GpuStatReader, GpuStat;
import io : IoStuff, VmStatReader, VmStat;
import cpu;
import proc;
import exec;

import async : async_wrap;



int main(string[] args) {
  import std.algorithm : map;
  import std.conv : to;
  import std.stdio : writefln, writef, writeln, stderr;
  import core.thread : Thread;
  import core.time : dur;
  import std.array : array;
  import std.datetime : Clock;

  import std.getopt;

  uint interval_msec = 200;
  uint duration_sec = uint.max;
  string[] process_names;
  uint[] pids;
  string[string] process_map;

  // Wait until all requested processes are up.
  // This only applies for processes by name.
  bool wait_for_all;

  // If the process is detected to be dead, try searching for it again.
  bool find_new_when_dead;

  // Stop collecting metrics and exit, when any of requested pids
  // exits too.
  bool exit_when_dead;

  // When looking for matching processes, if there are multiple
  // sum their metrics. This also enables watching for new
  // processes matching the name periodically.
  bool sum_all_matching;

  bool cpu;
  bool load;
  bool temp;
  bool sched;
  bool vm;
  bool interrupts;
  bool ctx;
  IoStuff io;
  bool net;
  string[] mangohud_fps;

  GpuStuff gpu_stuff;

  string[] exec;
  string[] exec_async;
  string[] pipe;
  string[] sub;

  bool auto_output;
  enum TimeMode { relative, boottime, absolute, all, }
  TimeMode time_mode = TimeMode.all;
  bool utc_nice;
  bool buffered;
  bool human_friendly = true;
  bool csv;
  bool verbose;

  uint async_delay_msec = 200;

  arraySep = ",";  // defaults to "", separation by whitespace

  const string[] args_copy = args.idup;

  void opt_handle_sub(string _option, string value) {
    sub ~= value;
  }

  const bool empty_args = (args.length <= 1);

  // Note: Please do not add single letter options! They are harder to read,
  // and can make extending options in the future harder due to conflicts.
  auto helpInformation = getopt(
    args,
    std.getopt.config.caseSensitive,
    "sub",                "Launch a single external command, monitor it just like --pid and finish once it finishes", &opt_handle_sub,
    "pids|pid",           "List of process pids to monitor", &pids,
    "process",            "List of process names to monitor", &process_names,
    "process_map",        "Assign short names to processes, i.e. a=firefox,b=123", &process_map,
    "cpu",                "Overall CPU stats, i.e. load, average and max frequency", &cpu,
    "load",               "System-wide load average", &load,
    "temp",               "CPU temperature", &temp,
    "sched",              "System-wide CPU scheduler details", &sched,
    "vm",                 "System-wide virtual memory subsystem details", &vm,
    "interrupts",         "System-wide interrupts details", &interrupts,
    "ctx",                "System-wide context switching metrics", &ctx,
    "io",                 "System-wide IO details. Available: none, min, max", &io,
    "net",                "System-wide networking metrics", &net,
    "gpu",                "System-wide GPU stats. Available: none, min, max", &gpu_stuff,
    "mangohud_fps",       "Gather FPS information for given processes using MangoHud RPC", &mangohud_fps,
    // TODO(baryluk): It would be nice to preserve relative order when varoius options are mixed.
    "exec",               "Run external command with arbitrary output once per sample", &exec,
    "exec_async",         "Run external command with arbitrary output asynchronously", &exec_async,
    "pipe",               "Run external command and consume output lines as they come", &pipe,
    // TODO(baryluk): It would be nice, to default to interval_msec.
    "async_delay_msec",   "Change how often to run --exec_async and --gpu commands. (default: 200ms)", &async_delay_msec,
    "wait_for_all",       "Wait until all named processes are up", &wait_for_all,
    "find_new_when_dead", "If the named process is dead, try searching again", &find_new_when_dead,
    "exit_when_dead",     "Stop collecting metrics and exit, when any of requested pids exits too", &exit_when_dead,
    "sum_all_matching",   "For named processes, sum all matching processes metrics (sum CPU, smart memory sum)", &sum_all_matching,
    "auto_output",        "Automatically create timestamped output file in current working directory with data, instead of using standard output. (default: false)", &auto_output,
    "interval_msec",      "Target interval for main metric sampling and output. (default: 200ms)",   &interval_msec,
    "duration_sec",       "How long to log. (default: forever)", &duration_sec,
    "time",               "Time mode, one of: relative, boottime, absolute, all. (default: all)", &time_mode,
    "utc_nice",           "Show abssolute time as ISO 8601 formated date and time in UTC timezone. Otherwise Unix time is printed. (default: false).", &utc_nice,
    "buffered",           "Use buffered output. (default: false)", &buffered,
    "H|human_friendly",   "Use human friendly (pretty), but still fixed units. Otherwise strip units. (default: true)", &human_friendly,
    "csv",                "Use (mostly) CSV format, with variable width columns. (default: false)", &csv,
    "verbose",            "Show timeing loop debug info", &verbose
  );

  //if (sub_.length) {
  //  sub ~= sub_;
  //}

  if (helpInformation.helpWanted || empty_args) {
    defaultGetoptPrinter(
        "Multimonitor - sample information about system and processes.",
        helpInformation.options);
    if (helpInformation.helpWanted) {
      return 0;
    }
    return 1;
  }

  writefln!"# Arguments: %s"(args_copy);
  // TODO(baryluk): Add username, hostname, CPU and Memory overview for
  // referencing.

  const interval = dur!"msecs"(interval_msec);
  const duration = duration_sec != duration_sec.max ? dur!"seconds"(duration_sec) : Duration.max;
  const async_delay = dur!"msecs"(async_delay_msec);

  auto amdgpu_hwmon_dir = gpu_stuff != GpuStuff.none ? searchHWMON("amdgpu") : null;
  auto gpu_stat_reader = amdgpu_hwmon_dir !is null ? async_wrap(new GpuStatReader(amdgpu_hwmon_dir), async_delay) : null;

  // For basic I/O stats.
  auto vmstat_reader = io != IoStuff.none ? new VmStatReader(io) : null;

  foreach (process_name; process_names) {
    bool found = false;
    do {
      int[] pids0 = find_process_by_name(process_name);
      if (pids0.length == 0) {
        stderr.writefln!"# Waiting for process %s"(process_name);
        Thread.sleep(interval);
        continue;
      }
      stderr.writefln!"# For process name %s found pids: %s"(process_name, pids0);
      pids ~= pids0;
      found = true;
    } while (!found);
  }

  import std.process : Pid, spawnShell;

  Pid[] pids_to_wait;
  foreach (ref sub_process; sub) {
    // This is a quick and dirty method, but should do the job.
    // BTW. spawnShell takes care of closing all other file descriptors,
    // before executing the sub in the shell in forked process.
    //
    // TODO(baryluk): Possible improvement might be to close
    // stdin too for all spawned sub-processes.
    auto pid = spawnShell(sub_process);
    stderr.writefln!"# Spawned %s for --sub: %s"(pid.processID, sub_process);
    pids_to_wait ~= pid;
    // pids ~= pid.processID;
  }

  PidProcStatReader[] pid_readers = pids.map!(x => new PidProcStatReader(x)).array ~ pids_to_wait.map!(x => new PidProcStatReader(x.processID, x)).array;

  // TODO(baryluk): Support tids. pid and tid are the same from Linux kernel
  // perspective, but `/proc/<pid>/{sched,}stat` sum all threads. To access specific
  // thread only one needs to do `/proc/<pid>/task/<tid>/{sched,}stat`, which
  // require a bit of prod file system traversal to find them out.

  PidProcStat[] prev;
  prev.length = pid_readers.length;
  PidProcStat[] next;
  next.length = pid_readers.length;

  // TODO(baryluk): It would be nice to preserve relative order when varoius options are mixed.
  ExecReader[] exec_readers = exec.map!(x => new ExecReader(x)).array;
  auto exec_async_readers = exec_async.map!(x => async_wrap(new ExecReader(x), async_delay)).array;
  auto pipe_readers = pipe.map!(x => async_wrap(new PipeReader(x), Duration.zero)).array;

  // At the moment, we can't append all to the same array, because async_wrap
  // returns a different type, and we don't have dynamic interfaces to support
  // inheritance / virtual dispatch.

  ExecResult[] exec_prev;
  exec_prev.length = exec_readers.length;
  ExecResult[] exec_next;
  exec_next.length = exec_readers.length;

  ExecResult[] exec_async_prev;
  exec_async_prev.length = exec_async_readers.length;
  ExecResult[] exec_async_next;
  exec_async_next.length = exec_async_readers.length;

  ExecResult[] pipe_prev;
  pipe_prev.length = pipe_readers.length;
  ExecResult[] pipe_next;
  pipe_next.length = pipe_readers.length;



version (proc_stat_method) {
  const ticks_per_second = TickPerSecond();

  stderr.writefln!"# ticks_per_second: %d"(ticks_per_second);

  // 100 ticks per second. 0.01 per tick.
  // 200ms.
  // 20 ticks.
  // 1 tick error corresponds to 1/20, aka 5% error.
  // Warn about such things.
  const double ticks_per_interval = interval.total!("nsecs") * 1.0e-9 * ticks_per_second;
  if (ticks_per_interval <= 25) {
    stderr.writefln!"# With interval %s and %d ticks/s, expect CPU%% error of ±%.1f%%"(interval, ticks_per_second, 100.0 / ticks_per_interval);
  }
  if (ticks_per_interval <= 5) {
    stderr.writefln!"# Too few ticks per interval ( %f ) for reliable and accurate measurements"(ticks_per_interval);
    return 1;
  }
}

/+
user@debian:~/vps1/home/baryluk/multimonitor$ ./a.out $(pidof stress-ng-cpu) 1 2
                                       stress-ng-cpu                       systemd
                              stress-ng-cpu        |     stress-ng-cpu        |
                     stress-ng-cpu        |        | 1234567890123456|        |     kthreadd
                                 |        |        |        |        |        |        |
                              1004922  1004921  1004920  1004919  1004918        1        2
           TIME      RELTIME     CPU%     CPU%     CPU%     CPU%     CPU%     CPU%     CPU%
  292961.800403     0.022971    0.00%    0.00%    0.00%    0.00%    0.00%    0.00%    0.00%
  292962.266001     0.488569  100.94%  100.94%  100.94%   98.79%  100.93%    0.00%    0.00%



                            |1234567890123456|   stress-ng-cpu |
                            |        1004922 |         1004920 |
           TIME|     RELTIME|    CPU%    RSS%|    CPU%     RSS%|
  292962.266001     0.488569  100.94%   3.94%  100.94%   98.79%  100.93%

# Other major things we might want to look at per process, are Total
# threads, runnable threads, disk io, network io, FPS, cummulative frame
# number, API used for GFX, shared memory (in MB), RSS / CODE in MB.
#
# There might be other things too, but less important.
#
# Additionally for scripting we might want to drop the "%". As this it easier
# to use in gnuplot, and spreedsheets in general.

+/


  // Read prevs, so we don't start with first row being from the start / boot.
  // This also reads process names, so we can display them in header.
  foreach (i, pid_reader; pid_readers) {
    prev[i] = pid_reader.read();
  }

  foreach (i, exec_reader; exec_readers) {
    exec_prev[i] = exec_reader.read();
  }
  foreach (i, exec_async_reader; exec_async_readers) {
    exec_async_prev[i] = exec_async_reader.read();
  }
  foreach (i, pipe_reader; pipe_readers) {
    pipe_prev[i] = pipe_reader.read();
  }

  const unix_epoch = UnixEpoch();

  GpuStat gpu_prev, gpu_next;
  VmStat vmstat_prev, vmstat_next;

  import std.array : Appender, appender;
  // Appender!string w;
  //auto w = appender!string();
  auto w = appender!(char[])();
  w.reserve(4096);

  struct TimestampStat {
    SysTime scrape_realtime;
    Duration absolute_time;
    Duration relative_time;
  }

  struct TimestampFormatter {
    //static
    string[] header(bool human_friendly) {
      import std.format : format;
      string[] ret;
      if (time_mode == TimeMode.absolute || time_mode == TimeMode.all) {
        if (utc_nice) {
          ret ~= ["%26s|DATETIME-UTC|Date and time in ISO 8601 format in UTC timezone"];
        } else {
          ret ~= ["%17s|UNIX-TIME|Unix time - number of seconds from Unix Epoch (1970-01-01 00:00:00 \"UTC\"), minus leap seconds"];
        }
      }
      if (time_mode == TimeMode.boottime || time_mode == TimeMode.all) {
        ret ~= ["%15s|TIME|Monotonic time, i.e. from system boot time, in seconds"];
      }
      if (time_mode == TimeMode.relative || time_mode == TimeMode.all) {
        ret ~= ["%12s|RELTIME|Monotonic time, from start of the multimonitor monitoring, in seconds"];
      }
      return ret;
    }

    import std.array : Appender;

    //static
    final void format(ref Appender!(char[]) appender, const ref TimestampStat prev, const ref TimestampStat next, bool human_friendly) {
      import std.format : formattedWrite;
      final switch (time_mode) {
      case TimeMode.all:
        if (utc_nice) {
          appender.formattedWrite!"%26s %15.6f %12.6f"(
              toISO_UTC(next.scrape_realtime),
              next.absolute_time.total!"usecs" * 1.0e-6,
              next.relative_time.total!"usecs" * 1.0e-6);
        } else {
          // We don't call this "seconds_from_epoch", or "time_from_epoch",
          // because of how leap seconds are handled by Unix time.
          const unix_time = (next.scrape_realtime - unix_epoch).split!("seconds", "usecs")();
          // For human friendly output we use 10.6, it should work well up to a
          // year 2286.
          //
          // Unix time days ignores leap seconds, and each day has exactly
          // 86400 seconds.
          //
          // Manual pages for `clock_gettime` and `date` simply lie by omission,
          // saying CLOCK_REALTIME is "seconds from Epoch", which is not true.
          // Similarly many webpages, tutorials, calculators and time pages,
          // also use incorrect definitions.
          //
          // Even POSIX standards sometimes use "Seconds Since the Epoch",
          // but this phrase is just a coloquialism, and understood as an
          // approximation of actual seconds since the Epoch.
          //
          // CLOCK_TAI probably is real "seconds from Epoch", but that is not
          // what everyone uses.
          appender.formattedWrite!"%10d.%06d %15.6f %12.6f"(
              unix_time.seconds, unix_time.usecs,
              next.absolute_time.total!"usecs" * 1.0e-6,
              next.relative_time.total!"usecs" * 1.0e-6);
        }
        return;
      case TimeMode.absolute:
        if (utc_nice) {
          appender.formattedWrite!"%26s"(toISO_UTC(next.scrape_realtime));
        } else {
          const unix_time = (next.scrape_realtime - unix_epoch).split!("seconds", "usecs")();
          appender.formattedWrite!"%10d.%06d"(unix_time.seconds, unix_time.usecs);
        }
        return;
      case TimeMode.boottime:
        appender.formattedWrite!"%15.6f"(next.absolute_time.total!"usecs" * 1.0e-6);
        return;
      case TimeMode.relative:
         appender.formattedWrite!"%12.6f"(next.relative_time.total!"usecs" * 1.0e-6);
         return;
      }
      assert(0);
    }
  }

  TimestampFormatter timestamp_formatter;

  auto header = (){
    import std.algorithm.searching : findSplit;

    // Because we want columns to be actually narrow (to save space and parsing, and to fit on screen easily),
    // but the header things can be wide, spread things like names into multiple rows.
    const string[] timestamp_headers = timestamp_formatter.header(human_friendly);
/++
    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 2) {
        writef(" %-26s", pid_reader.name);  // We use 3*8+2 width.
      }
    }
    writeln();

    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 1) {
        writef(" |  %-16s", pid_reader.name);
      }
    }
    writeln();

    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 0) {
        writef(" %-16s |        |", pid_reader.name);
      }
    }
    writeln();


    foreach (i, ref pid_reader; pid_readers) {
      // writef(" %-8s", "⇩");  // phobos things the arrow is 2-3 characters long, and incorrect calculates the width, making it crawl left.
      writef(" %-8s", "|");
    }
    writeln();

    foreach (i, pid; pids) {
      writef(" %8d", pid);  // Pids can be wide, often 7 digits, but should be fine.
    }
    writeln();
++/

    const string[] gpu_headers = gpu_stat_reader ? gpu_stat_reader.header(human_friendly) : [];

    const string[] vmstat_headers = vmstat_reader ? vmstat_reader.header(human_friendly) : [];

    void process_header_data(const string[] headers) {
      foreach (i, s; headers) {
        auto ss = s.findSplit("|");
        writef!" "();
        writef(ss[0], ss[2].findSplit("|")[0]);
      }
    }

    foreach (i, s; timestamp_headers) {
      auto ss = s.findSplit("|");
      if (i) {
        writef!" "();
      } else {
        // writef!"# "();
        // TODO: We might need to offset back the first column header,
        // to make this work.
      }
      writef(ss[0], ss[2].findSplit("|")[0]);
    }
    process_header_data(gpu_headers);
    process_header_data(vmstat_headers);
    foreach (i, ref pid_reader; pid_readers) {
      process_header_data(pid_reader.header(human_friendly));
    }
    foreach (i, ref exec_reader; exec_readers) {
      process_header_data(exec_reader.header(human_friendly));
    }
    foreach (i, ref exec_async_reader; exec_async_readers) {
      process_header_data(exec_async_reader.header(human_friendly));
    }
    foreach (i, ref pipe_reader; pipe_readers) {
      process_header_data(pipe_reader.header(human_friendly));
    }

    writeln();
  };

  header();


  foreach (scrape_time, scrape_realtime, absolute_time, relative_time, good; time_loop(interval, verbose)) {
    foreach (i, pid_reader; pid_readers) {
      next[i] = pid_reader.read();
    }

    foreach (i, exec_reader; exec_readers) {
      exec_next[i] = exec_reader.read();
    }
    foreach (i, exec_async_reader; exec_async_readers) {
      exec_async_next[i] = exec_async_reader.read();
    }
    foreach (i, pipe_reader; pipe_readers) {
      pipe_next[i] = pipe_reader.read();
    }
    // writefln("%20s usec: %s usec", (scrape_time - start_time).total!"usecs", (next[0].timestamp - prev[0].timestamp).total!"usecs");

    if (gpu_stat_reader) {
      gpu_next = gpu_stat_reader.read();
    }

    if (vmstat_reader) {
      vmstat_next = vmstat_reader.read();
    }

    if (good) {  // If there was a large jump in expected time (i.e. we got some signal, system was susspended, or we got SIGSTOP, or tracing), don't compute differences.
      // TODO: We can still show the RSS tho.

      // recent_target_arrival_errors[1..$] = recent_target_arrival_errors[0 .. $-1];
      // recent_target_arrival_errors[0] = target_arrival_error;

      // writefln("%20s usec: %s usec target error", (scrape_time - start_time).total!"usecs", target_arrival_error.total!"usecs");

      w.clear();

      {
        TimestampStat time_prev;
        TimestampStat time_next;
        time_next.scrape_realtime = scrape_realtime;
        time_next.absolute_time = absolute_time;
        time_next.relative_time = relative_time;
        timestamp_formatter.format(w, time_prev, time_next, human_friendly);
      }

      if (gpu_stat_reader) {
        w.put(' ');
        gpu_stat_reader.format(w, gpu_prev, gpu_next, human_friendly);
      }

      if (vmstat_reader) {
        w.put(' ');
        vmstat_reader.format(w, vmstat_prev, vmstat_next, human_friendly);
      }

      foreach (i, pid_reader; pid_readers) {
        w.put(' ');
        pid_reader.format(w, prev[i], next[i], human_friendly);
      }

      foreach (i, exec_reader; exec_readers) {
        w.put(' ');
        exec_reader.format(w, exec_prev[i], exec_next[i], human_friendly);
      }

      foreach (i, exec_async_reader; exec_async_readers) {
        w.put(' ');
        exec_async_reader.format(w, exec_async_prev[i], exec_async_next[i], human_friendly);
      }

      foreach (i, pipe_reader; pipe_readers) {
        w.put(' ');
        pipe_reader.format(w, pipe_prev[i], pipe_next[i], human_friendly);
      }

      writeln(w[]);
      if (!buffered) {
        import std.stdio : stdout;
        stdout.flush();
      }
    } else {
      // writefln!("jump detected from %d to %d")(prev_j, j);
    }

    gpu_prev = gpu_next;
    vmstat_prev = vmstat_next;
    foreach (i, pid; pids) {
      prev[i] = next[i];
    }
    foreach (i, exec_reader; exec_readers) {
      exec_prev[i] = exec_next[i];
    }
    foreach (i, exec_async_reader; exec_async_readers) {
      exec_async_prev[i] = exec_async_next[i];
    }
    foreach (i, pipe_reader; pipe_readers) {
      pipe_prev[i] = pipe_next[i];
    }

    if (duration != duration.max && relative_time >= duration) {
      break;
    }
  }

  if (gpu_stat_reader) {
    gpu_stat_reader.stop();
  }
  foreach (i, exec_async_reader; exec_async_readers) {
    exec_async_reader.stop();
  }

  {
    import std.process : kill, tryWait, wait;
    import core.sys.posix.signal : SIGTERM, SIGKILL;
    // Send SIGTERM to all sub processes.
    foreach (ref pid; pids_to_wait) {
      // We need to check the process liveness, because it is possible other
      // thread already encountered, so error or the subprocess ended, and
      // ProcStatReader already waited on it (to determine if it should have
      // 0.0% or nan% CPU).
      auto waited = tryWait(pid);
      if (!waited.terminated) {
        stderr.writefln!"# Sending SIGTERM to not yet terminated pid %s"(pid.processID);
        kill(pid, SIGTERM);  // Default.
      }
    }
    Thread.sleep(dur!"msecs"(50));
    int processes_still_running = 0;
    foreach (ref pid; pids_to_wait) {
      auto waited = tryWait(pid);
      if (!waited.terminated) {
         processes_still_running++;
      }
    }
    if (processes_still_running > 0) {
      stderr.writefln!"# Still %d sub-processes running, waiting a bit..."(processes_still_running);
      Thread.sleep(dur!"msecs"(80));
      foreach (ref pid; pids_to_wait) {
        stderr.writefln!"# Sending SIGKILL to not yet terminated pid %s"(pid.processID);
        kill(pid, SIGKILL);
      }
      foreach (ref pid; pids_to_wait) {
        stderr.writefln!"# Waiting for pid %s"(pid.processID);
        wait(pid);
      }
    }
  }

  foreach (i, pipe_reader; pipe_readers) {
    pipe_reader.stop();
  }

  return 0;
}

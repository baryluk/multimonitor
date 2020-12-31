module multimonitor;

//version = NoAutodecodeStrings;

//import std.range : take;
//import std.array : array;

import types;
import util;
import time;
import hwmon;
import gpu;
import cpu;
import proc;

import async : async_wrap;




int main(string[] args) {
  import std.algorithm : map;
  import std.conv : to;
  import std.stdio : writefln, writef, writeln;
  import core.thread : Thread;
  import core.time : dur;
  import std.array : array;
  import std.datetime : Clock;

  import std.getopt;

  uint interval_msec = 200;
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

  bool temp;
  bool sched;
  bool vm;
  bool interrupts;
  bool io;
  bool net;
  string[] mangohud_fps;

  enum GpuStuff { none, min, max, }
  GpuStuff gpu_stuff;

  bool auto_output;
  bool utc_nice;
  bool human_friendly = true;
  bool verbose;

  arraySep = ",";  // defaults to "", separation by whitespace

  const bool empty_args = (args.length <= 1);

  // Note: Please do not add single letter options! They are harder to read,
  // and can make extending options in the future harder due to conflicts.
  auto helpInformation = getopt(
    args,
    std.getopt.config.caseSensitive,
    "interval_msec",      "Target interval for main metric sampling and output. (default: 200ms)",   &interval_msec,
    "process",            "List of process names to monitor", &process_names,
    "pids",               "List of process pids to monitor", &pids,
    "process_map",        "Assign short names to processes, i.e. a=firefox,b=123", &process_map,
    "temp",               "CPU temperature", &temp,
    "sched",              "CPU scheduler details", &sched,
    "vm",                 "Virtual memory subsystem", &sched,
    "interrupts",         "Interrupts details", &interrupts,
    "io",                 "System-wide IO details", &interrupts,
    "net",                "System-wide networking metrics", &interrupts,
    "gpu",                "Gather GPU stats. Available: none, min, max", &gpu_stuff,
    "mangohud_fps",       "Gather FPS information for given processes using MangoHud RPC", &mangohud_fps,
    "wait_for_all",       "Wait until all named processes are up", &wait_for_all,
    "find_new_when_dead", "If the named process is dead, try searching again", &find_new_when_dead,
    "exit_when_dead",     "Stop collecting metrics and exit, when any of requested pids exits too", &exit_when_dead,
    "sum_all_matching",   "For named processes, sum all matching processes metrics (sum CPU, smart memory sum)", &sum_all_matching,
    "auto_output",        "Automatically create timestamped output file in current working directory with data, instead of using standard output", &auto_output,
    "utc_nice",           "Show first column as ISO 8601 formated date and time in UTC timezone. Otherwise use seconds since Unix epoch.", &utc_nice,
    "H|human_friendly",   "Use human friendly (pretty) but still fixed units (default: true)", &human_friendly,
    "verbose",            "Show timeing loop debug info", &verbose
  );

  if (helpInformation.helpWanted || empty_args) {
    defaultGetoptPrinter(
        "Multimonitor - sample information about system and processes.",
        helpInformation.options);
    if (helpInformation.helpWanted) {
      return 0;
    }
    return 1;
  }

  const interval = dur!"msecs"(interval_msec);

  auto amdgpu_hwmon_dir = gpu_stuff != GpuStuff.none ? searchHWMON("amdgpu") : null;
  auto gpu_stat_reader = amdgpu_hwmon_dir !is null ? async_wrap(new GpuStatReader(amdgpu_hwmon_dir)) : null;

  foreach (process_name; process_names) {
    bool found = false;
    do {
      int[] pids0 = find_process_by_name(process_name);
      if (pids0.length == 0) {
        writefln("Waiting for process %s", process_name);
        Thread.sleep(interval);
        continue;
      }
      writefln("For process name %s found pids: %s", process_name, pids0);
      pids ~= pids0;
      found = true;
    } while (!found);
  }

  //PidProcStatReader[] pid_readers = pids.map(x => new PidProcStatReader(x));
  PidProcStatReader[] pid_readers = pids.map!(x => new PidProcStatReader(x)).array;

  const ticks_per_second = TickPerSecond();

  writefln("ticks_per_second: %d", ticks_per_second);

  PidProcStat[] prev;
  prev.length = pids.length;
  PidProcStat[] next;
  next.length = pids.length;

//  100 ticks per second. 0.01 per tick.
//  200ms.
//  20 ticks.

  const double ticks_per_interval = interval.total!("nsecs") * 1.0e-9 * ticks_per_second;
  if (ticks_per_interval <= 25) {
    //writefln!"With interval %s and %.1f ticks/s, expect CPU%% error of +/- %f%%"(interval, 100.0 / ticks_per_second);  // Not detected by ldc or dmd as error. Too few arguments.
    writefln!"With interval %s and %d ticks/s, expect CPU%% error of +/- %.1f%%"(interval, ticks_per_second, 100.0 / ticks_per_interval);
  }
  if (ticks_per_interval <= 5) {
    writefln!"Too few ticks per interval ( %f ) for reliable and accurate measurements"(ticks_per_interval);
    return 1;
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


  auto header = (){
    // Because we want columns to be actually narrow (to save space and parsing, and to fit on screen easily),
    // but the header things can be wide, spread things like names into multiple rows.
    if (utc_nice) {
      writef("%26s %15s %12s", "", "", "");
    } else {
      writef("%18s %15s %12s", "", "", "");
    }
    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 2) {
        writef(" %-26s", pid_reader.name);  // We use 3*8+2 width.
      }
    }
    writeln();

    if (utc_nice) {
      writef("%26s %15s %12s", "", "", "");
    } else {
      writef("%18s %15s %12s", "", "", "");
    }
    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 1) {
        writef(" |  %-16s", pid_reader.name);
      }
    }
    writeln();

    if (utc_nice) {
      writef("%26s %15s %12s", "", "", "");
    } else {
      writef("%18s %15s %12s", "", "", "");
    }
    foreach (i, ref pid_reader; pid_readers) {
      if (i % 3 == 0) {
        writef(" %-16s |        |", pid_reader.name);
      }
    }
    writeln();


    if (utc_nice) {
      writef("%26s %15s %12s", "", "", "");
    } else {
      writef("%18s %15s %12s", "", "", "");
    }
    foreach (i, ref pid_reader; pid_readers) {
      // writef(" %-8s", "⇩");  // phobos things the arrow is 2-3 characters long, and incorrect calculates the width, making it crawl left.
      writef(" %-8s", "|");
    }
    writeln();

    if (utc_nice) {
      writef("%26s %15s %12s", "", "", "");
    } else {
      writef("%18s %15s %12s", "", "", "");
    }
    foreach (i, pid; pids) {
      writef(" %8d", pid);  // Pids can be wide, often 7 digits, but should be fine.
    }
    writeln();

    if (utc_nice) {
      writef("%26s %15s %12s", "DATETIME UTC", "TIME", "RELTIME");
    } else {
      writef("%18s %15s %12s", "SECONDS-FROM-EPOCH", "TIME", "RELTIME");
    }
    foreach (i, pid; pids) {
      writef(" %7s%% %10s", "CPU", "RSS");
    }
    writeln();
  };

  header();

  // Read prevs, so we don't start with first row being from the start / boot.
  // This also reads process names, so we can display them in header.
  foreach (i, pid_reader; pid_readers) {
    prev[i] = pid_reader.read();
  }

  const unix_epoch = UnixEpoch();

  GpuStat gpu_prev, gpu_next;

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
      if (utc_nice) {
        string h = format!"%26s %15s %12s"("DATETIME UTC", "TIME", "RELTIME");
        return ["DATETIME UTC|Date and time in ISO 8601 format in UTC timezone",
                "TIME|Monotonic time, i.e. from system boot time, in seconds",
                "RELTIME|Monotonic time, from start of the multimonitor monitoring, in seconds"];
      } else {
        string h = format!"%18s %15s %12s"("SECONDS-FROM-EPOCH", "TIME", "RELTIME");
        return ["SECONDS-FROM-EPOCH|Seconds from Unix Epoch (1970-01-01 00:00)",
                "TIME|Monotonic time, i.e. from system boot time, in seconds",
                "RELTIME|Monotonic time, from start of the multimonitor monitoring, in seconds"];
      }
    }

    import std.array : Appender;

    //static
    void format(ref Appender!(char[]) appender, const ref TimestampStat prev, const ref TimestampStat next, bool human_friendly) {
      import std.format : formattedWrite;
      if (utc_nice) {
        appender.formattedWrite!"%26s %15.6f %12.6f"(
            toISO_UTC(next.scrape_realtime),
            next.absolute_time.total!"usecs" * 1.0e-6,
            next.relative_time.total!"usecs" * 1.0e-6);
      } else {
        const time_from_epoch = (next.scrape_realtime - unix_epoch).split!("seconds", "usecs")();
        appender.formattedWrite!"%11d.%06d %15.6f %12.6f"(
            time_from_epoch.seconds, time_from_epoch.usecs,
            next.absolute_time.total!"usecs" * 1.0e-6,
            next.relative_time.total!"usecs" * 1.0e-6);
      }
    }
  }

  TimestampFormatter timestamp_formatter;

  foreach (scrape_time, scrape_realtime, absolute_time, relative_time, good; time_loop(interval, verbose)) {
    foreach (i, pid_reader; pid_readers) {
      next[i] = pid_reader.read();
    }
    // writefln("%20s usec: %s usec", (scrape_time - start_time).total!"usecs", (next[0].timestamp - prev[0].timestamp).total!"usecs");

    if (gpu_stat_reader) {
      gpu_next = gpu_stat_reader.read();
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

      foreach (i, pid; pids) {
        w.put(' ');
        pid_readers[i].format(w, prev[i], next[i], human_friendly);
      }

      writeln(w[]);
    } else {
      // writefln!("jump detected from %d to %d")(prev_j, j);
    }

    gpu_prev = gpu_next;
    foreach (i, pid; pids) {
      prev[i] = next[i];
    }
  }

  //return 0;
  assert(0);
}

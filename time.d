public import core.time : MonoTimeImpl, MonoTime, Duration, dur, ClockType;

//version (Linux) {
alias MyMonoTime = MonoTimeImpl!(ClockType.normal);
//alias MyMonoTime = MonoTimeImpl!(ClockType.raw);
//alias CoarseMonoTime = MonoTimeImpl!(ClockType.coarse);
//}

auto time_avg(T)(T t1, T t2) {
  assert(t1 <= t2);
  return t1 + (t2 - t1) / 2;
}

import std.datetime : Clock;

public import core.sys.posix.time : clockid_t, timespec;
public import core.sys.posix.sys.types : pid_t;
extern(C) int clock_getcpuclockid(pid_t, clockid_t*) nothrow @nogc;
extern(C) int clock_nanosleep(clockid_t, int, in timespec*, timespec*) nothrow @nogc;

ulong timespec_to_usecs(const timespec ts) pure {
  return ts.tv_sec * 1000000uL + ts.tv_nsec / 1000;
}

auto TickPerSecond() @nogc {
  import core.sys.posix.unistd : sysconf, _SC_CLK_TCK;
  return sysconf(_SC_CLK_TCK);
}

auto UnixEpoch() /*pure*/ {
  import std.datetime : SysTime, DateTime, UTC;
  return SysTime(DateTime(1970, 1, 1), UTC());
}

// Our own version of toISOString. because SysTime.toISOExtString() is kind of broken
// (i.e. it can have from 0 to 8 fractional seconds, with or without
// decimal dot), which makes it useless for a lot of things.
//
// See https://issues.dlang.org/show_bug.cgi?id=21507 for details.
public import std.datetime : SysTime;
string toISO_UTC(const SysTime t) {
  import std.datetime : UTC;
  debug assert(t.tz == UTC());
  const string iso1 = t.toISOExtString();
  import std.conv : to, toChars;
  import std.range : /*padRight,*/ padLeft;
  import std.array : array;

  // 2020-12-27T04:15:07.3831892Z

  // We are going to assume that year is positive and 4 digits.
  assert(t.year >= 1900);
  assert(t.year <= 9999);
  const string subsecond = iso1[19 .. $-1];
  int usecs = 0;
  if (subsecond.length == 0) {
    usecs = 0;
  } else {
    assert(subsecond[0] == '.');
    // import std.string : representation
    char[7] hnsecs_string = void;
    foreach (i, ref char c; hnsecs_string) {
      if (i < subsecond.length - 1) {
        c = subsecond[i + 1];
      } else {
        c = '0';
      }
    }

    // const hnsec = to!int(subsecond[1 .. $].padRight('0', 7).array);
    const hnsec = to!int(hnsecs_string[]);
    usecs = hnsec / 10;
  }
  return iso1[0 .. 19] ~ "." ~ cast(string)(usecs.toChars.padLeft('0', 6).array);
}

bool mysleep(const MyMonoTime when) {
  import std.stdio : stderr;

  const MyMonoTime now = MyMonoTime.currTime();
  if (when <= now) {
    stderr.writeln("# Execution too slow (--exec subprocess too slow?), retrying loop");
    return false;
  }

  import core.time : Duration;
  const Duration sleep_dur = when - now;

  //Thread.sleep(sleep_dur);  // This is wrong. This is using CLOCK_REALTIME by default. Posix kind of says to use CLOCK_REALTIME for nanoclock, but also says not ignore setting the realtime clock. LOL. Linux uses instead MONOTONIC.
  // But in strace I see clock_nanosleep REALTIME. 

  import core.stdc.errno : EINTR;
  import core.sys.posix.signal;
  import core.sys.posix.time : timespec, CLOCK_MONOTONIC;

  timespec request = void;
  timespec remain = void;
  sleep_dur.split!("seconds", "nsecs")(request.tv_sec, request.tv_nsec);
  //import std.stdio : writefln;
  //writefln("Will sleep for: sec: %s , nsec: %s , because now = %s and when = %s", request.tv_sec, request.tv_nsec, now, when);
  if (sleep_dur.total!"seconds" > request.tv_sec.max) {
    request.tv_sec  = request.tv_sec.max;
  }
  assert(request.tv_nsec >= 0);
  assert(request.tv_nsec <= 999_999_999);
  while (true) {
    const int ret = clock_nanosleep(CLOCK_MONOTONIC, /*flags=*/0, &request, &remain);
    if (!ret) {
      return true;  // likely
    }
    // clock_nanosleep returns error directly, instead of setting errno.
    if (ret != EINTR) {
      assert(0, "Unable to sleep for the specified duration");
    }
    request = remain;
  }

/++
  timespec request = void;
  when.split!("seconds", "nsecs")(request.tv_sec, request.tv_nsec);
  if (when.total!"seconds" > request.tv_sec.max) {
    request.tv_sec  = request.tv_sec.max;
  }
  while (true) {
    const int ret = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &request, null);
    if (!ret) {
      return true;  // likely
    }
    if (ret != EINTR) {
      assert(0, "Unable to sleep for the specified duration");
    }
  }
++/
}

auto time_loop(Duration interval, bool verbose = false) {
  struct TimeLooper {
    int opApply(int delegate(const(MyMonoTime) timestamp_, const(SysTime) scrape_realtime_, const(Duration), const(Duration), bool good_) loop_body) {
      long j = 0;
      Duration[4] recent_target_arrival_errors;

      long prev_j = -5;
      long ignored = -1;

      const unix_epoch = UnixEpoch();

      const MyMonoTime start_time = MyMonoTime.currTime();

      import std.stdio : writeln;
      debug import std.stdio : writef, writefln;


      while (true) {
        MyMonoTime scrape_time = MyMonoTime.currTime();  // Arbitrary, but accurate time.

        // Detect time jumps (suspends, SIGSTOP, breakpoint, etc.)
        const new_j_guess = (scrape_time - start_time) / interval;
        if (new_j_guess > j + 1) {
          writeln();
          j = new_j_guess;
          ignored = -1;
        }

        ignored++;

        import std.datetime : UTC;
        const scrape_realtime = Clock.currTime!(ClockType.coarse)(UTC());  // Realtime. I.e. UNIX epoch style.
        // writefln("%s", CoarseMonoTime.currTime);
        // writefln("%s", MonoTime.currTime);
        // writefln("%s  %20s", scrape_realtime.toISOExtString(), scrape_realtime.toUnixTime!long);  // This only returns seconds. We force long, instead of time_t, because time_t can be 32-bit!

        const target_arrival_error = scrape_time - (start_time + j * interval);

        const bool good = (j - prev_j <= 1 && ignored > 0);

        const absolute_time = (scrape_time - MyMonoTime.zero);
        const relative_time = (scrape_time - start_time);

        int ret = loop_body(scrape_time, scrape_realtime, absolute_time, relative_time, good);
        if (ret) {
          break;
        }

        prev_j = j;

        j++;

        // A small correction to sleep little less to compensate for overheads,
        // in the Thread.sleep and kernel itself.
        //const correction_offset = dur!"usecs"(20);
        Duration recent_target_arrival_errors_total;
        foreach (i, ref recent_target_arrival_error; recent_target_arrival_errors) {
          recent_target_arrival_errors_total += recent_target_arrival_error;
        }

        //const correction_offset = dur!"usecs"(20) + target_arrival_error / 3;  // 20usec + 1/3 of the arrival error. this is to ensure stability.

        const correction_offset = dur!"usecs"(1) + target_arrival_error / 2;  // 20usec + 1/3 of the arrival error. this is to ensure stability.

    //    writefln("   recent average of errors: %s", recent_target_arrival_errors_total / recent_target_arrival_errors.length);

    //    const correction_offset = dur!"usecs"(10) + (recent_target_arrival_errors_total / recent_target_arrival_errors.length) * 2;

        // writefln("%s usec processing time", end_time - scrape_time);
        //Thread.sleep(interval - (end_time - scrape_time) - correction_offset);  // This is wrong. This is using CLOCK_REALTIME by default.
        // TODO: Compensate for the long term drift.

        const MyMonoTime next_scrape_time_target = start_time + j * interval - correction_offset;
        if (!mysleep(next_scrape_time_target)) {
          const MyMonoTime now = MyMonoTime.currTime();
          j = 1 + (now - start_time) / interval;
          // This can still be improved futher a bit.
          ignored = -1;
        }
      }

      // return ret;
      return 0;
    }
  }

  // return TimeLooper(interval);
  return TimeLooper();
}

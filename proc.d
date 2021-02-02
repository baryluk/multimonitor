import types;
import util;
import time;

/*
user@debian:~/vps1/home/baryluk/multimonitor$ ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0 167868 11920 ?        Ss   Dec23   0:59 /lib/systemd/systemd --system --deserialize 129
root           2  0.0  0.0      0     0 ?        S    Dec23   0:00 [kthreadd]
root         219  0.0  0.0      0     0 ?        SN   Dec23   0:03 [khugepaged]
user      653251  0.0  0.0   5600   900 pts/8    S+   Dec25   0:00 mangohud_server
user      653252  0.0  0.0  10372  7052 pts/9    Ss+  Dec25   0:00 /bin/bash
user      673349  0.0  0.0 398444 39480 ?        Sl   Dec25   1:42 /usr/lib/mate-applets/mate-cpufreq-applet
root      724105  0.0  0.0      0     0 ?        I<   Dec25   0:00 [kworker/u259:0-hci0]
root      724106  0.0  0.0 236260  6288 ?        Ssl  Dec25   0:03 /usr/libexec/accounts-daemon
root      896477  0.0  0.0 174748 13652 ?        Ssl  Dec26   0:00 /usr/sbin/cups-browsed
user      895825  0.0  0.0 4591396 52428 ?       Sl   Dec26   0:00 /opt/google/chrome/chrome --type=renderer --field-trial-handle=15833414874564887865,369192937199794,131072 --lang=en-US --n
user     1000666  0.0  0.0   9592  3300 pts/1    R+   01:16   0:00 ps aux



PROCESS STATE CODES
       Here are the different values that the s, stat and state output specifiers (header "STAT" or "S") will display to describe the state of a process:

               D    uninterruptible sleep (usually IO)
               I    Idle kernel thread
               R    running or runnable (on run queue)
               S    interruptible sleep (waiting for an event to complete)
               T    stopped by job control signal
               t    stopped by debugger during the tracing
               W    paging (not valid since the 2.6.xx kernel)
               X    dead (should never be seen)
               Z    defunct ("zombie") process, terminated but not reaped by its parent

       For BSD formats and when the stat keyword is used, additional characters may be displayed:

               <    high-priority (not nice to other users)
               N    low-priority (nice to other users)
               L    has pages locked into memory (for real-time and custom IO)
               s    is a session leader
               l    is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)
               +    is in the foreground process group
*/




/*
              (10) minflt  %lu
                     The number of minor faults the process has made which have not required loading a memory page from disk.

              (11) cminflt  %lu
                     The number of minor faults that the process's waited-for children have made.

              (12) majflt  %lu
                     The number of major faults the process has made which have required loading a memory page from disk.

              (13) cmajflt  %lu
                     The number of major faults that the process's waited-for children have made.

              (14) utime  %lu
                     Amount of time that this process has been scheduled in user mode, measured in clock ticks (divide by sysconf(_SC_CLK_TCK)).  This includes guest time, guest_time (time spent running  a
                     virtual CPU, see below), so that applications that are not aware of the guest time field do not lose that time from their calculations.

              (15) stime  %lu
                     Amount of time that this process has been scheduled in kernel mode, measured in clock ticks (divide by sysconf(_SC_CLK_TCK)).

              (16) cutime  %ld
                     Amount  of time that this process's waited-for children have been scheduled in user mode, measured in clock ticks (divide by sysconf(_SC_CLK_TCK)).  (See also times(2).)  This includes
                     guest time, cguest_time (time spent running a virtual CPU, see below).

              (17) cstime  %ld
                     Amount of time that this process's waited-for children have been scheduled in kernel mode, measured in clock ticks (divide by sysconf(_SC_CLK_TCK)).

              (18) priority  %ld
                     (Explanation for Linux 2.6) For processes running a real-time scheduling policy (policy below; see sched_setscheduler(2)), this is the negated scheduling priority, minus one; that  is,
                     a  number  in the range -2 to -100, corresponding to real-time priorities 1 to 99.  For processes running under a non-real-time scheduling policy, this is the raw nice value (setprior‐
                     ity(2)) as represented in the kernel.  The kernel stores nice values as numbers in the range 0 (high) to 39 (low), corresponding to the user-visible nice range of -20 to 19.

                     Before Linux 2.6, this was a scaled value based on the scheduler weighting given to this process.

              (19) nice  %ld
                     The nice value (see setpriority(2)), a value in the range 19 (low priority) to -20 (high priority).

              (20) num_threads  %ld
                     Number of threads in this process (since Linux 2.6).  Before kernel 2.6, this field was hard coded to 0 as a placeholder for an earlier removed field.


              (22) starttime  %llu
                     The time the process started after system boot.  In kernels before Linux 2.6, this value was expressed in jiffies.  Since Linux 2.6, the value is expressed in clock  ticks  (divide  by
                     sysconf(_SC_CLK_TCK)).

                     The format for this field was %lu before Linux 2.6.

              (23) vsize  %lu
                     Virtual memory size in bytes.

              (24) rss  %ld
                     Resident  Set  Size:  number of pages the process has in real memory.  This is just the pages which count toward text, data, or stack space.  This does not include pages which have not
                     been demand-loaded in, or which are swapped out.  This value is inaccurate; see /proc/[pid]/statm below.
*/

// This requires Linux 2.6.33 or newer. Some statuses
// were encoded and procezsed differently before 2.6.33.
//
// Also Kernels 2.6.33 to 3.13 inclusive, had some extra
// states (x, K, W, P), which no longer are exposed to user space,
// either because they were rearly used, inefficient to keep
// track or compute, or made it hard to made changes to the
// process scheduler in the kernel.
// Kernels before 2.6.0 also had state W (paging).
//
// In general states R, S, D, Z, T are safe to use.
// And X should be safe too (2.6.0+ from 2003-12-18).
// And t too (2.6.33+ from 2010-02-24).
enum ProcessState {
  Running,      // R
  Sleeping,     // S
  Waiting,      // D
  Zombie,       // Z
  Stoped,       // T (Stoped on a signal SIGSTOP),
  TracingStop,  // t
  Dead,         // X
}

/++
              (3) state  %c
                     One of the following characters, indicating process state:
                     R  Running
                     S  Sleeping in an interruptible wait
                     D  Waiting in uninterruptible disk sleep
                     Z  Zombie
                     T  Stopped (on a signal) or (before Linux 2.6.33) trace stopped
                     t  Tracing stop (Linux 2.6.33 onward)
                     W  Paging (only before Linux 2.6.0)
                     X  Dead (from Linux 2.6.0 onward)
                     x  Dead (Linux 2.6.33 to 3.13 only)
                     K  Wakekill (Linux 2.6.33 to 3.13 only)
                     W  Waking (Linux 2.6.33 to 3.13 only)
                     P  Parked (Linux 3.9 to 3.13 only)
++/

struct PidProcStat {
  MyMonoTime timestamp;


  // From /proc/<pid>/stat
  int pid;
  char state;  // R, S, D, Z, T, t, W, X, x, K, W, P
  uint64 minflt, cminflt;
  uint64 majflt, cmajflt;
  uint64 utime, stime;
  int64 cutime, cstime;
  int priority;
  int nice;
  int num_threads;
  uint64 starttime;
  uint64 vsize;
  int64 rss;  // Inaccurate.  Look in /proc/[pid]/smaps or /proc/[pid]/smaps_rollup, for slower but accurate reading.

  int num_threads_in_R;
  int num_threads_in_S;
  int num_threads_in_D;
  int num_threads_in_I;  // "Idle", aka Sleeping for 20 seconds more.

  // What about runnable, but not running? I.e. it can run, but there is not enough core to run it due to other threads and work.


version(timestamp_debugging) {
  MyMonoTime t1;
  MyMonoTime t2;
  MyMonoTime t3;
  MyMonoTime t4;
}

  // From POSIX process CPU clock.
  timespec cpu_clock_time;


  // From /proc/<pid>/schedstat
  uint64 schedstat_running_usec;
  uint64 schedstat_waiting_usec;

  // From getrusage
/++
       #include <sys/time.h>
       #include <sys/resource.h>

       int getrusage(int who, struct rusage *usage);

DESCRIPTION
       getrusage() returns resource usage measures for who, which can be one of the following:

       RUSAGE_SELF
              Return resource usage statistics for the calling process, which is the sum of resources used by all threads in the process.

       RUSAGE_CHILDREN
              Return  resource  usage  statistics  for all children of the calling process that have terminated and been waited for.  These statistics will include the resources used by
              grandchildren, and further removed descendants, if all of the intervening descendants waited on their terminated children.

       RUSAGE_THREAD (since Linux 2.6.26)
              Return resource usage statistics for the calling thread.  The _GNU_SOURCE feature test macro must be defined (before including any header file) in order to obtain the def‐
              inition of this constant from <sys/resource.h>.

       The resource usages are returned in the structure pointed to by usage, which has the following form:

           struct rusage {
               struct timeval ru_utime; /* user CPU time used */
               struct timeval ru_stime; /* system CPU time used */
               long   ru_maxrss;        /* maximum resident set size */
               long   ru_ixrss;         /* integral shared memory size */
               long   ru_idrss;         /* integral unshared data size */
               long   ru_isrss;         /* integral unshared stack size */
               long   ru_minflt;        /* page reclaims (soft page faults) */
               long   ru_majflt;        /* page faults (hard page faults) */
               long   ru_nswap;         /* swaps */
               long   ru_inblock;       /* block input operations */
               long   ru_oublock;       /* block output operations */
               long   ru_msgsnd;        /* IPC messages sent */
               long   ru_msgrcv;        /* IPC messages received */
               long   ru_nsignals;      /* signals received */
               long   ru_nvcsw;         /* voluntary context switches */
               long   ru_nivcsw;        /* involuntary context switches */
           };
++/
}

// The utime and stime are in ticks, which is usually 0.01s on most systems.
// That means, with sampling ever 200ms, app using 100% of 1 core,
// will usually return difference of 20 ticks. But somtimes 21 or 19,
// which is 5% deviation!

// Other options:
/++



$ cat /proc/$(pidof stress-ng-cpu)/sched
stress-ng-cpu (1317111, #threads: 1)
-------------------------------------------------------------------
se.exec_start                                :     371420754.715119
se.vruntime                                  :      17529814.209932
se.sum_exec_runtime                          :        111062.373979
se.nr_migrations                             :                    2
nr_switches                                  :                 2693
nr_voluntary_switches                        :                    1
nr_involuntary_switches                      :                 2692
se.load.weight                               :              1048576
se.avg.load_sum                              :                47071
se.avg.runnable_sum                          :             48208214
se.avg.util_sum                              :             48192935
se.avg.load_avg                              :                 1023
se.avg.runnable_avg                          :                 1024
se.avg.util_avg                              :                 1023
se.avg.last_update_time                      :      371420754714624
se.avg.util_est.ewma                         :                  503
se.avg.util_est.enqueued                     :                  502
policy                                       :                    0
prio                                         :                  120
clock-delta                                  :                   20
mm->numa_scan_seq                            :                   11
numa_pages_migrated                          :               164028
numa_preferred_nid                           :                    1
total_numa_faults                            :                 1023
current_node=1, numa_group_id=0
numa_faults node=0 task_private=0 task_shared=0 group_private=0 group_shared=0
numa_faults node=1 task_private=1023 task_shared=0 group_private=0 group_shared=0

$ cat /proc/$(pidof stress-ng-cpu)/schedstat
507957392529 236992188 20946

See https://www.kernel.org/doc/html/latest/scheduler/sched-stats.html#proc-pid-schedstat
for more details.

schedstat:
        time spent on the cpu
        time spent waiting on a runqueue
        # of timeslices run on this cpu



++/

/++
// for whole process.

       #include <time.h>

       int clock_getcpuclockid(pid_t pid, clockid_t *clockid);


// for threads, but only in current process:

       #include <pthread.h>
       #include <time.h>

       int pthread_getcpuclockid(pthread_t thread, clockid_t *clockid);
++/

/++
Manually talling threads.

$ grep . /proc/$(pidof stress-ng-cpu)/task/1317111/sched*
/proc/1317111/task/1317111/sched:stress-ng-cpu (1317111, #threads: 1)
/proc/1317111/task/1317111/sched:-------------------------------------------------------------------
/proc/1317111/task/1317111/sched:se.exec_start                                :     371728970.695462
/proc/1317111/task/1317111/sched:se.vruntime                                  :      17699037.376533
/proc/1317111/task/1317111/sched:se.sum_exec_runtime                          :        419105.520363
/proc/1317111/task/1317111/sched:se.nr_migrations                             :                   30
/proc/1317111/task/1317111/sched:nr_switches                                  :                18634
/proc/1317111/task/1317111/sched:nr_voluntary_switches                        :                    1
/proc/1317111/task/1317111/sched:nr_involuntary_switches                      :                18633
/proc/1317111/task/1317111/sched:se.load.weight                               :              1048576
/proc/1317111/task/1317111/sched:se.avg.load_sum                              :                46729
/proc/1317111/task/1317111/sched:se.avg.runnable_sum                          :             47856382
/proc/1317111/task/1317111/sched:se.avg.util_sum                              :             47825371
/proc/1317111/task/1317111/sched:se.avg.load_avg                              :                 1023
/proc/1317111/task/1317111/sched:se.avg.runnable_avg                          :                 1024
/proc/1317111/task/1317111/sched:se.avg.util_avg                              :                 1023
/proc/1317111/task/1317111/sched:se.avg.last_update_time                      :      371728970694656
/proc/1317111/task/1317111/sched:se.avg.util_est.ewma                         :                  503
/proc/1317111/task/1317111/sched:se.avg.util_est.enqueued                     :                  502
/proc/1317111/task/1317111/sched:policy                                       :                    0
/proc/1317111/task/1317111/sched:prio                                         :                  120
/proc/1317111/task/1317111/sched:clock-delta                                  :                   40
/proc/1317111/task/1317111/sched:mm->numa_scan_seq                            :                   17
/proc/1317111/task/1317111/sched:numa_pages_migrated                          :               164028
/proc/1317111/task/1317111/sched:numa_preferred_nid                           :                    1
/proc/1317111/task/1317111/sched:total_numa_faults                            :                 1024
/proc/1317111/task/1317111/sched:current_node=1, numa_group_id=0
/proc/1317111/task/1317111/sched:numa_faults node=0 task_private=0 task_shared=0 group_private=0 group_shared=0
/proc/1317111/task/1317111/sched:numa_faults node=1 task_private=1024 task_shared=0 group_private=0 group_shared=0
/proc/1317111/task/1317111/schedstat:419105520363 207180531 18635


// Before proceeding, check first line of /proc/schedstat file once.

$ cat /proc/schedstat
version 15
timestamp 4388093551
...


V15: 2.6.30+

++/


class PidProcStatReader {
  import std.process : Pid;

 public:
  // If pid2 is provided, the reader will periodically do a `pid2.tryWait`,
  // to determine if the pid finished. This needed, because even if processes
  // terminated, it will still be in process table, until we wait on it.
  // So without doing so, we will not detect "dead" process and forever
  // return "correct" data.
  this(int pid, Pid pid2 = null) {
    import core.sys.posix.fcntl : open, O_RDONLY;
    import std.conv : to;
    import std.string : toStringz;
    import core.sys.posix.unistd : read;
    import core.sys.posix.sys.types : ssize_t;
    // import core.sys.posix.time : clock_getcpuclockid;

    pid_ = pid;
    pid2_ = pid2_;
    stat_fd_ = open(toStringz("/proc/" ~ to!string(pid) ~ "/stat"), O_RDONLY);
    assert(stat_fd_ >= 0, "Can't open stat file for pid " ~ to!string(pid));

    // Do a read to extract a name.
    char[4096] buf = void;
    const ssize_t read_ret = enforceErrno(read(stat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length)));
    assert(read_ret > 0);
    const string data = cast(const(string))(buf[0 .. read_ret]);

    // import std.string : split;
    // const string[] splitted = data.split("(");

    import std.algorithm.searching : findSplit;
    const split0 = data.findSplit(" (");  //   pid (name) rest .... 
    assert(split0[0].ptr == data.ptr);
    const split1 = split0[2].findSplit(")");
    assert(split1[0].ptr == split0[2].ptr);

    name_ = split1[0].idup;
    done_ = false;

    enforceRet(clock_getcpuclockid(cast(pid_t)(pid_), &clockid_));

    schedstat_fd_ = open(toStringz("/proc/" ~ to!string(pid) ~ "/schedstat"), O_RDONLY);
    assert(schedstat_fd_ >= 0, "Can't open schedstat file for pid " ~ to!string(pid));
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(stat_fd_);
    close(schedstat_fd_);
  }

  PidProcStat read() @nogc nothrow {
    char[4096] buf = void;
    char[1024] buf2 = void;

    // pid2_.processID is non-@nogc. LOL. TODO(baryluk): Fill the bug.
    //if (pid2_ !is null && pid2_.processID >= 0) {

//    if (pid2_ !is null) {
//      import std.process: tryWait;
//      auto pid2_status = pid2_.tryWait();  // it is not noThrow.
//    }

    import core.stdc.errno : errno, ESRCH;
    import core.sys.posix.sys.types : ssize_t, off_t;
version (SimpleSeekPlusRead) {
    import core.sys.posix.unistd : read, lseek;
    import core.stdc.stdio : SEEK_SET;
    lseek(stat_fd_, cast(off_t)0, SEEK_SET);
    auto t1 = MyMonoTime.currTime();
    // TODO(baryluk): What happens exactly if the process dies while we keep open their stat file?
    const ssize_t stat_read_ret = read(stat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length));
    const int stat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();
    if (stat_read_ret == -1 && stat_read_errno0 == ESRCH) {
      done_ = true;
    }
    if (stat_read_ret < 0) {
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      return PidProcStat();
    }
} else {
    timespec ts;

    import core.sys.posix.unistd : pread;
    auto t1 = MyMonoTime.currTime();
    const ssize_t stat_read_ret = pread(stat_fd_, cast(void*)(buf.ptr), cast(size_t)(buf.length), cast(off_t)(0));
    const int stat_read_errno0 = errno;
    auto t2 = MyMonoTime.currTime();

    const ssize_t schedstat_read_ret = pread(schedstat_fd_, cast(void*)(buf2.ptr), cast(size_t)(buf2.length), cast(off_t)(0));
    const int schedstat_read_errno0 = errno;
    auto t3 = MyMonoTime.currTime();

    import core.sys.posix.time : clock_gettime;
    //enforceErrno(clock_gettime(clockid_, &ts));
    const int clock_gettime_ret = clock_gettime(clockid_, &ts);  // Temporarily disable enforceErrno;
    const int clock_gettime_errno = errno;
    auto t4 = MyMonoTime.currTime();


    if (stat_read_ret == -1 && stat_read_errno0 == ESRCH) {
      done_ = true;
    }
    if (schedstat_read_ret == -1 && schedstat_read_errno0 == ESRCH) {
      done_ = true;
    }
    if (clock_gettime_ret == -1) {
      done_ = true;
    }
    if (stat_read_ret < 0 || schedstat_read_ret < 0) {
      done_ = true;
      // Don't even set the timestamp, so the division of 0/0 will become nan.
      // import std.stdio;
      // debug writefln("Dead process");
      return PidProcStat();
    }
}


    const string stat_data = cast(const(string))(buf[0 .. stat_read_ret]);
    // 1235 (Web Content) S 0 1 1 0 -1 4194560 832470 238694343 103 1686500 1683 2560 474465 126333 20 0 1 0 5 171896832 3313 18446744073709551615 94719783747584 94719784579661 140736021273296 0 0 0 671173123 4096 1260 0 0 0 17 26 0 0 23 0 0 94719784966352 94719785267440 94719797018624 140736021278282 140736021278330 140736021278330 140736021278691 0
    // 1               2  3 4 5 6 7 ...

    const string schedstat_data = cast(const(string))(buf2[0 .. schedstat_read_ret]);
    // 419105520363 207180531 18635


    import std.algorithm.searching : findSplit;
    // import std.string : split;
    import std.algorithm.iteration : splitter;

    // We don't split by " (" first, because we don't really need pid or name.
    // We can't just skip constant amount of bytes, because the name of the
    // process can change during execution of the process.
    const split0 = stat_data.findSplit(") ");
    assert(split0[0].ptr == stat_data.ptr);

    // Note, we don't use std.string.split, because it can allocate memory.
    // const string[] splitted = split0[2].split(" ");
    const string rest0 = split0[2];  // Further issue is with popFront() called by splitter, or by us. It is not @nogc, because of narrow string decoding.

/* from Phobos:

enum bool autodecodeStrings;

    EXPERIMENTAL to try out removing autodecoding, set the version
    NoAutodecodeStrings. Most things are expected to fail with this
    version currently.

*/

    dchar[2048] rest = void;
    assert(rest0.length <= 2048);
    for (int i = 0; i < rest0.length; i++) {
      rest[i] = rest0[i];
    }

    auto splitted = rest[0 .. rest0.length].splitter(cast(dchar)(' '));
    // ["R", "1004917", "1004917", "288304", "34823", "1004917", "4194368", "313", "0", "0", "0", "5495", "3", "0", "0", "20", "0", "1", "0", "29165973", "55074816", "1664", "18446744073709551615", "94607888424960", "94607889641485", "140724117468080", "0", "0", "0", "0", "137366016", "595648687", "0", "0", "0", "17", "7", "0", "0", "0", "0", "0", "94607892001576", "94607892264928", "94607932248064", "140724117476305", "140724117476320", "140724117476320", "140724117479397", "0\n"]
    // ["S", "3490", "3047", "3047", "0", "-1", "4194560", "84821544", "23091863", "54286", "8571667", "956841", "241462", "229405", "29949", "20", "0", "84", "0", "18917945", "4349288448", "207943", "18446744073709551615", "93991170486272", "93991170950885", "140726116930768", "0", "0", "0", "0", "4096", "17663", "0", "0", "0", "17", "21", "0", "0", "5", "0", "0", "93991171060104", "93991171065284", "93991202156544", "140726116936450", "140726116936462", "140726116936462", "140726116937699", "0\n"]
    //    3

    PidProcStat r = void;

    // r.timestamp = time_avg(t1, t2);
    r.timestamp = time_avg(t2, t3);

    // r.pid = splitted0[0].to!int;
    // r.pid = split0[0].findSplit(" ")[0].to!int;

    r.pid = pid_;

    /*
    r.state =       splitted[ 3-1-2][0];
    r.minflt =      splitted[10-1-2].qto!uint64;
    r.cminflt =     splitted[11-1-2].qto!uint64;
    r.majflt =      splitted[12-1-2].qto!uint64;
    r.cmajflt =     splitted[13-1-2].qto!uint64;
    r.utime =       splitted[14-1-2].qto!uint64;
    r.stime =       splitted[15-1-2].qto!uint64;
    r.cutime =      splitted[16-1-2].qto!uint64;
    r.cstime =      splitted[17-1-2].qto!uint64;
    r.priority =    splitted[18-1-2].qto!int;
    r.nice =        splitted[19-1-2].qto!int;
    r.num_threads = splitted[20-1-2].qto!int;
    r.starttime =   splitted[22-1-2].qto!uint64;
    r.vsize =       splitted[23-1-2].qto!uint64;
    r.rss =         splitted[24-1-2].qto!int64;
    */

    r.state =       cast(char)(splitted.popy()[0]);  // 3
    splitted.popFront();  // 4
    splitted.popFront();  // 5
    splitted.popFront();  // 6
    splitted.popFront();  // 7
    splitted.popFront();  // 8
    splitted.popFront();  // 9
    r.minflt =      splitted.popy().qto!uint64;  // 10
    r.cminflt =     splitted.popy().qto!uint64;  // 11
    r.majflt =      splitted.popy().qto!uint64;  // 12
    r.cmajflt =     splitted.popy().qto!uint64;  // 13
    r.utime =       splitted.popy().qto!uint64;  // 14
    r.stime =       splitted.popy().qto!uint64;  // 15
    r.cutime =      splitted.popy().qto!uint64;  // 16
    r.cstime =      splitted.popy().qto!uint64;  // 17
    r.priority =    splitted.popy().qto!int;     // 18
    r.nice =        splitted.popy().qto!int;     // 19
    r.num_threads = splitted.popy().qto!int;     // 20
    splitted.popFront();  // 21
    r.starttime =   splitted.popy().qto!uint64;  // 22
    r.vsize =       splitted.popy().qto!uint64;  // 23
    r.rss =         splitted.popy().qto!int64;   // 24

    r.cpu_clock_time = ts;


    {
    const split1 = schedstat_data.findSplit(" ");
    const split2 = split1[2].findSplit(" ");
    r.schedstat_running_usec = split1[0].qto!uint64;  // Both user and system.
    r.schedstat_waiting_usec = split2[0].qto!uint64;  // Waiting in runqueue
    // r.schedstat_timeslices_run = split2[2].qto!uint64;
    }

    version(timestamp_debugging) {
       r.t1 = t1;
       r.t2 = t2;
       r.t3 = t3;
       r.t4 = t4;
    }

    return r;
  }

/*
 // procps-ng top has a "trick" / hack:

https://gitlab.com/procps-ng/procps/-/blob/master/top/top.c#L6213

            // process can't use more %cpu than number of threads it has
            // ( thanks Jaromir Capik <jcapik@redhat.com> )
            // if (u > 100.0 * p->nlwp) u = 100.0 * p->nlwp;
            // if (u > Cpu_pmax) u = Cpu_pmax;
 */

  @property
  const(string) name() const {
    return name_;
  }

  string[] header(bool human_friendly) const {
    import std.format : format;
    if (human_friendly) {
      return [format!"%%9s|CPU%%|CPU percentage for pid %d"(pid_),
              format!"%%10s|RSS|RSS memory usage in MiB for pid %d"(pid_)];
    } else {
      return [format!"%%7s|CPU%%|CPU percentage for pid %d"(pid_),
              format!"%%6s|RSS|RSS memory usage in MiB for pid %d"(pid_)];
    }
  }

  import std.array : Appender;

  static
  void format(ref Appender!(char[]) appender, const ref PidProcStat prev, const ref PidProcStat next, bool human_friendly) {
    import time : TickPerSecond;
    // static
    const ticks_per_second = TickPerSecond();

    // static
    const size_t page_size_kb = (){
      import core.sys.posix.unistd : sysconf, _SC_PAGESIZE;
      return cast(size_t)(sysconf(_SC_PAGESIZE)) / 1024;
    }();
    assert(page_size_kb > 0);
    // debug assert(page_size_kb * 1024 == cast(size_t)(sysconf(_SC_PAGESIZE)));

    const wall_clock_time_difference_nsec = (next.timestamp - prev.timestamp).total!"nsecs";
version (proc_stat_method) {
    const utime_difference_nsec = (next.utime - prev.utime) * 1_000_000_000uL / ticks_per_second;
    const stime_difference_nsec = (next.stime - prev.stime) * 1_000_000_000uL / ticks_per_second;
    const double cpu_time_pct = 100.0 * (utime_difference_nsec + stime_difference_nsec) / wall_clock_time_difference_nsec;
} else version (posix_cpuclock_method) {
    const double cpu_time_pct = 100.0 * (next.cpu_clock_time - prev.cpu_clock_time) / wall_clock_time_difference_nsec;
} else {  // proc_schedstat_method
    const double cpu_time_pct = 100.0 * (next.schedstat_running_usec - prev.schedstat_running_usec) / wall_clock_time_difference_nsec;
}

    import std.format : formattedWrite;  //, sformat;
    version(timestamp_debugging) {
      appender.formattedWrite!(" prev: t1= %s t2= %s t3= %s t4= %s utime= %s stime= %s cpu_clock_time= %s schedstat_run= %s   next: t11= %s t2= %s t3= %s t4= %s utime= %s stime= %s cpu_clock_time= %s schedstat_run= %s    dt= %s %7.2f%% %7dMiB")(
          prev.t1.ticks, prev.t2.ticks,
          prev.t3.ticks, prev.t4.ticks,
          prev.utime, prev.stime,
          timespec_to_usecs(prev.cpu_clock_time),
          prev.schedstat_running_usec,

          next.t1.ticks, next.t2.ticks,
          next.t3.ticks, next.t4.ticks,
          next.utime, next.stime,
          timespec_to_usecs(next.cpu_clock_time),
          next.schedstat_running_usec,

          wall_clock_time_difference_nsec,
          (cpu_time_pct >= 0.0 ? cpu_time_pct : double.nan),
          next.rss * page_size_kb / 1024);
    } else {
      const double cpu_time_pct_bypass = (next.pid != 0) ? cpu_time_pct : double.nan;
      if (human_friendly) {
        // We do display %% and MiB here, because when one has many columns,
        // having them there makes it easier to know what is what,
        // without needing to reference header somewhere behind.
        appender.formattedWrite!"%8.2f%% %7dMiB"(
            (cpu_time_pct_bypass >= 0.0 ? cpu_time_pct_bypass : double.nan),
            next.rss * page_size_kb / 1024);
      } else {
        // For non-human consumption, we use more narrow columns by default,
        // they will expand if needed, at the expense of uglier look
        // (jagged and not aligned). But that is fine.
        appender.formattedWrite!"%7.2f %6d"(
            (cpu_time_pct_bypass >= 0.0 ? cpu_time_pct_bypass : double.nan),
            next.rss * page_size_kb / 1024);
      }
    }
  }

 private:
  const int stat_fd_;
  const int schedstat_fd_;
  const int pid_;
  Pid pid2_;
  const string name_;  // This will be limited to 16 characters by kernel.
  bool done_;

  /*const*/ clockid_t clockid_;
}

// Return pids of processes matching given name.
//
// TODO(baryluk): It would be great to maybe return pidfd?
int[] find_process_by_name(string name, string username = null) {
  int[] ret;
  import std.file : dirEntries, SpanMode;
  import std.conv : to, ConvException;
  import util : readfile_string;
  foreach (string filename; dirEntries("/proc", SpanMode.shallow)) {
    try {
      // TODO(baryluk): Eliminate this throwing code.
      int pid = filename[6..$].to!int;
      // TODO(baryluk): Stat for the file first before throwwing FileException.
      const string comm = readfile_string(filename ~ "/comm");
      if (comm == name) {
        ret ~= pid;
      }
    } catch (ConvException ce) {}
  }
  return ret;
}

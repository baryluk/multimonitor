/*
       /proc/stat
              kernel/system statistics.  Varies with architecture.  Common entries include:

              cpu 10132153 290696 3084719 46828483 16683 0 25195 0 175628 0
              cpu0 1393280 32966 572056 13343292 6130 0 17875 0 23933 0
                     The  amount  of time, measured in units of USER_HZ (1/100ths of a second on most architectures, use sysconf(_SC_CLK_TCK) to obtain the right value), that the system ("cpu" line) or the
                     specific CPU ("cpuN" line) spent in various states:

                     user   (1) Time spent in user mode.

                     nice   (2) Time spent in user mode with low priority (nice).

                     system (3) Time spent in system mode.

                     idle   (4) Time spent in the idle task.  This value should be USER_HZ times the second entry in the /proc/uptime pseudo-file.

                     iowait (since Linux 2.5.41)
                            (5) Time waiting for I/O to complete.  This value is not reliable, for the following reasons:

                            1. The CPU will not wait for I/O to complete; iowait is the time that a task is waiting for I/O to complete.  When a CPU goes into idle state for outstanding task  I/O,  another
                               task will be scheduled on this CPU.

                            2. On a multi-core CPU, the task waiting for I/O to complete is not running on any CPU, so the iowait of each CPU is difficult to calculate.

                            3. The value in this field may decrease in certain conditions.

                     irq (since Linux 2.6.0)
                            (6) Time servicing interrupts.

                     softirq (since Linux 2.6.0)
                            (7) Time servicing softirqs.

                     steal (since Linux 2.6.11)
                            (8) Stolen time, which is the time spent in other operating systems when running in a virtualized environment

                     guest (since Linux 2.6.24)
                            (9) Time spent running a virtual CPU for guest operating systems under the control of the Linux kernel.

                     guest_nice (since Linux 2.6.33)
                            (10) Time spent running a niced guest (virtual CPU for guest operating systems under the control of the Linux kernel).

              page 5741 1808
                     The number of pages the system paged in and the number that were paged out (from disk).

              swap 1 0
                     The number of swap pages that have been brought in and out.

              intr 1462898
                     This  line  shows  counts of interrupts serviced since boot time, for each of the possible system interrupts.  The first column is the total of all interrupts serviced including unnum‐
                     bered architecture specific interrupts; each subsequent column is the total for that particular numbered interrupt.  Unnumbered interrupts are not shown, only summed into the total.

              disk_io: (2,0):(31,30,5764,1,2) (3,0):...
                     (major,disk_idx):(noinfo, read_io_ops, blks_read, write_io_ops, blks_written)
                     (Linux 2.4 only)

              ctxt 115315
                     The number of context switches that the system underwent.

              btime 769041601
                     boot time, in seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC).

              processes 86031
                     Number of forks since boot.

              procs_running 6
                     Number of processes in runnable state.  (Linux 2.5.45 onward.)

              procs_blocked 2
                     Number of processes blocked waiting for I/O to complete.  (Linux 2.5.45 onward.)

              softirq 229245889 94 60001584 13619 5175704 2471304 28 51212741 59130143 0 51240672
                     This line shows the number of softirq for all CPUs.  The first column is the total of all softirqs and each subsequent column is the total for particular softirq.   (Linux  2.6.31  on‐
                     ward.)

$ cat /proc/stat
cpu  16154830 907371 2199803 346347642 108562 0 95597 0 0 0
cpu0 677866 28469 77187 10639373 1939 0 2556 0 0 0
cpu1 484723 32632 54844 10862949 1202 0 1193 0 0 0
cpu2 367471 26414 169964 10834912 1240 0 943 0 0 0
cpu3 442327 27602 52866 10910256 1363 0 1214 0 0 0
cpu4 777408 29587 105419 10510907 7723 0 1355 0 0 0
cpu5 539636 25470 78676 10784426 6113 0 820 0 0 0
cpu6 449947 26506 68097 10878152 6985 0 5668 0 0 0
cpu7 489872 25755 72099 10837501 6167 0 960 0 0 0
cpu8 588270 34036 71726 10735550 2905 0 1250 0 0 0
cpu9 462243 25445 66304 10879261 2240 0 691 0 0 0
cpu10 468917 30711 54325 10878052 4771 0 1211 0 0 0
cpu11 359717 26252 66277 10976853 4212 0 1213 0 0 0
cpu12 694778 34096 105582 10594707 2584 0 981 0 0 0
cpu13 620751 26659 79845 10704607 1015 0 1016 0 0 0
cpu14 514142 26450 69497 10820313 1848 0 1046 0 0 0
cpu15 563320 25002 69291 10767782 2705 0 1215 0 0 0
cpu16 498349 31785 60034 10843523 3325 0 16 0 0 0
cpu17 422402 30417 43993 10939130 1529 0 16 0 0 0
cpu18 403087 28932 47728 10955630 1229 0 12 0 0 0
cpu19 412371 27706 41872 10956322 694 0 17 0 0 0
cpu20 654705 28373 62978 10681631 5032 0 20 0 0 0
cpu21 479850 24718 63800 10862378 5809 0 84 0 0 0
cpu22 492543 27824 68654 10837926 8479 0 14 0 0 0
cpu23 461223 26796 61846 10877311 9461 0 17 0 0 0
cpu24 433491 44821 60196 10894811 3306 0 22 0 0 0
cpu25 398085 29525 52315 10955913 2481 0 16 0 0 0
cpu26 356153 22722 47116 11009496 2491 0 19 0 0 0
cpu27 445305 25855 52832 10912620 2024 0 12 0 0 0
cpu28 497457 28291 63445 10843319 2190 0 72 0 0 0
cpu29 576842 27170 77190 10610558 1565 0 71786 0 0 0
cpu30 567568 24952 66309 10773477 1530 0 84 0 0 0
cpu31 553999 26385 67481 10777977 2388 0 45 0 0 0
intr 1476108027 35 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 57293 57293 57293 57293 0 0 44415 0 44415 0 29 6 0 0 0 0 1 0 3 18 0 0 0 0 1 0 12 0 11 0 0 0 0 74 0 46 0 0 0 0 0 0 0 1 0 27 0 0 1 0 0 0 46 58 0 0 1 0 0 0 1 7 0 0 0 0 0 0 3 57 0 1 0 0 0 0 0 0 57293 57293 57293 57293 69524515 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 264048 0 0 0 0 0 0 0 0 186654765 898990 3693548 2471604 2032018 3280751 2818746 1784104 13850530 2157008 2649380 1413524 2417584 2546071 1973455 1911523 2050538 2213592 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 3212 0 1784 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ctxt 2214759007
btime 1620548600
processes 1028121
procs_running 1
procs_blocked 0
softirq 1278259373 69526293 16726212 8600 52838981 1117899 0 732655 645874256 293176 491141301
$
*/


enum CpuFreqDriver {
  ACPI_CpuFreq,
  P4,
}

enum CpuFreqGovernor {
  Ondemand,
  Performance,
  PowerSave,
  Conservative,
  SchedUtil,
}

struct CpuStat {
  CpuFreqDriver driver;
  CpuFreqGovernor governor;
  int freq_khz;
}

class CpuStatReader {
  this() {
    import core.sys.posix.fcntl : open, O_RDONLY;
    import std.conv : to;
    import std.string : toStringz;
    driver_fd_ = open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver", O_RDONLY);
    governor_fd_ = open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", O_RDONLY);
    cur_freq_fd_ = open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", O_RDONLY);
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(driver_fd_);
    close(governor_fd_);
    close(cur_freq_fd_);
  }
  CpuStat read() @nogc {
    return CpuStat();
  }
 private:
  int driver_fd_;
  int governor_fd_;
  int cur_freq_fd_;
}



// grep . /sys/devices/system/cpu/cpu31/cpufreq/{scaling_driver,scaling_cur_freq,scaling_governor}
// /sys/devices/system/cpu/cpu31/cpufreq/scaling_driver:acpi-cpufreq
// /sys/devices/system/cpu/cpu31/cpufreq/scaling_cur_freq:4055517
// /sys/devices/system/cpu/cpu31/cpufreq/scaling_governor:performance

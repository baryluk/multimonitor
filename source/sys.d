import types;

/*
$ vmstat -w
procs -----------------------memory---------------------- ---swap-- -----io---- -system-- --------cpu--------
 r  b         swpd         free         buff        cache   si   so    bi    bo   in   cs  us  sy  id  wa  st
 0  0            0     89211824         3088     35839188    0    0     1     0    3    3   2   1  98   0   0
*/

/*
$ vmstat -f
       894689 forks
*/


// openat(AT_FDCWD, "/proc/stat", O_RDONLY) = 4
// read(4, "cpu  10455920 96309 4206016 5743"..., 65535) = 7054
// openat(AT_FDCWD, "/proc/vmstat", O_RDONLY) = 5
// lseek(5, 0, SEEK_SET)                   = 0


// /proc/stat
/*
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

*/

struct ProcStat {
  uint64 intr;
  uint64 ctxt;
  uint64 forks;
  uint64 procs_running;
  uint64 procs_blocked;
};

// awk '/procs_running/ { print $2 }' /proc/stat

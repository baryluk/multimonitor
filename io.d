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

/*
$ vmstat --disk
disk- ------------reads------------ ------------writes----------- -----IO------
       total merged sectors      ms  total merged sectors      ms    cur    sec
nvme0n1    202      0    7654       8      0      0       0       0      0      0
nvme1n1    202      0    7654       8      0      0       0       0      0      0
sda    56921    134 5113616  122326      0      0       0       0      0    145
sdd        0      0       0       0      0      0       0       0      0      0
sdc        0      0       0       0      0      0       0       0      0      0
sdb      350    269   14202     256      0      0       0       0      0      0
loop0 2561427      0 16852816   60730      0      0       0       0      0    578
loop1    238      0    5450       3    395      0   22198      30      0      0
loop2     88      0    3110       2    193      0    1352       3      0      0
loop3      0      0       0       0      0      0       0       0      0      0
loop4      0      0       0       0      0      0       0       0      0      0
loop5      0      0       0       0      0      0       0       0      0      0
loop6      0      0       0       0      0      0       0       0      0      0
loop7      0      0       0       0      0      0       0       0      0      0
dm-0     151      0    2348       4    384      0   22198      36      0      0
*/


/*
$ vmstat -D
           15 disks 
            2 partitions 
      2619653 total reads
          403 merged reads
     22007278 read sectors
       183338 milli reading
          972 writes
            0 merged writes
        45748 written sectors
           69 milli writing
            0 inprogress IO
          723 milli spent IO
*/


/*
$ iostat 
Linux 5.9.0-4-amd64 (debian) 	12/26/2020 	_x86_64_	(32 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.50    0.01    0.62    0.01    0.00   97.86

Device             tps    kB_read/s    kB_wrtn/s    kB_dscd/s    kB_read    kB_wrtn    kB_dscd
dm-0              0.00         0.00         0.04         0.00       1174      11099          0
loop0             9.09        29.89         0.00         0.00    8426850          0          0
loop1             0.00         0.01         0.04         0.00       2725      11099          0
loop2             0.00         0.01         0.00         0.00       1555        676          0
nvme0n1           0.00         0.01         0.00         0.00       3827          0          0
nvme1n1           0.00         0.01         0.00         0.00       3827          0          0
sda               0.20         9.07         0.00         0.00    2556808          0          0
sdb               0.00         0.03         0.00         0.00       7101          0          0
*/

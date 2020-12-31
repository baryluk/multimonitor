
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

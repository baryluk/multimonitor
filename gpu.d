import time : MyMonoTime, time_avg;
import util : readfile;

struct GpuStat {
  MyMonoTime timestamp;

  // From radeontop;
  // 1608932882.710944: bus 43, gpu 0.00%, ee 0.00%, vgt 0.00%, ta 0.00%, sx 0.00%, sh 0.00%, spi 0.00%, sc 0.00%, pa 0.00%, db 0.00%, cb 0.00%, vram 4.95% 200.91mb, gtt 0.63% 25.75mb, mclk 100.00% 0.500ghz, sclk 32.36% 0.340ghz
  float gpu_pct;

  float vram_pct;
  float vram_kb;

  float sclk_pct;
  float sclk_ghz;

  // From hwmon.
  float temp1_mC;
  float freq1_Hz;
  float freq2_Hz;
  float power1_uW;
  float VDD_mV;
}

// How much details / information to read.
enum GpuStuff {
  none,
  min,
  med,
  max,
}

class GpuStatReader {
  this(string hwmon_dir, const GpuStuff mode) {
    import core.sys.posix.fcntl : open, O_RDONLY;
    import std.conv : to;
    import std.string : toStringz;

    load_fd_ = open("/sys/class/drm/renderD128/device/gpu_busy_percent", O_RDONLY);
    vram_used_fd_ = open("/sys/class/drm/renderD128/device/mem_info_vram_used", O_RDONLY);
    vram_total_bytes = readfile!ulong("/sys/class/drm/renderD128/device/mem_info_vram_total");

    power1_fd_ = open(toStringz(hwmon_dir ~ "/power1_average"), O_RDONLY);
    freq1_fd_ = open(toStringz(hwmon_dir ~ "/freq1_input"), O_RDONLY);
    freq2_fd_ = open(toStringz(hwmon_dir ~ "/freq2_input"), O_RDONLY);
    temp1_fd_ = open(toStringz(hwmon_dir ~ "/temp1_input"), O_RDONLY);
    vdd_fd_ = open(toStringz(hwmon_dir ~ "/in0_input"), O_RDONLY);
    {
      import std.file : read;
      import std.string : stripRight;
      assert((cast(string)(read(hwmon_dir ~ "/in0_label"))).stripRight() == "vddgfx");
    }

    mode_ = mode;
  }
  ~this() {
    import core.sys.posix.unistd : close;
    close(load_fd_);

    close(power1_fd_);
    close(freq1_fd_);
    close(freq2_fd_);
    close(temp1_fd_);
    close(vdd_fd_);
  }

  GpuStat read() @nogc {
    // radeontop use ioctl in version 1.2. In fact in separat thread than the one reporting to screen.
    // [pid 720113] ioctl(4, DRM_IOCTL_AMDGPU_INFO or DRM_IOCTL_SIS_FB_FREE, 0x7f80aa978d70) = 0
    // [pid 720113] ioctl(4, DRM_IOCTL_AMDGPU_INFO or DRM_IOCTL_SIS_FB_FREE, 0x7f80aa978d70) = 0

    GpuStat r;
    MyMonoTime t1 = MyMonoTime.currTime();
    const vram_used_bytes = readfile!ulong(vram_used_fd_);
    r.vram_kb = vram_used_bytes / 1024;
    r.vram_pct = cast(double)(vram_used_bytes) / vram_total_bytes;
    r.gpu_pct = readfile!int(load_fd_);
    r.power1_uW = readfile!int(power1_fd_);
    r.freq1_Hz = readfile!ulong(freq1_fd_);
    r.freq2_Hz = readfile!ulong(freq2_fd_);
    r.temp1_mC = readfile!int(temp1_fd_);
    r.VDD_mV = readfile!int(vdd_fd_);
    MyMonoTime t2 = MyMonoTime.currTime();
    r.timestamp = time_avg(t1, t2);

    return r;
  }

  // static
  string[] header(bool human_friendly) {
    string[] ret;
    if (human_friendly) {
      ret ~= ["%4s|GPU%|GPU load percentage",
              "%10s|VRAM|GPU memory usage in MiB",
              "%7s|SCLK|GPU core clock frequency in MHz"];
    } else {
      ret ~= ["%6s|GPU%|GPU load percentage",
              "%7s|VRAM|GPU memory usage in MiB",
              "%6s|SCLK|GPU core clock frequency in MHz"];
    }
    if (mode_ >= GpuStuff.med) {
      ret ~= ["%5s|GPUT|GPU temperature in °C",
              "%7s|GPUP|GPU power in W"];
    }
    if (mode_ >= GpuStuff.max) {
      ret ~= ["%5s|GPUVdd|GPU VDD in V"];
    }
    return ret;
  }

  import std.array : Appender;

  // static
  void format(ref Appender!(char[]) appender, const ref GpuStat prev, const ref GpuStat next, bool human_friendly = true) {
    import std.format : formattedWrite;
    if (human_friendly) {
      appender.formattedWrite!("%3.0f%% %7.1fMiB %4.0fMHz")(next.gpu_pct, next.vram_kb / 1024.0, next.freq1_Hz * 1.0e-6);
      if (mode_ >= GpuStuff.med) {
        appender.formattedWrite!" %3.0f°C %6.2fW"(next.temp1_mC * 1.0e-3, next.power1_uW * 1.0e-6);
      }
      if (mode_ >= GpuStuff.max) {
        appender.formattedWrite!" %5.3fV"(next.VDD_mV * 1.0e-3);
      }
    } else {
      appender.formattedWrite!("%5.1f %8.2f %6.1f")(next.gpu_pct, next.vram_kb / 1024.0, next.freq1_Hz * 1.0e-6);
      if (mode_ >= GpuStuff.med) {
        appender.formattedWrite!" %6.2f %10.6f"(next.temp1_mC * 1.0e-3, next.power1_uW * 1.0e-6);
      }
      if (mode_ >= GpuStuff.max) {
        appender.formattedWrite!" %6.4f"(next.VDD_mV * 1.0e-3);
      }
    }
  }


 private:
  int load_fd_;
  int vram_used_fd_;

  int power1_fd_;
  int freq1_fd_;
  int freq2_fd_;
  int temp1_fd_;
  int vdd_fd_;

  const ulong vram_total_bytes;

  const GpuStuff mode_;
}

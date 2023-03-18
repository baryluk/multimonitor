// $ grep . /sys/class/hwmon/hwmon*/name
// /sys/class/hwmon/hwmon0/name:nvme
// /sys/class/hwmon/hwmon1/name:nvme
// /sys/class/hwmon/hwmon2/name:amdgpu
// /sys/class/hwmon/hwmon3/name:k10temp
// /sys/class/hwmon/hwmon4/name:k10temp

// hwmon0, hwmon2, ... are symlinks to pci devices, i.e. ../../devices/pci0000:40/0000:40:03.1/0000:43:00.0/hwmon/hwmon2
// they can probably point to other non-pci stuff, so this is pretty good way of dsicovering them.

// cat /sys/class/hwmon/hwmon2/in0_label
// vddgfx
// cat /sys/class/hwmon/hwmon2/in0_input
// 1043


// It probably makes more sense to return a directory file descriptor,
// then use openat
string searchHWMON(string name) {
  import std.file : dirEntries, SpanMode;
  import util : readfile_string;
  foreach (string filename; dirEntries("/sys/class/hwmon", SpanMode.shallow)) {
    if (readfile_string(filename ~ "/name") == name) {
      return filename;
    }
  }
  return null;
}

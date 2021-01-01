import time;

struct ExecResult {
  MyMonoTime timestamp;
  string result;
}

class ExecReader {
 public:
  this(string command) {
    command_ = command;
  }

  ExecResult read() {
    import std.process : executeShell, Config;
    import std.string : tr;
    MyMonoTime t1 = MyMonoTime.currTime();
    const output = executeShell(command_, /*env=*/null, Config.suppressConsole | Config.stderrPassThrough);
    MyMonoTime t2 = MyMonoTime.currTime();
    if (output.status != 0) {
      return ExecResult(time_avg(t1, t2), null);
    }
    // Replace newlines by space. This makes it easier to put multiple commands
    // in single --exec option. This also plays nicely with `awk` and `grep`
    // usage in general.
    const string line = output.output.tr("\n", " ");
    // Remove trailing newline (or after tr above), a trailing space.
    const string line_trim = (line.length >= 1 && (line[$-1] == '\n' || line[$-1] == ' ') ? line[0 .. $-1] : line);
    return ExecResult(time_avg(t1, t2), line_trim);
  }

  string[] header(bool human_friendly) {
    return ["EXEC|External command execution output"];
  }

  import std.array : Appender;

  static
  void format(ref Appender!(char[]) appender, const ref ExecResult prev, const ref ExecResult next, bool human_friendly) {
    appender.put(next.result);
  }

 private:
  const string command_;
}

class PipeReader {
  import std.process : ProcessPipes;

 public:
  this(string command) {
    import std.process : pipeShell, Redirect, Config;
    pipes_ = pipeShell(command, Redirect.stdout, /*env=*/null, Config.retainStderr | Config.suppressConsole);
  }

  ~this() {
    import std.process : wait, kill;
    pipes_.stdin.close();
    pipes_.pid.kill();  // SIGTERM by default.
    pipes_.pid.wait();
  }

  ExecResult read() {
    import std.stdio : readln;
    MyMonoTime t1 = MyMonoTime.currTime();
    const string line = pipes_.stdout.readln();
    MyMonoTime t2 = MyMonoTime.currTime();
    // Remove trailing new line if any.
    const string line_trim = (line.length >= 1 && line[$-1] == '\n' ? line[0 .. $-1] : line);

    return ExecResult(time_avg(t1, t2), line_trim);
  }

  string[] header(bool human_friendly) {
    return ["PIPE|External command execution output"];
  }

  import std.array : Appender;

  static
  void format(ref Appender!(char[]) appender, const ref ExecResult prev, const ref ExecResult next, bool human_friendly) {
    appender.put(next.result);
  }

 private:
  ProcessPipes pipes_;
  int width_;
}

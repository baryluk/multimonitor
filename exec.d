import time;

struct ExecResult {
  MyMonoTime timestamp;
  string result;
  ulong width;

  final void format(Writer)(ref Writer w, bool human_friendly) const {
    if (human_friendly) {
      import std.format : formattedWrite;
      w.formattedWrite!"%*s"(width, result);
    } else {
      w.put(result);
    }
  }
}

class ExecReader {
 public:
  this(string command) {
    command_ = command;

    // Set minimum to match "EXEC" header width.
    width_ = 4;

    // Do one explicit read, to update the width_.
    // This way the `header()` hopefully produces reasonable width.
    cast(void)(read());
  }

  ExecResult read() {
    import std.process : executeShell, Config;
    import std.string : tr;
    MyMonoTime t1 = MyMonoTime.currTime();
static if (__traits(compiles, Config.stderrPassThrough)) {
    const output = executeShell(command_, /*env=*/null, Config.suppressConsole | Config.stderrPassThrough);
} else {
    // Workaround (ignore issue) for GDC: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=98494
    const output = executeShell(command_, /*env=*/null, Config.suppressConsole);
}
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

    if (line_trim.length > width_) {
      width_ = line_trim.length;
    }

    return ExecResult(time_avg(t1, t2), line_trim, width_);
  }

  string[] header(bool human_friendly) const {
    import std.format : format;
    return [format!"%%%ds|EXEC|External command execution output %s"(width_ ? width_ : 10, command_)];  // Meta.
  }

  static
  void format(Writter)(ref Writter w, const ref ExecResult prev, const ref ExecResult next, bool human_friendly) {
    next.format(w, human_friendly);
  }

 private:
  const string command_;
  ulong width_;
}

class PipeReader {
  import std.process : ProcessPipes;

 public:
  this(string command) {
    import std.process : pipeShell, Redirect, Config;
    pipes_ = pipeShell(command, Redirect.stdout, /*env=*/null, Config.retainStderr | Config.suppressConsole);
    command_ = command;  // This is just in case we need to restart the process, or format the header / annotations.

    {
      import std.stdio : stderr;
      stderr.writefln!"# Spawned %s for --pipe: %s"(pipes_.pid.processID, command);
    }

    // Set minimum to match "PIPE" header width.
    width_ = 4;

    // Do one explicit read, to update the width_.
    // This way the `header()` hopefully produces reasonable width.
    cast(void)(read());
  }

  // TODO(baryluk): I think it is possible that kill() and wait() can throw.
  ~this() {
    import std.process : wait, kill;
    pipes_.pid.kill();  // SIGTERM by default.
    pipes_.pid.wait();
    pipes_.stdout.close();
  }

  void stop() {
    pipes_.stdout.close();
  }

  ExecResult read() {
    import std.stdio : readln;
    MyMonoTime t1 = MyMonoTime.currTime();
    const string line = pipes_.stdout.readln();
    MyMonoTime t2 = MyMonoTime.currTime();
    // Remove trailing new line if any.
    const string line_trim = (line.length >= 1 && line[$-1] == '\n' ? line[0 .. $-1] : line);

    if (line_trim.length > width_) {
      width_ = line_trim.length;
    }
    // TODO(baryluk): It might make sense to track maximum width of lets say
    // last 30 second, and adjust based on that. This has an advantage
    // of handling spike in width, but then recovering to narrower width.

    // We put the width_ into the ExecResult, so format can be static, also not
    // to cause race conditions when reading in format, while writing in read
    // (when using async_wrap).
    return ExecResult(time_avg(t1, t2), line_trim, width_);
  }

  string[] header(bool human_friendly) const {
    import std.format : format;
    return [format!"%%%ds|PIPE|External command execution output for %s"(width_ ? width_ : 10, command_)];  // Meta.
  }

  static
  void format(Writer)(ref Writer w, const ref ExecResult prev, const ref ExecResult next, bool human_friendly) {
    next.format(w, human_friendly);
  }

 private:
  ProcessPipes pipes_;
  const string command_;
  ulong width_;
}

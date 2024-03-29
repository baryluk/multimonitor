void enforceRet(T)(lazy T x) {  // To make this @nogc, we need to also make x a @nogc. And get rid of enforce which can throw.
  import std.exception : enforce;
  const T ret = x();
  if (ret != 0) {
    enforce(false, "");
  }
}

T enforceErrno(T)(lazy T x) {
  import std.exception : errnoEnforce;
  import core.stdc.errno : errno;
  const T ret = x();
  if (ret < 0) {
     errnoEnforce(false, "");
  }
  return ret;
}

// Parse a string into integer type.
// No leading zeros supported. No leading or trailing spaces supported.
// No + supported.
// Only radix 10 supported.
// No overflow handling.
// No error handling. The input must be valid.
//
// '-' prefix supported, but T.min, might not work.
//
// This is heavily simplified version of std.conv.parse.
// See https://github.com/dlang/phobos/blob/master/std/conv.d#L2317
//
// We don't use std.range.{front,popFront} because it looks like they can throw, and are not @nogc
//
// We use 'S' instead of 'string', so we can also decode dstring.
template qto(T) {
  // TODO(baryluk): Would be nice to make this immutable or in.
  T qto(S)(const S s) @nogc nothrow pure {
    import std.range : front, popFront, empty;

    // import std.stdio;
    // debug writefln("qto '%s'", s);

    auto source = s;
    size_t count = 0;
    int i = 0;
    uint c = s[i];
    i++;
    T neg = 1;
    if (c == '-') {
       neg = -1;
       c = s[i];
       i++;
    }
    c -= '0';
    assert(0 <= c && c <= 9);
    T v = cast(T)(c);
    while (i < s.length) {
      c = cast(typeof(c))(source[i] - '0');
      assert(0 <= c && c <= 9);
      v = cast(T)(v * 10 + c);
      i++;
    }
    return neg * v;
  }
}
unittest {
  assert("1".qto!int == 1);
  assert("0".qto!int == 0);
  assert("-1".qto!int == -1);
  assert("-0".qto!int == 0);

  assert("654".qto!int == 654);
  assert("654".qto!uint == 654);
  assert("654".qto!long == 654);
  assert("654".qto!ulong == 654);

  assert("-654".qto!int == -654);
  assert("-654".qto!long == -654);
}

// Like qto, but for floating point values. No scientific notation supported.
template qtof(T) {
  // TODO(baryluk): Would be nice to make this immutable or in.
  T qtof(S)(const S s) @nogc nothrow pure {
    import std.range : front, popFront, empty;

    // import std.stdio;
    // debug writefln("qtof %s", s);

    auto source = s;
    size_t count = 0;
    int i = 0;
    uint c = s[i];
    i++;
    T neg = cast(T)(1.0f);
    if (c == '-') {
       neg = cast(T)(-1.0f);
       c = s[i];
       i++;
    }
    c -= '0';
    assert(0 <= c && c <= 9);
    T integral_part = cast(T)(c);
    while (i < s.length) {
      if (source[i] == '.') {
          i++;
          break;
      }
      c = cast(typeof(c))(source[i] - '0');
      assert(0 <= c && c <= 9);
      integral_part = cast(T)(integral_part * cast(T)(10.0) + cast(T)(c));
      i++;
    }
    // int j = 0;
    T decimal_part = cast(T)(0.0);
    T decimal_multiplier = cast(T)(1.0);
    while (i < s.length) {
      c = cast(typeof(c))(source[i] - '0');
      assert(0 <= c && c <= 9);
      decimal_part = cast(T)(decimal_part * cast(T)(10.0) + cast(T)(c));
      decimal_multiplier *= cast(T)(10.0);
      i++;
    }

    // debug writefln("qtof2 '%s' '%s'", s, neg * (integral_part + decimal_part / decimal_multiplier));
    return neg * (integral_part + decimal_part / decimal_multiplier);
  }
}
unittest {
  assert("1".qtof!float == 1);
  assert("0".qtof!float == 0);
  assert("-1".qtof!float == -1);
  assert("-0".qtof!float == 0);

  assert("1.00".qtof!float == 1.0f);
  assert("0.00".qtof!float == 0.0f);
  assert("-1.00".qtof!float == -1.0f);
  assert("-0.00".qtof!float == 0.0f);

  import std.math : isClose;

  assert(isClose("6.54".qtof!float, 6.54f, 1.0e-5));
  assert(isClose("6.54".qtof!double, 6.54, 1.0e-10));
  assert(isClose("006.54".qtof!float, 6.54f, 1.0e-5));
  assert(isClose("006.54".qtof!double, 6.54, 1.0e-10));
  assert(isClose("6.5400".qtof!float, 6.54f, 1.0e-5));
  assert(isClose("6.5400".qtof!double, 6.54, 1.0e-10));
  assert(isClose("6.0054".qtof!float, 6.0054f, 1.0e-5));
  assert(isClose("6.0054".qtof!double, 6.0054, 1.0e-10));

  assert(isClose("-6.54".qtof!float, -6.54f, 1.0e-5));
  assert(isClose("-6.54".qtof!double, -6.54, 1.0e-10));
}

auto popy(R)(ref R r) {
  auto e = r.front();
  r.popFront();
  return e;
}

T readfile(T)(int fd) @nogc {
  char[256] buf = void;

  import core.stdc.errno : errno, ESRCH;
  import core.sys.posix.sys.types : ssize_t, off_t;
  import core.sys.posix.unistd : pread;

  const ssize_t ret = pread(fd, cast(void*)(buf.ptr), cast(size_t)(buf.length), cast(off_t)(0));
  const int errno0 = errno;

  if (ret == -1 && errno0 == ESRCH) {
    return T.init;
  }
  if (ret < 0) {
    return T.init;
  }
  assert(ret < buf.length);

  const string data = cast(const(string))(buf[0 .. ret]);
  assert(data.length >= 1);
  // Remove trailing new line if any.
  const string data_trim = (data[$-1] == '\n' ? data[0 .. $-1] : data);

  return qto!T(data_trim);
}

T readfile(T)(string filename) {
  import core.sys.posix.fcntl : open, O_RDONLY;
  // import std.conv : to;
  import std.string : toStringz;
  import core.sys.posix.unistd : close;

  int fd = open(toStringz(filename), O_RDONLY);
  assert(fd >= 0);
  const T r = readfile!T(fd);
  close(fd);
  return r;
}

// Read whole file from filename, and strip the end whitespaces.
string readfile_string(const string filename) {
  import std.file : read;
  import std.string : stripRight;
  return (cast(string)(cast(const(ubyte)[])(read(filename)))).stripRight();
}

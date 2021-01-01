
// Wrapps existing 'Reader' instance into async version,
// by running actual reader in a separate thread.
// Implements suitable channel of communication,
// caching / rate limiting.
//
// 'Reader' must implement `read` and `format` methods.
// `format` method can be static.

import core.time : Duration;

auto async_wrap(R)(R reader, const Duration async_delay) {
  import core.thread : Thread;
  import core.sync.mutex : Mutex;

  class AsyncWrappedReader {
   private:
    R reader_;

    Mutex m_;
    Thread thread_;

    alias typeof(reader_.read()) ReadResult;
    ReadResult last_read_;  // GUARDED_BY(m_)
    bool last_read_consumed_;  // GUARDED_BY(m_)
    bool stop_;  // GUARDED_BY(m_)

    this(ref R reader) {
      reader_ = reader;
      m_ = new Mutex();
      thread_ = new Thread(&thread_loop);
    }

   public:
    ~this() {
      m_.lock();
      stop_ = true;
      m_.unlock();
      thread_.join();
    }

   public:
    ReadResult read() {
      // scope MutexLock l(&m_);
      m_.lock();
      const ReadResult last_read_copy = last_read_;
      last_read_consumed_ = true;
      m_.unlock();
      return last_read_copy;
    }

    // Forward header and format calls directly to `reader_`.
    //alias reader_ this;

    import std.traits : hasFunctionAttributes;

    // __traits(isStaticFunction, reader_.header)

    // static if (__traits(getFunctionAttributes, reader_.header)

    static if (hasFunctionAttributes!(reader_.header, "const")) {
    string[] header(bool human_friendly) const {
      return reader_.header(human_friendly);
    }
    } else {
    string[] header(bool human_friendly) {
      return reader_.header(human_friendly);
    }
    }

    import std.array : Appender;

    void format(ref Appender!(char[]) appender, const ref ReadResult prev, const ref ReadResult next, bool human_friendly = true) {
      return reader_.format(appender, prev, next, human_friendly);
    }

   private:
    void thread_loop() {
      m_.lock();
      // TODO(baryluk): Reuse time.time_loop here?
      while (!stop_) {
        m_.unlock();
        const ReadResult new_read = reader_.read();
        m_.lock();
        last_read_ = new_read;
        last_read_consumed_ = false;
        m_.unlock();
        Thread.sleep(async_delay);
        m_.lock();
      }
    }
  }

  auto wrapped = new AsyncWrappedReader(reader);
  wrapped.thread_.start();
  return wrapped;
}

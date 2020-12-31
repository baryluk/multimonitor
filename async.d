
// Wrapps existing 'Reader' instance into async version,
// by running actual reader in a separate thread.
// Implements suitable channel of communication,
// caching / rate limiting.
//
// 'Reader' must implement `read` and `format` methods.
// `format` method can be static.
auto async_wrap(R)(R reader) {
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

    string[] header(bool human_friendly) const {
      return reader_.header(human_friendly);
    }

    import std.array : Appender;

    void format(ref Appender!(char[]) appender, const ref ReadResult prev, const ref ReadResult next, bool human_friendly = true) {
      return reader_.format(appender, prev, next, human_friendly);
    }

   private:
    void thread_loop() {
      import core.time : dur;
      m_.lock();
      while (!stop_) {
        m_.unlock();
        const ReadResult new_read = reader_.read();
        m_.lock();
        last_read_ = new_read;
        last_read_consumed_ = false;
        m_.unlock();
        Thread.sleep(dur!"msecs"(100));
        m_.lock();
      }
    }
  }

  auto wrapped = new AsyncWrappedReader(reader);
  wrapped.thread_.start();
  return wrapped;
}

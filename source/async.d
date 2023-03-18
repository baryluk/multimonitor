
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
  import core.sync.condition : Condition;

  class AsyncWrappedReader {
   private:
    R reader_;

    Mutex m_;
    Thread thread_;

    alias typeof(reader_.read()) ReadResult;
    ReadResult last_read_;  // GUARDED_BY(m_)
    bool last_read_consumed_;  // GUARDED_BY(m_)
    bool stop_;  // GUARDED_BY(m_)
    bool stopped_;  // GUARDED_BY(m_)
    Condition stopped_cv_;  // GUARDED_BY(m_)

    this(ref R reader) {
      reader_ = reader;
      m_ = new Mutex();
      stopped_cv_ = new Condition(m_);
      thread_ = new Thread(&thread_loop);
    }

   public:
    ~this() {
      //m_.lock();
      assert(stop_);
      assert(stopped_);
      //m_.unlock();

      // thread_.join(/*rethrow=*/false);  // Otherwise it could cause memory allocation.
    }

   public:
    void stop() {
      m_.lock();
      stop_ = true;
      while (!stopped_) {
        stopped_cv_.wait();
      }
      m_.unlock();
      thread_.join(/*rethrow=*/true);  // Default. Throw now, instead of later.
    }

    ReadResult read() {
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

    // TODO(baryluk): Make it const and/or static, depending on reader_.format attributes.
    final void format(Writer)(ref Writer writer, const ref ReadResult prev, const ref ReadResult next, bool human_friendly = true) {
      return reader_.format(writer, prev, next, human_friendly);
    }

   private:
    void thread_loop() {
      m_.lock();
      const bool do_delay = (async_delay != Duration.zero);
      // TODO(baryluk): Reuse time.time_loop here?
      while (!stop_) {
        m_.unlock();
        const ReadResult new_read = reader_.read();
        m_.lock();
        last_read_ = new_read;
        last_read_consumed_ = false;
        if (do_delay) {
          m_.unlock();
          Thread.sleep(async_delay);
          m_.lock();
        }
      }
      m_.unlock();

      import std.traits : hasMember;
      static if (hasMember!(typeof(reader_), "stop")) {
        reader_.stop();
      }

      m_.lock();
      stopped_ = true;
      stopped_cv_.notifyAll();
      m_.unlock();
    }
  }

  auto wrapped = new AsyncWrappedReader(reader);
  wrapped.thread_.start();
  return wrapped;
}

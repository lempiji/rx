module rx.algorithm.timer;

import core.time;
import std.range : put;
import rx.disposable;
import rx.observer;
import rx.observable;
import rx.scheduler;


//#########################
// Timer
//#########################
auto timer(TScheduler : AsyncScheduler)(Duration wait, Duration interval, TScheduler scheduler)
{
	static struct TimerObservable
	{
	public:
		alias ElementType = size_t;

	public:
		this(Duration wait, Duration interval, TScheduler scheduler)
		{
			_wait = wait;
			_interval = interval;
			_scheduler = scheduler;
		}

	public:
		auto subscribe(TObserver)(auto ref TObserver observer)
		{
			auto disposable = new SignalDisposable;
			auto signal = disposable.signal;

			auto makePut = (ElementType val) {
				return {
					import std.range : put;
					observer.put(val);
				};
		 	};

			auto th = new Thread({
					Thread.sleep(_wait);

					if (!signal.signal) _scheduler.start(makePut(0));

                    import core.time;
                    auto nextTime = MonoTime.currTime;
                    size_t n = 1;
					while (!signal.signal)
					{
                        nextTime += _interval;

                        auto dt = nextTime - MonoTime.currTime;
                        if (dt > Duration.zero) Thread.sleep(dt);

						if (!signal.signal) _scheduler.start(makePut(n++));
					}
				});
            th.isDaemon = true;
            th.start();

			return disposable;
		}

	private:
		Duration _wait;
		Duration _interval;
		TScheduler _scheduler;
	}

	return TimerObservable(wait, interval, scheduler);
}

auto timer(Duration wait, Duration interval)
{
	return timer(wait, interval, new TaskPoolScheduler);
}

unittest
{
    import std.algorithm;
    import std.array;
    auto t = timer(dur!"msecs"(30), dur!"msecs"(50));
    auto buf = appender!(size_t[]);
    auto d = t.subscribe(buf);
    Thread.sleep(dur!"msecs"(200));
    d.dispose();
    assert(buf.data.length == 4);
    assert(equal(buf.data, [0, 1, 2, 3]));
}

//#########################
// Throttle
//#########################
ThrottleObservable!(T, TScheduler, T.ElementType) throttle(T, TScheduler : AsyncScheduler)(T observable, Duration val, TScheduler scheduler)
{
    return typeof(return)(observable, scheduler, val);
}
ThrottleObservable!(T, TaskPoolScheduler, T.ElementType) throttle(T)(T observable, Duration val)
{
    return typeof(return)(observable, new TaskPoolScheduler, val);
}

struct ThrottleObserver(TObserver, TScheduler, E)
{
public:
    this(TObserver observer, TScheduler scheduler, Duration val, SerialDisposable disposable)
    {
        _observer = observer;
        _scheduler = scheduler;
        _dueTime = val;
        _disposable = disposable;
    }
public:
    void put(E obj)
    {
        static if (hasFailure!TObserver)
        {
            try
            {
                _disposable.disposable = _scheduler.schedule({
                    try
                    {
                        _observer.put(obj);
                    }
                    catch (Exception e)
                    {
                        _observer.failure(e);
                        _disposable.dispose();
                    }
                }, _dueTime);
            }
            catch (Exception e)
            {
                _observer.failure(e);
                _disposable.dispose();
            }
        }
        else
        {
            _disposable.disposable = _scheduler.schedule({ _observer.put(obj); }, _dueTime);
        }
    }
    void completed()
    {
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _disposable.dispose();
    }
    void failure(Exception e)
    {
        static if (hasFailure!TObserver)
        {
            _observer.failure(e);
        }
        _disposable.dispose();
    }
private:
    TObserver _observer;
    TScheduler _scheduler;
    Duration _dueTime;
    SerialDisposable _disposable;
}
struct ThrottleObservable(TObservable, TScheduler, E)
{
    alias ElementType = E;
public:
    this(TObservable observable, TScheduler scheduler, Duration val)
    {
        _observable = observable;
        _scheduler = scheduler;
        _dueTime = val;
    }
public:
    auto subscribe(T)(T observer)
    {
        alias ObserverType = ThrottleObserver!(T, TScheduler, ElementType);
        auto inner = new SerialDisposable;
        auto outer = _observable.doSubscribe(ObserverType(observer, _scheduler, _dueTime, inner));
        return new CompositeDisposable(disposableObject(outer), inner);
    }
private:
    TObservable _observable;
    TScheduler _scheduler;
    Duration _dueTime;
}
unittest
{
    import std.array;
    import rx.subject;
    auto s = new TaskPoolScheduler;
    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub
        .throttle(dur!"msecs"(50), s)
        .doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;
    assert(equal(buf.data, [9]));
}
unittest
{
    import std.array;
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub
        .throttle(dur!"msecs"(50))
        .doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;
    assert(equal(buf.data, [9]));
}
unittest
{
    import std.array;
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub
        .throttle(dur!"msecs"(50))
        .doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    d.dispose();
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;
    assert(buf.data.length == 0);
}
unittest
{
    import std.array;
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub
        .throttle(dur!"msecs"(50))
        .doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    sub.completed();
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;
    assert(buf.data.length == 0);
}
unittest
{
    import std.array;
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub
        .throttle(dur!"msecs"(50))
        .doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    sub.failure(null);
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;
    assert(buf.data.length == 0);
}

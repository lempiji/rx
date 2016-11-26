module rx.algorithm.debounce;

import core.time;
import core.thread;
import std.range : put;
import rx.disposable;
import rx.observer;
import rx.observable;
import rx.scheduler;

//#########################
// Debounce
//#########################
DebounceObservable!(T, TScheduler, T.ElementType) debounce(T, TScheduler : AsyncScheduler)(
        T observable, Duration val, TScheduler scheduler)
{
    return typeof(return)(observable, scheduler, val);
}

DebounceObservable!(T, TaskPoolScheduler, T.ElementType) debounce(T)(T observable, Duration val)
{
    return typeof(return)(observable, new TaskPoolScheduler, val);
}

struct DebounceObserver(TObserver, TScheduler, E)
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
                        .put(_observer, obj);
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
            _disposable.disposable = _scheduler.schedule({ .put(_observer, obj); }, _dueTime);
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

struct DebounceObservable(TObservable, TScheduler, E)
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
        alias ObserverType = DebounceObserver!(T, TScheduler, ElementType);
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

    auto d = sub.debounce(dur!"msecs"(50), s).doSubscribe(buf);

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

    auto d = sub.debounce(dur!"msecs"(50)).doSubscribe(buf);

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

    auto d = sub.debounce(dur!"msecs"(50)).doSubscribe(buf);

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

    auto d = sub.debounce(dur!"msecs"(50)).doSubscribe(buf);

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

    auto d = sub.debounce(dur!"msecs"(50)).doSubscribe(buf);

    foreach (i; 0 .. 10)
    {
        sub.put(i);
    }
    sub.failure(null);
    Thread.sleep(dur!"msecs"(100));

    import std.algorithm : equal;

    assert(buf.data.length == 0);
}

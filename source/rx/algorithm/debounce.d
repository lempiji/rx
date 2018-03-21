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
///
DebounceObservable!(T, TScheduler, T.ElementType) debounce(T, TScheduler : AsyncScheduler)(
        T observable, Duration val, TScheduler scheduler)
{
    return typeof(return)(observable, scheduler, val);
}
///
DebounceObservable!(T, TaskPoolScheduler, T.ElementType) debounce(T)(T observable, Duration val)
{
    return typeof(return)(observable, new TaskPoolScheduler, val);
}
///
unittest
{
    import rx.subject : SubjectObject;
    import core.thread : Thread;
    import core.time : dur;

    auto obs = new SubjectObject!int;

    import std.array : appender;

    auto buf = appender!(int[]);
    auto d = obs.debounce(dur!"msecs"(100), new TaskPoolScheduler).doSubscribe(buf);
    scope (exit)
        d.dispose();

    .put(obs, 1);
    Thread.sleep(dur!"msecs"(200));
    .put(obs, 2);
    .put(obs, 3);
    Thread.sleep(dur!"msecs"(200));

    assert(buf.data.length == 2);
    assert(buf.data[0] == 1);
    assert(buf.data[1] == 3);
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
    import std.format : format;

    assert(equal(buf.data, [9]), "buf.data is %s".format(buf.data));
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

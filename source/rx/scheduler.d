module rx.scheduler;

import rx.disposable;
import rx.observer;
import rx.observable;

import core.time;
import core.thread : Thread;
import std.range : put;
import std.parallelism : TaskPool, taskPool, task;

///
interface Scheduler
{
    void start(void delegate() op);
}
///
interface AsyncScheduler : Scheduler
{
    CancellationToken schedule(void delegate() op, Duration val);
}

///
class LocalScheduler : Scheduler
{
public:
    void start(void delegate() op)
    {
        op();
    }
}
///
class ThreadScheduler : AsyncScheduler
{
    void start(void delegate() op)
    {
        auto t = new Thread(op);
        t.start();
    }
    CancellationToken schedule(void delegate() op, Duration val)
    {
        auto target = MonoTime.currTime + val;
        auto c = new CancellationToken;
        start({
            if (c.isCanceled) return;
            auto dt = target - MonoTime.currTime;
            if (dt > Duration.zero) Thread.sleep(dt);
            if (!c.isCanceled) op();
        });
        return c;
    }
}
///
class TaskPoolScheduler : AsyncScheduler
{
public:
    this(TaskPool pool = taskPool)
    {
        _pool = pool;
    }

public:
    void start(void delegate() op)
    {
        _pool.put(task(op));
    }
    CancellationToken schedule(void delegate() op, Duration val)
    {
        auto target = MonoTime.currTime + val;
        auto c = new CancellationToken;
        start({
            if (c.isCanceled) return;
            auto dt = target - MonoTime.currTime;
            if (dt > Duration.zero) Thread.sleep(dt);
            if (!c.isCanceled) op();
        });
        return c;
    }

private:
    TaskPool _pool;
}
///
class HistoricalScheduler(T) : AsyncScheduler
{
    static assert(is(T : AsyncScheduler));

public:
    this(T innerScheduler)
    {
        _offset = Duration.zero;
        _innerScheduler = innerScheduler;
    }

public:
    void start(void delegate() op)
    {
        _innerScheduler.start(op);
    }

    CancellationToken schedule(void delegate() op, Duration val)
    {
        return _innerScheduler.schedule(op, val - _offset);
    }

    void roll(Duration val) { _offset += val; }

private:
    T _innerScheduler;
    Duration _offset;
}
///
HistoricalScheduler!TScheduler historicalScheduler(TScheduler)(auto ref TScheduler scheduler)
{
    return new typeof(return)(scheduler);
}

unittest
{
    void test(AsyncScheduler scheduler)
    {
        bool done = false;
        auto c = scheduler.schedule((){ done = true; }, dur!"msecs"(50));
        assert(!done);
        Thread.sleep(dur!"msecs"(100));
        assert(done);
    }

    test(new ThreadScheduler);
    test(new TaskPoolScheduler);
    test(new HistoricalScheduler!ThreadScheduler(new ThreadScheduler));
    test(new HistoricalScheduler!TaskPoolScheduler(new TaskPoolScheduler));
}
unittest
{
    void test(AsyncScheduler scheduler)
    {
        bool done = false;
        auto c = scheduler.schedule((){ done = true; }, dur!"msecs"(50));
        c.cancel();
        Thread.sleep(dur!"msecs"(100));
        assert(!done);
    }

    test(new ThreadScheduler);
    test(new TaskPoolScheduler);
    test(new HistoricalScheduler!ThreadScheduler(new ThreadScheduler));
    test(new HistoricalScheduler!TaskPoolScheduler(new TaskPoolScheduler));
}

unittest
{
    import std.typetuple : TypeTuple;
    foreach (T; TypeTuple!(ThreadScheduler, TaskPoolScheduler))
    {
        auto scheduler = historicalScheduler(new T);
        
        scheduler.roll(dur!"seconds"(20));

        auto done = false;
        auto c = scheduler.schedule((){ done = true; }, dur!"seconds"(10));
        Thread.sleep(dur!"msecs"(10)); // wait for a context switch
        assert(done);
    }
}
unittest
{
    static assert(!__traits(compiles, { HistoricalScheduler!LocalScheduler s; }));
}

struct ObserveOnObserver(TObserver, TScheduler, E)
{
public:
    static if (hasFailure!TObserver)
    {
        this(TObserver observer, TScheduler scheduler, Disposable disposable)
        {
            _observer = observer;
            _scheduler = scheduler;
            _disposable = disposable;
        }
    }
    else
    {
        this(TObserver observer, TScheduler scheduler)
        {
            _observer = observer;
            _scheduler = scheduler;
        }
    }
public:
    void put(E obj)
    {
        _scheduler.start({
            static if (hasFailure!TObserver)
            {
                try
                {
                    _observer.put(obj);
                }
                catch (Exception e)
                {
                    _observer.failure(e);
                    _disposable.dispose();
                }
            }
            else
            {
                _observer.put(obj);
            }
        });
    }
    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _scheduler.start({
                _observer.completed();
            });
        }
    }
    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _scheduler.start({
                _observer.failure(e);
            });
        }
    }
private:
    TObserver _observer;
    TScheduler _scheduler;
    static if (hasFailure!TObserver)
    {
        Disposable _disposable;
    }
}

struct ObserveOnObservable(TObservable, TScheduler)
{
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable, TScheduler scheduler)
    {
        _observable = observable;
        _scheduler = scheduler;
    }
public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = ObserveOnObserver!(TObserver, TScheduler, TObservable.ElementType);
        static if (hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _scheduler, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer, _scheduler));
        }
    }
private:
    TObservable _observable;
    TScheduler _scheduler;
}

ObserveOnObservable!(TObservable, TScheduler) observeOn(TObservable, TScheduler : Scheduler)(auto ref TObservable observable, TScheduler scheduler)
{
    return typeof(return)(observable, scheduler);
}

unittest
{
    import std.concurrency;
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto scheduler = new LocalScheduler;
    auto scheduled = subject.observeOn(scheduler);

    import std.array : appender;
    auto buf = appender!(int[]);
    auto observer = observerObject!int(buf);

    auto d1 = scheduled.subscribe(buf);
    auto d2 = scheduled.subscribe(observer);

    subject.put(0);
    assert(buf.data.length == 2);

    subject.put(1);
    assert(buf.data.length == 4);
}
unittest
{
    import std.concurrency;
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto scheduler = new LocalScheduler;
    auto scheduled = subject.observeOn(scheduler);

    struct ObserverA
    {
        void put(int n) { }
    }
    struct ObserverB
    {
        void put(int n) { }
        void completed() { }
    }
    struct ObserverC
    {
        void put(int n) { }
        void failure(Exception e) { }
    }
    struct ObserverD
    {
        void put(int n) { }
        void completed() { }
        void failure(Exception e) { }
    }

    scheduled.doSubscribe(ObserverA());
    scheduled.doSubscribe(ObserverB());
    scheduled.doSubscribe(ObserverC());
    scheduled.doSubscribe(ObserverD());

    subject.put(1);
    subject.completed();
}
unittest
{
    import core.atomic;
    import core.sync.condition;
    import std.typetuple;
    import rx.util : EventSignal;
    enum N = 4;

    void test(Scheduler scheduler)
    {
        auto signal = new EventSignal;
        shared count = 0;
        foreach (n; 0 .. N)
        {
            scheduler.start((){
                atomicOp!"+="(count, 1);
                Thread.sleep(dur!"msecs"(50));
                if (atomicLoad(count) == N) signal.setSignal();
            });
        }
        signal.wait();
        assert(count == N);
    }

    test(new LocalScheduler);
    test(new ThreadScheduler);
    test(new TaskPoolScheduler);
    test(new HistoricalScheduler!ThreadScheduler(new ThreadScheduler));
    test(new HistoricalScheduler!TaskPoolScheduler(new TaskPoolScheduler));
}

private __gshared Scheduler s_scheduler;
shared static this()
{
    s_scheduler = new TaskPoolScheduler;
}

Scheduler currentScheduler() @property
{
    return s_scheduler;
}
TScheduler currentScheduler(TScheduler : Scheduler)(TScheduler scheduler) @property
{
    s_scheduler = scheduler;
    return scheduler;
}

unittest
{
    Scheduler s = currentScheduler;
    scope(exit) currentScheduler = s;

    TaskPoolScheduler s1 = new TaskPoolScheduler;
    TaskPoolScheduler s2 = currentScheduler = s1;
    assert(s2 is s1);
}

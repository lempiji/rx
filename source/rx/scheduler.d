/++
 + This module defines the concept of Scheduler.
 +/
module rx.scheduler;

import rx.disposable;
import rx.observer;
import rx.observable;

import core.time;
import core.thread : Thread;
import std.range : put;
import std.parallelism : TaskPool, taskPool, task;
import std.container.binaryheap;
import std.datetime.stopwatch;

//Note:
// In single core, taskPool's worker are not initialized.
// Some asynchronous algorithm does not work as expected, so at least 1 thread is reserved.
version (Disable_ReservePoolThreadsOnSingleCore)
{
}
else
{
    shared static this()
    {
        import std.parallelism : defaultPoolThreads;

        if (defaultPoolThreads == 0)
            defaultPoolThreads = 1;
    }
}

///
enum isScheduler(T) = is(typeof({
            T scheduler = void;

            void delegate() work = null;
            Duration time = void;
            auto disposable = scheduler.schedule(work, time);
            static assert(isDisposable!(typeof(disposable)));
        }));

///
unittest
{
    static assert(isScheduler!Scheduler);
    static assert(isScheduler!ImmediateScheduler);
    static assert(isScheduler!ThreadScheduler);
    static assert(isScheduler!TaskPoolScheduler);
    static assert(isScheduler!(HistoricalScheduler!ThreadScheduler));
    static assert(isScheduler!(HistoricalScheduler!TaskPoolScheduler));
}

///
interface Scheduler
{
    ///
    Disposable schedule(void delegate() op, Duration val);
}

///
class ImmediateScheduler : Scheduler
{
public:
    ///
    Disposable schedule(void delegate() op, Duration dueTime)
    {
        if (dueTime > Duration.zero)
            Thread.sleep(dueTime);
        op();
        return NopDisposable.instance;
    }
}

///
class ThreadScheduler : Scheduler
{
    ///
    Disposable schedule(void delegate() op, Duration val)
    {
        auto target = MonoTime.currTime + val;
        auto c = new CancellationToken;
        auto t = new Thread({
            if (c.isCanceled)
                return;
            auto dt = target - MonoTime.currTime;
            if (dt > Duration.zero)
                Thread.sleep(dt);
            if (!c.isCanceled)
                op();
        });
        t.start();
        return c;
    }
}

unittest
{
    import std.stdio : writeln;

    writeln("Testing ThreadScheduler...");
    scope (exit)
        writeln("ThreadScheduler test is completed.");

    import rx.util : EventSignal;

    auto scheduler = new ThreadScheduler;
    auto signal = new EventSignal;
    auto done = false;
    auto c = scheduler.schedule({ done = true; signal.setSignal(); }, 10.msecs);

    signal.wait();
    assert(done);
    assert(!(cast(CancellationToken) c).isCanceled);
}

///
class TaskPoolScheduler : Scheduler
{
public:
    ///
    this(TaskPool pool = null)
    {
        if (pool is null)
            pool = taskPool;

        _pool = pool;
    }

public:
    ///
    Disposable schedule(void delegate() op, Duration val)
    {
        auto target = MonoTime.currTime + val;
        auto c = new CancellationToken;
        _pool.put(task({
                if (c.isCanceled)
                    return;
                auto dt = target - MonoTime.currTime;
                if (dt > Duration.zero)
                    Thread.sleep(dt);
                if (!c.isCanceled)
                    op();
            }));
        return c;
    }

private:
    TaskPool _pool;
}

unittest
{
    import std.stdio : writeln;
    import std.parallelism : totalCPUs, defaultPoolThreads;

    writeln("Testing TaskPoolScheduler...");
    scope (exit)
        writeln("TaskPoolScheduler test is completed.");

    version (OSX)
    {
        writeln("totalCPUs: ", totalCPUs);
        writeln("defaultPoolThreads: ", defaultPoolThreads);
    }

    import rx.util : EventSignal;

    auto scheduler = new TaskPoolScheduler;
    auto signal = new EventSignal;
    auto done = false;
    auto c = scheduler.schedule({ done = true; signal.setSignal(); }, 10.msecs);

    signal.wait();
    assert(done);
    assert(!(cast(CancellationToken) c).isCanceled);
}

///
class HistoricalScheduler(T) : Scheduler
{
    static assert(is(T : Scheduler));

public:
    ///
    this(T innerScheduler)
    {
        this(innerScheduler, Duration.zero);
    }

    this(T innerScheduler, Duration offset)
    {
        _innerScheduler = innerScheduler;
        _offset = offset;
    }

public:
    ///
    Disposable schedule(void delegate() op, Duration val)
    {
        return _innerScheduler.schedule(op, val - _offset);
    }

    void roll(Duration val)
    {
        _offset += val;
    }

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
    import std.stdio : writeln;

    writeln("Testing HistoricalScheduler...");
    scope (exit)
        writeln("HistoricalScheduler test is completed.");

    void test(Scheduler scheduler)
    {
        import rx.util : EventSignal;

        bool done = false;
        auto signal = new EventSignal;

        auto c = scheduler.schedule(() { done = true; signal.setSignal(); }, dur!"msecs"(100));
        assert(!done);

        signal.wait();
        assert(done);
        assert(!(cast(CancellationToken) c).isCanceled);
    }

    //test(new ThreadScheduler);
    //test(new TaskPoolScheduler);
    test(new HistoricalScheduler!ThreadScheduler(new ThreadScheduler));
    test(new HistoricalScheduler!TaskPoolScheduler(new TaskPoolScheduler));
}

unittest
{
    void test(Scheduler scheduler)
    {
        bool done = false;
        auto c = scheduler.schedule(() { done = true; }, dur!"msecs"(50));
        c.dispose();
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
        auto c = scheduler.schedule(() { done = true; }, dur!"seconds"(10));
        Thread.sleep(dur!"msecs"(10)); // wait for a context switch
        assert(done);
    }
}

unittest
{
    static assert(__traits(compiles, { HistoricalScheduler!ImmediateScheduler s; }));
}

///
final class SchedulerObject(TScheduler) : Scheduler
{
private:
    TScheduler scheduler;

public:
    ///
    this(TScheduler scheduler)
    {
        this.scheduler = scheduler;
    }

    ///
    this(ref TScheduler scheduler)
    {
        this.scheduler = scheduler;
    }

    ///
    Disposable schedule(void delegate() op, Duration val)
    {
        return scheduler.schedule(op, val).disposableObject();
    }
}

unittest
{
    auto inner = new ImmediateScheduler;
    auto scheduler = new SchedulerObject!Scheduler(inner);
}

///
auto schedulerObject(TScheduler)(TScheduler scheduler)
{
    static assert(isScheduler!TScheduler);

    static if (is(TScheduler : Scheduler))
        return scheduler;
    else static if (isScheduler!TScheduler)
        return new SchedulerObject!TScheduler(scheduler);
    else
        static assert(false);
}

///
unittest
{
    struct MyDisposable
    {
        void dispose()
        {
        }
    }

    struct MyScheduler
    {
        MyDisposable schedule(void delegate() op, Duration val)
        {
            return MyDisposable();
        }
    }

    class MyClassScheduler
    {
        Disposable schedule(void delegate() op, Duration val)
        {
            return null;
        }
    }

    class MyClassDerivedScheduler : Scheduler
    {
        Disposable schedule(void delegate() op, Duration val)
        {
            return null;
        }
    }

    static assert(isScheduler!MyScheduler);
    static assert(isScheduler!MyClassScheduler);
    static assert(isScheduler!MyClassDerivedScheduler);

    auto s1 = MyScheduler();
    auto s2 = new MyClassScheduler;
    auto s3 = new MyClassDerivedScheduler;

    Scheduler t1 = s1.schedulerObject();
    Scheduler t2 = s2.schedulerObject();
    Scheduler t3 = s3.schedulerObject();

    assert(t1 !is null);
    assert(t2 !is null);
    assert(t3 !is null);
    assert(t3 is s3);
}

///
unittest
{
    struct MyScheduler
    {
        Disposable schedule(void delegate() op, Duration dueTime)
        {
            if (dueTime > Duration.zero)
                Thread.sleep(dueTime);

            op();
            return NopDisposable.instance;
        }
    }

    MyScheduler scheduler;
    Scheduler wrapped = scheduler.schedulerObject();
    assert(wrapped !is null);
}

///
struct ObserveOnObserver(TObserver, TScheduler, E)
{
public:
    static if (hasFailure!TObserver)
    {
        ///
        this(TObserver observer, TScheduler scheduler, Disposable disposable)
        {
            _observer = observer;
            _scheduler = scheduler;
            _disposable = disposable;
        }
    }
    else
    {
        ///
        this(TObserver observer, TScheduler scheduler)
        {
            _observer = observer;
            _scheduler = scheduler;
        }
    }
public:
    ///
    void put(E obj)
    {
        _scheduler.schedule({
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
        }, Duration.zero);
    }

    static if (hasCompleted!TObserver)
    {
        ///
        void completed()
        {
            _scheduler.schedule({ _observer.completed(); }, Duration.zero);
        }
    }
    static if (hasFailure!TObserver)
    {
        ///
        void failure(Exception e)
        {
            _scheduler.schedule({ _observer.failure(e); }, Duration.zero);
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

///
struct ObserveOnObservable(TObservable, TScheduler : Scheduler)
{
    alias ElementType = TObservable.ElementType;
public:
    ///
    this(TObservable observable, TScheduler scheduler)
    {
        _observable = observable;
        _scheduler = scheduler;
    }

public:
    ///
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = ObserveOnObserver!(TObserver, TScheduler, TObservable.ElementType);
        static if (hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable,
                    ObserverType(observer, _scheduler, disposable))));
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

unittest
{
    alias TestObservable = ObserveOnObservable!(Observable!int, Scheduler);
    static assert(isObservable!(TestObservable, int));

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto scheduler = new ImmediateScheduler;

    auto scheduled = TestObservable(sub, scheduler);

    auto flag1 = false;
    auto d = scheduled.subscribe((int n) { flag1 = true; });
    scope (exit)
        d.dispose();
    .put(sub, 1);
    assert(flag1);

    auto flag2 = false;
    auto d2 = scheduled.doSubscribe((int n) { flag2 = true; });
    scope (exit)
        d2.dispose();
    .put(sub, 2);
    assert(flag2);
}

///
ObserveOnObservable!(TObservable, TScheduler) observeOn(TObservable, TScheduler : Scheduler)(
        auto ref TObservable observable, TScheduler scheduler)
{
    return typeof(return)(observable, scheduler);
}

///
unittest
{
    import std.concurrency;
    import rx.subject;

    auto subject = new SubjectObject!int;
    auto scheduler = new ImmediateScheduler;
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
    auto scheduler = new ImmediateScheduler;
    auto scheduled = subject.observeOn(scheduler);

    struct ObserverA
    {
        void put(int n)
        {
        }
    }

    struct ObserverB
    {
        void put(int n)
        {
        }

        void completed()
        {
        }
    }

    struct ObserverC
    {
        void put(int n)
        {
        }

        void failure(Exception e)
        {
        }
    }

    struct ObserverD
    {
        void put(int n)
        {
        }

        void completed()
        {
        }

        void failure(Exception e)
        {
        }
    }

    scheduled.doSubscribe(ObserverA());
    scheduled.doSubscribe(ObserverB());
    scheduled.doSubscribe(ObserverC());
    scheduled.doSubscribe(ObserverD());

    subject.put(1);
    subject.completed();
}

///
class SubscribeOnObservable(TObservable, TScheduler : Scheduler)
{
    alias ElementType = TObservable.ElementType;

public:
    ///
    this(TObservable observable, TScheduler scheduler)
    {
        _observable = observable;
        _scheduler = scheduler;
    }

public:
    ///
    auto subscribe(TObserver)(TObserver observer)
    {
        auto disposable = new SingleAssignmentDisposable;
        auto cancel = _scheduler.schedule({
            auto temp = doSubscribe(_observable, observer);
            disposable.setDisposable(disposableObject(temp));
        }, Duration.zero);
        return new CompositeDisposable(disposable, cancel);
    }

private:
    TObservable _observable;
    TScheduler _scheduler;
}

unittest
{
    alias TestObservable = SubscribeOnObservable!(Observable!int, Scheduler);
    static assert(isObservable!(TestObservable, int));

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto scheduler = new ImmediateScheduler;

    auto scheduled = new TestObservable(sub, scheduler);

    auto flag1 = false;
    auto d = scheduled.subscribe((int n) { flag1 = true; });
    scope (exit)
        d.dispose();
    .put(sub, 1);
    assert(flag1);

    auto flag2 = false;
    auto d2 = scheduled.doSubscribe((int n) { flag2 = true; });
    scope (exit)
        d2.dispose();
    .put(sub, 2);
    assert(flag2);
}

///
SubscribeOnObservable!(TObservable, TScheduler) subscribeOn(TObservable, TScheduler : Scheduler)(
        auto ref TObservable observable, auto ref TScheduler scheduler)
{
    return new typeof(return)(observable, scheduler);
}
///
unittest
{
    import rx.observable : defer;

    auto sub = defer!int((Observer!int observer) {
        .put(observer, 100);
        return NopDisposable.instance;
    });
    auto scheduler = new ImmediateScheduler;

    auto scheduled = sub.subscribeOn(scheduler);

    int value = 0;
    auto d = scheduled.doSubscribe((int n) { value = n; });
    scope (exit)
        d.dispose();

    assert(value == 100);
}
///
unittest
{
    import rx.observable : defer;
    import rx.util : EventSignal;

    auto sub = defer!int((Observer!int observer) {
        .put(observer, 100);
        return NopDisposable.instance;
    });
    auto scheduler = new TaskPoolScheduler;
    auto scheduled = sub.subscribeOn(scheduler);

    int value = 0;
    auto signal = new EventSignal;
    auto d = scheduled.subscribe((int n) { value = n; signal.setSignal(); });
    scope (exit)
        d.dispose();

    signal.wait();
    assert(value == 100);
}

unittest
{
    import std.algorithm : equal;
    import std.array : Appender;
    import rx.util : EventSignal;

    auto buf = Appender!(int[])();
    auto data = [1, 2, 3, 4];

    auto event = new EventSignal;
    auto observer = (int n) {
        buf.put(n);
        if (n == 4)
            event.setSignal();
    };
    data.asObservable().subscribeOn(new ThreadScheduler).subscribe(observer);

    event.wait();

    assert(equal(buf.data, data));
}

unittest
{
    import std.algorithm : equal;
    import std.array : Appender;
    import rx.util : EventSignal;

    auto buf = Appender!(int[])();
    auto data = [1, 2, 3, 4];

    auto event = new EventSignal;
    auto observer = (int n) {
        buf.put(n);
        if (n == 4)
            event.setSignal();
    };
    data.asObservable().subscribeOn(new ThreadScheduler).doSubscribe(observer);

    event.wait();

    assert(equal(buf.data, data));
}

unittest
{
    import rx.util : EventSignal;

    auto data = [1, 2, 3, 4];
    auto event = new EventSignal();

    data.asObservable().subscribeOn(new ThreadScheduler).subscribe((int a) {
        if (a == 4)
            event.setSignal();
    });

    event.wait();
}

unittest
{
    import rx.util : EventSignal;

    auto data = [1, 2, 3, 4];
    auto event = new EventSignal();

    data.asObservable().subscribeOn(new ThreadScheduler).doSubscribe((int a) {
        if (a == 4)
            event.setSignal();
    });

    event.wait();
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
            scheduler.schedule(() {
                atomicOp!"+="(count, 1);
                Thread.sleep(dur!"msecs"(50));
                if (atomicLoad(count) == N)
                    signal.setSignal();
            }, Duration.zero);
        }
        signal.wait();
        assert(count == N);
    }

    test(new ImmediateScheduler);
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

///
Scheduler currentScheduler() @property
{
    return s_scheduler;
}

///
TScheduler currentScheduler(TScheduler : Scheduler)(TScheduler scheduler) @property
{
    s_scheduler = scheduler;
    return scheduler;
}

unittest
{
    Scheduler s = currentScheduler;
    scope (exit)
        currentScheduler = s;

    TaskPoolScheduler s1 = new TaskPoolScheduler;
    TaskPoolScheduler s2 = currentScheduler = s1;
    assert(s2 is s1);
}

private struct ScheduleItem
{
    CancellationToken disposable;
    Duration dueTime;
    void delegate() action;

    this(Duration dueTime, void delegate() action)
    {
        this.disposable = new CancellationToken;
        this.dueTime = dueTime;
        this.action = action;
    }

    bool isCanceled() @property
    {
        return disposable.isDisposed;
    }

    int opCmp(const ScheduleItem rhs) const
    {
        return dueTime.opCmp(rhs.dueTime);
    }
}

unittest
{
    bool flag = false;
    auto item = ScheduleItem(1.seconds, () { flag = true; });
    assert(!flag);
    assert(!item.isCanceled);
    item.action();
    assert(flag);
    assert(!item.isCanceled);
}

unittest
{
    bool flag = false;
    auto item = ScheduleItem(1.seconds, () { flag = true; });
    auto disposable = item.disposable;

    disposable.dispose();
    if (!item.isCanceled)
        item.action();
    assert(item.isCanceled);
    assert(!flag);
}

private class SchedulerQueue
{
    alias Queue = BinaryHeap!(ScheduleItem[], "a > b");

    Queue queue; // min heap

    this()
    {
        this.queue = Queue([], 4);
    }

    bool empty()
    {
        return queue.empty;
    }

    void enqueue(ScheduleItem item)
    {
        queue.insert(item);
    }

    ScheduleItem dequeue()
    {
        return queue.removeAny();
    }
}

unittest
{
    auto queue = new SchedulerQueue;
    queue.enqueue(ScheduleItem(1.seconds, null));
    queue.enqueue(ScheduleItem(2.seconds, null));

    auto item0 = queue.dequeue();
    assert(item0.dueTime == 1.seconds);
    auto item1 = queue.dequeue();
    assert(item1.dueTime == 2.seconds);
}

///
class CurrentThreadScheduler : Scheduler
{
    private static SchedulerQueue currentThreadQueue;
    private static StopWatch stopwatch;

    private Duration time()
    {
        if (stopwatch is StopWatch.init)
            stopwatch = StopWatch(AutoStart.yes);

        return stopwatch.peek();
    }

    ///
    void start(void delegate() op)
    {
        schedule(op, Duration.zero);
    }

    ///
    Disposable schedule(void delegate() op, Duration dueTime)
    {
        auto item = ScheduleItem(time() + dueTime, op);

        if (currentThreadQueue is null)
        {
            currentThreadQueue = new SchedulerQueue;
            scope (exit)
                currentThreadQueue = null;

            currentThreadQueue.enqueue(item);

            while (!currentThreadQueue.empty)
            {
                auto work = currentThreadQueue.dequeue();
                auto dt = work.dueTime - time();

                if (dt > Duration.zero)
                {
                    Thread.sleep(dt);
                }

                if (!work.isCanceled)
                    work.action();
            }
        }
        else
        {
            currentThreadQueue.enqueue(item);
        }

        return item.disposable;
    }
}

unittest
{
    auto current = new CurrentThreadScheduler;

    size_t count = 0;
    void pushTask()
    {
        count++;
        if (count < 5)
        {
            current.schedule(&pushTask, (count * 10).msecs);
        }
    }

    const start = MonoTime.currTime;
    current.start(&pushTask);
    const end = MonoTime.currTime;

    import std.conv : to;

    assert(end - start > 99.msecs, "time : " ~ to!string(end - start));
    // This test failed on OSX on Travis-CI. Excluded because it depends on performance.
    // assert(end - start < 105.msecs, "time : " ~ to!string(end - start));
    assert(count == 5);
}

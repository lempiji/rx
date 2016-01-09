module rx.scheduler;

import rx.disposable;
import rx.observer;
import rx.observable;

import std.range : put;
import std.concurrency : Scheduler;


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
    auto scheduler = new FiberScheduler;
    auto fibered = subject.observeOn(scheduler);

    import std.array : appender;
    auto buf = appender!(int[]);
    auto observer = observerObject!int(buf);

    auto d1 = fibered.subscribe(buf);
    auto d2 = fibered.subscribe(observer);

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
    auto scheduler = new FiberScheduler;
    auto fibered = subject.observeOn(scheduler);

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

    fibered.doSubscribe(ObserverA());
    fibered.doSubscribe(ObserverB());
    fibered.doSubscribe(ObserverC());
    fibered.doSubscribe(ObserverD());

    subject.put(1);
    subject.completed();
}

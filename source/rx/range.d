module rx.range;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import core.atomic : cas, atomicLoad;
import std.range : put;

//####################
// Overview
//####################
unittest
{
    import rx.subject;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;

    auto subject = new SubjectObject!int;
    auto pub = subject
        .drop(2)
        .take(3);

    auto buf = appender!(int[]);
    auto disposable = pub.subscribe(observerObject!int(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, [2, 3, 4]));
}

//####################
// Drop
//####################
struct DropObserver(TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);
public:
    this(TObserver observer, size_t count)
    {
        _observer = observer;
        _counter = new shared(AtomicCounter)(count);
    }
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(TObserver observer, size_t count, Disposable disposable)
        {
            _observer = observer;
            _counter = new shared(AtomicCounter)(count);
            _disposable = disposable;
        }
    }
private:
    void putImpl(E obj)
    {
        if (_counter.tryUpdateCount())
        {
            _observer.put(obj);
        }
    }
private:
    shared(AtomicCounter) _counter;
}
struct DropObservable(TObservable)
{
public:
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable, size_t n)
    {
        _observable = observable;
        _count = n;
    }
public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = DropObserver!(TObserver, ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _count, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer, _count));
        }
    }
private:
    TObservable _observable;
    size_t _count;
}
auto drop(TObservable)(auto ref TObservable observable, size_t n)
{
    return DropObservable!TObservable(observable, n);
}
unittest
{
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto dropped = subject.drop(1);
    static assert(isObservable!(typeof(dropped), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = dropped.subscribe(buf);

    subject.put(0);
    assert(buf.data.length == 0);
    subject.put(1);
    assert(buf.data.length == 1);

    auto buf2 = appender!(int[]);
    dropped.subscribe(buf2);
    assert(buf2.data.length == 0);
    subject.put(2);
    assert(buf2.data.length == 0);
    assert(buf.data.length == 2);
    subject.put(3);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 3);
}


//####################
// Take
//####################
struct TakeObserver(TObserver, E)
{
public:
    this(TObserver observer, size_t count, Disposable disposable)
    {
        _observer = observer;
        _count = count;
        _disposable = disposable;
    }
public:
    void put(E obj)
    {
        shared(size_t) oldValue = void;
        size_t newValue = void;
        do
        {
            oldValue = _count;
            if (oldValue == 0) return;

            newValue = atomicLoad(oldValue) - 1;
        } while(!cas(&_count, oldValue, newValue));

        _observer.put(obj);
        if (newValue == 0)
        {
            static if (hasCompleted!TObserver)
            {
                _observer.completed();
            }
            _disposable.dispose();
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
    shared(size_t) _count;
    Disposable _disposable;
}

struct TakeObservable(TObservable)
{
public:
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable, size_t n)
    {
        _observable = observable;
        _count = n;
    }
public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = TakeObserver!(TObserver, ElementType);
        auto disposable = new SingleAssignmentDisposable;
        disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _count, disposable))));
        return disposable;
    }
private:
    TObservable _observable;
    size_t _count;
}

auto take(TObservable)(auto ref TObservable observable, size_t n)
{
    return TakeObservable!TObservable(observable, n);
}
unittest
{
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto taken = subject.take(1);
    static assert(isObservable!(typeof(taken), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = taken.subscribe(buf);

    subject.put(0);
    assert(buf.data.length == 1);
    subject.put(1);
    assert(buf.data.length == 1);

    auto buf2 = appender!(int[]);
    taken.subscribe(buf2);
    assert(buf2.data.length == 0);
    subject.put(2);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 1);
    subject.put(3);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 1);
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto taken = sub.take(2);

    int countPut = 0;
    int countCompleted = 0;
    struct TestObserver
    {
        void put(int n) { countPut++; }
        void completed() { countCompleted++; }
    }

    auto d = taken.doSubscribe(TestObserver());
    assert(countPut == 0);
    sub.put(1);
    assert(countPut == 1);
    assert(countCompleted == 0);
    sub.put(2);
    assert(countPut == 2);
    assert(countCompleted == 1);
}


//####################
// TakeLast
//####################
auto takeLast(TObservable)(auto ref TObservable observable)
{
    static struct TakeLastObservable
    {
    public:
        alias ElementType = TObservable.ElementType;

    public:
        this(ref TObservable observable)
        {
            _observable = observable;
        }

    public:
        auto subscribe(TObserver)(auto ref TObserver observer)
        {
            static class TakeLastObserver
            {
            public:
                this(ref TObserver observer, SingleAssignmentDisposable disposable)
                {
                    _observer = observer;
                    _disposable = disposable;
                }

            public:
                void put(ElementType obj)
                {
                    _current = obj;
                    _hasValue = true;
                }

                void completed()
                {
                    if (_hasValue) _observer.put(_current);

                    static if (hasCompleted!TObserver)
                    {
                        _observer.completed();
                    }
                    _disposable.dispose();
                }

                static if (hasFailure!TObserver)
                {
                    void failure(Exception e)
                    {
                        _observer.failure(e);
                    }
                }

            private:
                bool _hasValue = false;
                ElementType _current;
                TObserver _observer;
                SingleAssignmentDisposable _disposable;
            }

            auto d = new SingleAssignmentDisposable;
            d.setDisposable(disposableObject(doSubscribe(_observable, new TakeLastObserver(observer, d))));
            return d;
        }

    private:
        TObservable _observable;
    }

    return TakeLastObservable(observable);
}

unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception e) { failureCount++; }
    }

    auto d = sub.takeLast.subscribe(TestObserver());

    assert(putCount == 0);
    sub.put(1);
    assert(putCount == 0);
    sub.put(10);
    assert(putCount == 0);
    sub.completed();
    assert(putCount == 1);
    assert(completedCount == 1);
    sub.put(100);
    assert(putCount == 1);
    assert(completedCount == 1);
}

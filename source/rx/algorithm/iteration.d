module rx.algorithm.iteration;

import rx.disposable;
import rx.observer;
import rx.observable;

import core.atomic : cas, atomicLoad;
import std.functional : unaryFun;
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
        .filter!(n => n % 2 == 0)
        .map!(o => to!string(o))
        .drop(1)
        .take(3);

    auto buf = appender!(string[]);
    auto disposable = pub.subscribe(observerObject!string(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["2", "4", "6"]));
}

//####################
// Filter
//####################
struct FilterObserver(alias f, TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);

public:
    this(TObserver observer)
    {
        _observer = observer;
    }
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(TObserver observer, Disposable disposable)
        {
            _observer = observer;
            _disposable = disposable;
        }
    }
private:
    void putImpl(E obj)
    {
        alias fun = unaryFun!f;
        if (fun(obj)) _observer.put(obj);
    }
}
unittest
{
    alias TObserver = FilterObserver!(o => true, Observer!int, int);

    static assert(isObserver!(TObserver, int));
}

struct FilterObservable(alias f, TObservable)
{
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = FilterObserver!(f, TObserver, ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer));
        }
    }

private:
    TObservable _observable;
}
unittest
{
    import rx.subject;

    alias TObservable = FilterObservable!(o => true, Subject!int);

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception) { failureCount++; }
    }

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);
    auto disposable = observable.subscribe(TestObserver());
    assert(putCount == 0);
    sub.put(0);
    assert(putCount == 1);
    sub.put(1);
    assert(putCount == 2);
    disposable.dispose();
    sub.put(2);
    assert(putCount == 2);
}

template filter(alias f)
{
    FilterObservable!(f, TObservable) filter(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!(n => n % 2 == 0);
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}
unittest
{
    import rx.subject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!"a % 2 == 0";
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}

//####################
// Map
//####################
struct MapObserver(alias f, TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);

public:
    this(TObserver observer)
    {
        _observer = observer;
    }
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(TObserver observer, Disposable disposable)
        {
            _observer = observer;
            _disposable = disposable;
        }
    }
private:
    void putImpl(E obj)
    {
        alias fun = unaryFun!f;
        _observer.put(fun(obj));
    }
}
unittest
{
    import std.conv : to;
    alias TObserver = MapObserver!(o => to!string(o), Observer!string, int);

    static assert(isObserver!(TObserver, int));
}

struct MapObservable(alias f, TObservable)
{
    alias ElementType = typeof({ return unaryFun!(f)(TObservable.ElementType.init); }());
public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = MapObserver!(f, TObserver, TObservable.ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer));
        }
    }

private:
    TObservable _observable;
}
unittest
{
    import rx.subject;
    import std.conv : to;

    alias TObservable = MapObservable!(n => to!string(n), Subject!int);
    static assert(is(TObservable.ElementType : string));
    static assert(isSubscribable!(TObservable, Observer!string));

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(string n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception) { failureCount++; }
    }

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);
    auto disposable = observable.subscribe(TestObserver());
    assert(putCount == 0);
    sub.put(0);
    assert(putCount == 1);
    sub.put(1);
    assert(putCount == 2);
    disposable.dispose();
    sub.put(2);
    assert(putCount == 2);
}

template map(alias f)
{
    MapObservable!(f, TObservable) map(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    import std.array : appender;
    import std.conv : to;

    Subject!int sub = new SubjectObject!int;
    auto mapped = sub.map!(n => to!string(n));
    static assert(isObservable!(typeof(mapped), string));
    static assert(isSubscribable!(typeof(mapped), Observer!string));

    auto buffer = appender!(string[])();
    auto disposable = mapped.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    import std.algorithm : equal;
    assert(equal(buffer.data, ["0", "1", "2"][]));
}
unittest
{
    import rx.subject;
    import std.array : appender;
    import std.conv : to;

    Subject!int sub = new SubjectObject!int;
    auto mapped = sub.map!"a * 2";
    static assert(isObservable!(typeof(mapped), int));
    static assert(isSubscribable!(typeof(mapped), Observer!int));

    auto buffer = appender!(int[])();
    auto disposable = mapped.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2, 4][]));
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
        if (_counter.tryUpdateCount()) return;
        _observer.put(obj);
    }
private:
    shared(AtomicCounter) _counter;
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
//####################
// Util
//####################
package shared class AtomicCounter
{
public:
    this(size_t n)
    {
        _count = n;
    }
public:
    bool tryUpdateCount() @trusted
    {
        shared(size_t) oldValue = void;
        size_t newValue = void;
        do
        {
            oldValue = _count;
            if (oldValue == 0)
                return true;

            newValue = oldValue - 1;
        } while (!cas(&_count, oldValue, newValue));

        return false;
    }
private:
    size_t _count;
}

private mixin template SimpleObserverImpl(TObserver, E)
{
public:
    void put(E obj)
    {
        static if (hasFailure!TObserver)
        {
            try
            {
                putImpl(obj);
            }
            catch(Exception e)
            {
                _observer.failure(e);
                _disposable.dispose();
            }
        }
        else
        {
            putImpl(obj);
        }
    }
    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
            _disposable.dispose();
        }
    }
    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
            _disposable.dispose();
        }
    }
private:
    TObserver _observer;
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        Disposable _disposable;
    }
}

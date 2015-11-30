module rx.algorithm.iteration;

import rx.observer;
import rx.observable;

import core.atomic : cas, atomicLoad;

import std.functional : unaryFun;
import std.range : put;
import std.typecons : RefCounted, refCounted;

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
        .map!(o => to!string(o));

    auto buf = appender!(string[]);
    auto disposable = pub.subscribe(buf);

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}

//####################
// Filter
//####################
struct FilterObserver(alias f, TObserver, E)
{
public:
    this(TObserver observer)
    {
        _observer = observer;
    }

public:
    void put(E obj)
    {
        alias fun = unaryFun!f;
        if (fun(obj)) _observer.put(obj);
    }

    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
        }
    }

    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
        }
    }

private:
    TObserver _observer;
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
        return doSubscribe(_observable, ObserverType(observer));
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
public:
    this(TObserver observer)
    {
        _observer = observer;
    }

public:
    void put(E obj)
    {
        alias fun = unaryFun!f;
        _observer.put(fun(obj));
    }

    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
        }
    }

    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
        }
    }

private:
    TObserver _observer;
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
        return doSubscribe(_observable, ObserverType(observer));
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
public:
    this(TObserver observer, DropObservablePayload payload)
    {
        _observer = observer;
        _payload = payload;
    }
public:
    void put(E obj)
    {
        if (_payload.tryUpdateCount())
        {
            _observer.put(obj);
        }
    }

    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
        }
    }

    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
        }
    }
private:
    TObserver _observer;
    DropObservablePayload _payload;
}
package class DropObservablePayload
{
public:
    this(size_t n)
    {
        _count = n;
    }
public:
    bool tryUpdateCount()
    {
        shared(size_t) oldValue = void;
        size_t newValue = void;
        do
        {
            oldValue = _count;
            if (atomicLoad(oldValue) == 0)
                return true;

            newValue = oldValue - 1;
        } while (!cas(&_count, oldValue, newValue));

        return false;
    }
private:
    shared(size_t) _count;
}
struct DropObservable(TObservable)
{
public:
    alias ElementType = TObservable.ElementType;
public:
    this(TObservable observable, size_t n)
    {
        _observable = observable;
        _payload = new DropObservablePayload(n);
    }
public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = DropObserver!(TObserver, ElementType);
        return doSubscribe(_observable, ObserverType(observer, _payload));
    }
private:
    TObservable _observable;
    DropObservablePayload _payload;
}
auto drop(TObservable)(ref TObservable observable, size_t n)
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
    assert(buf2.data.length == 1);
    assert(buf.data.length == 2);
}

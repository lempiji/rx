/+++++++++++++++++++++++++++++
 + This module defines algorithm 'map'
 +/
module rx.algorithm.map;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.functional;
import std.range;

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

///
template map(alias f)
{
    MapObservable!(f, TObservable) map(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
///
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
    scope(exit) disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);

    import std.algorithm : equal;
    assert(equal(buffer.data, ["0", "1", "2"][]));
}
///
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
    scope(exit) disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);

    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2, 4][]));
}

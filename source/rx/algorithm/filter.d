/+++++++++++++++++++++++++++++
 + This module defines algorithm 'filter'
 +/
module rx.algorithm.filter;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : unaryFun;
import std.range : put;

//####################
// Filter
//####################
///Implements the higher order filter function. The predicate is passed to std.functional.unaryFun, and can either accept a string, or any callable that can be executed via pred(element).
template filter(alias pred)
{
    auto filter(TObservable)(auto ref TObservable observable)
    {
        return FilterObservable!(pred, TObservable)(observable);
    }
}

///
unittest
{
    import rx.subject : Subject, SubjectObject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!(n => n % 2 == 0);
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    scope (exit)
        disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);

    import std.algorithm : equal;

    assert(equal(buffer.data, [0, 2][]));
}

unittest
{
    import rx.subject : Subject, SubjectObject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!"a % 2 == 0";
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    scope (exit)
        disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);

    import std.algorithm : equal;

    assert(equal(buffer.data, [0, 2][]));
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!(int[]);

    auto sum = 0;
    auto observer = (int n) { sum += n; };

    auto d = sub.filter!(a => a.length > 0).subscribe(observer);
    scope (exit)
        d.dispose();

    assert(sum == 0);

    sub.put([]);
    sub.put([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    assert(sum == 55);
}

unittest
{
    static assert(!__traits(compiles, {
            import rx.subject : SubjectObject;

            auto sub = new SubjectObject!int;
            auto sum = 0;
            auto d = sub.filter!(a => a.length > 0)
            .doSubscribe!(n => sum += n); //a.length can not compile
        }));
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    auto sum = 0;
    auto d = sub.filter!(a => a > 0)
        .doSubscribe!(n => sum += n);
    scope (exit)
        d.dispose();

    assert(sum == 0);

    .put(sub, [-1, -2, -3]);
    .put(sub, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    assert(sum == 55);
}

///
struct FilterObservable(alias pred, TObservable)
{
    alias ElementType = TObservable.ElementType;

public:
    ///
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    ///
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = FilterObserver!(pred, TObserver, ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable,
                    ObserverType(observer, disposable))));
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

struct FilterObserver(alias pred, TObserver, E)
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
        alias fun = unaryFun!pred;
        if (fun(obj))
            .put(_observer, obj);
    }
}

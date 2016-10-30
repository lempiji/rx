/+++++++++++++++++++++++++++++
 + This module defines algorithm 'tee'
 +/
module rx.algorithm.tee;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : unaryFun;
import std.range : put;

//####################
// Tee
//####################
struct TeeObserver(alias f, TObserver, E)
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
        unaryFun!f(obj);
        .put(_observer, obj);
    }
}

struct TeeObservable(alias f, TObservable, E)
{
    alias ElementType = E;

public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(T)(auto ref T observer)
    {
        alias ObserverType = TeeObserver!(f, T, E);
        static if (hasCompleted!T || hasFailure!T)
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

///
template tee(alias f)
{
    TeeObservable!(f, TObservable, TObservable.ElementType) tee(TObservable)(
            auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
///
unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    import std.array : appender;

    auto buf1 = appender!(int[]);
    auto buf2 = appender!(int[]);

    import rx.algorithm : map;

    auto disposable = sub.tee!(i => buf1.put(i))().map!(i => i * 2)().subscribe(buf2);

    sub.put(1);
    sub.put(2);
    disposable.dispose();
    sub.put(3);

    import std.algorithm : equal;

    assert(equal(buf1.data, [1, 2]));
    assert(equal(buf2.data, [2, 4]));
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    int countPut = 0;
    int countFailure = 0;
    struct Test
    {
        void put(int)
        {
            countPut++;
        }

        void failure(Exception)
        {
            countFailure++;
        }
    }

    int foo(int n)
    {
        if (n == 0)
            throw new Exception("");
        return n * 2;
    }

    auto d = sub.tee!foo().doSubscribe(Test());
    scope (exit)
        d.dispose();

    assert(countPut == 0);
    sub.put(1);
    assert(countPut == 1);
    assert(countFailure == 0);
    sub.put(0);
    assert(countPut == 1);
    assert(countFailure == 1);
}

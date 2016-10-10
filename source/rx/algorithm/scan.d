/+++++++++++++++++++++++++++++
 + This module defines algorithm 'scan'
 +/
module rx.algorithm.scan;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.functional;
import std.range;

//####################
// Scan
//####################
struct ScanObserver(alias f, TObserver, E, TAccumulate)
{
    mixin SimpleObserverImpl!(TObserver, E);

public:
    this(TObserver observer, TAccumulate seed)
    {
        _observer = observer;
        _current = seed;
    }
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(TObserver observer, TAccumulate seed, Disposable disposable)
        {
            _observer = observer;
            _current = seed;
            _disposable = disposable;
        }
    }

public:
    void putImpl(E obj)
    {
        alias fun = binaryFun!f;
        _current = fun(_current, obj);
        _observer.put(_current);
    }

private:
    TAccumulate _current;
}
unittest
{
    import std.array : appender;
    auto buf = appender!(int[]);
    alias TObserver = ScanObserver!((a,b)=> a + b, typeof(buf), int, int);
    auto observer = TObserver(buf, 0);
    foreach (i; 1 .. 6)
    {
        observer.put(i);
    }
    auto result = buf.data;
    assert(result.length == 5);
    assert(result[0] == 1);
    assert(result[1] == 3);
    assert(result[2] == 6);
    assert(result[3] == 10);
    assert(result[4] == 15);
}

struct ScanObservable(alias f, TObservable, TAccumulate)
{
    alias ElementType = TAccumulate;

public:
    this(TObservable observable, TAccumulate seed)
    {
        _observable = observable;
        _seed = seed;
    }

public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = ScanObserver!(f, TObserver, TObservable.ElementType, TAccumulate);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _seed, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer, _seed));
        }
    }

private:
    TObservable _observable;
    TAccumulate _seed;
}
unittest
{
    alias Scan = ScanObservable!((a,b)=>a+b, Observable!int, int);
    static assert(isObservable!(Scan, int));
}
unittest
{
    import rx.subject : SubjectObject;
    auto sub = new SubjectObject!int;

    alias Scan = ScanObservable!((a,b)=>a+b, Observable!int, int);
    auto s = Scan(sub, 0);

    import std.stdio : writeln;
    auto disposable = s.subscribe((int i) => writeln(i));
    static assert(isDisposable!(typeof(disposable)));
}

///
template scan(alias f)
{
    auto scan(TObservable, TAccumulate)(auto ref TObservable observable, TAccumulate seed)
    {
        return ScanObservable!(f, TObservable, TAccumulate)(observable, seed);
    }
}
///
unittest
{
    import rx.subject : SubjectObject;
    auto subject = new SubjectObject!int;

    auto sum = subject.scan!((a, b) => a + b)(0);
    static assert(isObservable!(typeof(sum), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = sum.subscribe(buf);
    scope(exit) disposable.dispose();

    foreach (_; 0 .. 5)
    {
        subject.put(1);
    }

    auto result = buf.data;
    assert(result.length == 5);
    import std.algorithm : equal;
    assert(equal(result, [1, 2, 3, 4, 5]));
}

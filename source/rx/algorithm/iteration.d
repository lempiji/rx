/+++++++++++++++++++++++++++++
 + This module defines some algorithm like std.algorithm.iteration.
 +/
module rx.algorithm.iteration;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

public import rx.algorithm.filter;
public import rx.algorithm.map;
public import rx.algorithm.scan;
public import rx.algorithm.tee;

import core.atomic : cas, atomicLoad;
import std.functional : unaryFun, binaryFun;
import std.range : put;

//####################
// Overview
//####################
///
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
    auto disposable = pub.subscribe(observerObject!string(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}




//####################
// Merge
//####################
struct MergeObservable(TObservable1, TObservable2)
{
    import std.traits;
    alias ElementType = CommonType!(TObservable1.ElementType, TObservable2.ElementType);

public:
    this(TObservable1 o1, TObservable2 o2)
    {
        _observable1 = o1;
        _observable2 = o2;
    }

public:
    auto subscribe(T)(T observer)
    {
        auto d1 = _observable1.doSubscribe(observer);
        auto d2 = _observable2.doSubscribe(observer);
        return new CompositeDisposable(disposableObject(d1), disposableObject(d2));
    }

private:
    TObservable1 _observable1;
    TObservable2 _observable2;
}
MergeObservable!(T1, T2) merge(T1, T2)(auto ref T1 observable1, auto ref T2 observable2)
{
    return typeof(return)(observable1, observable2);
}

unittest
{
    import rx.subject;
    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!short;

    auto merged = s1.merge(s2);

    int count = 0;
    auto d = merged.doSubscribe((int n){ count++; });

    assert(count == 0);
    s1.put(1);
    assert(count == 1);
    s2.put(2);
    assert(count == 2);

    d.dispose();

    s1.put(10);
    assert(count == 2);
    s2.put(100);
    assert(count == 2);
}


//####################
// Fold
//####################
///
auto fold(alias fun, TObservable, Seed)(auto ref TObservable observable, Seed seed)
{
    import rx.range : takeLast;
    return observable.scan!fun(seed).takeLast;
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto sum = sub.fold!"a+b"(0);

    int result = 0;
    sum.doSubscribe((int n){ result = n; });

    foreach (i; 1 .. 11)
    {
        sub.put(i);
    }
    assert(result == 0);
    sub.completed();
    assert(result == 55);
}

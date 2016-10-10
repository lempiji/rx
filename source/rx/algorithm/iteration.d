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
public import rx.algorithm.merge;

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

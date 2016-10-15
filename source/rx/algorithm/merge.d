/+++++++++++++++++++++++++++++
 + This module defines algorithm 'merge'
 +/
module rx.algorithm.merge;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

//####################
// Merge
//####################
struct MergeObservable(TObservable1, TObservable2)
{
    import std.traits : CommonType;

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

///
MergeObservable!(T1, T2) merge(T1, T2)(auto ref T1 observable1, auto ref T2 observable2)
{
    return typeof(return)(observable1, observable2);
}
///
unittest
{
    import rx.subject : SubjectObject;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!short;

    auto merged = s1.merge(s2);

    int count = 0;
    auto d = merged.doSubscribe((int n) { count++; });

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

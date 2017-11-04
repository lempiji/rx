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

///[WIP] Observable!(Observable!int).merge() => Observable!int
auto merge(TObservable)(auto ref TObservable observable)
        if (isObservable!TObservable && isObservable!(TObservable.ElementType))
{
    import rx.subject : SubjectObject;

    static struct MergeObservable_Flat
    {
        alias ElementType = TObservable.ElementType.ElementType;

        this(TObservable observable)
        {
            _observable = observable;
        }

        auto subscribe(TObserver)(TObserver observer)
        {
            auto subject = new SubjectObject!ElementType;
            auto groupSubscription = new CompositeDisposable;
            auto innerSubscription = subject.doSubscribe(observer);
            auto outerSubscription = _observable.doSubscribe((TObservable.ElementType obj) {
                auto subscription = obj.doSubscribe(subject);
                groupSubscription.insert(subscription.disposableObject());
            }, { subject.completed(); }, (Exception e) { subject.failure(e); });
            return new CompositeDisposable(groupSubscription, innerSubscription, outerSubscription);
        }

        TObservable _observable;
    }

    return MergeObservable_Flat(observable);
}

///
unittest
{
    import rx.algorithm.groupby : groupBy;
    import rx.algorithm.map : map;
    import rx.algorithm.fold : fold;
    import rx.subject : SubjectObject, CounterObserver;

    auto subject = new SubjectObject!int;
    auto counted = subject.groupBy!(n => n % 10).map!(o => o.fold!((a, b) => a + 1)(0)).merge();

    auto counter = new CounterObserver!int;

    auto disposable = counted.subscribe(counter);

    subject.put(0);
    subject.put(0);
    assert(counter.putCount == 0);
    subject.completed();
    assert(counter.putCount == 1);
    assert(counter.lastValue == 2);
}

/+++++++++++++++++++++++++++++
 + This module defines algorithm 'merge'
 +/
module rx.algorithm.merge;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;
import std.range : put;

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
        static struct MergeObserver
        {
            T _observer;
            shared(AtomicCounter) _counter;
            Disposable _subscription;

            void put(ElementType obj)
            {
                if (_counter.isZero) return;

                .put(_observer, obj);
            }

            void completed()
            {
                auto result = _counter.tryDecrement();
                if (result.success && result.count == 0)
                {
                    static if (hasCompleted!T)
                    {
                        _observer.completed();
                    }
                    _subscription.dispose();
                }
            }

            void failure(Exception e)
            {
                if (_counter.trySetZero())
                {
                    static if (hasFailure!T)
                    {
                        _observer.failure(e);
                    }
                    _subscription.dispose();
                }
            }
        }

        auto subscription = new SingleAssignmentDisposable;
        auto counter = new shared(AtomicCounter)(2);
        auto mergeObserver = MergeObserver(observer, counter, subscription);
        auto d1 = _observable1.doSubscribe(mergeObserver);
        auto d2 = _observable2.doSubscribe(mergeObserver);
        subscription.setDisposable(new CompositeDisposable(disposableObject(d1), disposableObject(d2)));
        return subscription;
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

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto merged = merge(s1, s2);
    auto observer = new CounterObserver!int;

    auto disposable = merged.doSubscribe(observer);
    scope(exit) disposable.dispose();

    s1.put(0);
    assert(observer.putCount == 1);
    s2.put(1);
    assert(observer.putCount == 2);
    s1.completed();
    assert(observer.completedCount == 0);
    s2.completed();
    assert(observer.completedCount == 1);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto source1 = new SubjectObject!int;
    auto source2 = new SubjectObject!int;
    auto subject = merge(source1, source2);

    auto counter = new CounterObserver!int;
    subject.subscribe(counter);

    source1.put(0);
    assert(counter.putCount == 1);
    assert(counter.lastValue == 0);
    source1.completed();
    assert(counter.completedCount == 0);

    source2.put(1);
    assert(counter.putCount == 2);
    assert(counter.lastValue == 1);

    assert(counter.completedCount == 0);
    source2.completed();
    assert(counter.completedCount == 1);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto merged = merge(s1, s2);
    auto observer = new CounterObserver!int;

    auto disposable = merged.doSubscribe(observer);
    scope(exit) disposable.dispose();

    s1.put(0);
    assert(observer.putCount == 1);
    s2.put(1);
    assert(observer.putCount == 2);

    auto ex = new Exception("TEST");
    s1.failure(ex);
    assert(observer.failureCount == 1);
    assert(observer.lastException == ex);

    s2.put(2);
    assert(observer.putCount == 2);
    
    s2.completed();
    assert(observer.completedCount == 0);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto merged = merge(s1, s2);
    auto observer = new CounterObserver!int;

    auto disposable = merged.doSubscribe(observer);

    s1.put(0);
    s2.put(1);
    assert(observer.putCount == 2);

    disposable.dispose();

    s1.put(2);
    s1.completed();

    s2.put(3);
    s2.completed();
    // no effect
    assert(observer.putCount == 2);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 0);
}

unittest
{
    import rx : SubjectObject;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    int result = -1;
    auto disposable = merge(s1, s2).doSubscribe((int n) { result = n; });
    
    s1.put(0);
    assert(result == 0);
    s2.put(1);
    assert(result == 1);

    s1.failure(null);
    s2.put(2);
    assert(result == 1);
}

///
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
                groupSubscription.insert(disposableObject(subscription));
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

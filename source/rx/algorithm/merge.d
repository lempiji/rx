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
                if (_counter.isZero)
                    return;

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
        subscription.setDisposable(new CompositeDisposable(disposableObject(d1),
                disposableObject(d2)));
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
    scope (exit)
        disposable.dispose();

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
    scope (exit)
        disposable.dispose();

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

        auto subscribe(TObserver)(auto ref TObserver observer)
        {
            auto sink = new MergeSink!(TObservable.ElementType, TObserver, ElementType)(observer);
            sink._upstream = _observable.doSubscribe(sink).disposableObject();
            return sink;
        }

        TObservable _observable;
    }

    return MergeObservable_Flat(observable);
}

///
unittest
{
    import rx;

    auto outer = new SubjectObject!(Observable!int);

    Observable!int flatten = outer.merge().observableObject!int();

    int[] xs;
    auto disposable = flatten.doSubscribe((int n) { xs ~= n; });
    scope (exit)
        disposable.dispose();

    auto inner1 = new SubjectObject!int;
    auto inner2 = new SubjectObject!int;

    .put(outer, inner1);
    .put(inner1, 0);
    assert(xs == [0]);
    .put(inner1, 1);
    assert(xs == [0, 1]);

    .put(outer, inner2);
    .put(inner1, 2);
    assert(xs == [0, 1, 2]);
    .put(inner2, 3);
    assert(xs == [0, 1, 2, 3]);
    .put(inner2, 4);
    assert(xs == [0, 1, 2, 3, 4]);
}

///
unittest
{
    import rx;

    auto outer = new SubjectObject!(Observable!int);

    Observable!int flatten = outer.merge().observableObject!int();

    auto observer = new CounterObserver!int;
    auto disposable = flatten.doSubscribe(observer);
    scope (exit)
        disposable.dispose();

    auto inner = new SubjectObject!int;

    .put(outer, inner);
    .put(inner, 0);

    inner.completed();
    assert(observer.completedCount == 0);
    outer.completed();
    assert(observer.completedCount == 1);
}

///
unittest
{
    import rx;

    auto outer = new SubjectObject!(Observable!int);

    Observable!int flatten = outer.merge().observableObject!int();

    auto observer = new CounterObserver!int;
    auto disposable = flatten.doSubscribe(observer);
    scope (exit)
        disposable.dispose();

    auto inner = new SubjectObject!int;

    .put(outer, inner);
    .put(inner, 0);

    outer.failure(new Exception("TEST"));
    assert(observer.failureCount == 1);
    .put(inner, 1);
    import std : format;

    assert(observer.putCount == 1, format!"putCount: %d"(observer.putCount));
}

///
unittest
{
    import rx.algorithm.groupby : groupBy;
    import rx.algorithm.map : map;
    import rx.algorithm.fold : fold;
    import rx.subject : SubjectObject, CounterObserver;

    auto subject = new SubjectObject!int;
    auto counted = subject.groupBy!(n => n % 10)
        .map!(o => o.fold!((a, b) => a + 1)(0))
        .merge();

    auto counter = new CounterObserver!int;

    auto disposable = counted.subscribe(counter);

    subject.put(0);
    subject.put(0);
    assert(counter.putCount == 0);
    subject.completed();
    assert(counter.putCount == 1);
    assert(counter.lastValue == 2);
}

///
unittest
{
    import std.format : format;
    import rx;

    auto outer = new SubjectObject!(Observable!int);
    auto inner_pair1 = new SubjectObject!int;
    auto inner_pair2 = new SubjectObject!int;
    auto inner_flat1 = new SubjectObject!int;
    auto inner_flat2 = new SubjectObject!int;

    auto mergePair = merge(inner_pair1, inner_pair2);
    auto mergeFlat = outer.merge();

    auto counter1 = new CounterObserver!int;
    auto counter2 = new CounterObserver!int;

    auto disposable1 = mergePair.doSubscribe(counter1);
    auto disposable2 = mergeFlat.doSubscribe(counter2);
    .put(outer, inner_flat1);
    .put(outer, inner_flat2);

    .put(inner_pair1, 0);
    .put(inner_flat1, 0);

    .put(inner_pair2, 1);
    .put(inner_flat2, 1);

    assert(counter1.putCount == counter2.putCount);
    assert(counter1.lastValue == counter2.lastValue);
    assert(counter1.completedCount == counter2.completedCount);
    assert(counter1.failureCount == counter2.failureCount);

    inner_pair1.completed();
    inner_flat1.completed();

    assert(counter1.putCount == counter2.putCount);
    assert(counter1.lastValue == counter2.lastValue);
    assert(counter1.completedCount == counter2.completedCount,
            format!"%d == %d"(counter1.completedCount, counter2.completedCount));
    assert(counter1.failureCount == counter2.failureCount);

    .put(inner_pair2, 10);
    .put(inner_flat2, 10);

    assert(counter1.putCount == counter2.putCount);
    assert(counter1.lastValue == counter2.lastValue);
    assert(counter1.completedCount == counter2.completedCount);
    assert(counter1.failureCount == counter2.failureCount);

    disposable1.dispose();
    disposable2.dispose();

    assert(counter1.putCount == counter2.putCount);
    assert(counter1.lastValue == counter2.lastValue);
    assert(counter1.completedCount == counter2.completedCount);
    assert(counter1.failureCount == counter2.failureCount);

    .put(inner_pair2, 100);
    .put(inner_flat2, 100);

    assert(counter1.putCount == counter2.putCount);
    assert(counter1.lastValue == counter2.lastValue);
    assert(counter1.completedCount == counter2.completedCount);
    assert(counter1.failureCount == counter2.failureCount);
}

class MergeSink(TObservable, TObserver, E) : Observer!TObservable, Disposable
{
    private TObserver _observer;
    private Disposable _upstream;
    private Object _gate;
    private shared(bool) _disposed;
    private shared(bool) _isStopped;
    private CompositeDisposable _group;

    this(TObserver observer)
    {
        _observer = observer;
        _gate = new Object;
        _group = new CompositeDisposable;
    }

    void dispose()
    {
        import core.atomic : atomicStore;

        atomicStore(_disposed, true);
        tryDispose(_upstream);
        _group.dispose();
    }

    void put(TObservable obj)
    {
        auto inner = new InnerObserver(this);
        _group.insert(inner);
        inner._upstream = obj.doSubscribe(inner).disposableObject();
    }

    void completed()
    {
        import core.atomic;

        atomicStore(_isStopped, true);
        if (_group.count == 0)
        {
            forwardCompleted();
        }
        else
        {
            dispose();
        }
    }

    void failure(Exception e)
    {
        forwardFailure(e);
        dispose();
    }

    private void forwardPut(E obj)
    {
        if (_disposed)
            return;
        synchronized (_gate)
        {
            .put(_observer, obj);
        }
    }

    private void forwardCompleted()
    {
        if (_disposed)
            return;
        synchronized (_gate)
        {
            static if (hasCompleted!TObserver)
            {
                _observer.completed();
            }
            tryDispose(_upstream);
        }
    }

    private void forwardFailure(Exception e)
    {
        if (_disposed)
            return;
        synchronized (_gate)
        {
            static if (hasFailure!TObserver)
            {
                _observer.failure(e);
            }
            tryDispose(_upstream);
        }
    }

    private static final class InnerObserver : Observer!E, Disposable
    {
        private MergeSink _parent;
        private Disposable _upstream;

        this(MergeSink parent)
        {
            assert(parent !is null);

            _parent = parent;
        }

        void dispose()
        {
            tryDispose(_upstream);
        }

        void put(E obj)
        {
            scope (failure)
                dispose();
            _parent.forwardPut(obj);
        }

        void completed()
        {
            scope (exit)
                dispose();
            _parent._group.remove(this);
            if (_parent._isStopped && _parent._group.count == 0)
            {
                _parent.forwardCompleted();
            }
        }

        void failure(Exception e)
        {
            scope (exit)
                dispose();
            _parent.forwardFailure(e);
        }
    }
}

unittest
{
    import rx;

    auto sub = new SubjectObject!(Observable!int);

    auto counter = new CounterObserver!int;
    auto sink = new MergeSink!(Observable!int, Observer!int, int)(counter);

    auto d = sub.subscribe(sink.observerObject!(Observable!int)());
    sink._upstream = d.disposableObject();

    auto inner1 = new SubjectObject!int;
    sub.put(inner1);

    assert(counter.putCount == 0);
    inner1.put(1);
    assert(counter.putCount == 1);
    inner1.put(2);
    assert(counter.putCount == 2);
    inner1.put(3);
    assert(counter.putCount == 3);

    auto inner2 = new SubjectObject!int;
    sub.put(inner2);

    inner2.put(10);
    assert(counter.putCount == 4);
    inner2.put(11);
    assert(counter.putCount == 5);

    inner1.put(4);
    assert(counter.putCount == 6);

    inner1.completed();
    assert(counter.completedCount == 0);
    inner2.completed();
    assert(counter.completedCount == 0);

    sub.completed();
    assert(counter.completedCount == 1);
}

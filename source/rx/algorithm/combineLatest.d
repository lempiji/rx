/+++++++++++++++++++++++++++++
 + This module defines algorithm 'combineLatest'
 +/
module rx.algorithm.combineLatest;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.range : put;
import std.meta : staticMap, allSatisfy;
import std.typecons : Tuple, tuple;

///
template combineLatest(alias f = tuple)
{
    CombineLatestObservable!(f, TObservables) combineLatest(TObservables...)(TObservables observables)
        if (allSatisfy!(isObservable, TObservables))
    {
        return typeof(return)(observables);
    }
}

///
unittest
{
    import rx : SubjectObject, CounterObserver;

    auto hello = new SubjectObject!string;
    auto world = new SubjectObject!string;

    auto message = combineLatest!((a, b) => a ~ ", " ~ b ~ "!")(hello, world);
    
    auto observer = new CounterObserver!string;
    message.doSubscribe(observer);

    .put(hello, "Hello");
    .put(world, "world");

    assert(observer.putCount == 1);
    assert(observer.lastValue == "Hello, world!");

    .put(world, "D-man");
    assert(observer.putCount == 2);
    assert(observer.lastValue == "Hello, D-man!");
}

///
unittest
{
    import rx : SubjectObject, CounterObserver, uniq;

    auto count1 = new SubjectObject!int;
    auto count2 = new SubjectObject!int;
    auto count3 = new SubjectObject!int;

    import std.algorithm : max;

    alias pickMax = combineLatest!max;
    auto observable = pickMax(count1, count2, count3).uniq();
    
    auto observer = new CounterObserver!int;
    observable.doSubscribe(observer);

    .put(count1, 0);
    .put(count2, 0);
    .put(count3, 0);
    
    assert(observer.putCount == 1);
    assert(observer.lastValue == 0);

    .put(count1, 10);
    assert(observer.putCount == 2);
    assert(observer.lastValue == 10);

    .put(count2, 10);
    assert(observer.putCount == 2);

    .put(count3, 11);
    assert(observer.putCount == 3);
    assert(observer.lastValue == 11);
}

unittest
{
    import rx : SubjectObject;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto comb = combineLatest(s1, s2);

    Tuple!(int, int)[] result;
    comb.doSubscribe!(t => result ~= t);

    .put(s1, 0);
    .put(s2, 100);
    assert(result.length == 1);
    assert(result[0] == tuple(0, 100));

    .put(s1, 1);
    assert(result.length == 2);
    assert(result[1] == tuple(1, 100));

    .put(s2, 101);
    assert(result.length == 3);
    assert(result[2] == tuple(1, 101));
}

unittest
{
    import rx : SubjectObject, CounterObserver, map;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto sum = combineLatest(s1, s2).map!"a[0] + a[1]"();

    auto observer = new CounterObserver!int;
    sum.doSubscribe(observer);

    .put(s1, 1);
    .put(s2, 2);
    assert(observer.putCount == 1);
    assert(observer.lastValue == 3);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2);
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = observable.doSubscribe(observer);

    disposable.dispose();

    .put(s1, 1);
    .put(s2, 2);
    assert(observer.putCount == 0);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2);
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = observable.doSubscribe(observer);

    .put(s1, 1);
    .put(s2, 2);
    assert(observer.putCount == 1);

    disposable.dispose();
    .put(s1, 10);
    .put(s2, 100);
    assert(observer.putCount == 1);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2);
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = observable.doSubscribe(observer);

    s1.completed();
    assert(observer.completedCount == 0);
    s2.completed();
    assert(observer.completedCount == 1);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2);
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = observable.doSubscribe(observer);

    auto ex = new Exception("message");
    s1.failure(ex);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);

    .put(s2, 10);
    assert(observer.putCount == 0);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2);
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = observable.doSubscribe(observer);

    s1.completed();
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 0);

    auto ex = new Exception("message");
    s2.failure(ex);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);
}

unittest
{
    import rx : SubjectObject, CounterObserver;

    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;
    auto s3 = new SubjectObject!int;
    auto s4 = new SubjectObject!int;
    auto s5 = new SubjectObject!int;

    auto observable = combineLatest(s1, s2, s3, s4, s5);
    auto observer = new CounterObserver!(Tuple!(int, int, int, int, int));
    auto disposable = observable.doSubscribe(observer);

    .put(s1, 0);
    .put(s2, 0);
    .put(s3, 0);
    .put(s4, 0);
    .put(s5, 0);
    assert(observer.putCount == 1);
    assert(observer.lastValue == tuple(0, 0, 0, 0, 0));
}


private template GetElementType(T) {
    alias GetElementType = T.ElementType;
}

struct CombineLatestObservable(alias f, TObservables...)
{
    alias ElementType = typeof(({
        alias ElementTypes = staticMap!(GetElementType, TObservables);
        return f(ElementTypes.init);
    })());

    TObservables _observables;

    auto subscribe(TObserver)(TObserver observer)
    {
        alias CombCoordinator = CombineLatestCoordinator!(f, TObserver, staticMap!(GetElementType, TObservables));

        auto subscription = new SingleAssignmentDisposable;
        auto coordinator = new CombCoordinator(observer, subscription);

        Disposable[TObservables.length] innerSubscriptions;
        foreach(i, T; TObservables)
        {
            alias CombObserver = CombineLatestObserver!(CombCoordinator, TObservables[i].ElementType, i);
            innerSubscriptions[i] = _observables[i].doSubscribe(CombObserver(coordinator)).disposableObject();
        }
        subscription.setDisposable(new CompositeDisposable(innerSubscriptions));

        return subscription;
    }
}

class CombineLatestCoordinator(alias f, TObserver, ElementTypes...)
{
public:
    this(TObserver observer, Disposable subscription)
    {
        _gate = new Object;
        _counter = new shared(AtomicCounter)(ElementTypes.length);
        _observer = observer;
        _subscription = subscription;
    }

public:
    void innerPut(size_t index)(ElementTypes[index] obj)
    {
        if (_counter.isZero) return;

        synchronized (_gate)
        {
            _values[index] = obj;
            _hasValues[index] = true;

            foreach (hasValue; _hasValues)
            {
                if (!hasValue) return;
            }
            
            .put(_observer, f(_values));
        }
    }

    void innerCompleted()
    {
        auto res = _counter.tryDecrement();
        if (res.success && res.count == 0)
        {
            static if (hasCompleted!TObserver)
            {
                _observer.completed();
            }
            _subscription.dispose();
        }
    }

    void innerFailure(Exception e)
    {
        if (_counter.trySetZero())
        {
            static if (hasFailure!TObserver)
            {
                _observer.failure(e);
            }
            _subscription.dispose();
        }
    }
    
public:
    Object _gate;
    shared(AtomicCounter) _counter;
    bool[ElementTypes.length] _hasValues;
    ElementTypes _values;

    TObserver _observer;
    Disposable _subscription;
}

struct CombineLatestObserver(TCoordinator, E, size_t index)
{
    TCoordinator _parent;

    void put(E obj)
    {
        _parent.innerPut!index(obj);
    }

    void completed()
    {
        _parent.innerCompleted();
    }

    void failure(Exception e)
    {
        _parent.innerFailure(e);
    }
}

unittest
{
    import rx : CounterObserver;

    alias CombCoordinator = CombineLatestCoordinator!(tuple, Observer!(Tuple!int), int);
    alias CombObserver = CombineLatestObserver!(CombCoordinator, int, 0);

    auto subscription = new SingleAssignmentDisposable;
    auto observer = new CounterObserver!(Tuple!int);
    auto coordinator = new CombCoordinator(observer, subscription);
    auto co = CombObserver(coordinator);
}

unittest
{
    alias CombObservable = CombineLatestObservable!(tuple, Observable!string, Observable!int);
    static assert(is(CombObservable.ElementType == Tuple!(string, int)));

    import rx : SubjectObject, CounterObserver;

    auto name = new SubjectObject!string;
    auto age = new SubjectObject!int;

    auto observable = CombObservable(name, age);
    auto observer = new CounterObserver!(Tuple!(string, int));
    auto subscription = observable.subscribe(observer);

    subscription.dispose();
}

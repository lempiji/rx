/+++++++++++++++++++++++++++++
 + This module defines algorithm 'groupBy'
 +/
module rx.algorithm.groupby;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.subject;
import rx.util;

import std.functional : unaryFun;
import std.range : put;

//####################
// GroupBy
//####################
///
interface GroupedObservable(TKey, E) : Observable!E
{
    TKey key() const pure nothrow @safe @nogc @property;
}

private class GroupedObservableObject(TKey, E) : GroupedObservable!(TKey, E)
{
    alias ElementType = E;

public:
    this(TKey key, Observable!E subject, RefCountDisposable cancel = null)
    {
        _key = key;
        _subject = subject;
        _cancel = cancel;
    }

public:
    TKey key() const pure nothrow @safe @nogc @property
    {
        return _key;
    }

public:
    Disposable subscribe(Observer!E observer)
    {
        if (_cancel is null)
        {
            return _subject.subscribe(observer);
        }
        else
        {
            auto canceler = _cancel.getDisposable();
            auto subscription = _subject.subscribe(observer);
            return new CompositeDisposable(canceler, subscription);
        }
    }

private:
    TKey _key;
    Observable!E _subject;
    RefCountDisposable _cancel;
}

private class GroupByObserver(alias selector, TObserver, E)
{
public:
    alias TKey = typeof({ return unaryFun!(selector)(E.init); }());

public:
    this(TObserver observer, Disposable disposable, RefCountDisposable refCountedDisposable)
    {
        _observer = observer;
        _disposable = disposable;
        _refCountDisposable = refCountedDisposable;
    }

public:
    void put(E obj)
    {
        alias keySelector = unaryFun!selector;

        Subject!E writer;

        TKey key;
        bool fireNewEntry = false;

        try
        {
            key = keySelector(obj);

            static if (__traits(compiles, { TKey unused = null; }))
            {
                if (key is null)
                {
                    if (_null is null)
                    {
                        _null = new SubjectObject!E;
                        fireNewEntry = true;
                    }
                    writer = _null;
                }
                else
                {
                    if (key in _map)
                    {
                        writer = _map[key];
                    }
                    else
                    {
                        _map[key] = writer = new SubjectObject!E;
                        fireNewEntry = true;
                    }
                }
            }
            else
            {
                if (key in _map)
                {
                    writer = _map[key];
                }
                else
                {
                    _map[key] = writer = new SubjectObject!E;
                    fireNewEntry = true;
                }
            }
        }
        catch (Exception e)
        {
            failure(e);
            return;
        }

        if (fireNewEntry)
        {
            auto group = new GroupedObservableObject!(TKey, E)(key, writer, _refCountDisposable);
            .put(_observer, group);
        }

        .put(writer, obj);
    }

    void completed()
    {
        static if (__traits(compiles, { TKey unused = null; }))
        {
            if (_null !is null)
            {
                _null.completed();
            }
        }
        foreach (sink; _map.values)
        {
            sink.completed();
        }
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _disposable.dispose();
    }

    void failure(Exception e)
    {
        static if (__traits(compiles, { TKey unused = null; }))
        {
            if (_null !is null)
            {
                _null.failure(e);
            }
        }
        foreach (sink; _map.values)
        {
            sink.failure(e);
        }
        static if (hasFailure!TObserver)
        {
            _observer.failure(e);
        }
        _disposable.dispose();
    }

private:
    TObserver _observer;
    Disposable _disposable;
    Subject!E[TKey] _map;
    static if (__traits(compiles, { TKey unused = null; }))
    {
        Subject!E _null;
    }
    RefCountDisposable _refCountDisposable;
}

unittest
{
    alias TObserver = GroupByObserver!(n => n % 10, Observer!(GroupedObservable!(int, int)), int);

    auto observer = new CounterObserver!(GroupedObservable!(int, int));
    auto refCount = new RefCountDisposable(NopDisposable.instance);
    auto group = new TObserver(observer, NopDisposable.instance, refCount);

    assert(observer.putCount == 0);
    group.put(0);
    assert(observer.putCount == 1);
    assert(observer.lastValue.key == 0);
    group.put(0);
    assert(observer.putCount == 1);
    assert(observer.lastValue.key == 0);

    group.put(1);
    assert(observer.putCount == 2);
    assert(observer.lastValue.key == 1);
    group.put(11);
    assert(observer.putCount == 2);
    assert(observer.lastValue.key == 1);

    group.put(3);
    assert(observer.putCount == 3);
    assert(observer.lastValue.key == 3);
}

unittest
{
    alias TObserver = GroupByObserver!(n => n % 2 == 0,
            Observer!(GroupedObservable!(bool, int)), int);

    import std.typecons : Tuple, tuple;
    import rx.algorithm.map : map;

    auto tester = new CounterObserver!(Tuple!(bool, int));
    auto observer = observerObject!(GroupedObservable!(bool, int))(
            (GroupedObservable!(bool, int) observable) {
        observable.map!(n => tuple(observable.key, n)).doSubscribe(tester);
    });

    auto refCount = new RefCountDisposable(NopDisposable.instance);

    auto group = new TObserver(observer, NopDisposable.instance, refCount);

    group.put(0);
    assert(tester.putCount == 1);
    assert(tester.lastValue == tuple(true, 0));
    group.put(1);
    assert(tester.putCount == 2);
    assert(tester.lastValue == tuple(false, 1));
    group.put(3);
    assert(tester.putCount == 3);
    assert(tester.lastValue == tuple(false, 3));
}

unittest
{
    alias TObserver = GroupByObserver!(n => n % 2 == 0,
            Observer!(GroupedObservable!(bool, int)), int);

    auto tester = new CounterObserver!int;
    auto observer = observerObject!(GroupedObservable!(bool, int))(
            (GroupedObservable!(bool, int) observable) {
        observable.doSubscribe(tester);
    });

    auto refCount = new RefCountDisposable(NopDisposable.instance);

    auto group = new TObserver(observer, NopDisposable.instance, refCount);

    assert(tester.putCount == 0);
    assert(tester.completedCount == 0);
    assert(tester.failureCount == 0);

    group.put(0);

    assert(tester.putCount == 1);
    assert(tester.completedCount == 0);
    assert(tester.failureCount == 0);

    group.completed();

    assert(tester.putCount == 1);
    assert(tester.completedCount == 1);
    assert(tester.failureCount == 0);
}

private struct GroupByObservable(alias selector, TObservable)
{
    static assert(isObservable!TObservable);

    alias TKey = typeof({
        return unaryFun!(selector)(TObservable.ElementType.init);
    }());
    alias ElementType = GroupedObservable!(TKey, TObservable.ElementType);

public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    Disposable subscribe(TObserver)(TObserver observer)
    {
        auto result = new SingleAssignmentDisposable;
        auto refCountDisposable = new RefCountDisposable(result);

        alias ObserverType = GroupByObserver!(selector, TObserver, TObservable.ElementType);

        auto subscription = _observable.doSubscribe(new ObserverType(observer,
                result, refCountDisposable));
        result.setDisposable(disposableObject(subscription));
        return result;
    }

private:
    TObservable _observable;
}

unittest
{
    alias TObservable = GroupByObservable!(n => n % 10, Observable!int);
    static assert(is(TObservable.TKey == int));
    static assert(is(TObservable.ElementType == GroupedObservable!(int, int)));

    auto subject = new SubjectObject!int;
    auto group = TObservable(subject);

    auto observer = new CounterObserver!(GroupedObservable!(int, int));
    auto disposable = group.subscribe(observer);

    subject.put(0);
    assert(observer.putCount == 1);
    subject.put(0);
    assert(observer.putCount == 1);
    subject.put(10);
    assert(observer.putCount == 1);

    subject.put(11);
    assert(observer.putCount == 2);

    subject.put(12);
    assert(observer.putCount == 3);

    subject.put(102);
    assert(observer.putCount == 3);
}

///
template groupBy(alias selector)
{
    GroupByObservable!(selector, TObservable) groupBy(TObservable)(auto ref TObservable observable)
    {
        static assert(isObservable!TObservable);

        return typeof(return)(observable);
    }
}

///
unittest
{
    auto sub = new SubjectObject!int;

    auto group = sub.groupBy!(n => n % 10);

    auto tester = new CounterObserver!(typeof(group).ElementType);
    auto disposable = group.subscribe(tester);

    sub.put(0);
    assert(tester.putCount == 1);
    assert(tester.lastValue.key == 0);

    sub.put(10);
    assert(tester.putCount == 1);
}

///
unittest
{
    auto sub = new SubjectObject!string;

    auto group = sub.groupBy!(text => text);

    auto tester = new CounterObserver!(typeof(group).ElementType);
    auto disposable = group.subscribe(tester);

    sub.put("A");
    assert(tester.putCount == 1);
    assert(tester.lastValue.key == "A");

    sub.put("B");
    assert(tester.putCount == 2);
    assert(tester.lastValue.key == "B");

    sub.put("XXX");
    assert(tester.putCount == 3);
    assert(tester.lastValue.key == "XXX");
}

unittest
{
    auto sub = new SubjectObject!string;

    string delegate(string _) dg = (test) { throw new Exception(""); };

    auto group = sub.groupBy!(dg);

    auto tester = new CounterObserver!(typeof(group).ElementType);
    auto disposable = group.subscribe(tester);

    sub.put("A");
    assert(tester.putCount == 0);
    assert(tester.completedCount == 0);
    assert(tester.failureCount == 1);
}

unittest
{
    auto sub = new SubjectObject!string;

    auto group = sub.groupBy!(test => null);

    auto tester = new CounterObserver!(typeof(group).ElementType);
    auto disposable = group.subscribe(tester);

    sub.put("A");
    assert(tester.putCount == 1);
    assert(tester.lastValue.key is null);
}

unittest
{
    auto sub = new SubjectObject!string;

    auto group = sub.groupBy!(test => null);

    auto tester = new CounterObserver!string;
    auto disposable = group.doSubscribe!((o) {
        o.doSubscribe(tester);
    });

    sub.put("A");
    assert(tester.putCount == 1);
    assert(tester.lastValue == "A");
}

unittest
{
    import rx;

    auto sub = new SubjectObject!int;

    auto group = sub.groupBy!(i => i % 2 == 0);

    auto evenObserver = new CounterObserver!int;
    auto oddObserver = new CounterObserver!int;

    auto container = new CompositeDisposable();
    auto disposable = group.doSubscribe!((o) {
        container.insert(o.fold!"a + b"(0).doSubscribe(o.key ? evenObserver : oddObserver));
    });
    container.insert(disposable);

    scope (exit)
        container.dispose();

    sub.put(1);
    assert(oddObserver.putCount == 0);
    sub.put(2);
    assert(evenObserver.putCount == 0);
    sub.put(3);
    sub.put(4);
    sub.completed();
    assert(oddObserver.putCount == 1);
    assert(oddObserver.lastValue == 4);
    assert(evenObserver.putCount == 1);
    assert(evenObserver.lastValue == 6);
}

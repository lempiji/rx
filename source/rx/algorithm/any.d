/+++++++++++++++++++++++++++++
 + This module defines algorithm 'any'
 +/
module rx.algorithm.any;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : unaryFun;
import std.range : put;

struct AnyObserver(TObserver, E, alias pred = "true")
{
    this() @disable;
    this(TObserver observer, Disposable cancel)
    {
        _observer = observer;
        _cancel = cancel;
        _ticket = new Ticket;
    }

    void put(E obj)
    {
        alias fun = unaryFun!pred;
        if (fun(obj))
        {
            if (!_ticket.stamp())
                return;

            _observer.put(true);
            _cancel.dispose();
        }
    }

    void failure(Exception)
    {
        if (!_ticket.stamp())
            return;

        _observer.put(false);

        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _cancel.dispose();
    }

    void completed()
    {
        if (!_ticket.stamp())
            return;

        _observer.put(false);
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _cancel.dispose();
    }

private:
    TObserver _observer;
    Disposable _cancel;
    Ticket _ticket;
}

unittest
{
    import std.array : Appender;

    alias Buffer = Appender!(bool[]);
    alias TObserver = AnyObserver!(Buffer, int);
    assert(isObserver!(TObserver, int));
}

unittest
{
    import std.array : Appender, appender;

    alias TObserver = AnyObserver!(Appender!(bool[]), int);
    auto buf = appender!(bool[]);
    auto a = TObserver(buf, NopDisposable.instance);

    assert(buf.data.length == 0);
    a.put(0);
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);
    a.put(0);
    assert(buf.data.length == 1);

    auto b = a;
    b.put(1);
    assert(buf.data.length == 1);
}

unittest
{
    import std.array : Appender, appender;

    alias TObserver = AnyObserver!(Appender!(bool[]), int);

    auto buf = appender!(bool[]);
    {
        auto a = TObserver(buf, NopDisposable.instance);
        assert(buf.data.length == 0);
        a.failure(null);
        assert(buf.data.length == 1);
        assert(buf.data[0] == false);
    }
    buf.clear();
    {
        auto a = TObserver(buf, NopDisposable.instance);
        assert(buf.data.length == 0);
        a.completed();
        assert(buf.data.length == 1);
        assert(buf.data[0] == false);
    }
}

unittest
{
    import std.array : Appender, appender;

    alias TObserver = AnyObserver!(Appender!(bool[]), int, "a % 2 == 0");

    auto buf = appender!(bool[]);
    auto a = TObserver(buf, NopDisposable.instance);

    assert(buf.data.length == 0);
    a.put(1);
    assert(buf.data.length == 0);
    a.put(2);
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);
}

struct AnyObservable(TObservable, alias pred = "true")
{
    alias ElementType = bool;

    this(TObservable observable)
    {
        _observable = observable;
    }

    Disposable subscribe(TObserver)(auto ref TObserver observer)
    {
        alias ObserverType = AnyObserver!(TObserver, TObservable.ElementType, pred);

        auto subscription = new SingleAssignmentDisposable;
        subscription.setDisposable(disposableObject(_observable.doSubscribe(ObserverType(observer,
                subscription))));
        return subscription;
    }

private:
    TObservable _observable;
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int);

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto o1 = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = o1.subscribe(buf);

    assert(buf.data.length == 0);
    sub.put(1);
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);

    d.dispose();
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int, "a % 2 == 0");

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto o1 = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = o1.subscribe(buf);

    assert(buf.data.length == 0);
    sub.put(1);
    assert(buf.data.length == 0);
    sub.put(2);
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);

    d.dispose();
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int, a => a % 3 == 0);

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto o1 = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = o1.subscribe(buf);

    assert(buf.data.length == 0);
    sub.put(1);
    assert(buf.data.length == 0);
    sub.put(3);
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);

    d.dispose();
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int);

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto o1 = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = o1.subscribe(buf);

    assert(buf.data.length == 0);
    sub.failure(null);
    assert(buf.data.length == 1);
    assert(buf.data[0] == false);

    sub.put(0);
    assert(buf.data.length == 1);

    d.dispose();
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int);

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto o1 = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = o1.subscribe(buf);

    assert(buf.data.length == 0);
    sub.completed();
    assert(buf.data.length == 1);
    assert(buf.data[0] == false);

    sub.put(0);
    assert(buf.data.length == 1);

    d.dispose();
}

unittest
{
    alias TObservable = AnyObservable!(Observable!int);

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);

    import std.array : appender;

    auto buf = appender!(bool[]);
    auto d = observable.subscribe(buf);

    d.dispose();

    assert(buf.data.length == 0);
    sub.put(0);
    assert(buf.data.length == 0);
}

///
template any(alias pred = "true")
{
    AnyObservable!(TObservable, pred) any(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
///
unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = false;
    sub.any!("a % 2 == 0").doSubscribe((bool) { result = true; });

    assert(result == false);
    sub.put(1);
    assert(result == false);
    sub.put(0);
    assert(result == true);
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = false;
    sub.any!().doSubscribe((bool) { result = true; });

    assert(result == false);
    sub.put(1);
    assert(result == true);
}

///
AnyObservable!TObservable any(TObservable)(auto ref TObservable observable)
{
    return typeof(return)(observable);
}
///
unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = false;
    sub.any().doSubscribe((bool) { result = true; });

    assert(result == false);
    sub.put(1);
    assert(result == true);
}

unittest
{
    import rx.algorithm : filter;
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = true;
    sub.filter!"a % 2 == 0"().any().doSubscribe((bool t) { result = t; });

    assert(result == true);
    sub.completed();
    assert(result == false);
}

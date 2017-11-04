/+++++++++++++++++++++++++++++
 + This module defines algorithm 'all'
 +/
module rx.algorithm.all;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : unaryFun;
import std.range : isOutputRange, put;

struct AllObserver(TObserver, E, alias pred = "true")
{
    static assert(isOutputRange!(TObserver, bool), "TObserver must be OutputRange of bool.");

public:
    this() @disable;

    this(TObserver observer, Disposable cancel)
    {
        _observer = observer;
        _cancel = cast(shared) cancel;
        _ticket = new Ticket;
        _hasValue = new Ticket;
    }

public:
    void put(E obj)
    {
        _hasValue.stamp();

        alias fun = unaryFun!pred;
        static if (hasFailure!TObserver)
        {
            bool res = false;
            try
            {
                res = fun(obj);
            }
            catch (Exception e)
            {
                if (!_ticket.stamp())
                    return;

                _observer.failure(e);
                dispose();
                return;
            }

            if (!res)
            {
                if (!_ticket.stamp())
                    return;

                .put(_observer, false);
                static if (hasCompleted!TObserver)
                {
                    _observer.completed();
                }

                dispose();
            }
        }
        else
        {
            if (!fun(obj))
            {
                if (!_ticket.stamp())
                    return;

                .put(_observer, false);
                static if (hasCompleted!TObserver)
                {
                    _observer.completed();
                }

                dispose();
            }
        }
    }

    void failure(Exception e)
    {
        if (!_ticket.stamp())
            return;

        static if (hasFailure!TObserver)
        {
            _observer.failure(e);
        }

        dispose();
    }

    void completed()
    {
        if (!_ticket.stamp())
            return;

        .put(_observer, _hasValue.isStamped);
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }

        dispose();
    }

    void dispose()
    {
        auto cancel = assumeUnshared(exchange(_cancel, null));
        if (cancel !is null)
            cancel.dispose();
    }

private:
    TObserver _observer;
    shared(Disposable) _cancel;
    Ticket _ticket;
    Ticket _hasValue;
}

unittest
{
    static assert(!__traits(compiles, {
            AllObserver!(Observer!string, int) observer;
        }));
}

unittest
{
    alias TObserver = AllObserver!(Observer!bool, string);

    static assert(isOutputRange!(TObserver, string));
    static assert(hasFailure!(TObserver));
    static assert(hasCompleted!(TObserver));
}

unittest
{
    alias TObserver = AllObserver!(Observer!bool, string);

    static class CounterObserver : Observer!bool
    {
        void put(bool obj)
        {
            putCount++;
            lastValue = obj;
        }

        void failure(Exception e)
        {
            failureCount++;
            lastException = e;
        }

        void completed()
        {
            completedCount++;
        }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }

    static class CounterDisposable : Disposable
    {
        void dispose()
        {
            disposeCount++;
        }

        size_t disposeCount = 0;
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        .put(observer, "TEST");
        observer.completed();
        assert(counterObserver.putCount == 1);
        assert(counterObserver.lastValue == true);
        assert(counterObserver.completedCount == 1);
        assert(counterDisposable.disposeCount == 1);
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        observer.completed();
        assert(counterObserver.putCount == 1);
        assert(counterObserver.lastValue == false);
        assert(counterObserver.completedCount == 1);
        assert(counterDisposable.disposeCount == 1);
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        auto e = new Exception("MyException");
        observer.failure(e);
        assert(counterObserver.putCount == 0);
        assert(counterObserver.failureCount == 1);
        assert(counterObserver.lastException is e);
        assert(counterDisposable.disposeCount == 1);
    }
}

unittest
{
    alias TObserver = AllObserver!(Observer!bool, int, "a % 2 == 0");

    static class CounterObserver : Observer!bool
    {
        void put(bool obj)
        {
            putCount++;
            lastValue = obj;
        }

        void failure(Exception e)
        {
            failureCount++;
            lastException = e;
        }

        void completed()
        {
            completedCount++;
        }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }

    static class CounterDisposable : Disposable
    {
        void dispose()
        {
            disposeCount++;
        }

        size_t disposeCount = 0;
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        .put(observer, 0);
        observer.completed();
        assert(counterObserver.putCount == 1);
        assert(counterObserver.lastValue == true);
        assert(counterObserver.completedCount == 1);
        assert(counterDisposable.disposeCount == 1);
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        .put(observer, 1);
        observer.completed();
        assert(counterObserver.putCount == 1);
        assert(counterObserver.lastValue == false);
        assert(counterObserver.completedCount == 1);
        assert(counterDisposable.disposeCount == 1);
    }
}

unittest
{
    bool testThrow(int)
    {
        throw new Exception("MyException");
    }

    alias TObserver = AllObserver!(Observer!bool, int, testThrow);

    static class CounterObserver : Observer!bool
    {
        void put(bool obj)
        {
            putCount++;
            lastValue = obj;
        }

        void failure(Exception e)
        {
            failureCount++;
            lastException = e;
        }

        void completed()
        {
            completedCount++;
        }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }

    static class CounterDisposable : Disposable
    {
        void dispose()
        {
            disposeCount++;
        }

        size_t disposeCount = 0;
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        .put(observer, 0);
        observer.completed();
        assert(counterObserver.putCount == 0);
        assert(counterObserver.failureCount == 1);
        assert(counterObserver.completedCount == 0);
        assert(counterObserver.lastException.msg == "MyException");
        assert(counterDisposable.disposeCount == 1);
    }
}

unittest
{
    import std.array : Appender, appender;

    alias TObserver = AllObserver!(Appender!(bool[]), int);

    auto buf = appender!(bool[]);
    auto observer = TObserver(buf, NopDisposable.instance);

    .put(observer, 0);
    observer.completed();

    assert(buf.data.length == 1);
    assert(buf.data[0] == true);
}

struct AllObservable(TObservable, alias pred = "true")
{
    alias ElementType = bool;

public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    Disposable subscribe(TObserver)(auto ref TObserver observer)
    {
        alias ObserverType = AllObserver!(TObserver, TObservable.ElementType, pred);

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
    alias TObservable = AllObservable!(Observable!int);

    static assert(isObservable!(TObservable, bool));

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    import std.array : appender;

    auto buf = appender!(bool[]);

    auto observable = TObservable(sub);
    auto d = observable.subscribe(buf);

    sub.put(0);
    sub.completed();
    assert(buf.data.length == 1);
    assert(buf.data[0] == true);
}

///
template all(alias pred = "true")
{
    AllObservable!(TObservable, pred) all(TObservable)(auto ref TObservable observable)
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
    sub.all!"a % 2 == 0"().doSubscribe((bool res) { result = res; });

    sub.put(0);
    sub.completed();
    assert(result);
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = false;
    sub.all!().doSubscribe((bool res) { result = res; });

    sub.put(0);
    sub.completed();
    assert(result);
}

///
AllObservable!TObservable all(TObservable)(auto ref TObservable observable)
{
    return typeof(return)(observable);
}
///
unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = false;
    sub.all().doSubscribe((bool res) { result = res; });

    sub.put(0);
    sub.completed();
    assert(result);
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    import std.array : appender;

    auto buf = appender!(bool[]);

    auto d = sub.all!(a => a % 2 == 0).doSubscribe(buf);

    assert(buf.data.length == 0);
    sub.put(1);
    assert(buf.data.length == 1);
    assert(buf.data[0] == false);
}

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool[] result;
    auto d = sub.all!(a => a % 2 == 0).doSubscribe!(b => result ~= b);

    assert(result.length == 0);
    sub.put(1);
    assert(result.length == 1);
    assert(result[0] == false);
}

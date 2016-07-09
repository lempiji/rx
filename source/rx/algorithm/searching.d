/+++++++++++++++++++++++++++++
 + This module defines some algorithm like std.algorithm.searching.
 +/
module rx.algorithm.searching;

import std.functional;
import std.range : isOutputRange, put;
import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

///
unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    auto hasEven = sub.any!"a % 2 == 0"();
    auto result = false;
    auto d = hasEven.doSubscribe((bool b) { result = b; });

    sub.put(1);
    sub.put(3);
    sub.put(2);
    assert(result);
}

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
            if (!_ticket.stamp()) return;

            _observer.put(true);
            _cancel.dispose();
        }
    }

    void failure(Exception)
    {
        if (!_ticket.stamp()) return;

        _observer.put(false);
        
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _cancel.dispose();
    }

    void completed()
    {
        if (!_ticket.stamp()) return;

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
        subscription.setDisposable(disposableObject(_observable.doSubscribe(ObserverType(observer, subscription))));
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
    import rx.algorithm.iteration : filter;
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    bool result = true;
    sub.filter!"a % 2 == 0"().any().doSubscribe((bool t){ result = t; });

    assert(result == true);
    sub.completed();
    assert(result == false);
}

struct AllObserver(TObserver, E, alias pred = "true")
{
    static assert(isOutputRange!(TObserver, bool), "TObserver must be OutputRange of bool.");

public:
    this() @disable;

    this(TObserver observer, Disposable cancel)
    {
        _observer = observer;
        _cancel = cast(shared)cancel;
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
                if (!_ticket.stamp()) return;

                _observer.failure(e);
                dispose();
                return;
            }
            
            if (!res)
            {
                if (!_ticket.stamp()) return;

                _observer.put(false);
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
                if (!_ticket.stamp()) return;

                _observer.put(false);
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
        if (!_ticket.stamp()) return;

        static if (hasFailure!TObserver)
        {
            _observer.failure(e);
        }

        dispose();
    }

    void completed()
    {
        if (!_ticket.stamp()) return;

        _observer.put(_hasValue.isStamped);
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }

        dispose();
    }

    void dispose()
    {
        auto cancel = exchange(_cancel, null);
        if (cancel !is null) cancel.dispose();
    }

private:
    TObserver _observer;
    shared(Disposable) _cancel;
    Ticket _ticket;
    Ticket _hasValue;
}

unittest
{
    alias TObserver = AllObserver!(Observer!bool, int);

    static assert(isOutputRange!(TObserver, bool));
    static assert(hasFailure!(TObserver));
    static assert(hasCompleted!(TObserver));
}
unittest
{
    alias TObserver = AllObserver!(Observer!bool, int);
    
    static class CounterObserver : Observer!bool
    {
        void put(bool obj) { putCount++; lastValue = obj; }
        void failure(Exception e) { failureCount++; lastException = e; }
        void completed() { completedCount++; }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }
    static class CounterDisposable : Disposable
    {
        void dispose() { disposeCount++; }

        size_t disposeCount = 0;
    }


    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        observer.put(0);
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
        void put(bool obj) { putCount++; lastValue = obj; }
        void failure(Exception e) { failureCount++; lastException = e; }
        void completed() { completedCount++; }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }
    static class CounterDisposable : Disposable
    {
        void dispose() { disposeCount++; }

        size_t disposeCount = 0;
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        observer.put(0);
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

        observer.put(1);
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
        void put(bool obj) { putCount++; lastValue = obj; }
        void failure(Exception e) { failureCount++; lastException = e; }
        void completed() { completedCount++; }

        size_t putCount = 0;
        size_t failureCount = 0;
        size_t completedCount = 0;
        bool lastValue;
        Exception lastException;
    }
    static class CounterDisposable : Disposable
    {
        void dispose() { disposeCount++; }

        size_t disposeCount = 0;
    }

    {
        auto counterObserver = new CounterObserver;
        auto counterDisposable = new CounterDisposable;
        auto observer = TObserver(counterObserver, counterDisposable);

        observer.put(0);
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

    observer.put(0);
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
        subscription.setDisposable(disposableObject(_observable.doSubscribe(ObserverType(observer, subscription))));
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
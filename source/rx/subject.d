/+++++++++++++++++++++++++++++
 + This module defines the Subject and some implements.
 +/
module rx.subject;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util : assumeUnshared;

import core.atomic : atomicLoad, cas;
import std.range : put;

///Represents an object that is both an observable sequence as well as an observer.
interface Subject(E) : Observer!E, Observable!E
{
}

///Represents an object that is both an observable sequence as well as an observer. Each notification is broadcasted to all subscribed observers.
class SubjectObject(E) : Subject!E
{
    alias ElementType = E;

public:
    ///
    this()
    {
        _observer = cast(shared) NopObserver!E.instance;
    }

public:
    ///
    void put(E obj)
    {
        auto temp = assumeUnshared(atomicLoad(_observer));
        .put(temp, obj);
    }
    ///
    void completed()
    {
        shared(Observer!E) oldObserver = void;
        shared(Observer!E) newObserver = cast(shared) DoneObserver!E.instance;
        Observer!E temp = void;
        do
        {
            oldObserver = _observer;
            temp = assumeUnshared(atomicLoad(oldObserver));
            if (cast(DoneObserver!E) temp)
                break;
        }
        while (!cas(&_observer, oldObserver, newObserver));
        temp.completed();
    }
    ///
    void failure(Exception error)
    {
        shared(Observer!E) oldObserver = void;
        shared(Observer!E) newObserver = cast(shared) new DoneObserver!E(error);
        Observer!E temp = void;
        do
        {
            oldObserver = _observer;
            temp = assumeUnshared(atomicLoad(oldObserver));
            if (cast(DoneObserver!E) temp)
                break;
        }
        while (!cas(&_observer, oldObserver, newObserver));
        temp.failure(error);
    }

    ///
    Disposable subscribe(T)(T observer)
    {
        return subscribe(observerObject!E(observer));
    }
    ///
    Disposable subscribe(Observer!E observer)
    {
        shared(Observer!E) oldObserver = void;
        shared(Observer!E) newObserver = void;
        do
        {
            oldObserver = _observer;
            auto temp = assumeUnshared(atomicLoad(oldObserver));

            if (temp is DoneObserver!E.instance)
            {
                observer.completed();
                return NopDisposable.instance;
            }

            if (auto fail = cast(DoneObserver!E) temp)
            {
                observer.failure(fail.exception);
                return NopDisposable.instance;
            }

            if (auto composite = cast(CompositeObserver!E) temp)
            {
                newObserver = cast(shared) composite.add(observer);
            }
            else if (auto nop = cast(NopObserver!E) temp)
            {
                newObserver = cast(shared) observer;
            }
            else
            {
                newObserver = cast(shared)(new CompositeObserver!E([temp, observer]));
            }
        }
        while (!cas(&_observer, oldObserver, newObserver));

        return subscription(this, observer);
    }

    ///
    void unsubscribe(Observer!E observer)
    {
        shared(Observer!E) oldObserver = void;
        shared(Observer!E) newObserver = void;
        do
        {
            oldObserver = _observer;

            import rx.util : assumeUnshared;

            auto temp = assumeUnshared(atomicLoad(oldObserver));
            if (auto composite = cast(CompositeObserver!E) temp)
            {
                newObserver = cast(shared) composite.remove(observer);
            }
            else
            {
                if (temp !is observer)
                    return;

                newObserver = cast(shared) NopObserver!E.instance;
            }
        }
        while (!cas(&_observer, oldObserver, newObserver));
    }

private:
    shared(Observer!E) _observer;
}

///
unittest
{
    import std.array : appender;

    auto data = appender!(int[])();
    auto subject = new SubjectObject!int;
    auto disposable = subject.subscribe(observerObject!(int)(data));
    assert(disposable !is null);
    subject.put(0);
    subject.put(1);

    import std.algorithm : equal;

    assert(equal(data.data, [0, 1]));

    disposable.dispose();
    subject.put(2);
    assert(equal(data.data, [0, 1]));
}

unittest
{
    static assert(isObserver!(SubjectObject!int, int));
    static assert(isObservable!(SubjectObject!int, int));
    static assert(!isObservable!(SubjectObject!int, string));
    static assert(!isObservable!(SubjectObject!int, string));
}

unittest
{
    auto subject = new SubjectObject!int;
    auto observer = new CounterObserver!int;
    auto disposable = subject.subscribe(observer);
    scope (exit)
        disposable.dispose();

    subject.put(0);
    subject.put(1);

    assert(observer.putCount == 2);
    subject.completed();
    subject.put(2);
    assert(observer.putCount == 2);
    assert(observer.completedCount == 1);
}

unittest
{
    auto subject = new SubjectObject!int;
    auto observer = new CounterObserver!int;
    auto disposable = subject.subscribe(observer);
    scope (exit)
        disposable.dispose();

    subject.put(0);
    subject.put(1);

    assert(observer.putCount == 2);
    auto ex = new Exception("Exception");
    subject.failure(ex);
    subject.put(2);
    assert(observer.putCount == 2);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);
}

unittest
{
    import std.array : appender;

    auto buf1 = appender!(int[]);
    auto buf2 = appender!(int[]);
    auto subject = new SubjectObject!int;
    subject.subscribe(observerObject!(int)(buf1));
    subject.doSubscribe((int n) => buf2.put(n));

    assert(buf1.data.length == 0);
    assert(buf2.data.length == 0);
    subject.put(0);
    assert(buf1.data.length == 1);
    assert(buf2.data.length == 1);
    assert(buf1.data[0] == buf2.data[0]);
}

unittest
{
    auto sub = new SubjectObject!int;
    sub.completed();

    auto observer = new CounterObserver!int;
    assert(observer.putCount == 0);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 0);
    sub.subscribe(observer);
    assert(observer.putCount == 0);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
}

unittest
{
    auto sub = new SubjectObject!int;
    auto ex = new Exception("Exception");
    sub.failure(ex);

    auto observer = new CounterObserver!int;
    assert(observer.putCount == 0);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 0);
    sub.subscribe(observer);
    assert(observer.putCount == 0);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);
}

private class Subscription(TSubject, TObserver) : Disposable
{
public:
    this(TSubject subject, TObserver observer)
    {
        _subject = subject;
        _observer = observer;
    }

public:
    void dispose()
    {
        if (_subject !is null)
        {
            _subject.unsubscribe(_observer);
            _subject = null;
        }
    }

private:
    TSubject _subject;
    TObserver _observer;
}

private Subscription!(TSubject, TObserver) subscription(TSubject, TObserver)(
        TSubject subject, TObserver observer)
{
    return new typeof(return)(subject, observer);
}

///
class AsyncSubject(E) : Subject!E
{
public:
    ///
    Disposable subscribe(Observer!E observer)
    {
        Exception ex = null;
        E value;
        bool hasValue = false;

        synchronized (this)
        {
            if (!_isStopped)
            {
                _observers ~= observer;
                return subscription(this, observer);
            }

            ex = _exception;
            hasValue = _hasValue;
            value = _value;
        }

        if (ex !is null)
        {
            observer.failure(ex);
        }
        else if (hasValue)
        {
            .put(observer, value);
            observer.completed();
        }
        else
        {
            observer.completed();
        }

        return NopDisposable.instance;
    }

    ///
    auto subscribe(T)(T observer)
    {
        return subscribe(observerObject!E(observer));
    }

    ///
    void unsubscribe(Observer!E observer)
    {
        if (observer is null)
            return;

        synchronized (this)
        {
            import std.algorithm : remove, countUntil;

            auto index = countUntil(_observers, observer);
            if (index != -1)
            {
                _observers = remove(_observers, index);
            }
        }
    }

public:
    ///
    void put(E value)
    {
        synchronized (this)
        {
            if (!_isStopped)
            {
                _value = value;
                _hasValue = true;
            }
        }
    }

    ///
    void completed()
    {
        Observer!E[] os = null;

        E value;
        bool hasValue = false;

        synchronized (this)
        {
            if (!_isStopped)
            {
                os = _observers;
                _observers.length = 0;
                _isStopped = true;
                value = _value;
                hasValue = _hasValue;
            }
        }

        if (os)
        {
            if (hasValue)
            {
                foreach (observer; os)
                {
                    .put(observer, value);
                    observer.completed();
                }
            }
            else
            {
                foreach (observer; os)
                {
                    observer.completed();
                }
            }
        }
    }

    ///
    void failure(Exception e)
    {
        assert(e !is null);

        Observer!E[] os = null;
        synchronized (this)
        {
            if (!_isStopped)
            {
                os = _observers;
                _observers.length = 0;
                _isStopped = true;
                _exception = e;
            }
        }

        if (os)
        {
            foreach (observer; os)
            {
                observer.failure(e);
            }
        }
    }

private:
    Observer!E[] _observers;
    bool _isStopped;
    E _value;
    bool _hasValue;
    Exception _exception;
}

unittest
{
    auto sub = new AsyncSubject!int;

    .put(sub, 1);
    sub.completed();

    auto observer = new CounterObserver!int;

    assert(observer.hasNotBeenCalled);

    sub.subscribe(observer);

    assert(observer.putCount == 1);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
    assert(observer.lastValue == 1);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);
    scope (exit)
        d.dispose();

    assert(observer.hasNotBeenCalled);

    sub.put(100);

    assert(observer.hasNotBeenCalled);

    assert(sub._hasValue);
    assert(sub._value == 100);

    sub.completed();

    assert(observer.putCount == 1);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
    assert(observer.lastValue == 100);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    sub.put(100);

    assert(sub._hasValue);
    assert(sub._value == 100);

    auto d = sub.subscribe(observer);
    scope (exit)
        d.dispose();

    assert(observer.hasNotBeenCalled);

    sub.completed();

    assert(observer.putCount == 1);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
    assert(observer.lastValue == 100);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);

    d.dispose();
    assert(observer.hasNotBeenCalled);

    sub.put(100);
    assert(observer.hasNotBeenCalled);

    sub.completed();
    assert(observer.hasNotBeenCalled);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);
    assert(observer.hasNotBeenCalled);

    sub.put(100);
    assert(observer.hasNotBeenCalled);

    d.dispose();
    assert(observer.hasNotBeenCalled);

    sub.completed();
    assert(observer.hasNotBeenCalled);
}

unittest
{

    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    sub.put(100);
    assert(observer.hasNotBeenCalled);

    auto d = sub.subscribe(observer);
    assert(observer.hasNotBeenCalled);

    d.dispose();
    assert(observer.hasNotBeenCalled);

    sub.completed();
    assert(observer.hasNotBeenCalled);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);
    scope (exit)
        d.dispose();

    assert(observer.hasNotBeenCalled);

    sub.completed();

    assert(observer.putCount == 0);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);
    scope (exit)
        d.dispose();

    assert(observer.hasNotBeenCalled);

    auto ex = new Exception("TEST");
    sub.failure(ex);

    assert(observer.putCount == 0);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto ex = new Exception("TEST");
    sub.failure(ex);

    auto observer = new CounterObserver!int;

    auto d = sub.subscribe(observer);
    scope (exit)
        d.dispose();

    assert(observer.putCount == 0);
    assert(observer.completedCount == 0);
    assert(observer.failureCount == 1);
    assert(observer.lastException is ex);
}

unittest
{
    auto sub = new AsyncSubject!int;
    auto observer = new CounterObserver!int;

    sub.completed();
    assert(observer.hasNotBeenCalled);

    sub.subscribe(observer);
    assert(observer.putCount == 0);
    assert(observer.completedCount == 1);
    assert(observer.failureCount == 0);
}

version (unittest)
{
    class CounterObserver(T) : Observer!T
    {
    public:
        size_t putCount;
        size_t completedCount;
        size_t failureCount;
        T lastValue;
        Exception lastException;

    public:
        bool hasNotBeenCalled() const pure nothrow @nogc @safe @property
        {
            return putCount == 0 && completedCount == 0 && failureCount == 0;
        }

    public:
        void put(T obj)
        {
            putCount++;
            lastValue = obj;
        }

        void completed()
        {
            completedCount++;
        }

        void failure(Exception e)
        {
            failureCount++;
            lastException = e;
        }
    }
}

///
class BehaviorSubject(E) : Subject!E
{
public:
    ///
    this()
    {
        this(E.init);
    }

    ///
    this(E value)
    {
        _subject = new SubjectObject!E;
        _value = value;
    }

public:
    ///
    inout(E) value() inout @property
    {
        return _value;
    }

    ///
    void value(E value) @property
    {
        if (_value != value)
        {
            _value = value;
            .put(_subject, value);
        }
    }

public:
    ///
    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        .put(observer, value);
        return _subject.doSubscribe(observer);
    }

    ///
    Disposable subscribe(Observer!E observer)
    {
        .put(observer, value);
        return disposableObject(_subject.doSubscribe(observer));
    }

    ///
    void put(E obj)
    {
        value = obj;
    }

    ///
    void completed()
    {
        _subject.completed();
    }

    ///
    void failure(Exception e)
    {
        _subject.failure(e);
    }

private:
    SubjectObject!E _subject;
    E _value;
}

unittest
{
    static assert(isObservable!(BehaviorSubject!int, int));
    static assert(is(BehaviorSubject!int.ElementType == int));
}

unittest
{
    int num = 0;
    auto subject = new BehaviorSubject!int(100);

    auto d = subject.doSubscribe((int n) { num = n; });
    assert(num == 100);

    .put(subject, 1);
    assert(num == 1);

    d.dispose();
    .put(subject, 10);
    assert(num == 1);
}

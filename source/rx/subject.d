/+++++++++++++++++++++++++++++
 + This module defines the Subject and some implements.
 +/
module rx.subject;

import rx.disposable;
import rx.observer;
import rx.observable;

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
    this()
    {
        _observer = cast(shared) NopObserver!E.instance;
    }

public:
    ///
    void put(E obj)
    {
        auto temp = atomicLoad(_observer);
        temp.put(obj);
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
            temp = atomicLoad(oldObserver);
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
            temp = atomicLoad(oldObserver);
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
            auto temp = atomicLoad(oldObserver);

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

            auto temp = atomicLoad(oldObserver);
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
    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n)
        {
            putCount++;
        }

        void completed()
        {
            completedCount++;
        }

        void failure(Exception)
        {
            failureCount++;
        }
    }

    auto subject = new SubjectObject!int;
    auto disposable = subject.subscribe(observerObject!(int)(TestObserver()));

    subject.put(0);
    subject.put(1);

    assert(putCount == 2);
    subject.completed();
    subject.put(2);
    assert(putCount == 2);
    assert(completedCount == 1);
}

unittest
{
    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n)
        {
            putCount++;
        }

        void completed()
        {
            completedCount++;
        }

        void failure(Exception)
        {
            failureCount++;
        }
    }

    auto subject = new SubjectObject!int;
    auto disposable = subject.subscribe(observerObject!(int)(TestObserver()));

    subject.put(0);
    subject.put(1);

    assert(putCount == 2);
    subject.failure(null);
    subject.put(2);
    assert(putCount == 2);
    assert(failureCount == 1);
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
    static class CountObserver(T) : Observer!T
    {
    public:
        size_t putCount;
        size_t failureCount;
        size_t completedCount;

        void put(T)
        {
            putCount++;
        }

        void failure(Exception)
        {
            failureCount++;
        }

        void completed()
        {
            completedCount++;
        }
    }

    auto sub = new SubjectObject!int;
    sub.completed();
    auto observer = new CountObserver!int;
    assert(observer.putCount == 0);
    assert(observer.failureCount == 0);
    assert(observer.completedCount == 0);
    sub.subscribe(observer);
    assert(observer.putCount == 0);
    assert(observer.failureCount == 0);
    assert(observer.completedCount == 1);
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

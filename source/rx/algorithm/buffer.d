/+++++++++++++++++++++++++++++
 + This module defines algorithm 'buffer'
 +/
module rx.algorithm.buffer;

import rx.disposable;
import rx.observable;
import rx.observer;

import std.range : put;

private class Buffer(E, size_t Size)
{
    this()
    {
        buffer = new E[Size];
        buffer.length = 0;
    }

    bool isFull() const pure nothrow @safe @nogc @property
    {
        return buffer.length == Size;
    }

    bool hasElements() const pure nothrow @safe @nogc @property
    {
        return buffer.length > 0;
    }

    void append(ref E obj)
    {
        buffer ~= obj;
    }

    void clear()
    {
        buffer.length = 0;
    }

    E[] buffer;
}

struct BufferedObserver(E, TObserver, size_t Size)
{
    this(TObserver observer, Disposable disposable)
    {
        _observer = observer;
        _disposable = disposable;

        _buffer = new Buffer!(E, Size);
    }

    void put(E obj)
    {
        _buffer.append(obj);
        if (_buffer.isFull)
        {
            .put(_observer, _buffer.buffer);
            _buffer.clear();
        }
    }

    void completed()
    {
        if (_buffer.hasElements)
        {
            .put(_observer, _buffer.buffer);
            _buffer.clear();
        }
        static if (hasCompleted!TObserver)
        {
            _observer.completed();
        }
        _disposable.dispose();
    }

    static if (hasFailure!TObserver)
    {
        void failure(Exception e)
        {
            _observer.failure(e);
            _disposable.dispose();
        }
    }

private:
    TObserver _observer;
    Buffer!(E, Size) _buffer;
    Disposable _disposable;
}

unittest
{
    alias Bufd = BufferedObserver!(int, Observer!int, 2);

    size_t putCount, completedCount;
    auto observer = observerObject!int(makeObserver((int n) { putCount++; }, {
            completedCount++;
        }));
    auto bufd = Bufd(observer, NopDisposable.instance);

    bufd.put(1);
    assert(putCount == 0);
    bufd.put(1);
    assert(putCount == 2);
    bufd.put(1);
    assert(putCount == 2);
    assert(completedCount == 0);
    bufd.completed();
    assert(putCount == 3);
    assert(completedCount == 1);
}

struct BufferedObservable(TObservable, size_t Size)
{
    alias ElementType = TObservable.ElementType[];

    this(TObservable observable)
    {
        _observable = observable;
    }

    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        alias ObserverType = BufferedObserver!(TObservable.ElementType, TObserver, Size);

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
    alias TObservable = BufferedObservable!(Observable!int, 2);
    static assert(isObservable!(TObservable, int[]));

    import rx.subject : SubjectObject;
    import std.array : appender;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto observable = TObservable(sub);
    auto d = observable.subscribe(buf);

    sub.put(0);
    sub.put(1);
    assert(buf.data.length == 2);
    assert(buf.data[0] == 0);
    assert(buf.data[1] == 1);
    sub.put(2);
    assert(buf.data.length == 2);
    sub.completed();
    assert(buf.data.length == 3);
    assert(buf.data[2] == 2);
}

template buffered(size_t Size)
{
    BufferedObservable!(TObservable, Size) buffered(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}

unittest
{
    import rx.subject : SubjectObject;
    import std.array : appender;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub.buffered!2.doSubscribe(buf);

    sub.put(0);
    sub.put(1);
    assert(buf.data.length == 2);
    assert(buf.data[0] == 0);
    assert(buf.data[1] == 1);
    sub.put(2);
    assert(buf.data.length == 2);
    sub.completed();
    assert(buf.data.length == 3);
    assert(buf.data[2] == 2);
}

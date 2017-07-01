/+++++++++++++++++++++++++++++
 + This module defines algorithm 'buffer'
 +/
module rx.algorithm.buffer;

import rx.disposable;
import rx.observable;
import rx.observer;

import std.range : put;

class BufferedObserver(E, TObserver)
{
    this(TObserver observer, Disposable disposable, size_t size)
    {
        assert(size > 0);

        _observer = observer;
        _disposable = disposable;

        _gate = new Object;
        _bufferSize = size;
        _buffer = new E[](size);
        _buffer.length = 0;
    }

    void put(E obj)
    {
        synchronized (_gate)
        {
            _buffer ~= obj;
            if (_buffer.length == _bufferSize)
            {
                .put(_observer, _buffer);
                _buffer.length = 0;
            }
        }
    }

    void completed()
    {
        synchronized (_gate)
        {
            if (_buffer.length > 0)
            {
                .put(_observer, _buffer);
                _buffer.length = 0;
            }
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
    Object _gate;
    size_t _bufferSize;
    E[] _buffer;
    Disposable _disposable;
}

unittest
{
    alias Bufd = BufferedObserver!(int, Observer!int);

    size_t putCount, completedCount;
    auto observer = observerObject!int(makeObserver((int n) { putCount++; }, {
            completedCount++;
        }));
    auto bufd = new Bufd(observer, NopDisposable.instance, 2);

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

struct BufferedObservable(TObservable)
{
    alias ElementType = TObservable.ElementType[];

    this(TObservable observable, size_t bufferSize)
    {
        _observable = observable;
        _bufferSize = bufferSize;
    }

    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        alias ObserverType = BufferedObserver!(TObservable.ElementType, TObserver);

        auto subscription = new SingleAssignmentDisposable;
        subscription.setDisposable(disposableObject(_observable.doSubscribe(new ObserverType(observer,
                subscription, _bufferSize))));
        return subscription;
    }

private:
    TObservable _observable;
    size_t _bufferSize;
}

unittest
{
    alias TObservable = BufferedObservable!(Observable!int);
    static assert(isObservable!(TObservable, int[]));

    import rx.subject : SubjectObject;
    import std.array : appender;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto observable = TObservable(sub, 2);
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

///
BufferedObservable!(TObservable) buffered(TObservable)(
        auto ref TObservable observable, size_t bufferSize)
{
    return typeof(return)(observable, bufferSize);
}

///
unittest
{
    import rx.subject : SubjectObject;
    import std.array : appender;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto d = sub.buffered(2).doSubscribe(buf);

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

///
unittest
{
    import rx.subject : SubjectObject;
    import std.array : appender;
    import std.parallelism : taskPool, task;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);
    auto d = sub.buffered(100).doSubscribe(buf);

    import std.range : iota;

    auto t1 = task({ .put(sub, iota(100)); });
    auto t2 = task({ .put(sub, iota(100)); });
    auto t3 = task({ .put(sub, iota(100)); });
    taskPool.put(t1);
    taskPool.put(t2);
    taskPool.put(t3);

    t1.workForce;
    t2.workForce;
    t3.workForce;

    sub.completed();

    assert(buf.data.length == 300);
}

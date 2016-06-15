/+++++++++++++++++++++++++++++
 + This module defines some operations like range.
 +/
module rx.range;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import core.atomic : cas, atomicLoad;
import std.range : put;

/+++++++++++++++++++++++++++++
 + Overview
 +/
unittest
{
    import rx.subject;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;

    auto subject = new SubjectObject!int;
    auto pub = subject
        .drop(2)
        .take(3);

    auto buf = appender!(int[]);
    auto disposable = pub.subscribe(observerObject!int(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, [2, 3, 4]));
}

//####################
// Drop
//####################
///Creates the observable that results from discarding the first n elements from the given source.
auto drop(TObservable)(auto ref TObservable observable, size_t n)
{
    static struct DropObservable
    {
    public:
        alias ElementType = TObservable.ElementType;

    public:
        this(TObservable observable, size_t n)
        {
            _observable = observable;
            _count = n;
        }

    public:
        auto subscribe(TObserver)(TObserver observer)
        {
            static struct DropObserver
            {
                mixin SimpleObserverImpl!(TObserver, ElementType);

            public:
                this(TObserver observer, size_t count)
                {
                    _observer = observer;
                    _counter = new shared(AtomicCounter)(count);
                }
                static if (hasCompleted!TObserver || hasFailure!TObserver)
                {
                    this(TObserver observer, size_t count, Disposable disposable)
                    {
                        _observer = observer;
                        _counter = new shared(AtomicCounter)(count);
                        _disposable = disposable;
                    }
                }

            private:
                void putImpl(ElementType obj)
                {
                    if (_counter.tryUpdateCount())
                    {
                        _observer.put(obj);
                    }
                }

            private:
                shared(AtomicCounter) _counter;
            }

            static if (hasCompleted!TObserver || hasFailure!TObserver)
            {
                auto disposable = new SingleAssignmentDisposable;
                disposable.setDisposable(disposableObject(doSubscribe(_observable, DropObserver(observer, _count, disposable))));
                return disposable;
            }
            else
            {
                return doSubscribe(_observable, DropObserver(observer, _count));
            }
        }

    private:
        TObservable _observable;
        size_t _count;
    }

    return DropObservable(observable, n);
}
///
unittest
{
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto dropped = subject.drop(1);
    static assert(isObservable!(typeof(dropped), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = dropped.subscribe(buf);

    subject.put(0);
    assert(buf.data.length == 0);
    subject.put(1);
    assert(buf.data.length == 1);

    auto buf2 = appender!(int[]);
    dropped.subscribe(buf2);
    assert(buf2.data.length == 0);
    subject.put(2);
    assert(buf2.data.length == 0);
    assert(buf.data.length == 2);
    subject.put(3);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 3);
}


//####################
// Take
//####################
///Creates a sub-observable consisting of only up to the first n elements of the given source.
auto take(TObservable)(auto ref TObservable observable, size_t n)
{
    static struct TakeObservable
    {
    public:
        alias ElementType = TObservable.ElementType;

    public:
        this(TObservable observable, size_t n)
        {
            _observable = observable;
            _count = n;
        }

    public:
        auto subscribe(TObserver)(TObserver observer)
        {
            static struct TakeObserver
            {
            public:
                this(TObserver observer, size_t count, Disposable disposable)
                {
                    _observer = observer;
                    _count = count;
                    _disposable = disposable;
                }

            public:
                void put(ElementType obj)
                {
                    shared(size_t) oldValue = void;
                    size_t newValue = void;
                    do
                    {
                        oldValue = _count;
                        if (oldValue == 0) return;

                        newValue = atomicLoad(oldValue) - 1;
                    } while(!cas(&_count, oldValue, newValue));

                    _observer.put(obj);
                    if (newValue == 0)
                    {
                        static if (hasCompleted!TObserver)
                        {
                            _observer.completed();
                        }
                        _disposable.dispose();
                    }
                }
                void completed()
                {
                    static if (hasCompleted!TObserver)
                    {
                        _observer.completed();
                    }
                    _disposable.dispose();
                }
                void failure(Exception e)
                {
                    static if (hasFailure!TObserver)
                    {
                        _observer.failure(e);
                    }
                    _disposable.dispose();
                }

            private:
                TObserver _observer;
                shared(size_t) _count;
                Disposable _disposable;
            }

            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, TakeObserver(observer, _count, disposable))));
            return disposable;
        }

    private:
        TObservable _observable;
        size_t _count;
    }

    return TakeObservable(observable, n);
}
///
unittest
{
    import std.array;
    import rx.subject;

    auto pub = new SubjectObject!int;
    auto sub = appender!(int[]);

    auto d = pub.take(2).subscribe(sub);
    foreach (i; 0 .. 10)
    {
        pub.put(i);
    }

    import std.algorithm;
    assert(equal(sub.data, [0, 1]));
}
unittest
{
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto taken = subject.take(1);
    static assert(isObservable!(typeof(taken), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = taken.subscribe(buf);

    subject.put(0);
    assert(buf.data.length == 1);
    subject.put(1);
    assert(buf.data.length == 1);

    auto buf2 = appender!(int[]);
    taken.subscribe(buf2);
    assert(buf2.data.length == 0);
    subject.put(2);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 1);
    subject.put(3);
    assert(buf2.data.length == 1);
    assert(buf.data.length == 1);
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;
    auto taken = sub.take(2);

    int countPut = 0;
    int countCompleted = 0;
    struct TestObserver
    {
        void put(int n) { countPut++; }
        void completed() { countCompleted++; }
    }

    auto d = taken.doSubscribe(TestObserver());
    assert(countPut == 0);
    sub.put(1);
    assert(countPut == 1);
    assert(countCompleted == 0);
    sub.put(2);
    assert(countPut == 2);
    assert(countCompleted == 1);
}


//####################
// TakeLast
//####################
///Creates a observable that take only a last element of the given source.
auto takeLast(TObservable)(auto ref TObservable observable)
{
    static struct TakeLastObservable
    {
    public:
        alias ElementType = TObservable.ElementType;

    public:
        this(ref TObservable observable)
        {
            _observable = observable;
        }

    public:
        auto subscribe(TObserver)(auto ref TObserver observer)
        {
            static class TakeLastObserver
            {
            public:
                this(ref TObserver observer, SingleAssignmentDisposable disposable)
                {
                    _observer = observer;
                    _disposable = disposable;
                }

            public:
                void put(ElementType obj)
                {
                    _current = obj;
                    _hasValue = true;
                }

                void completed()
                {
                    if (_hasValue) _observer.put(_current);

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
                    }
                }

            private:
                bool _hasValue = false;
                ElementType _current;
                TObserver _observer;
                SingleAssignmentDisposable _disposable;
            }

            auto d = new SingleAssignmentDisposable;
            d.setDisposable(disposableObject(doSubscribe(_observable, new TakeLastObserver(observer, d))));
            return d;
        }

    private:
        TObservable _observable;
    }

    return TakeLastObservable(observable);
}
///
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;

    int putCount = 0;
    int completedCount = 0;
    struct TestObserver
    {
        void put(int n) { putCount++; }
        void completed() { completedCount++; }
    }

    auto d = sub.takeLast.subscribe(TestObserver());

    assert(putCount == 0);
    sub.put(1);
    assert(putCount == 0);
    sub.put(10);
    assert(putCount == 0);
    sub.completed();
    assert(putCount == 1);
    assert(completedCount == 1);
    
    sub.put(100);
    assert(putCount == 1);
    assert(completedCount == 1);
}

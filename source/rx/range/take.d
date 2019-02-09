/+++++++++++++++++++++++++++++
 + This module is a submodule of rx.range.
 + It provides basic operation a 'take'
 +/
 module rx.range.take;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.range : put;

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
                    _counter = new shared(AtomicCounter)(count);
                    _disposable = disposable;
                }

            public:
                void put(ElementType obj)
                {
                    auto result = _counter.tryDecrement();
                    if (result.success)
                    {
                        .put(_observer, obj);
                        if (result.count == 0)
                        {
                            static if (hasCompleted!TObserver)
                            {
                                _observer.completed();
                            }
                            _disposable.dispose();
                        }
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
                shared(AtomicCounter) _counter;
                Disposable _disposable;
            }

            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable,
                    TakeObserver(observer, _count, disposable))));
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
        void put(int n)
        {
            countPut++;
        }

        void completed()
        {
            countCompleted++;
        }
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

unittest
{
    import rx.subject : SubjectObject;

    auto source1 = new SubjectObject!int;
    auto source2 = new SubjectObject!int;

    import rx.algorithm : merge;

    auto source = merge(source1, source2).take(2);
    int[] result;
    source.doSubscribe!(n => result ~= n);

    .put(source1, 0);
    .put(source2, 1);
    .put(source1, 2);
    .put(source2, 3);

    assert(result.length == 2);
    assert(result[0] == 0);
    assert(result[1] == 1);
}

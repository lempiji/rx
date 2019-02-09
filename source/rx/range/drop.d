/+++++++++++++++++++++++++++++
 + This module is a submodule of rx.range.
 + It provides basic operation a 'drop'
 +/
module rx.range.drop;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.range : put;

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
                        .put(_observer, obj);
                    }
                }

            private:
                shared(AtomicCounter) _counter;
            }

            static if (hasCompleted!TObserver || hasFailure!TObserver)
            {
                auto disposable = new SingleAssignmentDisposable;
                disposable.setDisposable(disposableObject(doSubscribe(_observable,
                        DropObserver(observer, _count, disposable))));
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

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!(int[]);
    int count = 0;
    auto d = sub.drop(1).subscribe((int) { count++; });
    scope (exit)
        d.dispose();

    assert(count == 0);
    sub.put([1, 2]);
    assert(count == 0);
    sub.put([2, 3]);
    assert(count == 2);
}

unittest
{
    import rx.subject : SubjectObject;

    auto source1 = new SubjectObject!int;
    auto source2 = new SubjectObject!int;

    import rx.algorithm : merge;

    auto source = merge(source1, source2).drop(2);
    int[] result;
    source.doSubscribe!(n => result ~= n);

    .put(source1, 0);
    .put(source2, 1);
    .put(source1, 2);
    .put(source2, 3);

    assert(result.length == 2);
    assert(result[0] == 2);
    assert(result[1] == 3);
}

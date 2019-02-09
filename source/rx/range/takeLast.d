/+++++++++++++++++++++++++++++
 + This module is a submodule of rx.range.
 + It provides basic operation a 'takeLast'
 +/
module rx.range.takeLast;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.range : put;

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
                    if (_hasValue)
                        .put(_observer, _current);

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
            d.setDisposable(disposableObject(doSubscribe(_observable,
                    new TakeLastObserver(observer, d))));
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
        void put(int n)
        {
            putCount++;
        }

        void completed()
        {
            completedCount++;
        }
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

unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!(int[]);

    int count = 0;
    auto d = sub.takeLast.subscribe((int) { count++; });
    scope(exit) d.dispose();

    assert(count == 0);
    sub.put([0]);
    assert(count == 0);
    sub.put([1, 2]);
    assert(count == 0);
    sub.completed();
    assert(count == 2);
}

unittest
{
    import rx : SubjectObject, merge;

    auto source1 = new SubjectObject!int;
    auto source2 = new SubjectObject!int;

    auto source = merge(source1, source2).takeLast();
    int[] result;
    source.doSubscribe!(n => result ~= n);

    .put(source1, 0);
    .put(source2, 1);
    source1.completed();
    
    assert(result.length == 0);

    .put(source2, 2);
    source2.completed();

    assert(result.length == 1);
    assert(result[0] == 2);
}
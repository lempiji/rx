/+++++++++++++++++++++++++++++
 + This module defines algorithm 'filter'
 +/
module rx.algorithm.filter;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : unaryFun;
import std.range : put;

//####################
// Filter
//####################
///Implements the higher order filter function. The predicate is passed to std.functional.unaryFun, and can either accept a string, or any callable that can be executed via pred(element).
template filter(alias pred)
{
    auto filter(TObservable)(auto ref TObservable observable)
    {
        static struct FilterObservable
        {
            alias ElementType = TObservable.ElementType;

        public:
            this(TObservable observable)
            {
                _observable = observable;
            }

        public:
            auto subscribe(TObserver)(TObserver observer)
            {
                static struct FilterObserver
                {
                    mixin SimpleObserverImpl!(TObserver, ElementType);

                public:
                    this(TObserver observer)
                    {
                        _observer = observer;
                    }
                    static if (hasCompleted!TObserver || hasFailure!TObserver)
                    {
                        this(TObserver observer, Disposable disposable)
                        {
                            _observer = observer;
                            _disposable = disposable;
                        }
                    }

                private:
                    void putImpl(ElementType obj)
                    {
                        alias fun = unaryFun!pred;
                        if (fun(obj)) _observer.put(obj);
                    }
                }

                alias ObserverType = FilterObserver;
                static if (hasCompleted!TObserver || hasFailure!TObserver)
                {
                    auto disposable = new SingleAssignmentDisposable;
                    disposable.setDisposable(disposableObject(doSubscribe(_observable, FilterObserver(observer, disposable))));
                    return disposable;
                }
                else
                {
                    return doSubscribe(_observable, FilterObserver(observer));
                }
            }

        private:
            TObservable _observable;
        }

        return FilterObservable(observable);
    }
}

///
unittest
{
    import rx.subject : Subject, SubjectObject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!(n => n % 2 == 0);
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    scope(exit) disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);

    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}

unittest
{
    import rx.subject : Subject, SubjectObject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!"a % 2 == 0";
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    scope(exit) disposable.dispose();

    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);

    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}

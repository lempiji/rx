/+++++++++++++++++++++++++++++
 + This module defines the concept of Observable.
 +/
module rx.observable;

import std.functional : unaryFun;
import std.range : put;

import rx.disposable;
import rx.observer;
import rx.util;

///Tests if something is a Observable.
template isObservable(T, E)
{
    enum bool isObservable = is(T.ElementType : E) && is(typeof({
                T observable = void;
                Observer!E observer = void;
                auto d = observable.subscribe(observer);
                static assert(isDisposable!(typeof(d)));
            }()));
}
///
unittest
{
    struct TestObservable
    {
        alias ElementType = int;

        Disposable subscribe(T)(T observer)
        {
            static assert(isObserver!(T, int));
            return null;
        }
    }

    static assert(isObservable!(TestObservable, int));
    static assert(!isObservable!(TestObservable, Object));
}

///Test if the observer can subscribe to the observable.
template isSubscribable(TObservable, TObserver)
{
    enum bool isSubscribable = is(typeof({
                TObservable observable = void;
                TObserver observer = void;
                auto d = observable.subscribe(observer);
                static assert(isDisposable!(typeof(d)));
            }()));
}
///
unittest
{
    struct TestDisposable
    {
        void dispose()
        {
        }
    }

    struct TestObserver
    {
        void put(int n)
        {
        }

        void completed()
        {
        }

        void failure(Exception e)
        {
        }
    }

    struct TestObservable
    {
        TestDisposable subscribe(TestObserver observer)
        {
            return TestDisposable();
        }
    }

    static assert(isSubscribable!(TestObservable, TestObserver));
}

///The helper for subscribe easier.
auto doSubscribe(TObservable, E)(auto ref TObservable observable, void delegate(E) doPut,
        void delegate() doCompleted, void delegate(Exception) doFailure)
{
    return doSubscribe(observable, makeObserver(doPut, doCompleted, doFailure));
}
///ditto
auto doSubscribe(TObservable, E)(auto ref TObservable observable,
        void delegate(E) doPut, void delegate() doCompleted)
{
    return doSubscribe(observable, makeObserver(doPut, doCompleted));
}
///ditto
auto doSubscribe(TObservable, E)(auto ref TObservable observable,
        void delegate(E) doPut, void delegate(Exception) doFailure)
{
    return doSubscribe(observable, makeObserver(doPut, doFailure));
}
///ditto
auto doSubscribe(TObservable, TObserver)(auto ref TObservable observable, auto ref TObserver observer)
{
    alias ElementType = TObservable.ElementType;
    static if (isSubscribable!(TObservable, TObserver))
        return observable.subscribe(observer);
    else static if (isSubscribable!(TObservable, Observer!ElementType))
        return observable.subscribe(observerObject!ElementType(observer));
    else
        static assert(false);
}
///
unittest
{
    struct TestObserver
    {
        void put(int n)
        {
        }
    }

    struct TestObservable1
    {
        alias ElementType = int;
        Disposable subscribe(Observer!int observer)
        {
            return null;
        }
    }

    struct TestObservable2
    {
        alias ElementType = int;
        Disposable subscribe(T)(T observer)
        {
            return null;
        }
    }

    TestObservable1 o1;
    auto d0 = o1.doSubscribe((int n) {  }, () {  }, (Exception e) {  });
    auto d1 = o1.doSubscribe((int n) {  }, () {  });
    auto d2 = o1.doSubscribe((int n) {  }, (Exception e) {  });
    auto d3 = o1.doSubscribe((int n) {  });
    auto d4 = o1.doSubscribe(TestObserver());
    TestObservable2 o2;
    auto d5 = o2.doSubscribe((int n) {  }, () {  }, (Exception e) {  });
    auto d6 = o2.doSubscribe((int n) {  }, () {  });
    auto d7 = o2.doSubscribe((int n) {  }, (Exception e) {  });
    auto d8 = o2.doSubscribe((int n) {  });
    auto d9 = o2.doSubscribe(TestObserver());
}

///Wrapper for Observable objects.
interface Observable(E)
{
    alias ElementType = E;

    Disposable subscribe(Observer!E observer);
}

unittest
{
    static assert(isObservable!(Observable!int, int));
}

///Class that implements Observable interface and wraps the subscribe method in virtual function.
class ObservableObject(R, E) : Observable!E
{
public:
    this(R observable)
    {
        _observable = observable;
    }

public:
    Disposable subscribe(Observer!E observer)
    {
        return disposableObject(_observable.subscribe(observer));
    }

private:
    R _observable;
}

///Wraps subscribe method in virtual function.
template observableObject(E)
{
    Observable!E observableObject(R)(auto ref R observable)
    {
        static if (is(R : Observable!E))
        {
            return observable;
        }
        else
        {
            return new ObservableObject!(R, E)(observable);
        }
    }
}
///
unittest
{
    int subscribeCount = 0;
    class TestObservable : Observable!int
    {
        Disposable subscribe(Observer!int observer)
        {
            subscribeCount++;
            return NopDisposable.instance;
        }
    }

    auto test = new TestObservable;
    auto observable = observableObject!int(test);
    assert(observable is test);
    assert(subscribeCount == 0);
    auto d = observable.subscribe(null);
    assert(subscribeCount == 1);
}

unittest
{
    int disposeCount = 0;
    int subscribeCount = 0;

    struct TestDisposable
    {
        void dispose()
        {
            disposeCount++;
        }
    }

    struct TestObservable
    {
        TestDisposable subscribe(Observer!int observer)
        {
            subscribeCount++;
            return TestDisposable();
        }
    }

    Observable!int observable = observableObject!int(TestObservable());
    assert(subscribeCount == 0);
    Disposable disposable = observable.subscribe(null);
    assert(subscribeCount == 1);
    assert(disposeCount == 0);
    disposable.dispose();
    assert(disposeCount == 1);
}

//#########################
// Defer
//#########################
///Create observable by function that template parameter.
auto defer(E, alias f)()
{
    static struct DeferObservable
    {
        alias ElementType = E;

    public:
        auto subscribe(TObserver)(TObserver observer)
        {
            static struct DeferObserver
            {
            public:
                this(TObserver observer, EventSignal signal)
                {
                    _observer = observer;
                    _signal = signal;
                }

            public:
                void put(E obj)
                {
                    if (_signal.signal)
                        return;

                    static if (hasFailure!TObserver)
                    {
                        try
                        {
                            .put(_observer, obj);
                        }
                        catch (Exception e)
                        {
                            _observer.failure(e);
                        }
                    }
                    else
                    {
                        .put(_observer, obj);
                    }
                }

                void completed()
                {
                    if (_signal.signal)
                        return;
                    _signal.setSignal();

                    static if (hasCompleted!TObserver)
                    {
                        _observer.completed();
                    }
                }

                void failure(Exception e)
                {
                    if (_signal.signal)
                        return;
                    _signal.setSignal();

                    static if (hasFailure!TObserver)
                    {
                        _observer.failure(e);
                    }
                }

            private:
                TObserver _observer;
                EventSignal _signal;
            }

            alias fun = unaryFun!f;
            auto d = new SignalDisposable;
            fun(DeferObserver(observer, d.signal));
            return d;
        }
    }

    return DeferObservable();
}
///
unittest
{
    auto sub = defer!(int, (observer) {
        observer.put(1);
        observer.put(2);
        observer.put(3);
        observer.completed();
    });

    int countPut = 0;
    int countCompleted = 0;
    struct A
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

    assert(countPut == 0);
    assert(countCompleted == 0);
    auto d = sub.doSubscribe(A());
    assert(countPut == 3);
    assert(countCompleted == 1);
}

unittest
{
    auto sub = defer!(int, (observer) {
        observer.put(0);
        observer.failure(new Exception(""));
        observer.put(1);
    });

    int countPut = 0;
    int countFailure = 0;
    struct A
    {
        void put(int n)
        {
            countPut++;
        }

        void failure(Exception e)
        {
            countFailure++;
        }
    }

    assert(countPut == 0);
    assert(countFailure == 0);
    auto d = sub.doSubscribe(A());
    assert(countPut == 1);
    assert(countFailure == 1);
}

unittest
{
    auto sub = defer!(int, (observer) {
        observer.put(0);
        observer.failure(new Exception(""));
        observer.put(1);
    });

    int countPut = 0;
    struct A
    {
        void put(int n)
        {
            countPut++;
        }
    }

    assert(countPut == 0);
    auto d = sub.doSubscribe(A());
    assert(countPut == 1);
}

unittest
{
    Disposable subscribeImpl(Observer!int observer)
    {
        .put(observer, 1);
        return null;
    }

    import std.array : appender;
    auto buf = appender!(int[]);

    auto put1 = defer!int(&subscribeImpl);
    auto d = put1.doSubscribe(buf);

    assert(buf.data.length == 1);
    assert(buf.data[0] == 1);
    assert(d is null);
}

auto defer(E, TSubscribe)(auto ref TSubscribe subscribeImpl)
{
    struct DeferObservable
    {
        alias ElementType = E;

        auto subscribe(TObserver)(auto ref TObserver observer)
        {
            return subscribeImpl(observer);
        }
    }

    return DeferObservable();
}

unittest
{
    import std.array : appender;
    auto buf = appender!(int[]);

    auto put12 = defer!int((Observer!int observer) {
        .put(observer, 1);
        .put(observer, 2);
        return NopDisposable.instance;
    });
    auto d = put12.doSubscribe(buf);

    assert(buf.data.length == 2);
    assert(buf.data[0] == 1);
    assert(buf.data[1] == 2);
}

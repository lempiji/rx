module rx.observable;

import rx.primitives;
import rx.disposable;
import rx.observer;

template isObservable(T, E)
{
    enum bool isObservable = is(T.ElementType : E) && is(typeof({
            T observable = void;
            Observer!E observer = void;
            auto d = observable.subscribe(observer);
            static assert(isDisposable!(typeof(d)));
        }()));
}
unittest
{
    struct TestDisposable
    {
        void dispose() { }
    }
    struct TestObservable
    {
        alias ElementType = int;
        TestDisposable subscribe(T)(T observer)
        {
            static assert(isObserver!(T, int));
            return TestDisposable();
        }
    }

    static assert( isObservable!(TestObservable, int));
    static assert(!isObservable!(TestObservable, Object));
}

template isSubscribable(TObservable, TObserver)
{
    enum bool isSubscribable = is(typeof({
            TObservable observable = void;
            TObserver observer = void;
            auto d = observable.subscribe(observer);
            static assert(isDisposable!(typeof(d)));
        }()));
}
unittest
{
    struct TestDisposable
    {
        void dispose() { }
    }
    struct TestObserver
    {
        void put(int n) { }
        void completed() { }
        void failure(Exception e) { }
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

interface Observable(E)
{
    alias ElementType = E;
    Disposable subscribe(Observer!E observer);
}

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

template observableObject(E)
{
    Observable!E observableObject(R)(R observable)
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

unittest
{
    static assert(isObservable!(Observable!int, int));
}

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
        void dispose() { disposeCount++; }
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

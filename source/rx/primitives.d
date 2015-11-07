module rx.primitives;

import std.range.primitives;

template isDisposable(T)
{
    enum bool isDisposable = is(typeof({
            T disposable = void;
            disposable.dispose();
        }()));
}
unittest
{
    struct A { void dispose(){} }
    class B {void dispose(){} }
    interface C { void dispose(); }

    static assert(isDisposable!A);
    static assert(isDisposable!B);
    static assert(isDisposable!C);
}

template hasCompleted(T)
{
    enum bool hasCompleted = is(typeof({
            T observer = void;
            observer.completed();
        }()));
}
unittest
{
    struct A
    {
        void completed();
    }
    struct B
    {
        void _completed();
    }

    static assert( hasCompleted!A);
    static assert(!hasCompleted!B);
}

template hasFailure(T)
{
    enum bool hasFailure = is(typeof({
            T observer = void;
            Exception e = void;
            observer.failure(e);
        }()));
}
unittest
{
    struct A
    {
        void failure(Exception e);
    }
    struct B
    {
        void _failure(Exception e);
    }
    struct C
    {
        void failure();
    }

    static assert(hasFailure!A);
    static assert(!hasFailure!B);
    static assert(!hasFailure!C);
}

template isObserver(T, E)
{
    enum bool isObserver = isOutputRange!(T, E) && hasCompleted!T && hasFailure!T;
}
unittest
{
    struct TestObserver
    {
        void put(int n) { }
        void completed() { }
        void failure(Exception e) { }
    }

    static assert(isObserver!(TestObserver, int));
}

template isObservable(T, E)
{
    enum bool isObservable = is(T.ElementType : E) && is(typeof({
            T observable = void;
            struct Observer
            {
                void put(E) { }
                void completed() { }
                void failure(Exception) { }
            }
            Observer observer = void;
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

///
module rx.range.zip;

import rx.disposable;
import rx.observable;
import rx.observer;

import std.range : put;
import std.typecons : tuple;
import std.meta;
import std.container.dlist : DList;

///
class ZipNObservable(alias selector, TObservables...)
{
    ///
    alias ElementType = typeof({
        GetElementsTuple!TObservables values = void;
        return selector(values);
    }());

    TObservables sources;

    ///
    this(TObservables observables)
    {
        sources = observables;
    }

    ///
    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        auto sink = new ZipNSink!(selector, ElementType, TObserver, TObservables)(sources, observer);
        return sink.run();
    }
}

class ZipNSink(alias selector, E, TObserver, TObservables...)
{
    alias ItemTypes = GetElementsTuple!TObservables;
    alias Store = GetZipStoreType!(TObserver, TObservables);

    TObservables sources;
    TObserver observer;
    Store store;
    Object gate;
    Disposable cancel;

    this(TObservables sources, TObserver observer)
    {
        this.sources = sources;
        this.observer = observer;
        this.gate = new Object;
    }

    auto run()
    {
        auto disposable = new SingleAssignmentDisposable;
        this.cancel = disposable;

        Disposable[] disposables;

        static foreach (i; 0 .. TObservables.length)
        {
            disposables ~= disposableObject(sources[i].doSubscribe(new ZipChildObserver!(i,
                    TObserver, ItemTypes[i])));
            disposables ~= new AnonymousDisposable({ store[i].queue.clear(); });
        }
        disposables ~= new AnonymousDisposable({
            static foreach (i; 0 .. TObservables.length)
            {
                store[i].queue.clear();
            }
        });
        disposable.setDisposable(new CompositeDisposable(disposables));

        return disposable;
    }

    bool hasElements()
    {
        static foreach (i; 0 .. TObservables.length)
        {
            if (store[i].empty)
                return false;
        }
        return true;
    }

    static if (hasCompleted!TObserver)
    {
        bool isCompleted()
        {
            static foreach (i; 0 .. TObservables.length)
            {
                if (!store[i].isCompleted)
                    return false;
            }
            return true;
        }
    }

    void enqueue()
    {

        if (hasElements())
        {
            ItemTypes items;
            static foreach (i; 0 .. TObservables.length)
            {
                items[i] = store[i].dequeue();
            }

            static if (hasFailure!TObserver)
            {
                E result = void;
                try
                {
                    result = selector(items);
                }
                catch (Exception e)
                {
                    observer.failure(e);
                    return;
                }
                .put(observer, result);
            }
            else
            {
                .put(observer, selector(items));
            }
            return;
        }

        static if (hasCompleted!TObserver)
        {
            if (isCompleted())
            {
                observer.completed();
            }
        }
    }

    static if (hasCompleted!TObserver)
    {
        void checkCompleted()
        {
            if (isCompleted())
            {
                observer.completed();
            }
        }
    }

    void failure(Exception e)
    {
        observer.failure(e);
    }

    class ZipChildObserver(size_t index, TObserver, E)
    {
        void put(E obj)
        {
            synchronized (gate)
            {
                store[index].enqueue(obj);
                this.outer.enqueue();
            }
        }

        static if (hasCompleted!TObserver)
        {
            void completed()
            {
                synchronized (gate)
                {
                    store[index].isCompleted = true;
                    this.outer.checkCompleted();
                }
            }
        }

        void failure(Exception e)
        {
            scope(exit) cancel.dispose();
            static if (hasFailure!TObserver)
            {
                store[index].isCompleted = true;
                this.outer.observer.failure(e);
            }
        }
    }
}

///
template GetElementsTuple(Ts...)
{
    alias GetElementType(TObservable) = TObservable.ElementType;
    alias GetElementsTuple = AliasSeq!(staticMap!(GetElementType, Ts));
}

///
alias GetZipStoreType(TObserver, TObservables...) = AliasSeq!(
        staticMap!(GetZipStoreTypeImpl!TObserver, GetElementsTuple!TObservables));

///
template GetZipStoreTypeImpl(TObserver)
{
    ///
    alias GetZipStoreTypeImpl(E) = ZipStore!(E, hasCompleted!TObserver);
}

unittest
{
    import rx;

    alias GetStore = GetZipStoreTypeImpl!(Observer!int);
    alias Store = GetStore!int;

    static assert(is(Store == ZipStore!(int, true)));
}

///
struct ZipStore(E, bool useCompleted)
{
    DList!E queue;
    static if (useCompleted)
    {
        bool isCompleted;
    }

    bool empty() @property
    {
        return queue.empty;
    }

    void enqueue(E obj)
    {
        queue.insertBack(obj);
    }

    E dequeue()
    {
        scope (success)
        {
            queue.removeFront();
        }

        return queue.front;
    }
}

unittest
{
    import rx;
    import std.conv : to;
    import std.range : iota;

    alias A = SubjectObject!int;
    alias B = SubjectObject!int;
    alias C = SubjectObject!int;

    alias concatAsStrings = (a, b, c) => to!string(a) ~ to!string(b) ~ to!string(c);

    alias Zip = ZipNObservable!(concatAsStrings, A, B, C);

    auto a = new A;
    auto b = new B;
    auto c = new C;
    auto zipped = new Zip(a, b, c);

    string s;
    auto observer = ((string text) { s = text; }).observerObject!string();
    auto disposable = zipped.subscribe(observer);
    scope (exit)
        disposable.dispose();

    .put(a, iota(3));
    .put(b, iota(3));

    assert(s == null);
    .put(c, 0);
    assert(s == "000");
    .put(c, 1);
    assert(s == "111");
    .put(c, 2);
    assert(s == "222");
    .put(c, 3);
    assert(s == "222");
    .put(a, 3);
    assert(s == "222");
    .put(b, 3);
    assert(s == "333");
}

///
template zip(alias selector = tuple)
{
    ZipNObservable!(selector, TObservables) zip(TObservables...)(TObservables observables)
    {
        return new typeof(return)(observables);
    }
}

///
unittest
{
    // use simple
    import rx;

    auto s0 = new SubjectObject!int;
    auto s1 = new SubjectObject!int;

    auto zipped = zip(s0, s1);

    int[] buf;
    auto disposable = zipped.doSubscribe!(t => buf ~= (t[0] * t[1]));
    scope (exit)
        disposable.dispose();

    .put(s0, [0, 1, 2, 3]);
    assert(buf.length == 0);

    .put(s1, 0);
    assert(buf == [0]);
    .put(s1, 1);
    assert(buf == [0, 1]);
    .put(s1, 2);
    assert(buf == [0, 1, 4]);
    .put(s1, 3);
    assert(buf == [0, 1, 4, 9]);
}

///
unittest
{
    // call completed
    import rx;
    import std.typecons;

    auto s0 = new SubjectObject!int;
    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!int;

    auto observer = new CounterObserver!(Tuple!(int, int, int));
    auto disposable = zip(s0, s1, s2).doSubscribe(observer);
    scope (exit)
        disposable.dispose();

    .put(s0, 100);
    .put(s1, 10);
    .put(s2, 1);
    assert(observer.putCount == 1);
    assert(observer.lastValue == tuple(100, 10, 1));

    s0.completed();
    assert(observer.completedCount == 0);
    s1.completed();
    assert(observer.completedCount == 0);
    s2.completed();
    assert(observer.completedCount == 1);
}

///
unittest
{
    // use selector
    import rx;

    auto s0 = new SubjectObject!int;
    auto s1 = new SubjectObject!int;

    int[] buf;
    auto disposable = zip!((a, b) => a + b)(s0, s1).doSubscribe!(n => buf ~= n);
    scope (exit)
        disposable.dispose();

    .put(s0, 100);
    .put(s0, 200);
    .put(s1, 10);
    .put(s1, 20);

    assert(buf == [110, 220]);
}

unittest
{
    // advanced
    import rx;
    import std.typecons : Tuple;

    auto sub = new SubjectObject!int;
    auto observer = new CounterObserver!(Tuple!(int, int));

    auto disposable = zip(sub, sub.drop(1)).doSubscribe(observer);
    scope (exit)
        disposable.dispose();

    .put(sub, 0);
    .put(sub, 1);
    assert(observer.putCount == 1);
    assert(observer.lastValue == tuple(0, 1));
    .put(sub, 2);
    assert(observer.putCount == 2);
    assert(observer.lastValue == tuple(1, 2));
}

unittest
{
    // dispose all
    import rx;
    import std.typecons : Tuple;

    alias InnerObserver = CounterObserver!(Tuple!(int, int));

    auto s0 = new TestingSubject!int;
    auto s1 = new TestingSubject!int;
    auto observer = new InnerObserver;

    auto disposable = zip(s0, s1).subscribe(observer);

    import std.conv;

    assert(s0.observerCount == 1, "Error: " ~ to!string(s0.observerCount));
    assert(s1.observerCount == 1, "Error: " ~ to!string(s1.observerCount));
    disposable.dispose();
    assert(s0.observerCount == 0, "Error: " ~ to!string(s0.observerCount));
    assert(s1.observerCount == 0, "Error: " ~ to!string(s1.observerCount));
}

unittest
{
    // unsbscribe when completed
    import rx;
    import std.typecons : Tuple;

    alias InnerObserver = CounterObserver!(Tuple!(int, int));

    auto s0 = new TestingSubject!int;
    auto s1 = new TestingSubject!int;
    auto observer = new InnerObserver;

    auto disposable = zip(s0, s1).subscribe(observer);
    scope (exit)
        disposable.dispose();

    s0.completed();
    assert(s0.observerCount == 0);
    assert(s1.observerCount == 1);
    s1.completed();
    assert(s0.observerCount == 0);
    assert(s1.observerCount == 0);
}

unittest
{
    // if any subject failured then call observer.failure
    import rx;
    import std.typecons : Tuple;

    auto s0 = new TestingSubject!int;
    auto s1 = new TestingSubject!int;
    auto observer = new CounterObserver!(Tuple!(int, int));
    auto disposable = zip(s0, s1).doSubscribe(observer);
    scope (exit)
        disposable.dispose();

    auto e = new Exception("TEST");
    s0.failure(e);
    assert(observer.failureCount == 1);
    assert(observer.lastException is e);
    s1.failure(new Exception("test"));
    assert(observer.failureCount == 1);
    assert(observer.lastException is e);
}

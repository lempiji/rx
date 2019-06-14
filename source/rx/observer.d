/+++++++++++++++++++++++++++++
 + This module defines the concept of Observer.
 +/
module rx.observer;

import std.range;
import std.typetuple;

///Tests if something has completed method.
template hasCompleted(T)
{
    //dfmt off
    enum bool hasCompleted = is(typeof({
            T observer = void;
            observer.completed();
        }()));
    //dfmt on
}
///
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

    static assert(hasCompleted!A);
    static assert(!hasCompleted!B);
}

///Tests if something has failure method.
template hasFailure(T)
{
    //dfmt off
    enum bool hasFailure = is(typeof({
            T observer = void;
            Exception e = void;
            observer.failure(e);
        }()));
    //dfmt on
}
///
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

///Tests if something is Observer.
template isObserver(T, E)
{
    enum bool isObserver = isOutputRange!(T, E) && hasCompleted!T && hasFailure!T;
}
///
unittest
{
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

    static assert(isObserver!(TestObserver, int));
}

///Wraps completed and failure method in virtual function.
interface Observer(E) : OutputRange!E
{
    ///
    void completed();
    ///
    void failure(Exception e);
}
///
unittest
{
    alias TObserver = Observer!byte;
    static assert(isObserver!(TObserver, byte));
}

///Class that implements Observer interface and wraps the completed and failure method in virtual functions. This class extends the OutputRangeObject.
class ObserverObject(R, E...) : OutputRangeObject!(R, E), staticMap!(Observer, E)
{
public:
    this(R range)
    {
        super(range);
        _range = range;
    }

public:
    ///
    void completed()
    {
        static if (hasCompleted!R)
        {
            _range.completed();
        }
    }
    ///
    void failure(Exception e)
    {
        static if (hasFailure!R)
        {
            _range.failure(e);
        }
    }

private:
    R _range;
}

///Wraps subscribe method in virtual function.
template observerObject(E)
{
    ObserverObject!(R, E) observerObject(R)(R range)
    {
        return new ObserverObject!(R, E)(range);
    }
}
///
unittest
{
    struct TestObserver
    {
        void put(int n)
        {
        }

        void put(Object obj)
        {
        }
    }

    Observer!int observer = observerObject!int(TestObserver());
    observer.put(0);
    observer.completed();
    observer.failure(null);
    static assert(isObserver!(typeof(observer), int));
}

unittest
{
    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;

    class TestObserver : Observer!int
    {
        void put(int n)
        {
            putCount++;
        }

        void completed()
        {
            completedCount++;
        }

        void failure(Exception e)
        {
            failureCount++;
        }
    }

    static assert(isObserver!(TestObserver, int));

    auto test = new TestObserver;
    Observer!int observer = observerObject!int(test);
    assert(putCount == 0);
    observer.put(0);
    assert(putCount == 1);
    assert(completedCount == 0);
    observer.completed();
    assert(completedCount == 1);
    assert(failureCount == 0);
    observer.failure(null);
    assert(failureCount == 1);
}

unittest
{
    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;

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

        void failure(Exception e)
        {
            failureCount++;
        }
    }

    static assert(isObserver!(TestObserver, int));

    TestObserver test;
    Observer!int observer = observerObject!int(test);
    assert(putCount == 0);
    observer.put(0);
    assert(putCount == 1);
    assert(completedCount == 0);
    observer.completed();
    assert(completedCount == 1);
    assert(failureCount == 0);
    observer.failure(null);
    assert(failureCount == 1);
}

unittest
{
    struct TestObserver1
    {
        void put(int n)
        {
        }
    }

    struct TestObserver2
    {
        void put(int n)
        {
        }

        void completed()
        {
        }
    }

    struct TestObserver3
    {
        void put(int n)
        {
        }

        void failure(Exception e)
        {
        }
    }

    struct TestObserver4
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

    Observer!int o1 = observerObject!int(TestObserver1());
    Observer!int o2 = observerObject!int(TestObserver2());
    Observer!int o3 = observerObject!int(TestObserver3());
    Observer!int o4 = observerObject!int(TestObserver4());

    //dfmt off
    o1.put(0); o1.completed(); o1.failure(null);
    o2.put(0); o2.completed(); o2.failure(null);
    o3.put(0); o3.completed(); o3.failure(null);
    o4.put(0); o4.completed(); o4.failure(null);
    //dfmt on
}

///
final class NopObserver(E) : Observer!E
{
private:
    this()
    {
    }

public:
    void put(E)
    {
    }

    void completed()
    {
    }

    void failure(Exception)
    {
    }

public:
    ///
    static Observer!E instance()
    {
        import std.concurrency : initOnce;

        static __gshared NopObserver!E inst;
        return initOnce!inst(new NopObserver!E);
    }
}
///
unittest
{
    Observer!int o1 = NopObserver!int.instance;
    Observer!int o2 = NopObserver!int.instance;
    assert(o1 !is null);
    assert(o1 is o2);
}

///
final class DoneObserver(E) : Observer!E
{
private:
    this()
    {
    }
public:
    this(Exception e)
    {
        _exception = e;
    }

public:
    Exception exception() @property
    {
        return _exception;
    }
    void exception(Exception e) @property
    {
        _exception = e;
    }

public:
    void put(E)
    {
    }

    void completed()
    {
    }

    void failure(Exception)
    {
    }

private:
    Exception _exception;

public:
    static Observer!E instance()
    {
        import std.concurrency : initOnce;

        static __gshared DoneObserver!E inst;
        return initOnce!inst(new DoneObserver!E);
    }
}
///
unittest
{
    Observer!int o1 = DoneObserver!int.instance;
    Observer!int o2 = DoneObserver!int.instance;
    assert(o1 !is null);
    assert(o1 is o2);
}

unittest
{
    auto e = new Exception("test");
    auto observer = new DoneObserver!int(e);
    assert(observer.exception is e);
}

///
public class CompositeObserver(E) : Observer!E
{
private:
    this()
    {
    }

public:
    ///
    this(Observer!E[] observers)
    {
        _observers = observers;
    }

public:
    ///
    Observer!E[] observers() @property
    {
        return _observers;
    }

public:
    ///
    void put(E obj)
    {
        foreach (observer; _observers)
            .put(observer, obj);
    }
    ///
    void completed()
    {
        foreach (observer; _observers)
            observer.completed();
    }
    ///
    void failure(Exception e)
    {
        foreach (observer; _observers)
            observer.failure(e);
    }
    ///
    CompositeObserver!E add(Observer!E observer)
    {
        return new CompositeObserver!E(_observers ~ observer);
    }
    ///
    Observer!E remove(Observer!E observer)
    {
        import std.algorithm : countUntil;

        auto i = _observers.countUntil(observer);
        if (i < 0)
            return this;

        if (_observers.length == 1)
            return CompositeObserver!E.empty;
        if (_observers.length == 2)
            return _observers[1 - i];

        return new CompositeObserver!E(_observers[0 .. i] ~ _observers[i + 1 .. $]);
    }
    ///
    CompositeObserver!E removeStrict(Observer!E observer)
    {
        import std.algorithm : countUntil;

        auto i = _observers.countUntil(observer);
        if (i < 0)
            return this;

        if (_observers.length == 1)
            return CompositeObserver!E.empty;
        if (_observers.length == 2)
        {
            if (i == 0)
                return new CompositeObserver!E(_observers[1 .. $]);
            if (i == 1)
                return new CompositeObserver!E(_observers[0 .. 1]);
        }
        return new CompositeObserver!E(_observers[0 .. i] ~ _observers[i + 1 .. $]);
    }

public:
    ///
    static CompositeObserver!E empty()
    {
        import std.concurrency : initOnce;

        static __gshared CompositeObserver!E inst;
        return initOnce!inst(new CompositeObserver!E);
    }

private:
    Observer!E[] _observers;
}
///
unittest
{
    int count = 0;
    struct TestObserver
    {
        void put(int n)
        {
            count++;
        }
    }

    auto c1 = new CompositeObserver!int;
    c1.put(0);
    auto o1 = observerObject!int(TestObserver());
    auto c2 = c1.add(o1);
    c1.put(0);
    assert(count == 0);
    c2.put(0);
    assert(count == 1);
    auto c3 = c2.add(observerObject!int(TestObserver()));
    c3.put(0);
    assert(count == 3);
    auto c4 = c3.remove(o1);
    c4.put(0);
    assert(count == 4);
}
unittest
{
    int count = 0;
    struct TestObserver
    {
        void put(int n)
        {
            count++;
        }
    }
    auto c1 = new CompositeObserver!(int[]);
    auto c2 = c1.add(observerObject!(int[])(TestObserver()));

    assert(count == 0);
    c2.put([1, 2]);
    assert(count == 2);
}

///The helper for the own observer.
auto makeObserver(E)(void delegate(E) doPut, void delegate() doCompleted,
        void delegate(Exception) doFailure)
{
    static struct AnonymouseObserver
    {
    public:
        this(void delegate(E) doPut, void delegate() doCompleted, void delegate(Exception) doFailure)
        {
            _doPut = doPut;
            _doCompleted = doCompleted;
            _doFailure = doFailure;
        }

    public:
        void put(E obj)
        {
            if (_doPut !is null)
                _doPut(obj);
        }

        void completed()
        {
            if (_doCompleted !is null)
                _doCompleted();
        }

        void failure(Exception e)
        {
            if (_doFailure !is null)
                _doFailure(e);
        }

    private:
        void delegate(E) _doPut;
        void delegate() _doCompleted;
        void delegate(Exception) _doFailure;
    }

    return AnonymouseObserver(doPut, doCompleted, doFailure);
}
///ditto
auto makeObserver(E)(void delegate(E) doPut, void delegate() doCompleted)
{
    static struct AnonymouseObserver
    {
    public:
        this(void delegate(E) doPut, void delegate() doCompleted)
        {
            _doPut = doPut;
            _doCompleted = doCompleted;
        }

    public:
        void put(E obj)
        {
            if (_doPut !is null)
                _doPut(obj);
        }

        void completed()
        {
            if (_doCompleted !is null)
                _doCompleted();
        }

    private:
        void delegate(E) _doPut;
        void delegate() _doCompleted;
    }

    return AnonymouseObserver(doPut, doCompleted);
}
///ditto
auto makeObserver(E)(void delegate(E) doPut, void delegate(Exception) doFailure)
{
    static struct AnonymouseObserver
    {
    public:
        this(void delegate(E) doPut, void delegate(Exception) doFailure)
        {
            _doPut = doPut;
            _doFailure = doFailure;
        }

    public:
        void put(E obj)
        {
            if (_doPut !is null)
                _doPut(obj);
        }

        void failure(Exception e)
        {
            if (_doFailure !is null)
                _doFailure(e);
        }

    private:
        void delegate(E) _doPut;
        void delegate(Exception) _doFailure;
    }

    return AnonymouseObserver(doPut, doFailure);
}
///
unittest
{
    int countPut = 0;
    int countCompleted = 0;
    int countFailure = 0;

    auto observer = makeObserver((int) { countPut++; }, () { countCompleted++; }, (Exception) {
        countFailure++;
    });

    .put(observer, 0);
    assert(countPut == 1);

    observer.completed();
    assert(countCompleted == 1);

    observer.failure(null);
    assert(countFailure == 1);
}

unittest
{
    int countPut = 0;
    int countCompleted = 0;

    auto observer = makeObserver((int) { countPut++; }, () { countCompleted++; });

    .put(observer, 0);
    assert(countPut == 1);

    observer.completed();
    assert(countCompleted == 1);

    static assert(!hasFailure!(typeof(observer)));
}

unittest
{
    int countPut = 0;
    int countFailure = 0;

    auto observer = makeObserver((int) { countPut++; }, (Exception) {
        countFailure++;
    });

    .put(observer, 0);
    assert(countPut == 1);

    static assert(!hasCompleted!(typeof(observer)));

    observer.failure(null);
    assert(countFailure == 1);
}

package mixin template SimpleObserverImpl(TObserver, E)
{
public:
    void put(E obj)
    {
        static if (hasFailure!TObserver)
        {
            try
            {
                putImpl(obj);
            }
            catch (Exception e)
            {
                _observer.failure(e);
                _disposable.dispose();
            }
        }
        else
        {
            putImpl(obj);
        }
    }

    static if (hasCompleted!TObserver)
    {
        void completed()
        {
            _observer.completed();
            _disposable.dispose();
        }
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
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        Disposable _disposable;
    }
}

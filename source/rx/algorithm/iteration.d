module rx.algorithm.iteration;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import core.atomic : cas, atomicLoad;
import std.functional : unaryFun, binaryFun;
import std.range : put;

//####################
// Overview
//####################
unittest
{
    import rx.subject;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;

    auto subject = new SubjectObject!int;
    auto pub = subject
        .filter!(n => n % 2 == 0)
        .map!(o => to!string(o))
        .drop(1)
        .take(3);

    auto buf = appender!(string[]);
    auto disposable = pub.subscribe(observerObject!string(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["2", "4", "6"]));
}

//####################
// Filter
//####################
struct FilterObserver(alias f, TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);

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
    void putImpl(E obj)
    {
        alias fun = unaryFun!f;
        if (fun(obj)) _observer.put(obj);
    }
}
unittest
{
    alias TObserver = FilterObserver!(o => true, Observer!int, int);

    static assert(isObserver!(TObserver, int));
}

struct FilterObservable(alias f, TObservable)
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
        alias ObserverType = FilterObserver!(f, TObserver, ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer));
        }
    }

private:
    TObservable _observable;
}
unittest
{
    import rx.subject;

    alias TObservable = FilterObservable!(o => true, Subject!int);

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(int n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception) { failureCount++; }
    }

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);
    auto disposable = observable.subscribe(TestObserver());
    assert(putCount == 0);
    sub.put(0);
    assert(putCount == 1);
    sub.put(1);
    assert(putCount == 2);
    disposable.dispose();
    sub.put(2);
    assert(putCount == 2);
}

template filter(alias f)
{
    FilterObservable!(f, TObservable) filter(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!(n => n % 2 == 0);
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}
unittest
{
    import rx.subject;
    import std.array : appender;

    Subject!int sub = new SubjectObject!int;
    auto filtered = sub.filter!"a % 2 == 0";
    auto buffer = appender!(int[])();
    auto disposable = filtered.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    sub.put(3);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2][]));
}

//####################
// Map
//####################
struct MapObserver(alias f, TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);

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
    void putImpl(E obj)
    {
        alias fun = unaryFun!f;
        _observer.put(fun(obj));
    }
}
unittest
{
    import std.conv : to;
    alias TObserver = MapObserver!(o => to!string(o), Observer!string, int);

    static assert(isObserver!(TObserver, int));
}

struct MapObservable(alias f, TObservable)
{
    alias ElementType = typeof({ return unaryFun!(f)(TObservable.ElementType.init); }());
public:
    this(TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = MapObserver!(f, TObserver, TObservable.ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer));
        }
    }

private:
    TObservable _observable;
}
unittest
{
    import rx.subject;
    import std.conv : to;

    alias TObservable = MapObservable!(n => to!string(n), Subject!int);
    static assert(is(TObservable.ElementType : string));
    static assert(isSubscribable!(TObservable, Observer!string));

    int putCount = 0;
    int completedCount = 0;
    int failureCount = 0;
    struct TestObserver
    {
        void put(string n) { putCount++; }
        void completed() { completedCount++; }
        void failure(Exception) { failureCount++; }
    }

    auto sub = new SubjectObject!int;
    auto observable = TObservable(sub);
    auto disposable = observable.subscribe(TestObserver());
    assert(putCount == 0);
    sub.put(0);
    assert(putCount == 1);
    sub.put(1);
    assert(putCount == 2);
    disposable.dispose();
    sub.put(2);
    assert(putCount == 2);
}

template map(alias f)
{
    MapObservable!(f, TObservable) map(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    import std.array : appender;
    import std.conv : to;

    Subject!int sub = new SubjectObject!int;
    auto mapped = sub.map!(n => to!string(n));
    static assert(isObservable!(typeof(mapped), string));
    static assert(isSubscribable!(typeof(mapped), Observer!string));

    auto buffer = appender!(string[])();
    auto disposable = mapped.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    import std.algorithm : equal;
    assert(equal(buffer.data, ["0", "1", "2"][]));
}
unittest
{
    import rx.subject;
    import std.array : appender;
    import std.conv : to;

    Subject!int sub = new SubjectObject!int;
    auto mapped = sub.map!"a * 2";
    static assert(isObservable!(typeof(mapped), int));
    static assert(isSubscribable!(typeof(mapped), Observer!int));

    auto buffer = appender!(int[])();
    auto disposable = mapped.subscribe(buffer);
    sub.put(0);
    sub.put(1);
    sub.put(2);
    import std.algorithm : equal;
    assert(equal(buffer.data, [0, 2, 4][]));
}

//####################
// Drop
//####################
struct DropObserver(TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);
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
    void putImpl(E obj)
    {
        if (_counter.tryUpdateCount())
        {
            _observer.put(obj);
        }
    }
private:
    shared(AtomicCounter) _counter;
}
struct DropObservable(TObservable)
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
        alias ObserverType = DropObserver!(TObserver, ElementType);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _count, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer, _count));
        }
    }
private:
    TObservable _observable;
    size_t _count;
}
auto drop(TObservable)(auto ref TObservable observable, size_t n)
{
    return DropObservable!TObservable(observable, n);
}
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
struct TakeObserver(TObserver, E)
{
public:
    this(TObserver observer, size_t count, Disposable disposable)
    {
        _observer = observer;
        _count = count;
        _disposable = disposable;
    }
public:
    void put(E obj)
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
struct TakeObservable(TObservable)
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
        alias ObserverType = TakeObserver!(TObserver, ElementType);
        auto disposable = new SingleAssignmentDisposable;
        disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _count, disposable))));
        return disposable;
    }
private:
    TObservable _observable;
    size_t _count;
}
auto take(TObservable)(auto ref TObservable observable, size_t n)
{
    return TakeObservable!TObservable(observable, n);
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
// Scan
//####################
struct ScanObserver(alias f, TObserver, E, TAccumulate)
{
    mixin SimpleObserverImpl!(TObserver, E);
public:
    this(TObserver observer, TAccumulate seed)
    {
        _observer = observer;
        _current = seed;
    }
    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(TObserver observer, TAccumulate seed, Disposable disposable)
        {
            _observer = observer;
            _current = seed;
            _disposable = disposable;
        }
    }
public:
    void putImpl(E obj)
    {
        alias fun = binaryFun!f;
        _current = fun(_current, obj);
        _observer.put(_current);
    }
private:
    TAccumulate _current;
}
unittest
{
    import std.array;
    auto buf = appender!(int[]);
    alias TObserver = ScanObserver!((a,b)=> a + b, typeof(buf), int, int);
    auto observer = TObserver(buf, 0);
    foreach (i; 1 .. 6)
    {
        observer.put(i);
    }
    auto result = buf.data;
    assert(result.length == 5);
    assert(result[0] == 1);
    assert(result[1] == 3);
    assert(result[2] == 6);
    assert(result[3] == 10);
    assert(result[4] == 15);
}
struct ScanObservable(alias f, TObservable, TAccumulate)
{
    alias ElementType = TAccumulate;
public:
    this(TObservable observable, TAccumulate seed)
    {
        _observable = observable;
        _seed = seed;
    }
public:
    auto subscribe(TObserver)(TObserver observer)
    {
        alias ObserverType = ScanObserver!(f, TObserver, TObservable.ElementType, TAccumulate);
        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, _seed, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer, _seed));
        }
    }
private:
    TObservable _observable;
    TAccumulate _seed;
}
unittest
{
    alias Scan = ScanObservable!((a,b)=>a+b, Observable!int, int);
    static assert(isObservable!(Scan, int));
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;
    Observer!int temp;
    alias Scan = ScanObservable!((a,b)=>a+b, Observable!int, int);
    auto s = Scan(sub, 0);
    import std.stdio;
    auto disposable = s.subscribe((int i) => writeln(i));
    static assert(isDisposable!(typeof(disposable)));
}
template scan(alias f)
{
    auto scan(TObservable, TAccumulate)(auto ref TObservable observable, TAccumulate seed)
    {
        return ScanObservable!(f, TObservable, TAccumulate)(observable, seed);
    }
}
unittest
{
    import rx.subject;
    auto subject = new SubjectObject!int;
    auto sum = subject.scan!((a, b) => a + b)(0);
    static assert(isObservable!(typeof(sum), int));

    import std.array : appender;
    auto buf = appender!(int[]);
    auto disposable = sum.subscribe(buf);

    foreach (_; 0 .. 5)
    {
        subject.put(1);
    }
    auto result = buf.data;
    assert(result.length == 5);
    assert(result[0] == 1);
    assert(result[1] == 2);
    assert(result[2] == 3);
    assert(result[3] == 4);
    assert(result[4] == 5);
}


//####################
// Tee
//####################
struct TeeObserver(alias f, TObserver, E)
{
    mixin SimpleObserverImpl!(TObserver, E);
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
    void putImpl(E obj)
    {
        unaryFun!f(obj);
        _observer.put(obj);
    }
}
struct TeeObservable(alias f, TObservable, E)
{
    alias ElementType = E;
public:
    this(TObservable observable)
    {
        _observable = observable;
    }
public:
    auto subscribe(T)(auto ref T observer)
    {
        alias ObserverType = TeeObserver!(f, T, E);
        static if (hasCompleted!T || hasFailure!T)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable, ObserverType(observer, disposable))));
            return disposable;
        }
        else
        {
            return doSubscribe(_observable, ObserverType(observer));
        }
    }
private:
    TObservable _observable;
}
template tee(alias f)
{
    TeeObservable!(f, TObservable, TObservable.ElementType) tee(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;
    import std.array;
    auto buf1 = appender!(int[]);
    auto buf2 = appender!(int[]);
    auto disposable = sub
        .tee!(i => buf1.put(i))()
        .map!(i => i * 2)()
        .subscribe(buf2);

    sub.put(1);
    sub.put(2);
    disposable.dispose();
    sub.put(3);

    import std.algorithm : equal;
    assert(equal(buf1.data, [1, 2]));
    assert(equal(buf2.data, [2, 4]));
}
unittest
{
    import rx.subject;
    auto sub = new SubjectObject!int;

    int countPut = 0;
    int countFailure = 0;
    struct Test
    {
        void put(int) { countPut++; }
        void failure(Exception) { countFailure++; }
    }

    int foo(int n)
    {
        if (n == 0) throw new Exception("");
        return n * 2;
    }

    auto d = sub.tee!foo().doSubscribe(Test());

    assert(countPut == 0);
    sub.put(1);
    assert(countPut == 1);
    assert(countFailure == 0);
    sub.put(0);
    assert(countPut == 1);
    assert(countFailure == 1);
}

//####################
// Merge
//####################
struct MergeObservable(TObservable1, TObservable2)
{
    import std.traits;
    alias ElementType = CommonType!(TObservable1.ElementType, TObservable2.ElementType);

public:
    this(TObservable1 o1, TObservable2 o2)
    {
        _observable1 = o1;
        _observable2 = o2;
    }

public:
    auto subscribe(T)(T observer)
    {
        auto d1 = _observable1.doSubscribe(observer);
        auto d2 = _observable2.doSubscribe(observer);
        return new CompositeDisposable(disposableObject(d1), disposableObject(d2));
    }

private:
    TObservable1 _observable1;
    TObservable2 _observable2;
}
MergeObservable!(T1, T2) merge(T1, T2)(auto ref T1 observable1, auto ref T2 observable2)
{
    return typeof(return)(observable1, observable2);
}

unittest
{
    import rx.subject;
    auto s1 = new SubjectObject!int;
    auto s2 = new SubjectObject!short;

    auto merged = s1.merge(s2);

    int count = 0;
    auto d = merged.doSubscribe((int n){ count++; });

    assert(count == 0);
    s1.put(1);
    assert(count == 1);
    s2.put(2);
    assert(count == 2);

    d.dispose();

    s1.put(10);
    assert(count == 2);
    s2.put(100);
    assert(count == 2);
}

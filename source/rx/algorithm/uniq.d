module rx.algorithm.uniq;

import rx.disposable;
import rx.observable;
import rx.observer;
import rx.util;

import std.functional : binaryFun;
import std.range : put;

struct UniqObserver(TObserver, E, alias pred = "a == b")
{
    mixin SimpleObserverImpl!(TObserver, E);

public:
    this(ref TObserver observer)
    {
        _observer = observer;
        _hasValue = false;
    }

    static if (hasCompleted!TObserver || hasFailure!TObserver)
    {
        this(ref TObserver observer, Disposable disposable)
        {
            _observer = observer;
            _disposable = disposable;
        }
    }

private:
    void putImpl(E obj)
    {
        alias fun = binaryFun!pred;

        if (_hasValue)
        {
            if (!fun(_current, obj))
            {
                _current = obj;
                .put(_observer, obj);
            }
        }
        else
        {
            _current = obj;
            _hasValue = true;
            .put(_observer, obj);
        }
    }

private:
    bool _hasValue;
    E _current;
}

@safe unittest
{
    import std.array : appender;

    auto buf = appender!(int[]);

    auto observer = UniqObserver!(typeof(buf), int)(buf);

    .put(observer, [1, 1, 2, 3]);

    import std.algorithm : equal;

    assert(equal(buf.data, [1, 2, 3]));
}

@safe unittest
{
    struct Person
    {
        string name;
        int age;
    }

    import std.array : appender;

    auto buf = appender!(Person[]);

    auto observer = UniqObserver!(typeof(buf), Person, "a.name == b.name")(buf);

    .put(observer, Person("Smith", 20));
    .put(observer, Person("Smith", 30));
    .put(observer, Person("Johnson", 40));
    .put(observer, Person("Johnson", 50));

    import std.algorithm : equal;

    auto data = buf.data;
    assert(data.length == 2);
    assert(data[0].name == "Smith");
    assert(data[0].age == 20);
    assert(data[1].name == "Johnson");
    assert(data[1].age == 40);
}

struct UniqObservable(TObservable, alias pred = "a == b")
{
    alias ElementType = TObservable.ElementType;

public:
    this(ref TObservable observable)
    {
        _observable = observable;
    }

public:
    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        alias ObserverType = UniqObserver!(TObserver, ElementType, pred);

        static if (hasCompleted!TObserver || hasFailure!TObserver)
        {
            auto disposable = new SingleAssignmentDisposable;
            disposable.setDisposable(disposableObject(doSubscribe(_observable,
                    ObserverType(observer, disposable))));
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

@system unittest
{
    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!int;

    auto observable = UniqObservable!(typeof(sub))(sub);

    import std.array : appender;

    auto buf = appender!(int[]);

    auto disposable = observable.subscribe(buf);
    scope (exit)
        disposable.dispose();

    .put(sub, 10);
    .put(sub, 10);
    .put(sub, 20);
    .put(sub, 30);

    auto data = buf.data;
    assert(data.length == 3);
    assert(data[0] == 10);
    assert(data[1] == 20);
    assert(data[2] == 30);
}

unittest
{
    struct Point
    {
        int x;
        int y;
    }

    import rx.subject : SubjectObject;

    auto sub = new SubjectObject!Point;

    auto observable = UniqObservable!(typeof(sub), "a.x == b.x")(sub);

    import std.array : appender;

    auto buf = appender!(Point[]);

    auto disposable = observable.subscribe(buf);
    scope (exit)
        disposable.dispose();

    .put(sub, Point(0, 0));
    .put(sub, Point(0, 10));
    .put(sub, Point(10, 10));
    .put(sub, Point(10, 20));

    auto data = buf.data;
    assert(data.length == 2);
    assert(data[0] == Point(0, 0));
    assert(data[1] == Point(10, 10));
}

///
template uniq(alias pred = "a == b")
{
    UniqObservable!(TObservable, pred) uniq(TObservable)(auto ref TObservable observable)
    {
        return typeof(return)(observable);
    }
}

///
unittest
{
    import rx.subject : SubjectObject;
    import std.array : appender;

    auto sub = new SubjectObject!int;
    auto buf = appender!(int[]);

    auto disposable = sub.uniq.subscribe(buf);
    scope (exit)
        disposable.dispose();

    .put(sub, [11, 11, 22, 22, 33]);

    auto data = buf.data;
    assert(data.length == 3);
    assert(data[0] == 11);
    assert(data[1] == 22);
    assert(data[2] == 33);
}

///
@system unittest
{
    import std.datetime : Date;
    import rx.subject : SubjectObject;
    import std.array : appender;
    
    auto sub = new SubjectObject!Date;
    auto buf = appender!(Date[]);

    auto disposable = sub.uniq!"a.year == b.year".subscribe(buf);
    scope (exit)
        disposable.dispose();

    .put(sub, Date(2000, 1, 1));
    .put(sub, Date(2000, 1, 2));
    .put(sub, Date(2017, 3, 24));
    .put(sub, Date(2017, 4, 24));
    .put(sub, Date(2017, 4, 24));

    auto data = buf.data;
    assert(data.length == 2);
    assert(data[0] == Date(2000, 1, 1));
    assert(data[1] == Date(2017, 3, 24));
}
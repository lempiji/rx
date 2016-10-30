module rx.algorithm;

public import rx.algorithm.all;
public import rx.algorithm.any;
public import rx.algorithm.filter;
public import rx.algorithm.fold;
public import rx.algorithm.map;
public import rx.algorithm.merge;
public import rx.algorithm.scan;
public import rx.algorithm.tee;
public import rx.algorithm.throttle;

//####################
// Overview
//####################
///
unittest
{
    import rx;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;
    import std.range : iota, put;

    auto subject = new SubjectObject!int;
    auto pub = subject.filter!(n => n % 2 == 0).map!(o => to!string(o));

    auto buf = appender!(string[]);
    auto disposable = pub.doSubscribe(buf);
    scope (exit)
        disposable.dispose();

    put(subject, iota(10));

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}

///
unittest
{
    import rx;

    auto sub = new SubjectObject!int;

    auto hasEven = sub.any!"a % 2 == 0"();
    auto result = false;
    auto disposable = hasEven.doSubscribe((bool b) { result = b; });
    scope (exit)
        disposable.dispose();

    sub.put(1);
    sub.put(3);
    sub.put(2);
    assert(result);
}

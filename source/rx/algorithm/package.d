module rx.algorithm;

public import rx.algorithm.all;
public import rx.algorithm.any;
public import rx.algorithm.buffer;
public import rx.algorithm.debounce;
public import rx.algorithm.filter;
public import rx.algorithm.fold;
public import rx.algorithm.map;
public import rx.algorithm.merge;
public import rx.algorithm.scan;
public import rx.algorithm.tee;
public import rx.algorithm.uniq;

//####################
// Overview
//####################
///
unittest
{
    import rx;
    import std.conv : to;
    import std.range : iota, put;

    auto subject = new SubjectObject!int;

    string[] result;
    auto disposable = subject.filter!(n => n % 2 == 0).map!(o => to!string(o))
        .doSubscribe!(text => result ~= text);

    scope (exit)
        disposable.dispose();

    put(subject, iota(10));

    assert(result == ["0", "2", "4", "6", "8"]);
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

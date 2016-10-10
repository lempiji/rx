module rx.algorithm;

public import rx.algorithm.filter;
public import rx.algorithm.map;
public import rx.algorithm.scan;
public import rx.algorithm.tee;
public import rx.algorithm.merge;
public import rx.algorithm.fold;
public import rx.algorithm.searching;
public import rx.algorithm.timer;


//####################
// Overview
//####################
///
unittest
{
    import rx.observer : observerObject;
    import rx.subject : SubjectObject;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;

    auto subject = new SubjectObject!int;
    auto pub = subject
        .filter!(n => n % 2 == 0)
        .map!(o => to!string(o));

    auto buf = appender!(string[]);
    auto disposable = pub.subscribe(observerObject!string(buf));
    scope(exit) disposable.dispose();

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}

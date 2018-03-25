/+++++++++++++++++++++++++++++
 + This module defines some operations like range.
 +/
module rx.range;

public import rx.range.drop;
public import rx.range.take;
public import rx.range.takeLast;

/+++++++++++++++++++++++++++++
 + Overview
 +/
unittest
{
    import rx : SubjectObject, observerObject, drop, take;
    import std.algorithm : equal;
    import std.array : appender;
    import std.conv : to;

    auto subject = new SubjectObject!int;
    auto pub = subject.drop(2).take(3);

    auto buf = appender!(int[]);
    auto disposable = pub.subscribe(observerObject!int(buf));

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, [2, 3, 4]));
}

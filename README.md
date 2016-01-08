## Reactive Extensions for D Programming Language
[![Build Status](https://travis-ci.org/lempiji/rx.svg?branch=master)](https://travis-ci.org/lempiji/rx)

### Example
```d
import rx;
import std.algorithm : equal;
import std.array : appender;
import std.conv : to;

void main()
{
    auto subject = new SubjectObject!int;
    auto pub = subject
        .filter!(n => n % 2 == 0)
        .map!(o => to!string(o));

    auto buf = appender!(string[]);
    auto disposable = pub.subscribe(buf);

    foreach (i; 0 .. 10)
    {
        subject.put(i);
    }

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}
```

### Future work
- more algorithms
 * reduce(aggregate)
 * zip
 * takeUntil
 * skipUntil
- more utilities
 * generators
 * help to make the observers
- more test
- more documents

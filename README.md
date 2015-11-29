## Reactive Extensions for D Programming Language

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
 * skip
 * take
 * scan
 * reduce(aggregate)
 * zip


- support concurrency(std.concurrency.Scheduler)


- more utilities
 * help to make the observers


- more test

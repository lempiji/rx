## Reactive Extensions for D Programming Language
[![Build Status](https://travis-ci.org/lempiji/rx.svg?branch=master)](https://travis-ci.org/lempiji/rx)

### Overview
The is a library like the [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET), for the asynchronous or event-based programs on OutputRange concept.

#### Basic concept interfaces
```d
//module rx.disposable
interface Disposable
{
    void dispose();
}

//module rx.observer
interface Observer(E) : OutputRange!E
{
    //void put(E obj); //inherits from OutputRange!E
    void completed();
    void failure(Exception e);
}

//module rx.observable
interface Observable(E)
{
    alias ElementType = E;
    Disposable subscribe(Observer!E observer);
}

```

#### Example
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
        subject.put(i); //fire some event
    }

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"])); //receive some event
}
```

### License
This library is under the MIT License.

Some code is borrowed from [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET).

### Future work
- more algorithms
 * reduce(aggregate)
 * zip
 * takeUntil
 * skipUntil
- more utilities
 * generators
- more test
- more documents

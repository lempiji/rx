## Reactive Extensions for D Programming Language

[![Dub version](https://img.shields.io/dub/v/rx.svg)](https://code.dlang.org/packages/rx)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)
[![Build Status](https://travis-ci.org/lempiji/rx.svg?branch=master)](https://travis-ci.org/lempiji/rx)

### Overview

This is a library like the [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET), for the asynchronous or event-based programs on OutputRange concept.

The operators' name is based on std.algorithm and [ReactiveX](http://reactivex.io/).

#### Example

```d
import rx;
import std.algorithm : equal;
import std.array : appender;
import std.conv : to;
import std.range : iota, put;

void main()
{
    auto subject = new SubjectObject!int;
    auto pub = subject
        .filter!(n => n % 2 == 0)
        .map!(o => to!string(o));

    auto buf = appender!(string[]);
    auto disposable = pub.doSubscribe(buf);

    put(subject, iota(10));

    auto result = buf.data;
    assert(equal(result, ["0", "2", "4", "6", "8"]));
}
```

And [more examples](https://github.com/lempiji/rx/tree/master/examples) or [Documents](https://lempiji.github.io/rx)

### Usage
Setting dependencies in dub.json
```json
{
    ...
    "dependencies": {
        "rx": "~>0.1.0"
    }
}
```
or dub.sdl
```
dependency "rx" version="~>0.1.0"
```

### Concepts

#### Basic interfaces
All operators are written using template and struct for optimization.
this example is a binary interface like std.range.interfaces.

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

### License

This library is under the MIT License.  
Some code is borrowed from [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET).

### Future work

- more algorithms
- more test
- more documents

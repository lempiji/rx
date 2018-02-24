## Reactive Extensions for D Programming Language

[![Dub version](https://img.shields.io/dub/v/rx.svg)](https://code.dlang.org/packages/rx)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)
[![Build Status](https://travis-ci.org/lempiji/rx.svg?branch=master)](https://travis-ci.org/lempiji/rx)
[![Coverage Status](https://coveralls.io/repos/github/lempiji/rx/badge.svg?branch=master)](https://coveralls.io/github/lempiji/rx?branch=master)

### Overview

This is a library like [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET) for asynchronous or event based programs, based on the concept of OutputRange.

The operators' name is based on std.algorithm and [ReactiveX](http://reactivex.io/).

#### Example

```d
import rx;
import std.conv : to;
import std.range : iota, put;

void main()
{
    auto subject = new SubjectObject!int;

    string[] result;
    auto disposable = subject.filter!(n => n % 2 == 0).map!(o => to!string(o))
        .doSubscribe!(text => result ~= text);

    scope (exit)
        disposable.dispose();

    put(subject, iota(10));

    assert(result == ["0", "2", "4", "6", "8"]);
}
```

And [more examples](https://github.com/lempiji/rx/tree/master/examples) or [Documents](https://lempiji.github.io/rx)

### Usage
Setting dependencies in dub.json
```json
{
    ...
    "dependencies": {
        "rx": "~>0.7.2"
    }
}
```
or dub.sdl
```
dependency "rx" version="~>0.7.2"
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

- generic observable factory
  - create, start, timer, interval
- more subjects
  - publish, replay
- more algorithms
  - window, combineLatest, zip
- more test
- more documents

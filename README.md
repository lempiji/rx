## Reactive Extensions for D Programming Language

[![Dub version](https://img.shields.io/dub/v/rx.svg)](https://code.dlang.org/packages/rx)
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)
[![Build Status](https://travis-ci.org/lempiji/rx.svg?branch=dev)](https://travis-ci.org/lempiji/rx)
[![codecov](https://codecov.io/gh/lempiji/rx/branch/dev/graph/badge.svg)](https://codecov.io/gh/lempiji/rx/branch/dev)

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
    // create own source of int
    auto subject = new SubjectObject!int;

    // define result array
    string[] result;

    // define pipeline and subscribe
    // sequence: source -> filter by even -> map to string -> join to result
    auto disposable = subject.filter!(n => n % 2 == 0).map!(o => to!string(o))
        .doSubscribe!(text => result ~= text);

    // set unsubscribe on exit
    // it is not necessary in this simple example,
    // but in many cases you should call dispose to prevent memory leaks.
    scope (exit)
        disposable.dispose();

    // put values to source. 
    put(subject, iota(10));

    // result is like this
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
        "rx": "~>0.10.0"
    }
}
```
or dub.sdl
```
dependency "rx" version="~>0.10.0"
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
### Supported Compilers
Supported compilers are `dmd` and `ldc` that latest 3 versions.

### License

This library is under the MIT License.  
Some code is borrowed from [Rx.NET](https://github.com/Reactive-Extensions/Rx.NET).

### Contributing
Issue and PullRequest are welcome! :smiley:

Refer to [CONTRIBUTING.md](/CONTRIBUTING.md) for details.

### Development

#### Build and unittest

```bash
git clone https://github.com/lempiji/rx
cd rx
dub test
```

#### Update documents

```bash
dub build -c ddox
```


### Future work

- generic observable factory
    - create, start, timer, interval
- more subjects
    - publish, replay
- more algorithms
    - window, zip
- more test
- more documents

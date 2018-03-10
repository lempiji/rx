Contributing
============

Thank you for your interest!
Issue and pull request are welcome!


Development and Testing
-----------------------
We are weolcoming tha refactoring and implements operators.

`rx` provides attractive code to users, like the general `std.range` and `std.algorithm`. But, its source code is unfortunately complicated.

In particular, it is important a variety operators combination tests, and multithreading tests.

### Things you will need

* Linux, Mac OS X, or Windows
* git (used for source version control).
* Some D Compiler. dmd and ldc.
* Latest dub (used for build and testing).
* An IDE. We recommend [Visual Studio Code](https://code.visualstudio.com/download) with [code-d](https://marketplace.visualstudio.com/items?itemName=webfreak.code-d).
* Use dfmt (with default settings) for code formatting.

### Patterns
Taking `map` as an example, the operator consists of the following three elements.

- struct `MapObserver`
- struct `MapObservable`
- template function `map`

#### MapObserver
Observer's role is to provide concrete algorithms in the constructed pipeline.

`MapObserver` has the function of passing processed values to Observer as source.

#### MapObservable
Observable as an operator has Observable as a source and has the role of processing a given Observer and constructing a pipeline.

`MapObservable` has the function of wrapping the passed Observer in `MapObserver` and subscribing to Observable as source.

Also, since Observable returns `Disposable`, it relays it.

#### map
It is utility function for build `MapObservable`.


### Naming priority
Unified naming conventions is important. It is now as follows.

1. Look for similar operators from `std.algorithm`.
2. If there are no similar operators, follow [Reactive X](http://reactivex.io/documentation/operators.html).


Documentation
-------------
We are welcoming the tutorial documentation.

For users, the goal is to think about the composition of the tutorial so that you can see how to use it, and to add practical examples.

For developers, We think that the following things are necessary.

- Manage the tutorial as part of the source.
  - Since the contribution log remains, it is easy to understand later.
  - Not separate it into another repository to avoid version inconsistency.
- Keep docs as a simple API reference.

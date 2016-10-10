/+++++++++++++++++++++++++++++
 + This module defines algorithm 'fold'
 +/
module rx.algorithm.fold;

import rx.disposable;
import rx.observable;
import rx.observer;

//####################
// Fold
//####################
///
auto fold(alias fun, TObservable, Seed)(auto ref TObservable observable, Seed seed)
{
    import rx.algorithm : scan;
    import rx.range : takeLast;
    return observable.scan!fun(seed).takeLast;
}
///
unittest
{
    import rx.subject : SubjectObject;
    auto sub = new SubjectObject!int;
    auto sum = sub.fold!"a+b"(0);

    int result = 0;
    auto disposable = sum.doSubscribe((int n){ result = n; });
    scope(exit) disposable.dispose();

    foreach (i; 1 .. 11) sub.put(i);

    assert(result == 0);
    sub.completed();
    assert(result == 55);
}

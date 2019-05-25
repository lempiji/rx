/+++++++++++++++++++++++++++++
 + This module is a submodule of rx.range.
 + It provides basic operation a 'takeUntil'
 +/
module rx.range.takeUntil;

import rx.disposable;
import rx.observer;
import rx.observable;
import rx.util;

import std.range : put;

//####################
// TakeUntil
//####################
///
auto takeUntil(TObservable1, TObservable2)(auto ref TObservable1 source, auto ref TObservable2 stopper)
        if (isObservable!TObservable1 && isObservable!TObservable2)
{
    static struct TakeUntilObservable
    {
        alias ElementType = TObservable1.ElementType;

        TObservable1 source;
        TObservable2 stopper;

        auto subscribe(TObserver)(auto ref TObserver observer)
        {
            auto sourceDisposable = source.doSubscribe(observer);
            auto stopperDisposable = stopper.doSubscribe((TObservable2.ElementType _) {
                static if (hasCompleted!TObserver)
                {
                    observer.completed();
                }
                sourceDisposable.dispose();
            });

            return new CompositeDisposable(sourceDisposable, stopperDisposable);
        }
    }

    return TakeUntilObservable(source, stopper);
}

///
unittest
{
    import std.algorithm;
    import rx;

    auto source = new SubjectObject!int;
    auto stopper = new SubjectObject!int;

    int[] buf;
    auto disposable = source.takeUntil(stopper).doSubscribe!((n) { buf ~= n; });

    source.put(0);
    source.put(1);
    source.put(2);

    stopper.put(0);

    source.put(3);
    source.put(4);

    assert(equal(buf, [0, 1, 2]));
}

unittest
{
    import std.algorithm;
    import rx;

    auto sub1 = new SubjectObject!int;
    auto sub2 = new SubjectObject!int;

    int[] buf;
    auto disposable = sub1.takeUntil(sub2).subscribe((int n) { buf ~= n; });

    sub1.put(0);

    disposable.dispose();

    sub1.put(1);
    
    assert(equal(buf, [0]));
}

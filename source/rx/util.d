module rx.util;

import core.atomic;

T exchange(T, U)(ref shared(T) store, shared(U) newValue)
{
    shared(T) oldValue = void;
    do
    {
        oldValue = store;
    } while(!cas(&store, oldValue, newValue));
    return atomicLoad(oldValue);
}

unittest
{
    struct A
    {
        int value = 0;
    }

    shared(A) a;
    a.value = 10;

    A temp = exchange(a, shared(A).init);
    assert(temp.value == 10);
    assert(a.value == 0);
}

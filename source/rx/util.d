module rx.util;

import core.atomic;

T exchange(T, U)(ref shared(T) store, U val)
{
    shared(T) temp = void;
    do
    {
        temp = store;
    } while(!cas(&store, temp, val));
    return atomicLoad(temp);
}
unittest
{
    shared(int) n = 1;
    auto temp = exchange(n, 10);
    assert(n == 10);
    assert(temp == 1);
}

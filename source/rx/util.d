module rx.util;

import core.atomic;
import core.sync.mutex;
import core.sync.condition;

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

class EventSignal
{
public:
    this()
    {
        _mutex = new Mutex;
        _condition = new Condition(_mutex);
    }

public:
    void setSignal()
    {
        synchronized (_mutex)
        {
            _signal = true;
            _condition.notify();
        }
    }

    void wait()
    {
        synchronized (_mutex)
        {
            if (_signal) return;
            _condition.wait();
        }
    }

private:
    Mutex _mutex;
    Condition _condition;
    bool _signal;
}

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
    bool signal() @property
    {
        synchronized (_mutex)
        {
            return _signal;
        }
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
unittest
{
    auto event = new EventSignal;
    assert(!event.signal);
    event.setSignal();
    assert(event.signal);
}

package shared class AtomicCounter
{
public:
    this(size_t n)
    {
        _count = n;
    }
public:
    bool tryUpdateCount() @trusted
    {
        shared(size_t) oldValue = void;
        size_t newValue = void;
        do
        {
            oldValue = _count;
            if (oldValue == 0)
                return true;

            newValue = oldValue - 1;
        } while (!cas(&_count, oldValue, newValue));

        return false;
    }
private:
    size_t _count;
}

shared class TicketBase
{
    bool stamp()
    {
        return cas(&_flag, false, true);
    }

private:
    bool _flag = false;
}
alias Ticket = shared(TicketBase);

unittest
{
    auto t = new Ticket;
    assert(t.stamp());
    assert(!t.stamp());
}

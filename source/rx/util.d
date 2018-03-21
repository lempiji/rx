module rx.util;

import core.atomic;
import core.sync.mutex;
import core.sync.condition;

// @@TODO@@ Remove this overload, when the phobos of LDC supports TailShared.
auto ref T assumeThreadLocal(T)(auto ref T obj) if (!is(T == shared))
{
    return obj;
}

auto ref T assumeThreadLocal(T)(auto ref shared(T) obj)
{
    return cast() obj;
}

unittest
{
    class Test
    {
        int hoge()
        {
            return 0;
        }
    }

    auto raw = new shared(Test);
    Test local1 = assumeThreadLocal(raw);
    Test local2 = assumeThreadLocal(new shared(Test));
}

auto exchange(T, U)(ref shared(T) store, U val)
{
    shared(T) temp = void;
    do
    {
        temp = store;
    }
    while (!cas(&store, temp, val));
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
            if (_signal)
                return;
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
    bool isZero() @property
    {
        return atomicLoad(_count) == 0;
    }

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
        }
        while (!cas(&_count, oldValue, newValue));

        return false;
    }

    auto tryDecrement() @trusted
    {
        static struct DecrementResult
        {
            bool success;
            size_t count;
        }

        shared(size_t) oldValue = void;
        size_t newValue = void;
        do
        {
            oldValue = _count;
            if (oldValue == 0)
                return DecrementResult(false, oldValue);

            newValue = oldValue - 1;
        }
        while (!cas(&_count, oldValue, newValue));

        return DecrementResult(true, newValue);
    }

    bool trySetZero() @trusted
    {
        shared(size_t) oldValue = void;
        do
        {
            oldValue = _count;
            if (oldValue == 0)
                return false;
        }
        while (!cas(&_count, oldValue, 0));

        return true;
    }

private:
    size_t _count;
}

shared class TicketBase
{
public:
    bool stamp()
    {
        return cas(&_flag, false, true);
    }

public:
    bool isStamped() @property
    {
        return atomicLoad(_flag);
    }

private:
    bool _flag = false;
}

alias Ticket = shared(TicketBase);

unittest
{
    auto t = new Ticket;
    assert(!t.isStamped);
    assert(t.stamp());
    assert(t.isStamped);
    assert(!t.stamp());
}

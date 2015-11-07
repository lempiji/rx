module rx.disposable;

import rx.primitives;

interface Disposable
{
    void dispose();
}

class DisposableObject(T) : Disposable
{
public:
    this(T disposable)
    {
        _disposable = disposable;
    }

public:
    void dispose()
    {
        _disposable.dispose();
    }

private:
    T _disposable;
}

Disposable disposableObject(T)(T disposable)
{
    static assert(isDisposable!T);

    static if (is(T : Disposable))
    {
        return disposable;
    }
    else
    {
        return new DisposableObject!T(disposable);
    }
}

unittest
{
    int count = 0;
    class TestDisposable : Disposable
    {
        void dispose()
        {
            count++;
        }
    }
    auto test = new TestDisposable;
    Disposable disposable = disposableObject(test);
    assert(disposable is test);
    assert(count == 0);
    disposable.dispose();
    assert(count == 1);
}
unittest
{
    int count = 0;
    struct TestDisposable
    {
        void dispose()
        {
            count++;
        }
    }

    TestDisposable test;
    Disposable disposable = disposableObject(test);
    assert(count == 0);
    disposable.dispose();
    assert(count == 1);
}

final class NopDisposable : Disposable
{
private:
    this() { }

public:
    void dispose() { }

public:
    static Disposable instance()
    {
        import std.concurrency : initOnce;
        static __gshared NopDisposable inst;
        return initOnce!inst(new NopDisposable);
    }
}

unittest
{
    Disposable d1 = NopDisposable.instance;
    Disposable d2 = NopDisposable.instance;
    assert(d1 !is null);
    assert(d1 is d2);
}

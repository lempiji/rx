module rx.disposable;

import core.atomic;
import core.sync.mutex;
import rx.util;

template isDisposable(T)
{
    enum bool isDisposable = is(typeof({
            T disposable = void;
            disposable.dispose();
        }()));
}
unittest
{
    struct A { void dispose(){} }
    class B {void dispose(){} }
    interface C { void dispose(); }

    static assert(isDisposable!A);
    static assert(isDisposable!B);
    static assert(isDisposable!C);
}
template isCancelable(T)
{
    enum isCancelable = isDisposable!T && is(typeof((inout int n = 0){
            T disposable = void;
            bool b = disposable.isDisposed;
        }));
}
unittest
{
    struct A
    {
        bool isDisposed() @property { return true; }
        void dispose() { }
    }
    class B
    {
        bool isDisposed() @property { return true; }
        void dispose() { }
    }
    interface C
    {
        bool isDisposed() @property;
        void dispose();
    }

    static assert(isCancelable!A);
    static assert(isCancelable!B);
    static assert(isCancelable!C);
}

interface Disposable
{
    void dispose();
}
interface Cancelable : Disposable
{
    bool isDisposed() @property;
}

class CancelToken : Cancelable
{
public:
    bool isDisposed() @property
    {
        return atomicLoad(_disposed);
    }
    alias isDisposed isCanceled;

public:
    void dispose()
    {
        atomicStore(_disposed, true);
    }
    alias dispose cancel;

private:
    shared(bool) _disposed;
}
unittest
{
    auto c = new CancelToken;
    assert(!c.isDisposed);
    assert(!c.isCanceled);
    c.dispose();
    assert(c.isDisposed);
    assert(c.isCanceled);
}
unittest
{
    auto c = new CancelToken;
    assert(!c.isDisposed);
    assert(!c.isCanceled);
    c.cancel();
    assert(c.isDisposed);
    assert(c.isCanceled);
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
class CancelableObject(T) : DisposableObject!T, Cancelable
{
public:
    this(T disposable)
    {
        super(disposable);
    }
public:
    bool isDisposed() @property
    {
        return _disposable.isDisposed;
    }
}

auto disposableObject(T)(T disposable)
{
    static assert(isDisposable!T);

    static if (is(T : Cancelable) || is(T : Disposable))
    {
        return disposable;
    }
    else static if (isCancelable!T)
    {
        return new CancelableObject!T(disposable);
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
unittest
{
    int count = 0;
    struct TestCancelable
    {
        bool isDisposed() @property { return _disposed; }
        void dispose()
        {
            count++;
            _disposed = true;
        }
        bool _disposed;
    }

    TestCancelable test;
    Cancelable cancelable = disposableObject(test);

    assert(!cancelable.isDisposed);
    assert(count == 0);
    cancelable.dispose();
    assert(cancelable.isDisposed);
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

package final class DisposedMarker : Cancelable
{
private:
    this() { }

public:
    bool isDisposed() @property { return true; }
public:
    void dispose() { }

public:
    static Cancelable instance()
    {
        import std.concurrency : initOnce;
        static __gshared DisposedMarker inst;
        return initOnce!inst(new DisposedMarker);
    }
}

final class SingleAssignmentDisposable : Cancelable
{
public:
    void setDisposable(Disposable disposable)
    {
        import core.atomic;
        if (!cas(&_disposable, shared(Disposable).init, cast(shared)disposable)) assert(false);
    }
public:
    bool isDisposed()
    {
        return _disposable is cast(shared)DisposedMarker.instance;
    }

    void dispose()
    {
        import rx.util;
        auto temp = exchange(_disposable, cast(shared)DisposedMarker.instance);
        if (temp !is null) temp.dispose();
    }
private:
    shared(Disposable) _disposable;
}
unittest
{
    static assert(isDisposable!SingleAssignmentDisposable);
}
unittest
{
    int count = 0;
    class TestDisposable : Disposable
    {
        void dispose() { count++; }
    }
    auto temp = new SingleAssignmentDisposable;
    temp.setDisposable(new TestDisposable);
    assert(!temp.isDisposed);
    assert(count == 0);
    temp.dispose();
    assert(temp.isDisposed);
    assert(count == 1);
}
unittest
{
    import core.exception;
    class TestDisposable : Disposable
    {
        void dispose() { }
    }
    auto temp = new SingleAssignmentDisposable;
    temp.setDisposable(new TestDisposable);
    try
    {
        temp.setDisposable(new TestDisposable);
    }
    catch(AssertError)
    {
        return;
    }
    assert(false);
}

class SerialDisposable : Cancelable
{
public:
    this()
    {
        _gate = new Mutex;
    }

public:
    bool isDisposed() @property
    {
        return _disposed;
    }

    void disposable(Disposable value) @property
    {
        auto shouldDispose = false;
        Disposable old = null;
        synchronized (_gate)
        {
            shouldDispose = _disposed;
            if (!shouldDispose)
            {
                old = _disposable;
                _disposable = value;
            }
        }
        if (old !is null)
            old.dispose();
        if (shouldDispose && value !is null)
            value.dispose();
    }
    Disposable disposable() @property
    {
        return _disposable;
    }

public:
    void dispose()
    {
        Disposable old = null;
        synchronized (_gate)
        {
            if (!_disposed)
            {
                _disposed = true;
                old = _disposable;
                _disposable = null;
            }
        }
        if (old !is null) old.dispose();
    }

private:
    Mutex _gate;
    bool _disposed;
    Disposable _disposable;
}
unittest
{
    int count = 0;
    struct A
    {
        void dispose() { count++; }
    }

    auto d = new SerialDisposable;
    d.disposable = disposableObject(A());
    assert(count == 0);
    d.disposable = disposableObject(A());
    assert(count == 1);
    d.dispose();
    assert(count == 2);
    d.disposable = disposableObject(A());
    assert(count == 3);
}
unittest
{
    int count = 0;
    struct A
    {
        void dispose() { count++; }
    }

    auto d = new SerialDisposable;
    d.dispose();
    assert(count == 0);
    d.disposable = disposableObject(A());
    assert(count == 1);
}

class SignalDisposable : Disposable
{
public:
    this()
    {
        _signal = new EventSignal;
    }
public:
    EventSignal signal() @property
    {
        return _signal;
    }
public:
    void dispose()
    {
        _signal.setSignal();
    }
private:
    EventSignal _signal;
}
unittest
{
    auto d = new SignalDisposable;
    auto signal = d.signal;
    assert(!signal.signal);
    d.dispose();
    assert(signal.signal);
}

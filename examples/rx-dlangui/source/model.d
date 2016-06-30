module model;

import rx;

class MyModel
{
public:
    this()
    {
        _count = 0;
        _counter = new SubjectObject!int;
    }

public:
    int count() @property
    {
        return _count;
    }

    Observable!int counter() @property
    {
        return _counter;
    }

public:
    void increment()
    {
        _count++;
        _counter.put(_count);
    }

    void decrement()
    {
        _count--;
        _counter.put(_count);
    }

private:
    int _count;
    SubjectObject!int _counter;
}

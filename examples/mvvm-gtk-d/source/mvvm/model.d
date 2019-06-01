module mvvm.model;

import rx;

class AppViewModel
{
    private BehaviorSubject!string _name;
    private BehaviorSubject!int _age;
    private Observable!bool _canDecrementAge;
    private Observable!bool _canClear;
    private Observable!string _profile;

    this()
    {
        _name = new BehaviorSubject!string("");
        _age = new BehaviorSubject!int(0);

        _canDecrementAge = _age.map!(age => age > 0).distinctUntilChanged()
            .observableObject!bool();

        _canClear = combineLatest(_name, _age).map!(t => t[0] != "" || t[1] != 0)
            .distinctUntilChanged().observableObject!bool();

        _profile = combineLatest!((a, b) => formatProfile(a, b))(_name, _age).distinctUntilChanged()
            .observableObject!string();
    }

    Subject!string name()
    {
        return _name;
    }

    Subject!int age()
    {
        return _age;
    }

    Observable!bool canDecrementAge()
    {
        return _canDecrementAge;
    }

    unittest
    {
        auto model = new AppViewModel;
        bool lastValue = true;
        model.canDecrementAge.doSubscribe((bool canDecrement) {
            lastValue = canDecrement;
        });
        assert(!lastValue);

        model.incrementAge();
        assert(lastValue);
        model.decrementAge();
        assert(!lastValue);
    }

    Observable!bool canClear()
    {
        return _canClear;
    }

    unittest
    {
        auto model = new AppViewModel;
        bool lastValue = true;
        model.canClear.doSubscribe((bool canClear) {
            lastValue = canClear;
        });
        assert(!lastValue);

        model.name.put("TEST");
        assert(lastValue);
        model.name.put("");
        assert(!lastValue);
        model.incrementAge();
        assert(lastValue);
        model.decrementAge();
        assert(!lastValue);
    }

    Observable!string profile()
    {
        return _profile;
    }

    void clear()
    {
        _name.value = "";
        _age.value = 0;
    }

    void incrementAge()
    {
        _age.value = _age.value + 1;
    }

    void decrementAge()
    {
        _age.value = _age.value - 1;
    }

    private string formatProfile(string name, int age)
    {
        if (name.length == 0)
            return "";

        import std.format;

        return format!"%s (%d)"(name, age);
    }

    unittest
    {
        auto model = new AppViewModel;
        assert(model.formatProfile("", 0) == "");
        assert(model.formatProfile("", 10) == "");
        assert(model.formatProfile("TEST", 0) == "TEST (0)");
        assert(model.formatProfile("TEST", 10) == "TEST (10)");
    }
}

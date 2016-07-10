module mvvm.models.simple;

import std.stdio;
import mvvm.common;


class SimpleViewModel
{
    private ReactiveProperty!string _title;
    public inout(ReactiveProperty!string) title() inout @property { return _title; }

    private ReactiveProperty!bool _isActive;
    public inout(ReactiveProperty!bool) isActive() inout @property { return _isActive; }

    private Command _clearTitleCommand;
    public inout(Command) clearTitleCommand() inout @property { return _clearTitleCommand; }

    this()
    {
        _title = new ReactiveProperty!string("");
        _isActive = new ReactiveProperty!bool(false);

        _clearTitleCommand = new DelegateCommand(&clearTitle, isActive);
    }

    void clearTitle()
    {
        title.value = "";
    }
}

unittest
{
    auto model = new IndexViewModel;
    assert(model.isActive.value == false);
    assert(model.title.value == "");
    
    model.title.value = "ABC";

    assert(model.title.value == "ABC");
    model.resetTitle();
    assert(model.title.value == "ABC");

    model.isActive.value = true;
    model.resetTitle();
    assert(model.title.value == "");
}
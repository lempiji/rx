module mvvm.common;

import dlangui;
import rx;
import std.range : isOutputRange, put;
import std.traits;

class ReactiveProperty(T) : Subject!T
{
public:
    this()
    {
        this(T.init);
    }

    this(T value)
    {
        _subject = new SubjectObject!T;
        _value = value;
    }

public:
    inout(T) value() inout @property
    {
        return _value;
    }

    void value(T value) @property
    {
        if (_value != value)
        {
            _value = value;
            .put(_subject, value);
        }
    }

public:
    auto subscribe(TObserver)(auto ref TObserver observer)
    {
        .put(observer, value);
        return _subject.doSubscribe(observer);
    }

    Disposable subscribe(Observer!T observer)
    {
        .put(observer, value);
        return disposableObject(_subject.doSubscribe(observer));
    }

    void put(T obj)
    {
        value = obj;
    }

    void failure(Exception e)
    {
        _subject.failure(e);
    }

    void completed()
    {
        _subject.completed();
    }

private:
    SubjectObject!T _subject;
    T _value;
}

interface Command
{
    void execute();
    bool canExecute() const @property;
    inout(Observable!bool) canExecuteObservable() inout @property;
}

class DelegateCommand : Command
{
    this(TObservable)(void delegate() onExecute, TObservable observable)
    {
        static assert(isObservable!(TObservable, bool));
        assert(onExecute !is null);

        _onExecute = onExecute;
        _canExecuteObservable = new ReactiveProperty!bool(false);
        _canExecuteObservable.doSubscribe((bool b) { _canExecute = b; });

        observable.doSubscribe(_canExecuteObservable);
    }

    void execute()
    {
        if (_onExecute !is null && _canExecute)
            _onExecute();
    }

    bool canExecute() const @property
    {
        return _canExecute;
    }

    inout(Observable!bool) canExecuteObservable() inout @property
    {
        return _canExecuteObservable;
    }

private:
    void delegate() _onExecute;
    ReactiveProperty!bool _canExecuteObservable;
    bool _canExecute;
}

//############################
// Binding methods
//############################

Disposable bindText(TSubject)(EditWidgetBase editWidget, TSubject property)
{
    static assert(isObservable!(TSubject, string));
    static assert(isOutputRange!(TSubject, string));

    import std.conv : to;

    auto d1 = editWidget.contentChange.asObservable().doSubscribe((EditableContent _) {
        .put(property, to!string(editWidget.text));
    });
    auto d2 = property.doSubscribe((string value) {
        editWidget.text = to!dstring(value);
    });
    return new CompositeDisposable(d1, d2);
}

Disposable bindText(TObservable)(TextWidget textWidget, TObservable property)
{
    static assert(isObservable!(TObservable, string));

    import std.conv : to;

    return disposableObject(property.doSubscribe((string value) {
            textWidget.text = to!dstring(value);
        }));
}

Disposable bind(Button button, Command command)
{
    auto d1 = button.click.asObservable().doSubscribe((Widget _) {
        command.execute();
    });
    auto d2 = command.canExecuteObservable.doSubscribe((bool b) {
        button.enabled = b;
    });
    return new CompositeDisposable(d1, d2);
}

Disposable bind(TSubject)(SwitchButton button, TSubject property)
{
    static assert(isObservable!(TSubject, bool));
    static assert(isOutputRange!(TSubject, bool));

    auto d1 = button.click.asObservable().doSubscribe((Widget _) {
        .put(property, button.checked);
    });
    auto d2 = property.doSubscribe((bool b) { button.checked = b; });
    return new CompositeDisposable(d1, d2);
}

//Utility

///Wrap a Signal!T as Observable
auto asObservable(T)(ref T signal) if (is(T == Signal!U, U) && is(U == interface))
{
    static if (is(T == Signal!U, U))
    {
        alias return_t = ReturnType!(__traits(getMember, U, __traits(allMembers, U)[0]));
        alias param_t = ParameterTypeTuple!(__traits(getMember, U, __traits(allMembers, U)[0]));
        static assert(param_t.length == 1);
    }

    static struct LocalObservable
    {
        alias ElementType = param_t[0];
        this(ref T signal)
        {
            _subscribe = (Observer!ElementType o) {
                auto dg = (ElementType w) {
                    .put(o, w);
                    static if (is(return_t == bool))
                    {
                        return true;
                    }
                };

                signal.connect(dg);

                return new AnonymouseDisposable({ signal.disconnect(dg); });
            };
        }

        auto subscribe(U)(U observer)
        {
            return _subscribe(observerObject!ElementType(observer));
        }

        Disposable delegate(Observer!ElementType) _subscribe;
    }

    return LocalObservable(signal);
}

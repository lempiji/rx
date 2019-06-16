module mvvm.util;

import std.range : put;

import gobject.Signals;

import gtk.Button;
import gtk.Entry;
import gtk.Label;

import rx;

Entry toBindedEntry(Subject!string source, CompositeDisposable bag)
{
    auto entry = new Entry;
    auto handleId = entry.addOnChanged(_ => .put(source, entry.getText()));
    bag.insert(new AnonymousDisposable({
            Signals.handlerDisconnect(entry, handleId);
        }));
    bag.insert(source.doSubscribe((string text) { entry.setText(text); }));
    return entry;
}

Label toBindedLabel(TObservable)(auto ref TObservable source, CompositeDisposable bag)
{
    import std.conv;

    auto label = new Label("");
    bag.insert(source.doSubscribe((TObservable.ElementType obj) {
            label.setText(obj.to!string);
        }));
    return label;
}

Button makeBindedButton(string text, void delegate() onClick, Observable!bool sensitiveSource, CompositeDisposable disposeBag)
in
{
    const hasSensitiveSource = sensitiveSource is null;
    const hasDisposeBag = disposeBag is null;
    assert(hasSensitiveSource == hasDisposeBag);
}
do
{
    auto button = new Button(text);
    button.addOnClicked((Button _) { onClick(); });
    if (sensitiveSource !is null)
    {
        disposeBag.insert(sensitiveSource.doSubscribe(&button.setSensitive));
    }
    return button;
}

Button makeBindedButton(string text, void delegate() onClick)
{
    return makeBindedButton(text, onClick, null, null);
}

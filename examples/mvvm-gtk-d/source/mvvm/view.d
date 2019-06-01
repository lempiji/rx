module mvvm.view;

import core.time;

import gtk.MainWindow;
import gtk.Box;
import gtk.Entry;
import gtk.Label;
import gtk.Button;
import gtk.Widget;

import rx;

import mvvm.model;
import mvvm.util;

class MyAppWindow : MainWindow
{
    this(AppViewModel model)
    {
        super("rx example");
        setDefaultSize(640, 480);

        auto disposeBag = new CompositeDisposable;
        this.addOnDestroy((Widget _) { disposeBag.dispose(); });

        auto name = model.name.toBindedEntry(disposeBag);
        auto age = model.age.toBindedLabel(disposeBag);
        auto profile = model.profile.debounce(500.msecs).toBindedLabel(disposeBag);
        auto incrementAge = makeBindedButton("+1", &model.incrementAge);
        auto decrementAge = makeBindedButton("-1", &model.decrementAge,
                model.canDecrementAge, disposeBag);
        auto clear = makeBindedButton("Clear", {
            model.clear();
            profile.setText("");
        }, model.canClear, disposeBag);

        auto box = new Box(GtkOrientation.VERTICAL, 5);
        box.packStart(makeLine("Name:", name), false, false, 0);
        box.packStart(makeLine("Age:", age, decrementAge, incrementAge), false, false, 0);
        box.packStart(makeLine("Profile:", profile), false, false, 0);
        box.packStart(clear, false, false, 0);
        add(box);
    }
}

Box makeLine(string name, Widget[] widgets...)
{
    auto box = new Box(GtkOrientation.HORIZONTAL, 5);
    box.packStart(new Label(name), false, false, 0);
    foreach (widget; widgets)
        box.packStart(widget, false, false, 0);
    return box;
}

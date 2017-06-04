import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.EventBox;
import gtk.Entry;
import gtk.Label;
import gtk.Widget;
import gtk.Button;
import gtk.VBox;

import core.time;
import rx;
import std.range : put;

class MyApplication : ApplicationWindow
{
	this(Application application)
	{
		super(application);
		setTitle("rx: Example");
		setDefaultSize(640, 480);

		auto vbox = new VBox(false, 0);
		auto desc = new Label("Label synchronize to Entry with delay");
		auto input = new Entry();
		auto noDelay = new Label("");
		auto delayed = new Label("");
		auto clearButton = new Button("Clear");
		auto detachButton = new Button("Detach");

		vbox.packStart(desc, false, false, 0);
		vbox.packStart(input, false, false, 0);
		vbox.packStart(noDelay, false, false, 0);
		vbox.packStart(delayed, false, false, 0);
		vbox.packStart(clearButton, false, false, 0);
		vbox.packStart(detachButton, false, false, 0);
		add(vbox);

		//Create two Observable, and delay one.
		auto changedText = input.changedAsObservable().map!(entry => entry.getText());
		auto delayedText = changedText.debounce(300.msecs);
		
		//Subscribe in the same way.
		auto d1 = changedText.doSubscribe((string text) { noDelay.setText(text); });
		auto d2 = delayedText.doSubscribe((string text) { delayed.setText(text); });

		clearButton.addOnClicked((Button _) { input.setText(""); });
		detachButton.addOnClicked((Button _) { d1.dispose(); d2.dispose(); });

		showAll();
	}
}

int main(string[] args)
{
	auto application = new Application("rx.myapplication", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app) {
		new MyApplication(application);
	});
	return application.run(args);
}

Observable!Entry changedAsObservable(Entry entry)
{
	import gobject.Signals;

	return defer!Entry((Observer!Entry observer) {
		auto handleId = entry.addOnChanged(_ => .put(observer, entry));
		return new AnonymouseDisposable({
			Signals.handlerDisconnect(entry, handleId);
		});
	}).observableObject!Entry();
}

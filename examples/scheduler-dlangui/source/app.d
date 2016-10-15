import core.time;
import std.datetime;
import std.conv;
import std.stdio;

import dlangui;
import rx;

import utils;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args)
{
    auto window = createAppWindow();

    auto scheduler = new DlangUIScheduler();
    window.mainWidget.addChild(scheduler);
    currentScheduler = scheduler;

    auto label = window.mainWidget.childById!TextWidget("label");
    auto edit = window.mainWidget.childById!EditLine("edit");

    edit.contentChange.asObservable().throttle(dur!"msecs"(500)).doSubscribe((EditableContent _) {
        label.text = edit.text;
    });

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}

Window createAppWindow()
{
    // create window
    Log.d("Creating window");
    if (!Platform.instance)
    {
        Log.e("Platform.instance is null!!!");
    }

    auto window = Platform.instance.createWindow("DlangUI with Rx", null);
    Log.d("Window created");

    // create some widget to show in window
    window.mainWidget = parseML(q{
        VerticalLayout {
            padding: 10
            layoutWidth: fill
            backgroundColor: "#C0E0E070" // semitransparent yellow background

	        EditLine { id: edit; layoutWidth: fill }
	        TextWidget { id: label; }
        }
    });

    return window;
}

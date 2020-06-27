// This source code is in the public domain.

// Cairo: Draw a Line

import std.stdio;
import std.conv;

import gtk.MainWindow;
import gtk.Main;
import gtk.Box;
import gtk.Widget;
import gtk.DrawingArea;
import gdk.Event;
import glib.Timeout;
import cairo.Context;

import rx;
import gfm.math : vec2d;
import std.range : put;

void main(string[] args)
{
    Main.init(args);

    auto testRigWindow = new TestRigWindow();

    Main.run();
}

class TestRigWindow : MainWindow
{
    string title = "Cairo: Draw a Line";
    AppBox appBox;

    this()
    {
        super(title);
        setSizeRequest(640, 480);

        addOnDestroy(&quitApp);

        appBox = new AppBox();
        add(appBox);

        showAll();
    }

    void quitApp(Widget _)
    {
        writeln("Bye.");
        Main.quit();
    }
}

class AppBox : Box
{
    MyDrawingArea myDrawingArea;

    this()
    {
        super(Orientation.VERTICAL, 10);

        myDrawingArea = new MyDrawingArea();

        packStart(myDrawingArea, true, true, 0); // LEFT justify
    }
}

import std.typecons : Tuple, tuple;

alias Path = Tuple!(vec2d, vec2d);
class MyDrawingArea : DrawingArea
{
    bool dragAndDraw = false;

    SubjectObject!vec2d _motion;
    SubjectObject!vec2d _buttonPress;
    SubjectObject!bool _buttonRelease;

    Path drawing;
    Path[] paths;

    this()
    {
        _motion = new SubjectObject!vec2d;
        _buttonPress = new SubjectObject!vec2d;
        _buttonRelease = new SubjectObject!bool;

        addOnDraw(&onDraw);
        addOnMotionNotify((Event event, Widget _) {
            if (event.type == EventType.MOTION_NOTIFY)
            {
                .put(_motion, vec2d(event.motion.x, event.motion.y));
                return true;
            }

            return false;
        });
        addOnButtonPress((Event event, Widget _) {
            if (event.type == EventType.BUTTON_PRESS)
            {
                .put(_buttonPress, vec2d(event.button.x, event.button.y));
                return true;
            }

            return false;
        });
        addOnButtonRelease((Event event, Widget _) {
            if (event.type == EventType.BUTTON_RELEASE)
            {
                .put(_buttonRelease, true);
                return true;
            }

            return false;
        });

        _buttonPress.doSubscribe((vec2d startPoint) {
            const t = vec2d(startPoint.x, startPoint.y);
            drawing = Path(t, t);
            dragAndDraw = true;
            auto innerDisposable = _motion.doSubscribe((vec2d endPoint) {
                drawing[1].x = endPoint.x;
                drawing[1].y = endPoint.y;
                queueDraw();
            });

            _buttonRelease.take(1).doSubscribe((bool _) {
                paths ~= drawing;
                dragAndDraw = false;
                innerDisposable.dispose();
                queueDraw();
            });
        });
    }

    bool onDraw(Scoped!Context context, Widget _)
    {
        foreach (path; paths)
        {
            context.setLineWidth(3);
            context.setSourceRgb(0.7, 0.2, 0.1);
            context.drawPath(path);
        }

        if (dragAndDraw)
        {
            context.setLineWidth(3);
            context.setSourceRgb(0.3, 0.2, 0.1);
            context.drawPath(drawing);
        }

        return true;
    }
}

void drawPath(scope ref Scoped!Context context, const Path path)
{
    context.moveTo(path[0].x, path[0].y);
    context.lineTo(path[1].x, path[1].y);
    context.stroke();
}

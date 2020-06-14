import core.thread;
import core.time;
import fswatch;
import rx;
import std.range : put;
import std.stdio;

void main()
{
    auto watcher = defer!(FileChangeEvent[], (observer) {
        auto shutdown = false;

        auto thread = new Thread({
            try
            {
                auto watch = FileWatch("./data", true);

                while (!shutdown)
                {
                    auto events = watch.getEvents();
                    if (events.length > 0)
                    {
                        .put(observer, events);
                    }

                    Thread.sleep(100.msecs);
                }
                observer.completed();
            }
            catch (Exception e)
            {
                observer.failure(e);
            }
        });
        thread.start();

        return new AnonymousDisposable({ shutdown = true; });
    });

    auto flatten = watcher.map!(events => from(events)).merge();
    auto changes = flatten.groupBy!(event => event.path)
        .map!(o => o.debounce(2.seconds))
        .merge();

    // start FileWatch
    auto disposable = changes.doSubscribe((FileChangeEvent event) {
        writeln(event);
    });

    scope (exit)
        disposable.dispose();

    writeln("Plaese Enter to exit.");
    readln();
}

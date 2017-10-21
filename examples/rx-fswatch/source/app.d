import core.thread;
import core.time;
import fswatch;
import rx;
import std.stdio;

void main()
{
    auto watcher = new FileWatcher("./data", true);

    auto flatten = watcher.map!(events => from(events)).merge();
    auto changes = flatten.groupBy!(event => event.path).map!(o => o.debounce(2.seconds)).merge();

    changes.doSubscribe((FileChangeEvent event) { writeln(event); });

    watcher.start();
    scope (exit)
        watcher.shutdown();

    writeln("Plaese Enter to exit.");
    readln();
}

class FileWatcher : SubjectObject!(FileChangeEvent[])
{
    this(string path, bool recursive = false, Duration period = 1000.msecs)
    {
        _watch = FileWatch(path, recursive);
        _period = period;
    }

    void start()
    {
        _thread = new Thread({
            while (!_shutdown)
            {
                auto events = _watch.getEvents();
                if (events.length > 0)
                {
                    this.put(events);
                }

                Thread.sleep(_period);
            }
        });
        _thread.start();
    }

    void shutdown()
    {
        _shutdown = true;
    }

private:
    FileWatch _watch;
    Thread _thread;
    bool _shutdown;
    Duration _period;
}

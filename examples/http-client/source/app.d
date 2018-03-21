import std.algorithm : splitter;
import std.stdio;
import std.range : put, take;
import rx;

void main()
{
    auto signal = new EventSignal;
    auto client = getAsync("dlang.org");

    // dfmt off
    client.map!(content => content.length)
		.doSubscribe((size_t length) {
        	writeln("Content-Length: ", length);
    	}, () {
			signal.setSignal();
		}, (Exception e) {
        	writeln(e);
        	signal.setSignal();
    	});
	// dfmt on

    signal.wait();
}

Observable!(char[]) getAsync(const(char)[] url)
{
    auto sub = new AsyncSubject!(char[]);

    import std.net.curl : HTTP, get;
    import std.parallelism : task, taskPool;

    taskPool.put(task({
            auto http = HTTP(url);
            http.caInfo = "./curl-ca-bundle.crt";

            try
            {
                .put(sub, get(url, http));
                sub.completed();
            }
            catch (Exception e)
            {
                sub.failure(e);
            }
        }));

    return sub;
}

auto getDefer(const(char)[] url)
{
    return defer!(char[])((Observer!(char[]) observer) {
        import std.net.curl : HTTP, get;

        try
        {
            auto http = HTTP(url);
            http.caInfo = "./curl-ca-bundle.crt";

            .put(observer, get(url, http));
            observer.completed();
        }
        catch (Exception e)
        {
            observer.failure(e);
        }

        return NopDisposable.instance;
    }).subscribeOn(new TaskPoolScheduler);
}

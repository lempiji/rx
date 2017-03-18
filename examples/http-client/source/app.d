import std.algorithm : splitter;
import std.stdio;
import std.range : put, take;
import rx;

void main()
{
	auto signal = new EventSignal;
	auto client = getAsync("http://dlang.org");

	client.map!(content => content.length)
		.doSubscribe((size_t len) => writeln("Content-Length: ", len), &signal.setSignal);

	signal.wait();
}

Observable!(char[]) getAsync(const(char)[] url)
{
	auto sub = new AsyncSubject!(char[]);

	import std.parallelism : task, taskPool;

	taskPool.put(task({
			import std.net.curl : get;

			try
			{
				.put(sub, get(url));
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
		import std.net.curl : get;

		try
		{
			.put(observer, get(url));
			observer.completed();
		}
		catch (Exception e)
		{
			observer.failure(e);
		}

		return NopDisposable.instance;
	}).subscribeOn(new TaskPoolScheduler);
}

import std.algorithm : splitter;
import std.stdio;
import std.range : put, take;
import rx;

void main()
{
	auto signal = new EventSignal;
	getAsync("http://dlang.org").map!(content => content.splitter('\n')
			.take(10)).doSubscribe((char[] line) => writeln(line), () => signal.setSignal());

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
				sub.failure(e);
		}));

	return sub;
}

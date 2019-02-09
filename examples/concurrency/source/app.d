import rx;

import core.time;
import core.thread;

import std.concurrency;
import std.range : put;
import std.stdio;

void main()
{
	auto timer = new ThreadTimer(1.seconds);
	auto counter = timer.scan!"a + 1"(0); // count up per 1sec

	auto receiver = counter.getReceiver();
	scope (exit)
		receiver.dispose();

	timer.start();
	scope (exit)
		timer.stop();

	auto n0 = receiver.receive();
	writeln(n0);
	auto n1 = receiver.receive();
	writeln(n1);
	auto n2 = receiver.receive();
	writeln(n2);
}

auto getReceiver(TObservable)(auto ref TObservable observable)
{
	auto tid = thisTid;
	auto disposable = observable.doSubscribe!((TObservable.ElementType elem) {
		send(tid, elem);
	});

	static struct Receiver
	{
		typeof(disposable) _disposable;

		TObservable.ElementType receive()
		{
			return receiveOnly!(TObservable.ElementType);
		}

		void dispose()
		{
			_disposable.dispose();
		}
	}

	return Receiver(disposable);
}

class ThreadTimer : SubjectObject!bool
{
	Thread _thread;
	shared(bool) _shutdown;
	const(Duration) _interval;

	this(Duration interval)
	{
		_interval = interval;
		_thread = new Thread(&this.run);
	}

	void start()
	{
		_thread.start();
	}

	void stop()
	in(_thread !is null)
	{
		_shutdown = true;
	}

	private void run()
	{
		if (!_shutdown)
			this.put(true);
		while (!_shutdown)
		{
			Thread.sleep(_interval);
			if (!_shutdown)
				this.put(true);
		}
		this.completed();
	}
}

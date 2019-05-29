/+
Benchmark for many observers.

[test_rx]
SubjectObject holds the subscribed Observer as an array.
It requires processing time proportional to the number of Observers for one put.

[test_rx_dispatch]
When it is intended to classify by message type, it is efficient to manage SubjectObject by type using associative arrays.
This idea is "divide and conquer".
+/
import std.stdio;
import std.algorithm : fold;
import std.conv;
import std.meta;

import rx;

import core.sys.windows.windows;

alias message_t = typeof(MSG.init.message);
enum N = 500;
enum M = 100;

void main()
{
	import std.datetime;

	auto data = makeTestData();

	auto t1 = Clock.currTime;
	auto r1 = test_rx(data);
	auto t2 = Clock.currTime;
	auto r2 = test_rx_dispatch(data);
	auto t3 = Clock.currTime;

	writeln("N : ", N);
	writeln("M : ", M);
	writeln("test_rx : ", (t2 - t1).total!"msecs");
	writeln("test_rx_dispatch : ", (t3 - t2).total!"msecs");

	writeln("task1 : ", r1.values.fold!"a+b"(0UL) == N * M ? "success" : "failure");
	writeln("task2 : ", r2.values.fold!"a+b"(0UL) == N * M ? "success" : "failure");
}

MSG[] makeTestData()
{
	import std.array : appender;
	import std.random : uniform;

	auto buf = appender!(MSG[]);
	MSG msg;
	foreach (_; 0 .. N * M)
	{
		msg.message = uniform(cast(message_t) 0, cast(message_t) N);
		buf.put(msg);
	}
	return buf.data;
}

size_t[message_t] test_rx(MSG[] messages)
{
	size_t[message_t] counts;

	auto source = new SubjectObject!MSG;

	static foreach (i; 0 .. N)
	{
		source.filter!(a => a.message == i).doSubscribe!((MSG msg) { counts[msg.message]++; });
	}

	foreach (ref msg; messages)
	{
		source.put(msg);
	}

	return counts;
}

size_t[message_t] test_rx_dispatch(MSG[] messages)
{
	size_t[message_t] counts;
	SubjectObject!(MSG)[message_t] sources;

	foreach (message_t i; 0 .. N)
	{
		sources[i] = new SubjectObject!MSG;
		sources[i].doSubscribe!((msg) { counts[msg.message]++; });
	}

	auto source = new SubjectObject!MSG;
	source.doSubscribe!((msg) { sources[msg.message].put(msg); });

	foreach (ref msg; messages)
	{
		source.put(msg);
	}

	return counts;
}

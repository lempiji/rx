module utils;

import core.time;
import std.traits;
import rx;
import dlangui.core.signals;
import dlangui.widgets.widget;

///Wrap a Signal!T as Observable
auto asObservable(T)(ref T signal)
if (is(T == Signal!U, U) && is(U == interface))
{
	static if (is(T == Signal!U, U))
	{
		alias return_t = ReturnType!(__traits(getMember, U, __traits(allMembers, U)[0]));
		alias param_t = ParameterTypeTuple!(__traits(getMember, U, __traits(allMembers, U)[0]));
		static assert(param_t.length == 1);
	}

	static struct LocalObservable
	{
		alias ElementType = param_t[0];
		this(ref T signal)
		{
			_subscribe = (Observer!ElementType o) {
				auto dg = (ElementType w) {
					o.put(w);
					static if (is(return_t == bool))
					{
						return true;
					}
				};

				signal.connect(dg);

				return new AnonymouseDisposable({
					signal.disconnect(dg);
				});
			};
		}

		auto subscribe(U)(U observer)
		{
			return _subscribe(observerObject!ElementType(observer));
		}

		Disposable delegate(Observer!ElementType) _subscribe;
	}

	return LocalObservable(signal);
}

struct TimerHandler
{
	CancellationToken token;
	void delegate() action;
}

class DlangUIScheduler : Widget, AsyncScheduler
{
	TimerHandler[ulong] _actions;
	Object _gate = new Object();
	ulong _timerId;

	void start(void delegate() op)
	{
		auto id = setTimer(0);
		synchronized (_gate)
		{
			_actions[id] = TimerHandler(null, op);
		}
	}

    CancellationToken schedule(void delegate() op, Duration val)
	{
		auto ms = val.total!"msecs";
		auto id = setTimer(ms);
		auto token = new CancellationToken();
		synchronized (_gate)
		{
			_actions[id] = TimerHandler(token, op);
		}
		return token;
	}

	override bool onTimer(ulong id)
	{
		CancellationToken token;
		void delegate() action;

		synchronized (_gate)
		{
			auto temp = id in _actions;
			if (temp)
			{
				token = (*temp).token;
				action = (*temp).action;

				_actions.remove(id);
			}
			else
			{
				return false;
			}
		}

		if (token is null || !token.isCanceled)
		{
			action();
			return true;
		}
		
		return false;
	}
}
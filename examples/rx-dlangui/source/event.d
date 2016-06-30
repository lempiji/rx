module event;

import std.traits;
import rx;
import dlangui.core.signals;

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

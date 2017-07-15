import rx;
import std.conv : to;
import std.range : iota, put;

void main()
{
    auto subject = new SubjectObject!int;

    string[] result;
    auto disposable = subject.filter!(n => n % 2 == 0).map!(o => to!string(o))
        .doSubscribe!(text => result ~= text);

    scope (exit)
        disposable.dispose();

    put(subject, iota(10));

    assert(result == ["0", "2", "4", "6", "8"]);
}

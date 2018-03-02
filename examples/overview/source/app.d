import rx;
import std.conv : to;
import std.range : iota, put;

void main()
{
    // create own source of int
    auto subject = new SubjectObject!int;

    // define result array
    string[] result;

    // define pipeline and subscribe
    // sequence: source -> filter by even -> map to string -> join to result
    auto disposable = subject.filter!(n => n % 2 == 0).map!(o => to!string(o))
        .doSubscribe!(text => result ~= text);

    // set unsubscribe on exit
    // it is not necessary in this simple example,
    // but in many cases you should call dispose to prevent memory leaks.
    scope (exit)
        disposable.dispose();

    // put values to source. 
    put(subject, iota(10));

    // result is like this
    assert(result == ["0", "2", "4", "6", "8"]);
}

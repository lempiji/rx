import std.conv;
import std.range;
import std.stdio;
import rx;

void main()
{
    auto sub = new SubjectObject!int;

    auto fizz = sub.filter!"a % 3 == 0"().map!(_ => "Fizz");
    auto buzz = sub.filter!"a % 5 == 0"().map!(_ => "Buzz");
    auto num = sub.filter!(a => a % 3 != 0 && a % 5 != 0).map!(to!string);

    fizz.merge(buzz).merge(num).merge(sub.map!(_ => "\n")).doSubscribe((string line) {
        write(line);
    });

    .put(sub, iota(100));
}

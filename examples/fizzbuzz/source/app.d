import std.conv;
import std.range;
import std.stdio;
import rx;

void main()
{
    // 1) make source stream for 0 to 99
    auto sub = new SubjectObject!int;

    // 2) source map to Fizz or Buzz or numbers
    auto fizz = sub.filter!"a % 3 == 0"().map!(_ => "Fizz");
    auto buzz = sub.filter!"a % 5 == 0"().map!(_ => "Buzz");
    auto num = sub.filter!(a => a % 3 != 0 && a % 5 != 0).map!(to!string);
    auto tokens = fizz.merge(buzz).merge(num);

    // 3) source map to newline for delimiters
    auto newlines = sub.map!(_ => "\n");

    // 4) merge tokens and newline
    // e.g.
    //    1 -> ( none ,  none ,  "1", "\n") -> write("1"); write("\n");
    //    3 -> ("Fizz",  none , none, "\n") -> write("Fizz"); write("\n");
    //    5 -> ( none , "Buzz", none, "\n") -> write("Buzz"); write("\n");
    //   15 -> ("Fizz", "Buzz", none, "\n") -> write("Fizz"); write("Buzz"); write("\n");
    merge(tokens, newlines).doSubscribe!(token => write(token));

    // 5) run with numbers
    .put(sub, iota(100));
}

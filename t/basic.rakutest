use OO::Monitors;
use Test;

plan 4;

monitor Counter {
    has $!a = 0;

    method inc() {
        $!a++;
    }
    
    method current() {
        $!a
    }
}

my $cnt = Counter.new;
isa-ok $cnt, Counter, 'A monitor works as a normal type';
ok $cnt.current === 0, 'Initialization works as expected';

await do for ^4 {
    start {
        $cnt.inc for ^1000;
    }
}
pass "Survived running 4 threads using the monitor";

is $cnt.current, 4000, 'Got correct value';

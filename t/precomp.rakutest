use Test;

use lib $*PROGRAM.parent.child('lib').Str;
use Test::Counter;

plan 2;

my $c = Test::Counter.new;
lives-ok { $c.inc },
    "method from monitor works when pre-compiled";
throws-like { $c.deadly }, TheExceptionWeExpect,
    "Exception thrown by monitor method is corret when pre-compiled";

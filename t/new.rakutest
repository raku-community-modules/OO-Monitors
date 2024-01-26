use Test;

plan 1;

use OO::Monitors;

monitor Grid {
    has @.grid;

    method new() {
        self.bless(grid => [23, 42]);
    }
}

my $g = Grid.new;
is $g.grid, [23, 42], 'new method ran OK and provided value for attribute';

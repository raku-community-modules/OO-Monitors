use Test;

plan 1;

use OO::Monitors;

monitor Grid {
    has @.grid;

    submethod BUILD() {
        @!grid = [23, 42];
    }
}

my $g = Grid.new;
is $g.grid, [23, 42], 'BUILD submethod ran OK and set attribute';

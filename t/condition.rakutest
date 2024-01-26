use OO::Monitors;
use Test;

plan 6;

monitor BoundedQueue is conditioned(< not-full not-empty >) {
    has @!tasks;
    constant $limit = 2;
    
    method add-task($task) {
        while @!tasks.elems == $limit {
            wait-condition <not-full>;
        }
        @!tasks.push($task);
        meet-condition <not-empty>;
    }

    method take-task() {
        until @!tasks {
            wait-condition <not-empty>;
        }
        meet-condition <not-full>;
        return @!tasks.shift;
    }
}

my $bq = BoundedQueue.new;

$bq.add-task("Buy beer");
$bq.add-task("Pet cat");
pass 'Added two items to the queue';

my $blocking-add = start { $bq.add-task("Feed cat"); }
sleep 1;
nok $blocking-add, 'Third add blocks';

is $bq.take-task(), "Buy beer", 'Get first item out of queue';

await $blocking-add;
pass 'After removing one item, blocked add took place';

is $bq.take-task(), "Pet cat", 'Got second item out of queue';
is $bq.take-task(), "Feed cat", 'Got third item out of queue';

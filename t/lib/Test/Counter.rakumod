use OO::Monitors;

class TheExceptionWeExpect is Exception { }

monitor Test::Counter {
    has $!a = 0;

    method inc() {
        $!a++;
    }
    
    method current() {
        $!a
    }

    method deadly() {
        die TheExceptionWeExpect.new;
    }
}

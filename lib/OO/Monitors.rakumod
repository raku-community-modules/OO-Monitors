use experimental :macros;

class MetamodelX::MonitorHOW is Metamodel::ClassHOW {
    has $!lock-attr;
    has %!condition-attrs;

    method new_type(|) {
        my \type = callsame();
        type.HOW.setup_monitor(type);
        type
    }

    method setup_monitor(Mu \type) {
        $!lock-attr = Attribute.new(
            name => '$!MONITR-lock',
            type => Lock,
            package => type
        );
        self.add_attribute(type, $!lock-attr);
    }

    method add_method(Mu \type, $name, $meth) {
        $name ne 'BUILDALL' && $meth.wrap(-> \SELF, | {
            if SELF.DEFINITE {
                # Instance method call; acquire lock.
                my $*MONITOR := SELF;
                my $lock = $!lock-attr.get_value(SELF);
                $lock.lock();
                LEAVE $lock.unlock();
                callsame
            }
            else {
                # Type object method call; delegate (presumably
                # .new or some such).
                callsame();
            }
        });
        self.Metamodel::ClassHOW::add_method(type, $name, $meth);
    }

    method add_condition(Mu \type, $name) {
        die "Already have a condition variable $name"
            if %!condition-attrs{$name}:exists;
        my $attr = Attribute.new(
            name => '$!MONITR-CONDITION-' ~ $name,
            type => Any,
            package => type,
            build => -> \SELF, | { $!lock-attr.get_value(SELF).condition }
        );
        self.add_attribute(type, $attr);
        %!condition-attrs{$name} = $attr;
    }

    method lookup_condition(Mu \type, $name) {
        die "No such condition variable $name; did you mean: " ~ %!condition-attrs.keys.join(', ')
            unless %!condition-attrs{$name}:exists;
        %!condition-attrs{$name}
    }

    method compose(Mu \type) {
        my &callsame := CORE::<&callsame>; # Workaround for RT #127858
        if self.method_table(type)<BUILDALL>:exists {
            self.method_table(type)<BUILDALL>.wrap: -> \SELF, | {
                $!lock-attr.set_value(SELF, Lock.new);
                callsame();
            };
        }
        else {
            my $lock-attr := $!lock-attr;
            self.add_method(type, 'BUILDALL', anon method BUILDALL(Mu \SELF: |) {
                $lock-attr.set_value(SELF, Lock.new);
                callsame();
            });
        }
        self.Metamodel::ClassHOW::compose(type);
    }
}

sub add_cond_var(Mu:U $type, $name) {
    die "Can only add a condition variable to a monitor"
        unless $type.HOW ~~ MetamodelX::MonitorHOW;
    $type.HOW.add_condition($type, $name);
}

multi trait_mod:<is>(Mu:U $type, :@conditioned!) is export {
    add_cond_var($type, $_) for @conditioned;
}

multi trait_mod:<is>(Mu:U $type, :$conditioned!) is export {
    add_cond_var($type, $conditioned);
}

sub get-cond-attr($cond, $user) {
    my $cond-canon = $cond.Str.subst(/<-alpha-[-]>+/, '', :g);
    die "Can only use $user in a monitor"
        unless $*PACKAGE.HOW ~~ MetamodelX::MonitorHOW;
    return $*PACKAGE.HOW.lookup_condition($*PACKAGE, $cond-canon);
}

macro wait-condition($cond) is export {
    my $cond-attr = get-cond-attr($cond, 'wait-condition');
    quasi { $cond-attr.get_value($*MONITOR).wait() }
}

macro meet-condition($cond) is export {
    my $cond-attr = get-cond-attr($cond, 'meet-condition');
    quasi { $cond-attr.get_value($*MONITOR).signal() }
}

my package EXPORTHOW {
    package DECLARE {
        constant monitor = MetamodelX::MonitorHOW;
    }
}

=begin pod

=head1 NAME

OO::Monitors - Objects with mutual exclusion and condition variables

=head1 SYNOPSIS

=begin code :lang<raku>

use OO::Monitors;

monitor Foo {
    has $.bar

    # accessible by one thread at a time
    method frobnicate() { }
}

=end code

=head1 DESCRIPTION

A monitor provides per-instance mutual exclusion for objects. This means
that for a given object instance, only one thread can ever be inside its
methods at a time. This is achieved by a lock being associated with each
object. The lock is acquired automatically at the entry to each method
in the monitor. Condition variables are also supported.

=head2 Basic Usage

A monitor looks like a normal class, but declared with the C<monitor> keyword.

=begin code :lang<raku>

use OO::Monitors;

monitor IPFilter {
    has %!active;
    has %!blacklist;
    has $.limit = 10;
    has $.blocked = 0;

    method should-start-request($ip) {
        if %!blacklist{$ip}
          || (%!active{$ip} // 0) == $.limit {
            $!blocked++;
            return False;
        }
        else {
            %!active{$ip}++;
            return True;
        }
    }

    method end-request($ip) {
        %!active{$ip}--;
    }
}

=end code

That's about all there is to it. The monitor meta-object enforces mutual
exclusion.

=head2 Conditions

Condition variables are declared with the C<conditioned> trait on the
monitor.  To wait on a condition, use C<wait-condition>. To signal that
a condition has been met, use C<meet-condition>. Here is an example of
a bounded queue.

=begin code :lang<raku>

monitor BoundedQueue is conditioned(<not-full not-empty>) {
    has @!tasks;
    has $.limit = die "Must specify a limit";

    method add-task($task) {
        while @!tasks.elems == $!limit {
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

=end code

When C<wait-condition> is used, the lock is released and the thread
blocks until the condition is met by some other thread. By contrast,
C<meet-condition> just marks a waiting thread as unblocked, but retains
the lock until the method is over.

=head2 Circular waiting

Monitors are vulnerable to deadlock, if you set up a circular dependency. Keep
object graphs involving monitors simple and cycle-free, so far as is possible.

=head1 AUTHOR

Jonathan Worthington

Source can be located at: https://github.com/raku-community-modules/OO-Monitors .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2014 - 2023 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

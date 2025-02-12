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
        !($name eq 'BUILDALL' | 'POPULATE') && $meth.wrap(-> \SELF, | {
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
        elsif self.method_table(type)<POPULATE>:exists {
            self.method_table(type)<POPULATE>.wrap: -> \SELF, | {
                $!lock-attr.set_value(SELF, Lock.new);
                callsame();
            };
        }
        else {
            my $lock-attr := $!lock-attr;
            my $method := anon method POPULATE(Mu \SELF: |) {
                $lock-attr.set_value(SELF, Lock.new);
                callsame();
            }
            self.add_method(type, 'BUILDALL', $method);
            self.add_method(type, 'POPULATE', $method);
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

# vim: expandtab shiftwidth=4

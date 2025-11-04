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

    method compose(Mu \type) {
        my %methods := self.method_table(type);

        if %methods<POPULATE>:exists {
            %methods<POPULATE>.wrap: -> \SELF, | {
                $!lock-attr.set_value(SELF, Lock.new);
                callsame();
            };
        }
        elsif %methods<BUILDALL>:exists {
            %methods<BUILDALL>.wrap: -> \SELF, | {
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

my package EXPORTHOW {
    package DECLARE {
        constant monitor = MetamodelX::MonitorHOW;
    }
}

# vim: expandtab shiftwidth=4

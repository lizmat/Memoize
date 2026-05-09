use v6.c;

# Role to be mixed in with given Callables.  Keeps the unwrap handle
# available for unmemoizing.
my role Memoized {
    has &.original;
    has %.cache;
    has $.unwrap-handle;
    method memoize-with(\original, \cache, \unwrap-handle) {
        &!original      := original;
        %!cache         := cache;
        $!unwrap-handle := unwrap-handle;  # UNCOVERABLE
        self
    }
}

# Role to mix into a Hash to make it thread-safe for Memoize
my role Multi {  # UNCOVERABLE
    has $!lock = Lock.new;
    method EXISTS-KEY(\key) {
        $!lock.protect: { self.Hash::EXISTS-KEY(key) }
    }
    method AT-KEY(\key) {
        $!lock.protect: { self.Hash::AT-KEY(key) }
    }
    method BIND-KEY(\key,\value) {
        $!lock.protect: { self.Hash::BIND-KEY(key, value) }
    }
    method STORE(|c) {
        $!lock.protect: { self.Hash::STORE(|c) }
    }
}

module Memoize {

    # The default normalizer
    my constant joiner = chr(28);
    sub default-normalizer(|c) {
        c.list.join(joiner) ~ joiner ~ c.hash.join(joiner)
    }

    # Convert name of sub to actual code object, or die
    sub name-to-code(\stash, $name) {
        stash.AT-KEY('&' ~ $name) // die "Could not find sub &$name"
    }

    # Make sure we export the proto only
    our proto sub memoize(|) is export(:DEFAULT:ALL) {*}

    # Cannot handle multiple memoization as we can only mixin the Memoized
    # role once.  Since this appears to be a remote chance this will happen
    # with reason, but instead is most likely the result of a bug in the
    # calling code, we just bail here should this happen.
    multi sub memoize(Memoized:D $code, |c) {
        die "Already memoized $code.name()$code.signature.gist()";
    }

    # The string case: convert string to Callable and pass on
    multi sub memoize(Str() $name, |c) {
        memoize( name-to-code(CALLER::LEXICAL::, $name), |c )
    }

    # The Callable frontend cases
    multi sub memoize(&code) {
        memoize( &code, NORMALIZER => &default-normalizer )
    }
    multi sub memoize(&code, :$CACHE!) {
        memoize( &code, NORMALIZER => &default-normalizer, :$CACHE )
    }
    multi sub memoize(&code, :&NORMALIZER!) {
        memoize( &code, :&NORMALIZER, :CACHE(my %) )
    }

    # The case of Callable, Normalizer and Cache
    multi sub memoize(&code, :&NORMALIZER!, :%CACHE!) {
        my &original = &code.clone;
        (&code does Memoized).memoize-with(
          &original,
          %CACHE,
          &code.wrap( -> |c {
            %CACHE.EXISTS-KEY(my $key := NORMALIZER(c))
              ?? %CACHE.AT-KEY($key)
              !! %CACHE.BIND-KEY($key,callsame);
          })
        );
    }

    # This candidate *must* be after the :&CACHE
    multi sub memoize(&code, :&NORMALIZER!, :$CACHE!) {
        $CACHE eq 'MEMORY'
          ?? memoize( &code, :&NORMALIZER )
          !! $CACHE eq 'MULTI'
            ?? memoize( &code, :&NORMALIZER, :CACHE(my %h does Multi) )
            !! die( "Illegal value for CACHE: $CACHE.raku()" )
    }

    our proto sub unmemoize(|) is export(:ALL) {*}
    multi sub unmemoize(Str() $name) {
        unmemoize(CALLER::LEXICAL::{ '&' ~ $name })
    }
    multi sub unmemoize(Memoized:D $code) {
        $code.cache.?FLUSH;
        $code.unwrap($code.unwrap-handle);
        $code.original
    }

    our proto sub flush_cache(|) is export(:ALL) {*}
    multi sub flush_cache(Str() $name --> Nil) {
        flush_cache(name-to-code(CALLER::LEXICAL::, $name))
    }
    multi sub flush_cache(Memoized:D $code --> Nil) {
        # For some reason, Map.STORE doesn't have a multi for .STORE()
        # so we feed it the empty Slip
        $code.cache.STORE( Empty )
    }
}

sub EXPORT(*@args) {

    if @args {
        my $imports := Map.new( |(EXPORT::ALL::{ @args.map: '&' ~ * }:p) );
        if $imports != @args {
            die "Memoize doesn't know how to export: "
              ~ @args.grep( { !$imports{$_} } ).join(', ')
        }
        $imports
    }
    else {
        EXPORT::DEFAULT::
    }
}

# vim: expandtab shiftwidth=4

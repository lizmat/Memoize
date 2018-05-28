use v6.c;

module Memoize:ver<0.0.1>:auth<cpan:ELIZABETH> {

    role Memoized {
        has %cache;
        has $lock = Lock.new;
        has &.normalizer;
    }

    my sub wrap-it(&code) {

    }

    my sub simple-scalar-hash-cache(|) {
        
    }


    my multi sub simple-hash-cache(:$scalar!, |c) {
    }
    my multi sub simple-hash-cache(|) {
    }

    our proto sub memoize(|) is export(:DEFAULT:ALL) {*}
    multi sub memoize(Str() $name) {
        my &code = CALLER::{ '&' ~ $name };
        my $unwrapper := &code.wrap(
        )
        memoize( CALLER::{ '&' ~ $name }, :wrap, |c)
    }
    multi sub memoize(&code,:$INSTALL! is rw, :$NORMALIZER, :$CACHE,:$wrap) {

    }
    multi sub memoize(&code, :$NORMALIZER, :$CACHE, :$wrap) {
    }

    our sub unmemoize(&code) is export(:ALL) { }

    our sub flush_cache(&code) is export(:ALL) { }
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

=begin pod

=head1 NAME

Memoize - Port of Perl 5's Memoize 1.03

=head1 SYNOPSIS

    use Memoize;
    memoize(&slow_function);
    slow_function(arguments);    # Is faster than it was before

This is normally all you need to know. However, many options are available:

    memoize(&function, options...);

Options include:

    NORMALIZER => &function
    INSTALL => my &new_name

    :CACHE<MEMORY>
    :CACHE('HASH', %cache_hash)

=head1 PORTING CAVEATS

Because pads / stashes are immutable at runtime in Perl 6, one B<must>
specify the value of the C<:INSTALL> named parameter as a variable with
the C<&> sigil.

Since Perl 6 does not have the concept of C<scalar> versus C<list> context,
only one type of cache is used internally, as opposed to two different ones
as in Perl 5.  Many functions / modules of the CPAN Butterfly Plan accept a
C<:scalar> parameter to indicate the scalar context version of the called
function is requested.  Since this is a parameter like any other, it will
be used to distinguish scalar vs list meaning by the default normalizer.

Therefore there are no separate C<:SCALAR_CACHE> and C<:LIST_CACHE> named
parameters necessary anymore: instead a single C<:CACHE> parameter is
recognized, that only accepts either C<'MEMORY'> or a list with C<'HASH'>
as a parameter (as there is no need for the C<'FAULT'> and C<'MERGE'> values
anymore.

=head1 DESCRIPTION

C<Memoizing> a function makes it faster by trading space for time.  It
does this by caching the return values of the function in a table.
If you call the function again with the same arguments, C<memoize>
jumps in and gives you the value out of the table, instead of letting
the function compute the value all over again.

Here is an extreme example.  Consider the Fibonacci sequence, defined
by the following function:

    # Compute Fibonacci numbers
    sub fib {
        my $n = shift;
        return $n if $n < 2;
        fib($n-1) + fib($n-2);
    }

This function is very slow.  Why?  To compute fib(14), it first wants
to compute fib(13) and fib(12), and add the results.  But to compute
fib(13), it first has to compute fib(12) and fib(11), and then it
comes back and computes fib(12) all over again even though the answer
is the same.  And both of the times that it wants to compute fib(12),
it has to compute fib(11) from scratch, and then it has to do it
again each time it wants to compute fib(13).  This function does so
much recomputing of old results that it takes a really long time to
run---fib(14) makes 1,200 extra recursive calls to itself, to compute
and recompute things that it already computed.

This function is a good candidate for memoization.  If you memoize the
`fib' function above, it will compute fib(14) exactly once, the first
time it needs to, and then save the result in a table.  Then if you
ask for fib(14) again, it gives you the result out of the table.
While computing fib(14), instead of computing fib(12) twice, it does
it once; the second time it needs the value it gets it from the table.
It doesn't compute fib(11) four times; it computes it once, getting it
from the table the next three times.  Instead of making 1,200
recursive calls to `fib', it makes 15.  This makes the function about
150 times faster.

You could do the memoization yourself, by rewriting the function, like
this:

    # Compute Fibonacci numbers, memoized version
    {
        my @fib;
        sub fib {
            my $n = shift;
            return $_ with @fib[$n];
            return @fib[$n] = $n if $n < 2;

            @fib[$n] = fib($n-1) + fib($n-2);
        }
    }

Or you could use this module, like this:

    use Memoize;
    memoize('fib');

    # Rest of the fib function just like the original version.

This makes it easy to turn memoizing on and off.

Here's an even simpler example: I wrote a simple ray tracer; the
program would look in a certain direction, figure out what it was
looking at, and then convert the C<color> value (typically a string
like C<red>) of that object to a red, green, and blue pixel value, like
this:

    for ^300 -> $direction {
        # Figure out which object is in direction $direction
        $color = $object{color};
        ($r, $g, $b) = ColorToRGB($color);
        ...
    }

Since there are relatively few objects in a picture, there are only a
few colors, which get looked up over and over again.  Memoizing
C<ColorToRGB> sped up the program by several percent.

=head1 DETAILS

This module exports exactly one function, C<memoize>.  The rest of the
functions in this package are None of Your Business.

You should say

    memoize(function)

where C<function> is the name of the function or the C<Routine> object that
you want to memoize.  C<memoize> returns a reference to the new, memoized
version of the function, or C<Nil> on a non-fatal error.
At present, there are no non-fatal errors, but there might be some in
the future.

If C<function> was the name of a function, then C<memoize> hides the
old version and installs the new memoized version under the old name,
so that C<&function(...)> actually invokes the memoized version.

=head1 OPTIONS

There are some optional options you can pass to C<memoize> to change
the way it behaves a little.  To supply options, invoke C<memoize>
like this:

    memoize(function,
      NORMALIZER => function,
      INSTALL => my &newname,
      CACHE => option,
    );

Each of these options is optional; you can include some, all, or none
of them.

=head2 INSTALL

If you supply variable with a C<&> sigil with C<INSTALL>, memoize will
install the new, memoized version of the function in that variable..
For example,

    my &fastfib;
    memoize('fib', INSTALL => &fastfib)

installs the memoized version of C<fib> as C<fastfib>; without the
C<INSTALL> option it would have replaced the old C<fib> with the
memoized version.

To prevent C<memoize> from installing the memoized version anywhere, use
C<INSTALL =E<gt> False> or C<:!INSTALL>.

=head2 NORMALIZER

Suppose your function looks like this:

    # Typical call: f('aha!', A => 11, B => 12);
    sub f($a, *%hash {
        %hash{B} ||= 2;  # B defaults to 2
        %hash{C} ||= 7;  # C defaults to 7

        # Do something with $a, %hash
    }

Now, the following calls to your function are all completely equivalent:

    f(OUCH);
    f(OUCH, B => 2);
    f(OUCH, C => 7);
    f(OUCH, B => 2, C => 7);
    f(OUCH, C => 7, B => 2);
    (etc.)

However, unless you tell C<Memoize> that these calls are equivalent,
it will not know that, and it will compute the values for these
invocations of your function separately, and store them separately.

To prevent this, supply a C<NORMALIZER> function that turns the
program arguments into a string in a way that equivalent arguments
turn into the same string.  A C<NORMALIZER> function for C<f> above
might look like this:

    sub normalize_f($a,*%hash {
        %hash{B} ||= 2;
        $hash{C} ||= 7;

        join(',', $a, %hash.sort>>.kv);
    }

Each of the argument lists above comes out of the C<normalize_f>
function looking exactly the same, like this:

    OUCH,B,2,C,7

You would tell C<Memoize> to use this normalizer this way:

    memoize('f', NORMALIZER => 'normalize_f');

C<memoize> knows that if the normalized version of the arguments is
the same for two argument lists, then it can safely look up the value
that it computed for one argument list and return it as the result of
calling the function with the other argument list, even if the
argument lists look different.

The default normalizer just concatenates the stringified arguments with
character 28 in between.  (In ASCII, this is called FS or control-\.)  This
always works correctly for functions with only one string argument,
and also when the arguments never contain character 28.  However, it
can confuse certain argument lists:

    normalizer("a\034", "b")
    normalizer("a", "\034b")
    normalizer("a\034\034b")

for example.

Since hash keys are strings, the default normalizer will not
distinguish between type objects / Nil and the empty string.

    sub normalize($a, @b) { join ' ', $a, @b }

For the example above, this produces the key "13 1 2 3 4 5 6 7".

Another use for normalizers is when the function depends on data other
than those in its arguments.  Suppose you have a function which
returns a value which depends on the current hour of the day:

    sub on_duty($problem_type) {
        my $hour = DateTime.now.hour;
        my $fh = open("$DIR/$problem_type") or die...;
        $fh.lines.skip(DateTime.now.hour).head;
    }

At 10:23, this function generates the 10th line of a data file; at
3:45 PM it generates the 15th line instead.  By default, C<Memoize>
will only see the $problem_type argument.  To fix this, include the
current hour in the normalizer:

    sub normalize(*@_) { join ' ', DateTime.now.hour, @_ }

Normally, C<Memoize> caches your function's return values into an
ordinary Perl hash variable.  However, you might like to have the
values cached on the disk, so that they persist from one run of your
program to the next, or you might like to associate some other
interesting semantics with the cached values.

The argument to C<CACHE> must either be one of
the following four strings:

    MEMORY
    HASH

or else it must be a reference to an array whose first element is one of
these four strings, such as C<[HASH, arguments...]>.

=item C<MEMORY>

C<MEMORY> means that return values from the function will be cached in
an ordinary Perl 6 hash.  The hash will not persist after the program exits.
This is the default.

=item C<HASH>

C<HASH> allows you to specify that a particular hash that you supply
will be used as the cache.  Any object that does the C<Associative> role
is acceptable.

Such an C<Associative> object can have any semantics at all.  It is typically
tied to an on-disk database, so that cached values are stored in the database
and retrieved from it again when needed, and the disk file typically
persists after your program has exited.

A typical example is:

    my %cache is MyStore[$filename];
    memoize 'function', CACHE => [HASH => %cache];

This has the effect of storing the cache in a C<MyStore> database
whose name is in C<$filename>.  The cache will persist after the
program has exited.  Next time the program runs, it will find the
cache already populated from the previous run of the program.  Or you
can forcibly populate the cache by constructing a batch program that
runs in the background and populates the cache file.  Then when you
come to run your real program the memoized function will be fast
because all its results have been precomputed.

Another reason to use C<HASH> is to provide your own hash variable.
You can then inspect or modify the contents of the hash to gain finer
control over the cache management.

=head1 OTHER FACILITIES

=head2 C<unmemoize>

There's an C<unmemoize> function that you can import if you want to.
Why would you want to?  Here's an example: Suppose you have your cache
tied to a DBM file, and you want to make sure that the cache is
written out to disk if someone interrupts the program.  If the program
exits normally, this will happen anyway, but if someone types
control-C or something then the program will terminate immediately
without synchronizing the database.  So what you can do instead is

    $SIG{INT} = sub { unmemoize 'function' };

C<unmemoize> accepts a reference to, or the name of a previously
memoized function, and undoes whatever it did to provide the memoized
version in the first place, including making the name refer to the
unmemoized version if appropriate.  It returns a reference to the
unmemoized version of the function.

If you ask it to unmemoize a function that was never memoized, it
will throw an exception.

=head2 C<flush_cache>

C<flush_cache(function)> will flush out the caches, discarding I<all>
the cached data.  The argument may be a function name or a reference
to a function.  For finer control over when data is discarded or
expired, see the documentation for C<Memoize::Expire>, included in
this package.

Note that if the cache is a tied hash, C<flush_cache> will attempt to
invoke the C<CLEAR> method on the hash.  If there is no C<CLEAR>
method, this will cause a run-time error.

An alternative approach to cache flushing is to use the C<HASH> option
(see above) to request that C<Memoize> use a particular hash variable
as its cache.  Then you can examine or modify the hash at any time in
any way you desire.  You may flush the cache by using C<%hash = ()>.

=head1 CAVEATS

Memoization is not a cure-all:

=item *

Do not memoize a function whose behavior depends on program
state other than its own arguments, such as global variables, the time
of day, or file input.  These functions will not produce correct
results when memoized.  For a particularly easy example:

	sub f {
	  time;
	}

This function takes no arguments, and as far as C<Memoize> is
concerned, it always returns the same result.  C<Memoize> is wrong, of
course, and the memoized version of this function will call C<time> once
to get the current time, and it will return that same time
every time you call it after that.

=item *

Do not memoize a function with side effects.

	sub f {
        my ($a, $b) = @_;
        my $s = $a + $b;
        say "$a + $b = $s.";
	}

This function accepts two arguments, adds them, and prints their sum.
Its return value is the number of characters it printed, but you
probably didn't care about that.  But C<Memoize> doesn't understand
that.  If you memoize this function, you will get the result you
expect the first time you ask it to print the sum of 2 and 3, but
subsequent calls will return 1 (the return value of
C<print>) without actually printing anything.

=item *

Do not memoize a function that returns a data structure that is
modified by its caller.

Consider these functions:  C<getusers> returns a list of users somehow,
and then C<main> throws away the first user on the list and prints the
rest:

    sub main {
        my @userlist = getusers();
        shift @userlist;
        for @userlist -> $u {
            print "User $u\n";
        }
    }

    sub getusers {
        my @users;
        # Do something to get a list of users;
        @users
    }

If you memoize C<getusers> here, it will work right exactly once.  The
reference to the users list will be stored in the memo table.  C<main>
will discard the first element from the referenced list.  The next
time you invoke C<main>, C<Memoize> will not call C<getusers>; it will
just return the same reference to the same list it got last time.  But
this time the list has already had its head removed; C<main> will
erroneously remove another element from it.  The list will get shorter
and shorter every time you call C<main>.

Similarly, this:

	$u1 = getusers();
	$u2 = getusers();
	pop @$u1;

will modify $u2 as well as $u1, because both variables are references
to the same array.  Had C<getusers> not been memoized, $u1 and $u2
would have referred to different arrays.

=item *

Do not memoize a very simple function.

Recently someone mentioned to me that the Memoize module made his
program run slower instead of faster.  It turned out that he was
memoizing the following function:

    sub square($value) {
      $value * $value;
    }

I pointed out that C<Memoize> uses a hash, and that looking up a
number in the hash is necessarily going to take a lot longer than a
single multiplication.  There really is no way to speed up the
C<square> function.

Memoization is not magical.

=head1 AUTHOR

Elizabeth Mattijsen <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/Memoize . Comments and
Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Elizabeth Mattijsen

Re-imagined from Perl 5 as part of the CPAN Butterfly Plan.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: ft=perl6 expandtab sw=4

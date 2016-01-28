use Test::More 0.98;
use Text::Diff;

use HTTP::Cookies::Mozilla;

my $class = 'HTTP::Cookies::Mozilla';
use_ok( $class );

my $dist_file = 't/cookies.txt';
my $save_file = 't/cookies2.txt';

my %Domains = qw( .ebay.com 2 .usatoday.com 3 );


my $start = time();
my $jar = HTTP::Cookies::Mozilla->new( File => $dist_file );
my $time_delta = time() - $start;

isa_ok( $jar, 'HTTP::Cookies::Mozilla' );
my $result = $jar->save( $save_file );

my $diff = Text::Diff::diff( $dist_file, $save_file );
my $same = not $diff;

if ((! $same) && $time_delta) { # adjust $diff based on pre-analysis

   # there is a race condition between H::C::M calculating the parameter
   # max_age for H::C::set_cookie, and H::C::set_cookie calculating the
   # expiration time back. We might have hit that race condition, so we
   # will clear $diff if this is actually the case.

   # isolate differences
   my (@minus, @plus);
   for my $line (split /\n/, $diff) {
      my $first_char = substr $line, 0, 1;
      my @fields = split /(\s+)/, $line;
      push @minus, \@fields if $first_char eq '-';
      push @plus, \@fields if $first_char eq '+';
   }

   # first two items are diff's headers... they always differ
   shift @minus;
   shift @plus;

   # we will compare @minus and @plus element by element. If pairs are
   # compatible, we will eventually clear $diff and $same, otherwise they
   # will remain untouched
   COMPARISON:
   while (@minus) {

      # if @plus is already empty, differences are not compatible and
      # we can just leave this extended comparison. Remaining element(s)
      # in @minus will flag the error condition.
      last COMPARISON unless @plus;

      # we want the line to remain in @minus and @plus until it's
      # clear that they are compatible, so we don't do shift-ing
      # here but only at the end of the loop
      my $minus_line = $minus[0];
      my $plus_line  = $plus[0];
      last COMPARISON if scalar(@$minus_line) != scalar(@$plus_line);

      # we kept separators, so the expiration time is the ninth element.
      # If they differ more than our estimated $time_delta, an
      # error occurred and we have to fail
      my $minus_expiration = $minus_line->[8];
      my $plus_expiration  = $plus_line->[8];
      last COMPARISON
         if ($plus_expiration - $minus_expiration) > $time_delta;

      # we will force the expiration time of plus to be the same as the
      # expiration time for minus and rebuild the two strings, to see if
      # they are the same now. We have to get rid of the initial character
      # because it's the '-' or '+'
      $plus_line->[8] = $minus_line->[8];
      my $minus_string = substr join('', @$minus_line), 1;
      my $plus_string  = substr join('', @$plus_line), 1;
      last COMPARISON if $minus_string ne $plus_string;

      # differing lines are compatible, we can clear them out
      shift @minus;
      shift @plus;
   }

   # If all comparisons of @minus vs @plus were fine, and they had the
   # same number of elements, both arrays are now empty. Any error
   # condition left at least one element inside either one.
   $diff = '' if (scalar(@minus) + scalar(@plus)) == 0;
   $same = not $diff;
}

ok( $same, 'Saved file is same as original' );
print STDERR $diff;

END { unlink $save_file }

done_testing();

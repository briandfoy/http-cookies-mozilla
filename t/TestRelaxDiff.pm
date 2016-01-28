package TestRelaxDiff;
use strict;
use warnings;
use Text::Diff ();

# there is a race condition between H::C::M calculating the parameter
# max_age for H::C::set_cookie, and H::C::set_cookie calculating the
# expiration time back. We might have hit that race condition, so we
# might relax the diff if the difference is within certain bounds.
sub diff {
   my ($file1, $file2, $time_delta) = @_;
   my $diff = Text::Diff::diff($file1, $file2);

   # return immediately if the files are equal or there is no 
   # way to relax the comparison
   return $diff unless $diff || $time_delta;

   # isolate differences
   my (@minus, @plus);
   for my $line (split /\n/, $diff) {
      my $first_char = substr $line, 0, 1, '';

      # we keep separators in the split, so that the comparison will
      # take them into account later
      my @fields = split /(\s+)/, $line;

      # dispatch
      push @minus, \@fields if $first_char eq '-';
      push @plus,  \@fields if $first_char eq '+';
   }

   # first two items are diff's headers... they always differ
   shift @minus;
   shift @plus;

   # we will compare @minus and @plus element by element
   while (@minus) {
      return $diff unless @plus; # no @plus? files differ heavily!

      my $minus_line = shift @minus;
      my $plus_line  = shift @plus;
      return $diff if scalar(@$minus_line) != scalar(@$plus_line);

      # we kept separators, so the expiration time is the ninth element.
      # If they differ more than our relax boundary $time_delta, an
      # error occurred and we have to fail
      my $minus_expiration = $minus_line->[8];
      my $plus_expiration  = $plus_line->[8];
      return $diff
         if abs($plus_expiration - $minus_expiration) > $time_delta;

      # we will force the expiration time of plus to be the same as the
      # expiration time for minus and rebuild the two strings, to see if
      # they are the same now.
      $plus_line->[8] = $minus_line->[8];
      my $minus_string = join '', @$minus_line;
      my $plus_string  = join '', @$plus_line;
      return $diff if $minus_string ne $plus_string;
   }

   # if we arrive here, all comparisons were fine so far. If there are
   # residual elements in @plus it's an error, otherwise the test was
   # fine
   return $diff if @plus;
   return '';
}

1;


package TestSqliteCmd;
use strict;
use warnings;

sub which_sqlite {
   my $prg = $ENV{SQLITE_PATH} || 'sqlite3';
   open my $fh, '-|', $prg, '--version' or return;
   my $version = <$fh>;
   return unless $version;
   my ($major) = split /\./, $version;
   $major =~ /\A \d+ \z/mxs or return;
   $major >= 3 or return;
   return $prg;
}

1;

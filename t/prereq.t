use Test::More;
eval "use Test::Prereq 0.9";
plan skip_all => "Test::Prereq required to test dependencies" if $@;

use lib 't';

# DBI and DBD::SQLite are only an option, skip them
# Work around Test::Prereq bug as well
prereq_ok(undef, undef, [qw( DBI DBD::SQLite TestSqliteCmd )]);

use Test::More;
eval "use Test::Prereq 0.9";
plan skip_all => "Test::Prereq required to test dependencies" if $@;

# DBI and DBD::SQLite are only an option, skip them
prereq_ok(undef, undef, [qw( DBI DBD::SQLite )]);

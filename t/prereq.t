use Test::More;
eval "use Test::Prereq 0.9";
plan skip_all => "Test::Prereq required to test dependencies" if $@;
prereq_ok();

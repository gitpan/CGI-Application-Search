use Test::More;
use CGI;
use lib './t/lib';
use MySearch;

# setup our tests
plan(tests => 2);
$ENV{CGI_APP_RETURN_ONLY} = 1;

# 1..2
# use without a correct index
{
    # first an index that does not exist
    my $cgi = CGI->new({
        'index'     => '/foo.txt',
        keywords    => 'please',    
        rm          => 'perform_search',
    });
    my $app = MySearch->new(
        QUERY   => $cgi,
    );
    eval { $app->run };
    ok($@);
    
    # now a file that isn't an index
    $cgi = CGI->new({
        'index'     => 't/conf/not-a-swish-e.index',
        keywords    => 'please',    
        rm          => 'perform_search',
    });
    $app = MySearch->new(
        QUERY   => $cgi,
    );
    eval { $app->run };
    ok($@);
}



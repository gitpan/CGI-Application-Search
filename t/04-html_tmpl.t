use Test::More;
use CGI;
use CGI::Application::Search;

# setup our tests
plan(tests => 96);
$ENV{CGI_APP_RETURN_ONLY} = 1;

# 1
# use the test app
require_ok('MySearch::HT');

# 2
# show search
{
    my $app = MySearch::HT->new();
    my $output = $app->run();
    like($output, qr/<h2>Search</i);
}

# 3..4
# blank keywords
{
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/No results/i);
}

# 5..23
# search
{
    # simple word 'please'
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    unlike($output, qr/No results/i);
    like($output, qr/Elapsed Time: \d\.\d{1,3}s/i);
    like($output, qr/>\w+ \d\d?, 200\d - \d+(K|M|G)?</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/>This is a test\. This is a only a test\. And please do not panic\.</i);
    like($output, qr/>Would you please help me find this document/i);
    like($output, qr/Results: 1 to 2 of 2/i);

    # phrase 'please help'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help"',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/>Would you please help me find this document/i);
    like($output, qr/Results: 1 to 1 of 1/i);

    # phrase 'please help' and keyword 'panic'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help" or panic',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/>Would you please help me find this document/i);
    like($output, qr/>This is a test\. This is a only a test\. And please do not panic\.</i);
    like($output, qr/Results: 1 to 2 of 2/i);
}

# 24..31
# search with context
{
    # simple word 'context'
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context',
        context     => 1,
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Find the Context</i);
    like($output, qr/I would like to find the context in this/i);
    unlike($output, qr/Lorem ipsum/i);

    # simple word 'context and like'
    # to test removal of boolean operators
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context and like or context not help',
        context     => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Find the Context</i);
    like($output, qr/I would like to find the context in this/i);
    unlike($output, qr/Lorem ipsum/i);
}

# 32..59
# search with highlighting
{
    # simple word 'please'
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        hl          => 1,
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    unlike($output, qr/No results/i);
    like($output, qr/Elapsed Time: \d\.\d{1,3}s/i);
    like($output, qr/>\w+ \d\d?, 200\d - \d+(K|M|G)?</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/And <strong>please<\/strong> do not panic/i);
    like($output, qr/<strong>please<\/strong> help me/i);
    like($output, qr/Results: 1 to 2 of 2/i);

    # phrase 'please help'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help"',
        hl          => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/<strong>please help<\/strong> me/i);
    like($output, qr/Results: 1 to 1 of 1/i);

    # phrase 'please help' and keyword 'panic'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help" or panic',
        hl          => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/<strong>please help<\/strong> me/i);
    like($output, qr/please do not <strong>panic<\/strong>/i);
    unlike($output, qr/<strong>or<\/strong>/);
    like($output, qr/Results: 1 to 2 of 2/i);

    # without 'real' keywords
    # $DEBUG off
    $cgi = CGI->new({
        rm          => 'perform_search',
        hl          => 1,
        keywords    => '--',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/No results/i);

    # $DEBUG on
    _throw_away_stderr();
    $CGI::Application::Search::DEBUG = 1;
    $cgi = CGI->new({
        rm          => 'perform_search',
        hl          => 1,
        keywords    => '--',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    eval { $output = $app->run() };
    like($output, qr/<h2>Search Results</i);
    like($output, qr/No results/i);
    _restore_stderr();

    # higlighting and context
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context',
        context     => 1,
        hl          => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>Find the Context</i);
    like($output, qr/I would like to find the <strong>context<\/strong> in this/i);
    unlike($output, qr/Lorem ipsum/i);
}

# 60..70
# add some EXTRA_PROPERTIES
{
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        extra       => 'foo',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/Results: 1 to 1 of 1/i);

    # make the extra property blank
    $cgi->param('extra' => '');
     $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/Results: 1 to 2 of 2/i);

    # delete the EXTRA_PROPERTIES entirely
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        extra       => 'foo',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $app->delete('EXTRA_PROPERTIES');
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is a Test</i);
    like($output, qr/>Please Help Me</i);
    like($output, qr/Results: 1 to 2 of 2/i);
}

# 71..72
# predefined results
{
    # without  keywords
    my $cgi = CGI->new({
        rm          => 'perform_search',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $app->param(results => [] );
    $output = $app->run();
    like($output, qr/<h2>Search</i);

    # with keywords
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $app->param(results => [] );
    $output = $app->run();
    like($output, qr/<h2>Search</i);
}

# 73..78
# result without a description
{
    # without highlighting
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="another"',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is another Test</i);
    like($output, qr/Results: 1 to 1 of 1/i);

    # without highlighting
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="another"',
        hl          => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is another Test</i);
    like($output, qr/Results: 1 to 1 of 1/i);
}

# 79..84
# result without a context
{
    # without highlighting
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="yet"',
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is yet a fourth Test</i);
    like($output, qr/Results: 1 to 1 of 1/i);

    # without highlighting
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="yet"',
        hl          => 1,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is yet a fourth Test</i);
    like($output, qr/Results: 1 to 1 of 1/i);
}

# 85..96
# PER_PAGE
{
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        per_page    => 1,
    });
    my $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    like($output, qr/>This is a Test</i);
    unlike($output, qr/>Please Help Me</i);
    like($output, qr/>This is a test\. This is a only a test\. And please do not panic\.</i);
    unlike($output, qr/>Would you please help me find this document/i);
    like($output, qr/Results: 1 to 1 of 2/i);

    # go to page 2
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        per_page    => 1,
        page        => 2,
    });
    $app = MySearch::HT->new(
        QUERY   => $cgi,
    );
    $output = $app->run();
    like($output, qr/<h2>Search Results</i);
    unlike($output, qr/>This is a Test</i);
    like($output, qr/>Please Help Me</i);
    unlike($output, qr/>This is a test\. This is a only a test\. And please do not panic\.</i);
    like($output, qr/>Would you please help me find this document/i);
    like($output, qr/Results: 2 to 2 of 2/i);
}

my $junk;
sub _throw_away_stderr {
    # First, save away STDERR
    no strict;
    open SAVE_ERR, ">&STDERR";
    close STDERR;
    open STDERR, ">", \$junk 
        or warn "Could not redirect STDERR?\n";

}

sub _restore_stderr {
    # Now close and restore STDERR to original condition.
    close STDERR;
    open STDERR, ">&SAVE_ERR";
    close SAVE_ERR;
}


package MyTest::Base;
use base 'Test::Class';
use Test::More;
use Test::LongString;
use CGI::Application::Search;
use CGI;
use File::Spec::Functions qw(catfile catdir);

# setup our tests
$ENV{CGI_APP_RETURN_ONLY} = 1;
our %BASE_OPTIONS = (
    SWISHE_INDEX  => catfile('t', 'conf', 'swish-e.index'),
    HIGHLIGHT_TAG => 'strong',
    DOCUMENT_ROOT => catdir('t', 'conf', 'data'),
);
# will be overridden by subclasses
sub options {
    return ();
}

sub A_blank_keywords: Test(2) {
    my $self = shift;
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS => {
            %BASE_OPTIONS,
            $self->options(),
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'No results');
}


sub B_keyword_search: Test(25) {
    my $self = shift;
    # simple word 'please'
    # no higlighting
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    lacks_string($output, 'No results');
    like($output, qr/Elapsed Time: \d\.\d{1,3}s/i);
    like($output, qr/>\w+ \d\d?, 200\d - \d+(K|M|G)?</i);
    contains_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'This is a test. This is a only a test. And please do not panic.');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'Results: 1 to 2 of 2');

    # phrase 'please help'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help"',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'Results: 1 to 1 of 1');

    # phrase 'please help' and keyword 'panic'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help" or panic',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'This is a test. This is a only a test. And please do not panic.');
    contains_string($output, 'Results: 1 to 2 of ');

    # built-in default templates
    my %params = (
        %BASE_OPTIONS,
        $self->options,
        HIGHLIGHT => 0,
    );
    delete $params{TEMPLATE};
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => \%params,
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'This is a test. This is a only a test. And please do not panic.');
    contains_string($output, 'Results: 1 to 2 of ');
}

sub C_search_with_context: Test(8) {
    my $self = shift;
    # simple word 'context'
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 0,
            DESCRIPTION_CONTEXT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</');
    contains_string($output, 'Find the Context');
    contains_string($output, 'I would like to find the context in this');
    lacks_string($output, 'Lorem ipsum');

    # simple word 'context and like'
    # to test removal of boolean operators
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context and like or context not help',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 0,
            DESCRIPTION_CONTEXT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'Find the Context');
    contains_string($output, 'I would like to find the context in this');
    lacks_string($output, 'Lorem ipsum');
}

sub D_search_with_highlighting: Test(28) {
    my $self = shift;
    # simple word 'please'
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    lacks_string($output, 'No results');
    like($output, qr/Elapsed Time: \d\.\d{1,3}s/i);
    like($output, qr/>\w+ \d\d?, 200\d - \d+(K|M|G)?</i);
    contains_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'And <strong>please</strong> do not panic');
    contains_string($output, '<strong>please</strong> help me');
    contains_string($output, 'Results: 1 to 2 of 2');

    # phrase 'please help'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help"',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'Please Help Me');
    contains_string($output, '<strong>please help</strong> me');
    contains_string($output, 'Results: 1 to 1 of 1');

    # phrase 'please help' and keyword 'panic'
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '"please help" or panic',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'This is a Test');
    contains_string($output, '<strong>please help</strong> me');
    contains_string($output, 'please do not <strong>panic</strong>');
    lacks_string($output, '<strong>or</strong>');
    contains_string($output, 'Results: 1 to 2 of 2');

    # without 'real' keywords
    # $DEBUG off
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '--',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'No results');

    # $DEBUG on
    _throw_away_stderr();
    $CGI::Application::Search::DEBUG = 1;
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => '--',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 0,
        },
    );
    eval { $output = $app->run() };
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'No results');
    _restore_stderr();

    # higlighting and context
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'context',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 1,
            DESCRIPTION_CONTEXT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'Find the Context');
    contains_string($output, 'I would like to find the <strong>context</strong> in this');
    lacks_string($output, 'Lorem ipsum');
}

sub E_with_extra_props: Test(11) {
    my $self = shift;
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        extra       => 'foo',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 0,
            EXTRA_PROPERTIES    => [qw(extra)],
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Results: 1 to 1 of 1');

    # make the extra property blank
    $cgi->param('extra' => '');
     $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 0,
            EXTRA_PROPERTIES    => [qw(extra)],
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'Results: 1 to 2 of 2');

    # delete the EXTRA_PROPERTIES entirely
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        extra       => 'foo',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT           => 0,
            EXTRA_PROPERTIES    => [qw(extra)],
        },
    );
    $app->delete('EXTRA_PROPERTIES');
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'Results: 1 to 2 of 2');
}

sub E_with_extra_range_props: Test(3) {
    my $self = shift;
    my $cgi = CGI->new({
        rm                  => 'perform_search',
          keywords          => 'range',
          extra_range_start => '5',
          extra_range_stop  => '25',
    });
    my $app = CGI::Application::Search->new(
        QUERY    => $cgi,
          PARAMS => {
            %BASE_OPTIONS, 
            $self->options,
            HIGHLIGHT              => 0,
            EXTRA_RANGE_PROPERTIES => [qw(extra_range)],
          },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Range Test');
    contains_string($output, 'Results: 1 to 2 of 2');
}

sub F_predefined_results: Test(2) {
    my $self = shift;
    # without  keywords
    my $cgi = CGI->new({
        rm          => 'perform_search',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $app->param(results => [] );
    $output = $app->run();
    contains_string($output, '<h2>Search</h2>');

    # with keywords
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $app->param(results => [] );
    $output = $app->run();
    contains_string($output, '<h2>Search</h2>');
}

sub G_without_description: Test(6) {
    my $self = shift;
    # without highlighting
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="another"',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is another Test');
    contains_string($output, 'Results: 1 to 1 of 1');

    # with highlighting
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="another"',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results<');
    contains_string($output, 'This is another Test');
    contains_string($output, 'Results: 1 to 1 of 1');
}

sub H_without_context: Test(6) {
    my $self = shift;
    # without highlighting
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="yet"',
    });
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
            DESCRIPTION_CONTEXT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is yet a fourth Test');
    contains_string($output, 'Results: 1 to 1 of 1');

    # with highlighting
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'title="yet"',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 1,
            DESCRIPTION_CONTEXT => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is yet a fourth Test');
    contains_string($output, 'Results: 1 to 1 of 1');
}

sub I_per_page: Test(18) {
    my $self = shift;
    my $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    # 1 per page
    my $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
            PER_PAGE  => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Test');
    lacks_string($output, 'Please Help Me');
    contains_string($output, 'This is a test. This is a only a test. And please do not panic.');
    lacks_string($output, 'Would you please help me find this document');
    contains_string($output, 'Results: 1 to 1 of 2');

    # go to page 2
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
        page        => 2,
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
            PER_PAGE  => 1,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    lacks_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    lacks_string($output, 'This is a test. This is a only a test. And please do not panic.');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'Results: 2 to 2 of 2');

    # 2 per page
    $cgi = CGI->new({
        rm          => 'perform_search',
        keywords    => 'please',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
            HIGHLIGHT => 0,
            PER_PAGE  => 2,
        },
    );
    $output = $app->run();
    contains_string($output, '<h2>Search Results</h2>');
    contains_string($output, 'This is a Test');
    contains_string($output, 'Please Help Me');
    contains_string($output, 'This is a test. This is a only a test. And please do not panic.');
    contains_string($output, 'Would you please help me find this document');
    contains_string($output, 'Results: 1 to 2 of 2');
}

sub J_highlight_local_page: Test(1) {
    my $self = shift;
    $cgi = CGI->new({
        rm          => 'highlight_local_page',
        keywords    => 'please',
        path        => 'helpme.html',
    });
    $app = CGI::Application::Search->new(
        QUERY   => $cgi,
        PARAMS  => {
            %BASE_OPTIONS,
            $self->options,
        },
    );
    my $output = $app->run();
    contains_string($output, 'you <strong>please</strong> help');
}

# to capture and junk STDERR
{
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
    sub _stderr_junk {
        return $junk;
    }
}

sub show_search: Test(1) {
    my $self = shift;
    my $app = CGI::Application::Search->new(
        PARAMS => {
            %BASE_OPTIONS,
            $self->options(),
        },
    );
    my $output = $app->run();
    contains_string($output, '<h2>Search</h2>');
}


1;


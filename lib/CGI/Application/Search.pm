package CGI::Application::Search;
use strict;
use warnings;
use Carp;
use base 'CGI::Application';

use CGI::Application::Plugin::AnyTemplate;
use Data::Page;
use File::Spec::Functions qw(catfile);
use Number::Format qw(format_bytes format_number);
use HTML::FillInForm;
use Time::HiRes;
use Time::Piece;
use POSIX;
use HTML::HiLiter;
use Text::Context;

our $VERSION = '0.05';
our $DEBUG;

# load SWISH::API and complain if not available.  This is done here
# and not in Makefile.PL because SWISH::API is not on CPAN.  It's part
# of the Swish-e distribution.
BEGIN {
    eval "use SWISH::API";
    croak(<<END) if $@;

Unable to load SWISH::API.  This module is included in the Swish-e
distribution, inside the perl/ directory.  Please see the
CGI::Application::Search documentation for more details.

END
}


=head1 NAME 

CGI::Application::Search - Base class for CGI::App Swish-e site engines

=head1 SYNOPSIS

    package My::Search;
    use base 'CGI::Application::Search';
	
    sub cgiapp_init {
        my $self = shift;
        $self->param(
            'SWISHE_INDEX' => 'my-swishe.index',
            'TEMPLATE'     => 'search_results.tmpl',
        );
    }

    #let the user turn context highlighting off
    sub cgiapp_prerun {
        my $self = shift;
        $self->param('HIGHLIGHT' => 0)
            if($self->query->param('highlight_off'));
    }

    1;

=head1 DESCRIPTION

A L<CGI::Application> based control module that uses Swish-e API in
perl (L<http://swish-e.org>) to to perform searches on a swish-e index
of documents. It uses L<HTML::Template> to display the search form and
the results.  You may customize this template to alter the look and
feel of the generated search interface.

=head1 TUTORIAL

You can skip this section if you're a Swish-e veteren.  Otherwise,
read on for a step-by-step guide to adding a search interface to your
site using CGI::Application::Search.

=head2 Step 1: Install Swish-e

The first thing you need to do is install Swish-e.  First, download it
from the swish-e site:

   http://swish-e.org

Then unpack it, cd into the directory, build and install:

  tar zxf swish-e-2.4.3.tar.gz
  cd swish-e-2.4.3
  ./configure
  make
  make install

You'll also need to build the Perl module, SWISH::API, which this
module uses:

  cd perl
  perl Makefile.PL
  make
  make install

=head2 Step 2: Setup a Config File

The first step to setting up a swish-e search engine is writing a
config file.  Swish-e supports a smorgasborg of configuration options
but just a few will get you started.

  # index all HTML files in /path/to/index
  IndexDir /path/to/index
  IndexOnly .html .htm
  IndexContents HTML2 .html .htm

  # C::A::Search needs a description, use the first 1,500 characters
  # of the body
  StoreDescription HTML2 <body> 1500

  # remove doc-root path so links will work on the results page
  ReplaceRules remove /path/to/index

Put the above in a file called F<swish-e.conf>.

NOTE: The above is a very simple swish-e.conf file. To bask in the
power and flexibility that is swish-e, please see the official documentation. 

=head2 Step 3: Run the Indexer

Now that you've got a basic configuration file you can index your site.  
The corresponding simple command is:

  $ swish-e -v 1 -c swish-e.conf -f /path/to/swishe-index

The last part is the place where Swish-e will write its index.  It
should be the name of a file in a directory writable by you and
readable by your CGI scripts.

Later you'll need to setup the indexer to run from cron, but for now
just run it once.

=head2 Step 4: Run a Test Search

Swish-e has a command-line interface to running searches which you can
use to confirm that your index is working.  For example, to search for
"foo":

  $ swish-e -w foo -f /path/to/swishe-index

If that works you should see some hits (assuming your site contains
"foo").

=head2 Step 5: Setup an Instance Script

Like all CGI::Application modules, CGI::Application::Search requires
an instance script.  Create a file called 'search.pl' or 'search.cgi'
in a place where your web server will execute it.  Put this in it:

  #!/usr/bin/perl -w
  use strict;
  use CGI::Application::Search;
  my $app = CGI::Application::Search->new(
    PARAMS => { SWISHE_INDEX => '/path/to/index' }
  );
  $app->run();

Now make it executable:

  $ chmod +x search.pl

=head2 Step 6: Test Your Instance Script

First, test it on the command-line:

  $ ./search.pl

That should show you the HTML for the search form with no results.
Now try it in your browser:

  http://yoursite.example.com/search.pl

If that doesn't work, check your error log.  Do not email me or the
CGI::Application mailing list until you check your error log.  Yes, I
mean you. Thanks.

=head2 Step 7: Rejoice

You've just completed the world's easiest search system setup!  Now go
setup that indexing cronjob.

=head1 RUN_MODES

This controller has two run modes. The start_mode is L<show_search>.

=over 8

=item * show_search

This run mode will show the simple search form. If there are any results they will also be displayed.
This is the default run mode and after a search is performed, this run mode is called to display
the results.

=item * perform_search

This run mode will actually use the SWISH::API module to perform the search on a given index. If
the L<HIGHLIGHT> option is set is will then use L<Text::Context> to obtain a suitable 
context of the search content for each result returned and highlight the text according to the
L<HIGHLIGHT_TAG>, L<HIGHLIGHT_CLASS> and L<HIGHLIGHT_COLORS> options.

=back

=head1 OTHER METHODS

Most of the time you will not need to call the methods that are implemented in this module. But
in cases where more customization is required than can be done in the templates, it might be prudent
to override or extend these methods in your derived class.

=head2 new()

We simply override and extend the L<CGI::Application> new() constructor
to also setup our callbacks.

=cut

sub new {
    my $class = shift;
    $class->add_callback(init => \&_my_init);
    my $self = $class->SUPER::new(@_);
    $class->add_callback(prerun => \&_my_prerun);
    return $self;
}

=head2 setup()

A simple no-op sub that you are free to override to run at setup time

=cut

# no-op to get around C::A setting the start_mode() in setup() and new().
sub setup { }


sub _my_init {
    my $self = shift;
    $self->start_mode('show_search');
    $self->run_modes(
        show_search    => 'show_search',
        perform_search => 'perform_search',
    );
}

sub _my_prerun {
    my $self = shift;

    # setup my defaults
    my %defaults = (
        SWISHE_INDEX        => catfile( 'data', 'swish-e.index' ),
        PER_PAGE            => 10,
        HIGHLIGHT           => 1,
        HIGHLIGHT_TAG       => q(strong),
        HIGHLIGHT_CLASS     => '',
        HIGHLIGHT_COLORS    => [],
        DESCRIPTION_LENGTH  => 250,
        TEMPLATE_TYPE       => 'HTMLTemplate',
        TEMPLATE_CONFIG     => undef,
    );
    foreach my $k (keys %defaults) {
        $self->param($k => $defaults{$k})
            unless( defined $self->param($k) );
    }

    # setup the template configs
    my %tmpl_config = (
        default_type                => $self->param('TEMPLATE_TYPE'),
        auto_add_template_extension => 0,
        include_paths               => [ $self->tmpl_path ],
        HTMLTemplate                => {
            global_var          => 1,
            loop_context_vars   => 1,
            die_on_bad_params   => 0,
        },
        HTMLTemplateExpr            => {
            global_var          => 1,
            loop_context_vars   => 1,
            die_on_bad_params   => 0,
        },
        TemplateToolkit             => {
            INCLUDE_PATH        => $self->tmpl_path(),
        },
    );
    
    # add any overriding TEMPLATE_CONFIG options
    if( $self->param('TEMPLATE_CONFIG') ) {
        $tmpl_config{$self->param('TEMPLATE_TYPE')} = {
            %{$tmpl_config{$self->param('TEMPLATE_TYPE')}},
            %{$self->param('TEMPLATE_CONFIG')},
        };
    }
    $self->template->config(%tmpl_config);
}

=head1 RUN MODES

=head2 generate_search_query($keywords)

This method is used to generate the query for swish-e from the $keywords (by default the 'keywords' 
CGI parameter), as well as any L<EXTRA_PROPERTIES> that are present. 

If you wish to generate your own search query then you should override this method. This is 
common if you need to have access/authorization control that will need to be taken into 
account for your search. (eg, anything under /protected can't be seen by someone not logged in).

Please see the swish-e documentation on the exact syntax for the query.

=cut 

sub generate_search_query {
    my $self = shift;
    my $keywords = shift;

    return undef unless( $keywords);

    #create a new swish-e search object
    my $query = $self->query->param('keywords');
    $query =~ s/=/\=/g;    #escape '=' just in case

    #add any EXTRA_PROPERTIES to the search
    if ( $self->param('EXTRA_PROPERTIES') ) {
        foreach my $prop ( @{$self->param('EXTRA_PROPERTIES')} ) {
            my $value = $self->query->param($prop);
            $query .= " and $prop=($value)" if $value;
        }
    }

    return $query;
}

=head1 CONFIGURATION

There are several configuration parameters that you can set at any 
time (using C<< param() >> in your cgiapp_init or cgiapp_prerun, 
or PARAMS hash in new()) before the run mode is called that will 
affect the search and display of the results. They are:

=head2 SWISHE_INDEX

This is the swishe index used for the searches. The default is 'data/swish-e.index'. You will probably
override this every time.

=head2 TEMPLATE

The name of the search interface template.  A default template is
included within the module which will be used if you don't specify
one.  A more elaborate example is included in the distribution under
the C<tmpl/> directory.

The following parameters are passed to your template regardless of it's 
C<< TEMPLATE_TYPE >>:

=head2 TEMPLATE_TYPE

This module uses L<CGI::Application::Plugin::AnyTemplate> to allow flexibility
in choosing which templating system to use for your search. This works especially
well when you are trying to integrate the Search into an existing app with an
existing templating structure.

This value is passed to the C<< $self->template->config() >> method as the 
C<< default_type >>. By default it is 'HTMLTemplate'. Please see 
L<CGI::Application::Plugin::AnyTemplate> for more options.

If you want more control of configuration for the template the it would probably
best be done by subclassing CGI::Application::Search and passing your desired
params to C<< $self->template->config >>.

=head2 PER_PAGE

How many search result items to display per page. The default is 10.

=head2 HIGHLIGHT

Boolean indicating whether or not we should highlight the description given to the
templates. The default is true.

=head2 HIGHLIGHT_TAG

The tag used to surround the highlighted context. The default is C<< strong >>.

=head2 HIGHLIGHT_CLASS

The class attribute of the HIGHLIGHT_TAG HTML tag. This is useful when you
want to dictacte the style through a CSS style sheet. If given, this value
will override that of HIGHLIGHT_COLORS. By default it is C<< '' >> (an empty string).

=head2 HIGHLIGHT_COLORS

This is an array ref of acceptable HTML colors. If provided, it will highlight each
matching word/phrase in an alternating style. For instance, if given 2 colors, every
other highlighted phrase would be a different color. By default it is an empty array.

=head2 EXTRA_PROPERTIES

This is an array ref of extra properties used in the search. By default, the module
will only use the value of the 'keywords' parameter coming in the CGI query.
If anything is provided as an extra property then it will be added to the 
query used in the search. 

An example: You have some of you pages designated into categories. You want the
user to have the option of narrowing his results by category. You add the word
'category' to the 'EXTRA_PROPERTIES' list and then you add a 'category' form element
that the user has the option of giving a value to your search form. If the user
gives that element a value, then it will be seen and applied to the search. This
will also only work if you have the 'category' element defined for your documents
(see L<SWISH-E Configuration> and 'MetaNames' in the swish-e.org SWISH-CONF
documentation).

The default is an empty list.

=head2 DESCRIPTION_LENGTH

This is the maximum length for the context (in chars) that is displayed for each
search result. The default is 250 characters.

=head2 DESCRIPTION_CONTEXT

This is the number of words on either side of the searched for words and phrases
(keywords) that will be displayed as part of the description. If this is 0, then
the entire description will be displayed. The default is 0. 

=cut

=head2 show_search()

This method will load the template pointed to by the C<TEMPLATE> param
(falling back on a default internal template if none is configured)
and display it to the user.  It will 'associate' this template with
$self so that any parameters in $self->param() are also accessible to
the template. It will also use L<HTML::FillInForm> to fill in the
search form with the previously selected parameters.

=cut 

sub show_search {
    my $self = shift;

    # load the template configured falling back to the default template
    my $tmpl;
    if ($self->param('TEMPLATE')) {
        $tmpl = $self->template->load($self->param('TEMPLATE'));
    } else {
        our $DEFAULT_TEMPLATE;
        require HTML::Template;
        $tmpl = HTML::Template->new(
            scalarref         => \$DEFAULT_TEMPLATE,
            global_vars       => 1,
            die_on_bad_params => 0,
        );
    }
    # give it all the stuff in $self
    my %tmpl_params = (
        self => $self
    );
    foreach my $param qw(
        searched elapsed_time keywords hits first_page 
        last_page prev_page next_page pages start_num 
        stop_num total_entries
    ) {
        $tmpl->param( $param => $self->param($param) )
            if( $self->param($param) );
    }
    $tmpl->param(%tmpl_params);
    my $output = $tmpl->output();

    my $filler = HTML::FillInForm->new();
    return $filler->fill( 
        scalarref   => ref( $output ) ? $output : \$output,
        fobject     => $self->query, 
    );
}

=head2 perform_search()

This is where the meat of the searching is performed. We create a L<SWISH::API>
object on the L<SWISHE_INDEX> and create the query for the search based on the
value of the 'keywords' parameter in CGI and any other L<EXTRA_PARAMETERS>. The search
is executed and if L<HIGHLIGHT> is true we will use Text::Context to highlight
it and then format the results data only showing L<PER_PAGE> number of elements per page
(if L<PER_PAGE> is true). We will also show a list of pages that can be selected for navigating
through the results. Then we will return to the L<show_search()> method for displaying.

=cut

sub perform_search {
    my $self = shift;
    my $query = $self->query;

    #if we have any keywords
    my $keywords = $self->query->param('keywords');
    if ( defined $keywords && !$self->param('results') ) {
        my $index = $self->param('SWISHE_INDEX');
        # make sure the index exists and is readable
        croak "Index file $index does not exist!"
            unless( -e $index );

        $self->param( 'searched' => 1 );
        my $start_time = Time::HiRes::time();

        #create my swish-e object
        my $swish = SWISH::API->new( $index );
        croak "Problem reading $index : " . $swish->ErrorString
            if ( $swish->Error );

        my $search_query = $self->generate_search_query($keywords);
        # if we got one
        if( defined $search_query ) {

            my $results = $swish->Query($search_query);
            if ( $swish->Error ) {
                carp "Unable to create query: " .  $swish->ErrorString
                    if( $DEBUG );
                return $self->show_search();
            }

            $self->param( 'elapsed_time' => format_number( Time::HiRes::time - $start_time, 3, 1 ) );

            #create my pager and then go to the start page
            $self->_get_paging_vars($results);
            my @words = $self->_get_search_terms( $swish, $results, $keywords );
            $self->param( 'hits' => $self->_process_results( $swish, $results, $search_query ) );
        } else {
            return $self->show_search();
        }
    }

    # if there are any extra properties used in the search, make them available to
    # the templates with the value in the query object
    foreach my $prop ( @{$self->param('EXTRA_PROPERTIES') || []} ) {
        $self->param($prop => $query->param($prop));
    } 
    $self->param( 'keywords' => $keywords );
    return $self->show_search();
}


#-------------------------PRIVATE METHODS-----------------------
sub _process_results {
    my ( $self, $swish, $results, $search_query ) = @_;

    # now let's go through the results and build our loop
    my @result_loop = ();
    my $count       = 0;

    # while we still have more results
    while ( my $current = $results->NextResult ) {
        my %tmp = (
          reccount      => $current->Property('swishreccount'),
          rank          => $current->Property('swishrank'),
          title         => $current->Property('swishtitle'),
          path          => $current->Property('swishdocpath'),
          size          => format_bytes( $current->Property('swishdocsize') ),
          description   => $current->Property('swishdescription') || '',
          last_modified => localtime($current->Property('swishlastmodified'))->strftime('%B %d, %Y'),
        );

        # now add any EXTRA_PROPERTIES that we want to show
        if ( $self->param('EXTRA_PROPERTIES') ) {
            $tmp{$_} = eval { $current->Property($_) }
              foreach ( @{ $self->param('EXTRA_PROPERTIES') } );
        }

        my $description = $tmp{description};
        if( $description ) {
            # if we want to zero in on the context
            if( $self->param('DESCRIPTION_CONTEXT') ) {
                # get the keywords from the swish search
                my @keywords = ();
                foreach my $kw ($results->ParsedWords($self->param('SWISHE_INDEX')) ) {
                    # remove boolean operators 'and', 'or' and 'not'
                    my $lc_kw = lc($kw);
                    if( $lc_kw ne 'and' && $lc_kw ne 'or' && $lc_kw ne 'not' ) {
                        push(@keywords, $kw);
                    }
                }
                # now get the context
                my $context = Text::Context->new(
                    $description,
                    @keywords,
                );
                $description = $context->as_text();
            }

            # if we want to highlight the description 
            if ( $self->param('HIGHLIGHT') ) {
                my $hi_liter = HTML::HiLiter->new(
                    HiTag   => $self->param('HIGHLIGHT_TAG'),
                    HiClass => $self->param('HIGHLIGHT_CLASS'),
                    Colors  => $self->param('HIGHLIGHT_COLORS'),
                    SWISH   => $swish,
                    Parser  => 0,
                );
                $hi_liter->Queries($search_query);
                $hi_liter->Inline();
                $description = $hi_liter->plaintext($description);
            }

            # now make sure it's the appropriate length
            $tmp{description} = substr( $description, 0, $self->param('DESCRIPTION_LENGTH') );
        }
        push( @result_loop, \%tmp );

        # only go as far as the number per page
        ++$count;
        last if ( $count == $self->param('PER_PAGE') );
    }
    return \@result_loop;
}

sub _get_search_terms {
    my ( $self, $swish, $results, $keywords ) = @_;
    my @phrases = ();
    my %terms      = ();

    while ( $keywords =~ /\G\s*"([^"]+)"/g ) {
        push( @phrases, $1 );
    }
    
    $keywords =~ s/"[^"]+?"//g;

    # remove stop words from highlighting
    # for some reason swish-e doesn't remove boolean operators as stop words... which
    # is probably good so that they actually get used in the searches, but still...
    my %stop_words = ();
    foreach my $word ($results->RemovedStopwords( $self->param('SWISHE_INDEX') ), 'and', 'or', 'not') {
        $stop_words{$word} = 1;
    }
    $stop_words{$_} = 1 foreach qw(and or not);

    for my $word ( split( /\s+/, $keywords ) ) {
        if ($word) {
            next if $stop_words{$word};
            $terms{$word} = 1;
        }
    }

    #now look at the stems of these words
    $terms{ $swish->StemWord($_) } = 1 foreach ( keys %terms );
    return keys %terms, @phrases;
}

#create a loop of pages with the first page, at most five pages before
#the current page, the current page, at most five pages after the current page
#and then the last page
sub _get_paging_vars {
    my ( $self, $results ) = @_;
    my @pages = ();

    #create my pager from the 'page' parameter in CGI or just use the first page
    my $page_num = $self->query->param('page') || 1;
    my $pager =
      Data::Page->new( $results->Hits, $self->param('PER_PAGE'), $page_num );

    #go to the result that we want to look at first
    $results->SeekResult( $pager->first - 1 );

    #now let's create the paging summary vars
    $self->param( 'total_entries' => $pager->total_entries );
    $self->param( 'start_num'     => $pager->first );
    $self->param( 'stop_num'      => $pager->last );
    $self->param( 'next_page'     => $pager->next_page );
    $self->param( 'prev_page'     => $pager->previous_page );
    $self->param( 'first_page'    => $pager->first_page eq $page_num );
    $self->param( 'last_page'     => $pager->last_page eq $page_num );

    foreach ( ( $page_num - 5 ) .. ( $page_num + 5 ) ) {

        #if we are in a real range
        if ( ( $_ > 0 )
            && (
                $_ <= ceil( $pager->total_entries / $self->param('PER_PAGE') ) )
          )
        {
            my %hash = ( page_num => $_, current => $_ eq $page_num );
            push( @pages, \%hash );
        }
    }
    $self->param( pages => \@pages ) if ($#pages);
}

# default template to use if the user doesn't specify one
our $DEFAULT_TEMPLATE = <<END;
<html>
<body>
<h2>Search<tmpl_if searched> Results</tmpl_if></h2>
<form><input name="rm" value="perform_search" type="hidden">

<p><input id="fi_keywords" name="keywords" value="" size="50"> <input value="Search" type="submit"></p>

<tmpl_if searched>
  <tmpl_if hits>
    (Elapsed Time: <tmpl_var escape=html elapsed_time>s)
     <tmpl_if pages>
       <p> Pages: 
       <tmpl_unless first_page>
             <a href="?rm=perform_search&amp;keywords=<tmpl_var escape=url keywords>&amp;page=<tmpl_var escape=url prev_page>"></tmpl_unless>&laquo;Prev<tmpl_unless first_page></a>
       </tmpl_unless>
       <tmpl_loop pages>
         <tmpl_if current>
           <tmpl_var escape=html page_num>
         <tmpl_else>
           <a href="?rm=perform_search&amp;keywords=<tmpl_var escape=url keywords>&amp;page=<tmpl_var escape=url page_num>"><tmpl_var escape=html page_num></a>
         </tmpl_if>
       </tmpl_loop>
       <tmpl_unless last_page><a href="?rm=perform_search&amp;keywords=<tmpl_var escape=url keywords>&amp;page=<tmpl_var escape=url next_page>"></tmpl_unless>Next&raquo;<tmpl_unless last_page></a></tmpl_unless>
       </p>
     </tmpl_if>

    <p>Results: <tmpl_var escape=html start_num> to <tmpl_var escape=html stop_num> of <tmpl_var escape=html total_entries></p>

    <dl>
    <tmpl_loop hits>
      <dt>
      <a href="<tmpl_var path>"><tmpl_if title><tmpl_var escape=html title><tmpl_else><tmpl_var escape=html path></tmpl_if></a>
      </dt>
      <dd><tmpl_var escape=html last_modified> - <tmpl_var escape=html size></dd>
      <dd><p><tmpl_var description></p></dd>
    </tmpl_loop>
    </dl>
</tmpl_if></tmpl_if>

<tmpl_if searched><tmpl_unless hits><p>No Results Found.</p></tmpl_unless></tmpl_if>
</body>
</html>

END

1;

__END__

=head1 TEMPLATES

A default template is provided inside the module which will be used if
you don't specify a template.  This is useful for testing out the
module and may also serve as a base for your template development.

Two more elaborate templates are provided as examples of how to use
this module in the C<tmpl/> directory. Please feel free to copy and
change them in what ever way you see fit. To help in giving you more
information to display (or not display, depending on your preference)
the following variables are available for your templates:

=head2 Global Tmpl Vars

These variables are available throughout the templates and contain information related to
the search as a whole:

=over 8

=item * searched

A boolean indicating whether or not a search was performed.

=item * keywords

The exact string that was recieved by the server from the input named 'keywords'

=item * elapsed_time

A string representing the number of seconds that the search took. This will
be a floating point number with a precision of 3.

=item * hits

This is an array of hashs (TMPL_LOOP in H::T) that contains one entry for
each result returned (for the current page). Each entry contains the following keys:

=over 8

=item reccount 

The C<swishreccount> property of the results as indexed by SWISH-E

=item rank

The rank to the result as given by SWISH-E (the C<swishrank> property)

=item title

The C<swishtitle> property of the results as indexed by SWISH-E

=item path

The C<swishdocpath> property of the results as indexed by SWISH-E

=item last_modified

The C<swishlastmodified> property of the results as indexed by SWISH-E
and then formatted using Time::Piece::strftime with a format string of
C<%B %d, %Y>.

=item size

The C<swishdocsize> property of the results as indexed by SWISH-E and
then formatted with Number::Format::format_bytes

=item description

The C<swishdescription> property of the results as indexed by SWISH-E. If
L<HIGHLIGHT> is true, then this description will also have search
terms highlighted and will only be, at most, L<DESCRIPTION_LENGTH> characters
long.

=back

=item * pages

This is an array of hashes (TMPL_LOOP in H::T) that contains paging information 
for the results. It contains the following keys:

=over 8

=item current

A boolean indicating whether or not this iteration is the current page or not.

=item page_num

The integer number of the page.

=back

=item * first_page

This is a boolean indicating whether or not this page of the results is the first or not.

=item * last_page

This is a boolean indicating whether or not this page of the results is the last or not.

=item * prev_page

The integer number of the previous page. Will be 0 if there is no previous page.

=item * next_page

The integer number of the next page. Will be 0 if there is no next page.

=item * start_num

This is the number of the first result on the current page

=item * stop_num

This is the number of the last result on the current page

=item * total_entries

The total number of results in their search, not the total number shown on the page.

=back

=head1 OTHER NOTES

=over

=item *

If at any time prior to the execution of the 'perform_search' run mode you set the 
C<$self-<gt>param('results')> parameter a search will not be performed, but rather
and empty set of results is returned. This is helpful when you decide in either
cgiapp_init or cgiapp_prerun that this user does not have permissions to perform the desired
search.

=item *

You must use the StoreDescription setting in your Swish-e
configuration file.  If you don't you'll get an error when
C::A::Search tries to retrieve a description for each hit.

=back

=head1 AUTHOR

Michael Peters <mpeters@plusthree.com>

Thanks to Plus Three, LP (http://www.plusthree.com) for sponsoring my work on this module.

=head1 CONTRIBUTORS

Sam Tregar <sam@tregar.com>



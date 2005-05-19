package CGI::Application::Search;
use base 'CGI::Application';
use strict;
use warnings;
use Text::Context;
use SWISH::API;
use Data::Page;
use File::Spec::Functions qw(catfile);
use Number::Format qw(format_bytes format_number);
use HTML::FillInForm;
use Time::HiRes;
use Time::Piece;
use POSIX;

$CGI::Application::Search::VERSION = '0.01';

=head1 NAME 

CGI::Application::Search - Base class for CGI::App Swish-e site engines

=head1 SYNOPSIS

	package My::Search;
	use base 'CGI::Application::Search';
	
	sub cgiapp_init {
	  my $self = shift;
	  $self->param('SWISHE-INDEX' =>'my-swishe.index');
	}

	#let the user turn context highlighting off
	sub cgiapp_prerun {
	  my $self = shift;
	  $self->param('HIGHLIGHT_CONTEXT' => 0)
		if($self->query->param('highlight_off'));
	}

	1;

=head1 DESCRIPTION

A L<CGI::Application> based control module that uses Swish-e API in perl (L<http://swish-e.org>) to
to perform searches on a swish-e index of documents. It uses L<HTML::Template> to display the search
form and the results. It uses two templates ('search_results.tmpl' and 'results_header.tmpl') and
any customization of the look and feel should happen in the templates. For the majority of the cases
you should simply be able to adjust the style section found in the 'search_results.tmpl' template.

This controller has two run modes. The start_mode is L<show_search>.

=over 8

=item * show_search

This run mode will show the simple search form. If there are any results they will also be displayed.
This is the default run mode and after a search is performed, this run mode is called to display
the results.

=item * perform_search

This run mode will actually use the SWISH::API module to perform the search on a given index. If
the L<HIGHLIGHT_CONTEXT> option is set is will then use L<Text::Context> to obtain a suitable 
context of the search content for each result returned and highlight the text according to the
L<HIGHLIGHT_START> and L<HIGHLIGHT_STOP> options.

=back


=head1 METHODS

Most of the time you will not need to call the methods that are implemented in this module. But
in cases where more customization is required than can be done in the templates, it might be prudent
to override or extend these methods in your derived class.

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
}

=head2 setup()

This method set's up our application with two run modes and sets the L<show_search> method
as the default run mode. It also sets the defaults for several internal parameters that
this module uses. These parameters can be reset at any time (in your cgiapp_init or cgiapp_prerun,
or PARAMS hash in new()).

Here is a list of these parameters, what each does, and what the default value is

=over 8

=item * SWISHE_INDEX

This is the swishe index used for the searches. The default is 'data/swish-e.index'. You will probably
override this every time.

=item * PER_PAGE

How many search result items to display per page. The default is 10.

=item * HIGHLIGHT_CONTEXT

Boolean indicating whether or not we should highlight the context. The default is true.

=item * HIGHLIGHT_START

The text to be prepended to a word being highlighted. If this value is false
and L<HIGHTLIGHT_CONTEXT> is true then it will use the default provided by
L<Text::Context>. The default text is C<<lt>strong<gt>>.

=item * HIGHLIGHT_STOP

The text to be appended to a word being highlighted. If this value is false
and L<HIGHTLIGHT_CONTEXT> is true then it will use the default provided by
L<Text::Context>. The default text is C<<lt>/strong<gt>>.

=item * EXTRA_PROPERTIES

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

=item * CONTEXT_LENGTH

This is the maximum length for the context (in chars) that is displayed for each
search result. The default is 250 characters.

=item * START_MODE

This contains the name of a run mode method that will be used as the start method
instead of L<show_search>. If you want to change this parameter it must be done prior
to running the 'setup()' sub (in PARAMS hash to new() or in cgiapp_init()).

=back

=cut

sub setup {
    my $self = shift;
    $self->start_mode( $self->param('START_MODE') || 'show_search' );
    $self->mode_param('mode');
    $self->run_modes(
        show_search    => 'show_search',
        perform_search => 'perform_search',
    );

    $self->param( SWISHE_INDEX => catfile( 'data', 'swish-e.index' ) )
      if ( !defined $self->param('SWISHE_INDEX') );
    $self->param( PER_PAGE => 10 )
      if ( !defined $self->param('PER_PAGE') );
    $self->param( HIGHLIGHT_CONTEXT => 1 )
      if ( !defined $self->param('HIGHLIGHT_CONTEXT') );
    $self->param( HIGHLIGHT_START => q(<strong>) )
      if ( !$self->param('HIGHLIGHT_START') );
    $self->param( HIGHLIGHT_STOP => q(</strong>) )
      if ( !$self->param('HIGHLIGHT_STOP') );
    $self->param( CONTEXT_LENGTH => 250 )
      if ( !defined $self->param('CONTEXT_LENGTH') );
}

=head1 RUN MODES

=head2 show_search()

This method will load the 'Search/search_results.tmpl' L<HTML::Template> and display it to the user.
It will 'associate' this template with $self so that any parameters in $self->param() are also 
accessible to the template. It will also use L<HTML::FillInForm> to fill in the search form
with the previously selected parameters.

=cut 

sub show_search {
    my $self = shift;

    my $tmpl = $self->load_tmpl(
        'Search/search_results.tmpl',
        associate         => $self,
        global_vars       => 1,
        cache             => 0,
        die_on_bad_params => 0,
    );

    my $filler = HTML::FillInForm->new();
    my $output = $tmpl->output();
    return $filler->fill( scalarref => \$output, fobject => $self->query );
}

=head2 perform_search()

This is where the meat of the searching is performed. We create a L<SWISH::API>
object on the L<SWISHE_INDEX> and create the query for the search based on the
value of the 'keywords' parameter in CGI and any other L<EXTRA_PARAMETERS>. The search
is executed and if L<HIGHLIGHT_CONTEXT> is true we will use Text::Context to highlight
it and then format the results data only showing L<PER_PAGE> number of elements per page
(if L<PER_PAGE> is true). We will also show a list of pages that can be selected for navigating
through the results. Then we will return to the L<show_search()> method for displaying.

=cut

sub perform_search {
    my $self = shift;

    #if we have any keywords
    my $keywords = $self->query->param('keywords');

    if ( !$self->param('results') ) {
        $self->param( 'searched' => 1 );
        my $start_time = Time::HiRes::time();

        #create my swish-e object
        my $swish = SWISH::API->new( $self->param('SWISHE_INDEX') );
        die $swish->ErrorString if ( $swish->Error );

        #get the query
        my $query = $self->generate_search_query($keywords);
        return $self->show_search() if not defined $query;

        #if we already have results (usually empty results)
        my $results = $swish->Query($query);
        if ( $swish->Error ) {
            warn "Unable to create query: " . $swish->ErrorString ;
            return $self->show_search();
        }

        $self->param( 'elapsed_time' => format_number( Time::HiRes::time - $start_time, 3, 1 ) );

        #create my pager and then go to the start page
        $self->_get_paging_vars($results);
        my @words = $self->_get_search_terms( $swish, $results, $keywords );
        $self->param( 'hits' => $self->_process_results( $results, @words ) );
    }

    # if there are any extra properties used in the search, make them available to
    # the templates with the value in the query object
    my $query = $self->query;
    foreach my $prop ( @{$self->param('EXTRA_PROPERTIES')} ) {
        $self->param($prop => $query->param($prop));
    } 
    $self->param( 'keywords' => $keywords );
    return $self->show_search();
}


#-------------------------PRIVATE METHODS-----------------------
sub _process_results {
    my ( $self, $results, @keywords ) = @_;

    #now let's go through the results and build our loop
    my @result_loop = ();
    my $count       = 0;

    #while we still have more results
    while ( my $current = $results->NextResult ) {
        my %tmp = (
          hit_reccount => $current->Property('swishreccount'),
          hit_rank     => $current->Property('swishrank'),
          hit_title    => $current->Property('swishtitle'),
          hit_path     => $current->Property('swishdocpath'),
          hit_size     => format_bytes( $current->Property('swishdocsize') ),
          hit_description   => $current->Property('swishdescription'),
          hit_last_modified => localtime($current->Property('swishlastmodified'))->strftime('%B %d, %Y'),
        );

        #now add any EXTRA_PROPERTIES that we want to show
        if ( $self->param('EXTRA_PROPERTIES') ) {
            $tmp{$_} = eval { $current->Property($_) }
              foreach ( @{ $self->param('EXTRA_PROPERTIES') } );
        }

        #if we want to highlight the description
        if ( $self->param('HIGHLIGHT_CONTEXT') && scalar(@keywords)) {
            my $content = $tmp{hit_description};

            #now get the context
            my $context = Text::Context->new( $content, @keywords );
            $context = $context->as_html(
                start   => $self->param('HIGHLIGHT_START'),
                end     => $self->param('HIGHLIGHT_STOP'),
                max_len => $self->param('CONTEXT_LENGTH'),
            );
            $tmp{hit_description} = $context
              || substr( $content, 0, $self->param('CONTEXT_LENGTH') );
        }

        elsif( $tmp{hit_description} ) {
            #else we aren't highlighting, but we still want the content to be the right length
            $tmp{hit_description} = substr( $tmp{hit_description}, 0, $self->param('CONTEXT_LENGTH') );
        }
        push( @result_loop, \%tmp );

        #only go as far as the number per page
        ++$count;
        last if ( $count == $self->param('PER_PAGE') );
    }
    return \@result_loop;
}

sub _get_search_terms {
    my ( $self, $swish, $results, $keywords ) = @_;

    if($keywords) {
        my @phrases = ();

        while ( $keywords =~ /\G\s*"([^"]+)"/g ) {
            push( @phrases, $1 );
        }
    
        $keywords =~ s/"[^"]+?"//g;

        my %terms      = ();
        my %stop_words = map { $_ => 1 } 
                        $results->RemovedStopwords( $self->param('SWISHE_INDEX') );
        #for some reason swish-e doesn't remove boolean operators as stop words... which
        #is probably good so that they actually get used in the searches, but still...
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
    } else {
        return ()
    };
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

1;

__END__

=head1 TEMPLATES

Two templates are provided as examples of how to use this module. Please feel free
to copy and change them in what ever way you see fit. To help in giving you more information
to display (or not display, depending on your preference) the following variables are available
for your templates:

=head2 Global Tmpl Vars

These variables are available throughout the templates and contain information related to
the search as a whole:

=over 8

=item * searched

A boolean indicating whether or not a search was performed.

=item * keywords

The exact string that was returned to the server from the input named 'keywords'

=item * elapsed_time

A string representing the number of seconds that the search took. This will
be a floating point number with a precision of 3.

=item * hits

This is the TMPL_LOOP that contains the actuall results from the search.

=item * pages

This is the TMPL_LOOP that contains paging information for the results

=item * first_page

This is a boolean indicating whether or not this page of the results is the first or not.

=item * last_page

This is a boolean indicating whether or not this page of the results is the last or not.

=item * start_num

This is the number of the first result on the current page

=item * stop_num

This is the number of the last result on the current page

=item * total_entries

The total number of results in their search, not the total number shown on the page.

=back

=head2 HITS TMPL_LOOP Vars

These variables are available only inside of the TMPL_LOOP named "HITS".

=over 8

=item * hit_reccount

The C<swishreccount> property of the results as indexed by SWISH-E

=item * hit_rank

The rank to the result as given by SWISH-E (the C<swishrank> property)

=item * hit_title

The C<swishtitle> property of the results as indexed by SWISH-E

=item * hit_path

The C<swishdocpath> property of the results as indexed by SWISH-E

=item * hit_size

The C<swishdocsize> property of the results as indexed by SWISH-E and
then formatted with Number::Format::format_bytes

=item * hit_description

The C<swishdescription> property of the results as indexed by SWISH-E. If
L<HIGHLIGHT_CONTEXT> is true, then this description will also have search
terms highlighted and will only be, at most, L<CONTEXT_LENGTH> characters
long.

=item * hit_last_modified

The C<swishlastmodified> property of the results as indexed by SWISH-E
and then formatted using Time::Piece::strftime with a format string of
C<%B %d, %Y>.

=back

=head2 PAGES TMPL_LOOP Vars

=over 8

=item *

=back

=head1 OTHER NOTES

If at any time prior to the execution of the 'perform_search' run mode you set the 
C<$self-<gt>param('results')> parameter a search will not be performed, but rather
and empty set of results is returned. This is helpful when you decide in either
cgiapp_init or cgiapp_prerun that this user does not have permissions to perform the desired
search.

=head1 AUTHOR

Michael Peters <mpeters@plusthree.com>

Thanks to Plus Three, LP (http://www.plusthree.com) for sponsoring my work on this module.



package MySearch;
use base 'CGI::Application::Search';

sub cgiapp_init {
    my $self = shift;
    my $query = $self->query;

    # allow the extra property 'extra'
    $self->param(
        EXTRA_PROPERTIES => [qw(extra)],
    );

    # let the user turn context highlighting on
    # defaulting to off
    $self->param('HIGHLIGHT' => ( $query->param('hl') || 0 ));

    # let the user set the per page
    $self->param('PER_PAGE' => $query->param('per_page'));

    # let the user pick an index (not really a good idea in production)
    my $index = $query->param('index') || 't/conf/swish-e.index';
    $self->param(SWISHE_INDEX => $index);

    # let the user turn on context
    $self->param(DESCRIPTION_CONTEXT => ($query->param('context') || 0));
}

1;

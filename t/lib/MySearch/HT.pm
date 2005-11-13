package MySearch::HT;
use base 'MySearch';

sub cgiapp_prerun {
    my $self = shift;
    $self->param(
        TEMPLATE        => 'templates/search_results.tmpl',
        TEMPLATE_TYPE   => 'HTMLTemplate'
    );
}


1;

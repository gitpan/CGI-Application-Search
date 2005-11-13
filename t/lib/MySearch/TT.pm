package MySearch::TT;
use base 'MySearch';

sub cgiapp_init {
    my $self = shift;
    $self->SUPER::cgiapp_init(@_);
    $self->param(
        TEMPLATE            => 'templates/search_results.tt',
        TEMPLATE_TYPE       => 'TemplateToolkit',
        TEMPLATE_CONFIG     => {
            DEBUG   => 1,
        },
    );
    $self->tmpl_path('.');
}


1;

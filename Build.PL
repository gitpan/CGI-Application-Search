use Module::Build;
my $build = Module::Build->new (
        module_name => 'CGI::Application::Search',
        license => 'perl',
        requires => {
            'perl'                                  => '5.6.1',
            'CGI::Application'                      => '3.2',
            'CGI::Application::Plugin::AnyTemplate' => 0,
            'Text::Context'                         => '3.5',
            'Text::Context::EitherSide'             => '1.1',
            'SWISH::API'                            => '0.01',
            'Data::Page'                            => '1.0',
            'File::Spec::Functions'                 => '0',
            'Number::Format'                        => '0',
            'HTML::FillInForm'                      => '1.04',
            'Time::HiRes'                           => '0',
            'Time::Piece'                           => '0',
            'POSIX'                                 => '0',
        },
        create_makefile_pl => 'traditional',
   );
$build->create_build_script;

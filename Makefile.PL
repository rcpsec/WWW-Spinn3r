use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR       => 'Vipul Ved Prakash <opensource@slaant.com>',
    NAME	     => 'WWW::Spinn3r',
    VERSION_FROM => 'lib/WWW/Spinn3r.pm',
    ABSTRACT_FROM => 'lib/WWW/Spinn3r.pm',
    PREREQ_PM    => { 
        'XML::RSS'          => 0,
        'DateTime'          => 0,
        'Class::Accessor'   =>0,
        'LWP::UserAgent'    =>
    },
    dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'HTML::Prototype',
    'VERSION_FROM' => 'Prototype.pm',
    'PREREQ_PM'    => { Class::Accessor::Fast => 0 }
);

use ExtUtils::MakeMaker;

WriteMakefile(
   'NAME'         => 'PHP::Session::DBI',
   'VERSION_FROM' => 'lib/PHP/Session/DBI.pm',
   'PREREQ_PM'    => {
      'PHP::Session' => '0.26',
      'DBI'          => 0,
      #'DBD::mysql'   => 0,
   },
   ($] >= 5.005 ? (
   AUTHOR   => 'Burak Gursoy <burak@cpan.org>',
   ABSTRACT => 'Interface to PHP DataBase Sessions',
   ) : ()),
   PL_FILES => {},
);

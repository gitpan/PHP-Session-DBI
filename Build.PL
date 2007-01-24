use strict;

eval { require Module::Build; };

if($@) {
   warn "Module::Build failed: $@\n";
   warn "Falling back to MakeMaker ...\n";
   do 'Makefile.PL';
}
else {
   Module::Build->new(
      module_name => 'PHP::Session::DBI',
      license     => 'perl',
      requires    => {
         'PHP::Session' => '0.26',
         'DBI'          => 0,
      },
      recommends  => {
         'DBD::mysql'   => 0,
      },
      sign        => 0,
      dist_author => 'Burak Gursoy <burak@cpan.org>',
   )->create_build_script;
}

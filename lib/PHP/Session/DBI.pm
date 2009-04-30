package PHP::Session::DBI;
use strict;
use vars qw($VERSION);
use base qw(PHP::Session);
use Carp qw(croak);

$VERSION = '0.23';

sub new {
   my($class, $sid, $opt) = @_;
   croak "OPTIONS must be present and must be a HASHref" if ! _ishash($opt);
   my $db_handle = delete($opt->{db_handle}) || croak "db_handle option is missing";
   my $db_table  = delete($opt->{db_table})  || croak "db_table option is missing";
   my $db_schema = delete($opt->{db_schema}) || croak "db_schema option is missing";
   my $self      = $class->SUPER::new($sid, $opt);
   # inject our keys into session object
   $self->{db_handle}    = $db_handle;
   $self->{db_table}     = $db_table;
   $self->{db_schema}    = $db_schema;
   $self->{_db_create}   = 0;
   $self->{_last_update} = 0;
   $self->_parse_session_real;
   return $self;
}

sub dbh { shift->{db_handle} }

sub save {
   my $self    = shift;
   my $encoded = $self->encode($self->{_data}) || '';
   my %schema  = $self->_db_schema;
   my($SQL, @params);
   if ($self->{_db_create}) {
      $SQL = qq(
         INSERT INTO $self->{db_table}
                ( $schema{date}, $schema{data}, $schema{id} )
         VALUES (             ?,             ?,           ? )
      );
      @params = (time, $encoded, $self->id);
   }
   else {
      if ($schema{update_date}) {
         $SQL = qq(
            UPDATE $self->{db_table}
            SET    $schema{date} = ?,
                   $schema{data} = ?
            WHERE  $schema{id}   = ?
         );
         @params = (time, $encoded, $self->id);
      }
      else {
         $SQL = qq(
            UPDATE $self->{db_table}
            SET    $schema{data} = ?
            WHERE  $schema{id}   = ?
         );
         @params = ($encoded, $self->id);
      }
   }
   $self->dbh->do( $SQL, undef, @params )
      or croak( "Can't update database: " . $self->dbh->errstr );
   $self->{_changed} = 0; # init
}

sub destroy {
   my $self   = shift;
   my %schema = $self->_db_schema;
   my $SQL    = qq(DELETE FROM $self->{db_table} WHERE $schema{id} = ?);
   $self->dbh->do( $SQL, undef, $self->id )
      || croak("Can't delete session from database: " . $self->dbh->errstr);
}

# private methods

sub _ishash { $_[0] && ref($_[0]) && ref($_[0]) eq 'HASH' }

sub _db_schema {
   my $self = shift;
   my $test = $self->{db_schema} || croak("Database session are enabled, but db_schema is missing");
   croak "db_schema must be a HASHref" if ! _ishash($test);
   $test->{id}   || croak("id parameter in db_schema is missing");
   $test->{data} || croak("data parameter in db_schema is missing");
   $test->{date} || croak("date parameter in db_schema is missing");
   return %{ $test };
}

# fake method for PHP::Session::new() workaround
sub _parse_session {}

sub _parse_session_real {
   my $self = shift;
   my $cont = $self->_slurp_content;
   if (!$cont && !$self->{create}) {
      $self->{_db_create} = 0;
      my $error = $self->dbh ? $self->dbh->errstr : '';
      my $id    = $self->id || "<unknown sid>";
      # $cont might be empty string, if this is a fresh session
      # in that case, _last_update must have a value
      if (! $self->{_last_update}) {
         croak("DBH($id)", ": ", $error || "entry does not exist in the database");
      }
   }
   $self->{_changed}++ if !$cont;
   $self->{_data} = $self->decode($cont);
}

sub _slurp_content {
   my $self   = shift;
   my $sid    = $self->id || return;
   my %schema = $self->_db_schema;
   my $SQL    = qq(SELECT * FROM $self->{db_table} WHERE $schema{id} = ?);
   my $sth    = $self->dbh->prepare($SQL) || croak("sth error: "         . $self->dbh->errstr);
      $sth->execute( $sid )               || croak("sth execute error: " . $self->dbh->errstr);
   # SID does not exist
   my $session = $sth->fetchrow_hashref || do { $self->{_db_create}++; return };
      $sth->finish;
      $self->{_last_update} = $session->{ $schema{date} };
   return $session->{ $schema{data} };
}

sub DESTROY {
   my $self = shift;
   $self->SUPER::DESTROY;
   delete $self->{db_handle};
   return;
}

1;

__END__

=head1 NAME

PHP::Session::DBI - Interface to PHP DataBase Sessions

=head1 SYNOPSIS

   use DBI;
   use PHP::Session::DBI;

   my $dbh = DBI->connect($DSN, $user, $password);
   my $opt = {
      db_handle => $dbh,
      db_table  => 'sessions',
      db_schema => {
         # session table schema for SMF
         id   => 'session_id',
         data => 'data',
         date => 'last_update',
      }
   };
   my $session = PHP::Session::DBI->new($sid, $opt);
   
   # the rest is regular PHP::Session interface
   
   # session id
   my $id = $session->id;
   
   # get/set session data
   my $foo = $session->get('foo');
   $session->set(bar => $bar);
   
   # remove session data
   $session->unregister('foo');
   
   # remove all session data
   $session->unset;
   
   # check if data is registered
   $session->is_registered('bar');
   
   # save session data
   $session->save;
   
   # destroy session
   $session->destroy;

=head1 DESCRIPTION

This document describes version C<0.23> of C<PHP::Session::DBI>
released on C<30 April 2009>.

PHP::Session::DBI provides a way to read / write PHP database sessions, with
which you can make your Perl application session shared with PHP.
This module is a C<PHP::Session> subclass, not a re-implementation of the 
whole interface.

=head1 METHODS

See L<PHP::Session> for other methods and extra documentation.

=head2 new

Usage:

   my $session = PHP::Session->new($SID, $OPTIONS);

First parameter is the session ID. It can be fetched from a cookie
or a get request. C<new> takes some options as hashref as the second
parameter. See L<PHP::Session> for other options. This documentation 
only discusses C<PHP::Session::DBI> related options.

=head3 db_handle

See L</DATABASE SESSIONS>.

=head3 db_table

See L</DATABASE SESSIONS>.

=head3 db_schema

See L</DATABASE SESSIONS>.

=head2 dbh

Returns the database handle.

=head2 save

See L<PHP::Session>.

=head2 destroy

See L<PHP::Session>.

=head1 DATABASE SESSIONS

PHP sessions can be stored in a RDBMS using C<session_set_save_handler()>
function. File sessions considered unsecure under shared environments.
So, database sessions start to gain popularity. An example usage for database 
sessions can be the popular SMF (L<http://www.simplemachines.org>) software.
Note that, this module I<might> not be compatible with some arbitrary 
session implementations.

You can enable three special options to C<new> to access database 
sessions: C<db_handle>, C<db_table> and C<db_schema>. But note that,
you must first install L<DBI> and the related C<DBD> 
(i.e.: L<DBD::mysql> for MySQL) to communicate with the database server. 

=head2 db_handle

C<db_handle> is the L<DBI> database handle. C<PHP::Session::DBI>
currently does not implement a way to create it's own connection
and it needs an I<already started> connection and a database handle.

=head2 db_table

C<db_table> is the table name of the sessions table.

=head2 db_schema

C<db_schema> describes the session table structure to C<PHP::Session::DBI>.
Without C<db_schema>, the module can not interface with the sessions table.
C<db_schema> is a hashref and includes some mandatory and optional keys.

You have to define different schemas for different software, since there is
no standard in field names.

=head3 id

Mandatory. The name of the I<session id> field in the table.

=head3 data

Mandatory. The name of the I<session data> field in the table.

=head3 date

Mandatory. The name of the session date field in the table. This can be
the I<last modified> or I<timeout> value or anything else.

=head3 update_date

Optional boolean value. If it is true, then the C<date> field
will be updated with C<time()> if the session is modified.

But note that, the C<date field> will get the initial value from C<time()>
if you are creating a new session.

=head1 EXAMPLE

   use DBI;
   use PHP::Session::DBI;
   use CGI qw(:standard);
   # database configuration
   my %CONFIG = (
      db_driver   => "mysql",
      db_user     => "root",
      db_password => "",
      db_host     => "localhost",
      db_port     => 3306,
      db_database => "mydatabase",
      db_table    => "sessions",
   );
   # DBI options
   my %DBI_ATTR = (
      RaiseError => 1,
      PrintError => 0,
      AutoCommit => 1,
   );
   # Data Source Name
   my $DSN = sprintf "DBI:%s:database=%s;host=%s;port=%s", 
                     @CONFIG{ qw/ db_driver db_database db_host db_port / };
   # database handle
   my $dbh = DBI->connect($DSN, @CONFIG{qw/ db_user db_password /}, \%DBI_ATTR);
   # get the session id from cookie
   my $SID     = cookie('PHPSESSID');
   # fetch the session
   my $session = PHP::Session::DBI->new(
                    $SID,
                    {
                       db_handle => $dbh,
                       db_table  => $CONFIG{db_table},
                       db_schema => {
                          id   => 'session_id',
                          data => 'data',
                          date => 'last_update',
                       },
                       auto_save => 1,
                    }
                 );
   #create a new session key
   $session->set(burak => "TESTING ... ");

=head1 SEE ALSO

L<PHP::Session>, 
L<http://tr.php.net/session_set_save_handler>,
L<http://www.raditha.com/php/session.php>
and L<http://www.simplemachines.org>. 

There is a similar module called L<PHP::Session::DB>.
However, it does not meet my requirements and especially,
the SQL statements are hard-coded with weird field names,
which makes it impossible to use in different systems.

=head1 AUTHOR

Burak GE<252>rsoy <burakE<64>cpan.org>

=head1 COPYRIGHT

Copyright 2007-2009 Burak GE<252>rsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.8.8 or, 
at your option, any later version of Perl 5 you may have available.

=cut

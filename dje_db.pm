#!/usr/bin/perl

use DBI;




#      _       _	_
#   __| | __ _| |_ __ _| |__   __ _ ___  ___
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#

my $db;
my $db_sth;

sub connect_db {
	(my $dbfile)=@_;
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	return $db;
}


sub db_dosql{
	(my $sql)=@_;
        $db_sth = $db->prepare($sql);
        $db_sth->execute();
	return $db_sth;
}

sub db_getrow {
	my @row;
	if (@row  = $db_sth->fetchrow()){
		return @row;
	}
	else {
		return ();
	}
}

1;

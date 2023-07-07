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
my $db_error=0;

sub connect_db {
	(my $dbfile)=@_;
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	$db_error=0;
	return $db;
}


sub db_dosql{
	(my $sql)=@_;
        if ($db_sth = $db->prepare($sql)){
        	$db_sth->execute();
		$db_error=0;
		return 0;
	}
	else { 
		print "Prepare failed for $sql\n";
		$db_error=1;
		return 1;
	}
}

sub db_getrow {
	my @row;
	if ($db_error==1){
		return ();
	}
	elsif (@row  = $db_sth->fetchrow()){
		return @row;
	}
	else {
		return ();
	}
}

1;

#!/usr/bin/perl
#INSTALL@ /opt/djedefre/djedefre_create_db
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
use strict;
use DBI;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;

my $topdir='.';
my $image_directory="$topdir/images";
my $dbfile="$topdir/database/djedefre.db";
my $configfilename="djedefre.conf";
my $last_message='.';

sub uniq {
my %seen;
grep !$seen{$_}++, @_;
}

sub parseconfig {
	my ($ConfigFileSpec)=@_;
	if ( -e $ConfigFileSpec ) {
		if (open (my $CONFIG, "<", $ConfigFileSpec )){
			while (<$CONFIG>){
				s/ //g;
				s/#.*//;
				if (/topdir=(.*)/) {$topdir=$1;}
				elsif (/dbfile=(.*)/) {$dbfile=$1;}
				elsif (/image_directory=(.*)/) {$image_directory=$1;}
				elsif (/last_message=(.*)/) {$last_message=$1;}
				elsif (/print/){
					print "dbfile=$dbfile\n";
					print "image_directory=$image_directory\n";
					print "last_message=$last_message\n";
				}
			}
			close $CONFIG;
		}
	}
}

parseconfig('/etc/djedefre.conf');
parseconfig('/opt/djedefre/etc/djedefre.conf');
parseconfig('/var/local/etc/djedefre.conf');
my $ConfigFileSpec = File::HomeDir->my_home . "/.$configfilename";
parseconfig($ConfigFileSpec);
parseconfig('djedefre.conf');

#      _       _        _
#   __| | __ _| |_ __ _| |__   __ _ ___  ___
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
#

my $db;

sub connect_db {
	$db = DBI->connect("dbi:SQLite:dbname=".$dbfile)
		or die $DBI::errstr;
	return $db;
}

connect_db();
my $schema='';
$schema="
CREATE TABLE IF NOT EXISTS interfaces (
	id            integer primary key autoincrement,
	macid         string,
	ip            string,
	hostname      string,
	host          integer,
	subnet        integer,
	access        string,
	connect_if    integer,
	port          integer,
	ifname        string,
	switch        integer
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS subnet (
	id         integer primary key autoincrement,
	nwaddress  string,
	cidr       integer,
	xcoord     integer,
	ycoord     integer,
	name       string,
	options    string,
	access     string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS server (
	id         integer primary key autoincrement,
	name       string,
	xcoord     integer,
	ycoord     integer,
	type       string,
	status     string,
	last_up    integer,
	options    string,
	ostype     string,
	os         string,
	processor  string,
	devicetype string,
	memory     string,
	interfaces dtring
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS command (
	id         integer primary key autoincrement,
	host       string,
	button     string,
	command    string
);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS details (
	id         integer,
	type       string,
	os         string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS pages (
	id         integer primary key autoincrement,
	page       string,
	tbl        string,
	item       integer,
	xcoord     integer,
	ycoord     integer
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS switch (
	id         integer primary key autoincrement,
	switch     string,
	server     integer,
	name       string,
	ports      integer
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS l2connect (
	id         integer primary key autoincrement,
	vlan       string,
	from_tbl   string,
	from_id    integer,
	from_port  integer,
	to_tbl     string,
	to_id      integer,
	to_port    integer,
	source     string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS config (
	id         integer primary key autoincrement,
	attribute  string,
	item       string,
	value      string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS cloud (
	id         integer primary key autoincrement,
	name       string,
        vendor     string,
	type       string,
	xcoord     integer,
	ycoord     integer,
	service    string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS dashboard (
	id         integer primary key autoincrement,
	server     string,
        type       string,
	variable   string,
	value      string,
	color1     string,
	color2     string
	);
";
$db->do($schema) or die $db->errstr;
$schema="
CREATE TABLE IF NOT EXISTS nfs (
	id         integer primary key autoincrement,
	server     string,
        export     string,
	client     string,
	mountpoint string
	);
";
$db->do($schema) or die $db->errstr;

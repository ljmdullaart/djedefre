CREATE TABLE interfaces (
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
	, options);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE subnet (
	id         integer primary key autoincrement,
	nwaddress  string,
	cidr       integer,
	xcoord     integer,
	ycoord     integer,
	name       string,
	options    string,
	access     string
	, source text);
CREATE TABLE server (
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
CREATE TABLE command (
	id         integer primary key autoincrement,
	host       string,
	button     string,
	command    string
);
CREATE TABLE details (
	id         integer,
	type       string,
	os         string
	);
CREATE TABLE pages (
	id         integer primary key autoincrement,
	page       string,
	tbl        string,
	item       integer,
	xcoord     integer,
	ycoord     integer
	);
CREATE TABLE switch (
	id         integer primary key autoincrement,
	switch     string,
	server     integer,
	name       string,
	ports      integer
	);
CREATE TABLE l2connect (
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
CREATE TABLE config (
	id         integer primary key autoincrement,
	attribute  string,
	item       string,
	value      string
	);
CREATE TABLE cloud (
	id         integer primary key autoincrement,
	name       string,
        vendor     string,
	type       string,
	xcoord     integer,
	ycoord     integer,
	service    string
	);
CREATE TABLE dashboard (
	id         integer primary key autoincrement,
	server     string,
        type       string,
	variable   string,
	value      string,
	color1     string,
	color2     string
	);
CREATE TABLE nfs (
	id         integer primary key autoincrement,
	server     string,
        export     string,
	client     string,
	mountpoint string
	);

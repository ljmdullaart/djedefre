CREATE TABLE interfaces (
	id            integer primary key autoincrement,
	access        text,
	connect_if    integer,
	host          integer,
	hostname      text,
	ifname        text,
	ip            text UNIQUE,
	ip_scope      text,
	macid         text,
	options       text,
	port          integer,
	remarks       text,
	source        text,
	subnet        integer,
	switch        integer
	);
CREATE TABLE subnet (
	id         integer primary key autoincrement,
	access     text,
	cidr       integer,
	name       text,
	nwaddress  text UNIQUE,
	options    text,
	remarks    text,
	scope      text,
	source     text,
	xcoord     integer,
	ycoord     integer
	);
CREATE TABLE server (
	id         integer primary key autoincrement,
	devicetype text,
	interfaces text,
	last_up    integer,
	memory     text,
	name       text UNIQUE,
	options    text,
	os         text,
	ostype     text,
	processor  text,
	remarks    text,
	source     text,
	status     text,
	type       text,
	xcoord     integer,
	ycoord     integer
	);

CREATE TABLE command (
	id         integer primary key autoincrement,
	host       text,
	button     text,
	command    text
);
CREATE TABLE details (
	id         integer,
	os         text,
	type       text
	);
CREATE TABLE pages (
	id         integer primary key autoincrement,
	item       integer,
	page       text,
	tbl        text,
	xcoord     integer,
	ycoord     integer
	);
CREATE TABLE switch (
	id         integer primary key autoincrement,
	name       text,
	ports      integer
	remarks    text,
	switch     text,
	server     integer
	);
CREATE TABLE l2connect (
	id         integer primary key autoincrement,
	vlan       text,
	from_tbl   text,
	from_id    integer,
	from_port  integer,
	to_tbl     text,
	to_id      integer,
	to_port    integer,
	source     text
	);
CREATE TABLE config (
	id         integer primary key autoincrement,
	attribute  text,
	item       text,
	value      text
	);
CREATE TABLE cloud (
	id         integer primary key autoincrement,
	name       text UNIQUE,
	options    text,
	remarks    text,
	type       text,
        vendor     text,
	xcoord     integer,
	ycoord     integer,
	service    text
	);
CREATE TABLE dashboard (
	id         integer primary key autoincrement,
	server     text,
        type       text,
	variable   text,
	value      text,
	color1     text,
	color2     text
	);
CREATE TABLE nfs (
	id         integer primary key autoincrement,
	client     text,
	mountpoint text,
	remarks    text,
	server     text,
        export     text
	);

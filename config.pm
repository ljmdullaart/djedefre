#!/usr/bin/perl
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
#INSTALL@ /opt/djedefre/config.pm

use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;

our %config;

sub config_read {
	(my $fle)=@_;
	if (open(my $FILE,'<',$fle)){
		my @cfg_in=<$FILE>;
		for (@cfg_in){
			s/#.*//;
			if (/(.*)=(.*)/){
				$config{$1}=$2;
			}
		}
	}
}

my $home=File::HomeDir->my_home;

sub config_get {
	config_read('/etc/djedefre.rc');
	config_read('/var/lib/djedefre/djedefre.rc');
	config_read('/var/local/lib/djedefre/djedefre.rc');
	config_read('/opt/djedefre/etc/djedefre.rc');
	config_read("$home/.djedefre.rc");
	config_read(".djedefre.rc");
	config_read("djedefre.rc");
}
1;

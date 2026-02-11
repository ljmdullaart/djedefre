#!/usr/bin/perl
#INSTALL@ /opt/djedefre/standard.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre
use strict;
use warnings;

our $Message;

#sub uniq {
    #my %seen;
    #grep !$seen{$_}++, @_;
#}

sub uniq {
    my %seen;
    my $undef_key = "__UNDEF__";   # interne sleutel voor undef

    return grep {
        my $key = defined($_) ? $_ : $undef_key;
        !$seen{$key}++;
    } @_;
}


sub ipisinsubnet {
        (my $ip, my $subnet)=@_;
	if (!($ip=~/([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)/)){
		return 0;
	}
        elsif ($subnet=~/([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)\/([0-9]*)/){
        	my @octets=split ('\.',$ip);
        	my $ipbin=256*(256*(256*$octets[0]+$octets[1])+$octets[2])+$octets[3];
        	my $net; my $cidr;
                $net=256*(256*(256*$1+$2)+$3)+$4;
                $cidr=$5;
                my $a=0xffffffff;
                my $b=$a<<(32-$cidr);
                my $c=$b&0xffffffff;
                if (($net & $c)==($ipbin & $c)){
                        return 1;
                }
                else {
                        return 0;
                }
        }
        elsif ($subnet=~/Internet/){
                if ($ip=~/Internet/){
                        return 1;
                }
                else { return 0;}
        }
        else {
                print "subnet $subnet is not recognized\n";
                $Message= "subnet $subnet is not recognized\n";

        }
        return 0;
}


1;

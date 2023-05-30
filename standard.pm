#!/usr/bin/perl

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub ipisinsubnet {
        (my $ip, my $subnet)=@_;
        my @octets=split ('\.',$ip);
        my $ipbin=256*(256*(256*$octets[0]+$octets[1])+$octets[2])+$octets[3];
        my $net; my $cidr;
        if ($subnet=~/([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)\/([0-9]*)/){
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

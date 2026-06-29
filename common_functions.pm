#-----------------------------------------------------------------------
# Name        : ip_in_subnet
# Purpose     : Determine if the IP address is in the subnet
# Arguments   : IP address, network address, CIDR-bits
# Returns     : true if IP address is in subnet, false otherwise
# Globals     : 
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
sub ip_in_subnet {
	my ($ip, $net, $cidr) = @_;
	$cidr=32 unless defined cidr;
	# Some exceptions for Internet and 0.0.0.0
	if ($net=~/[Ii]nternet/){
		if ($ip=~/^10\./){ return 0; }
		if ($ip=~/^192.168\./){ return 0; }
		if ($ip=~/^172.16\./){ return 0; }
		if ($ip=~/^.nterne/){ return 1; }
	}
	elsif ($net=~/0.0.0.0/){
		if ($ip=~/^10\./){ return 0; }
		if ($ip=~/^192.168\./){ return 0; }
		if ($ip=~/^172.16\./){ return 0; }
		if ($ip=~/^.nterne/){ return 1; }
	}
	else {
		# Convert dotted IPv4 to 32‑bit integer
		my $ip_i  = unpack("N", pack("C4", split(/\./, $ip)));
		my $net_i = unpack("N", pack("C4", split(/\./, $net)));
		# Build mask from CIDR bits
		my $mask = $cidr == 0 ? 0 : (0xFFFFFFFF << (32 - $cidr)) & 0xFFFFFFFF;
		# Compare masked values
		return ($ip_i & $mask) == ($net_i & $mask);
	}
}

sub api_log {
        (my $line)=@_;
        open my $fh, ">>", "log/api" or die "Cannot open log: $!";
        print $fh "$line\n";
        close $fh;
}


1;

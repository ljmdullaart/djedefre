# drawing.pm
use strict;
use warnings;

# Part of the dancer2 version

# ---------------------------------------------------------
# 1. Load all objects for a page
# ---------------------------------------------------------
sub load_page_objects {
	my ($page) = @_;

	my $seq = 0;
	my (@drawing, @srvdraw, @subnets, @vboxes);

	my $vboxcolor = q_config('line:color','vbox') // 'royalblue';

	my $ref = query_page('page', $page);
	my @page_content = @$ref;

	for my $object (@page_content) {
		$seq++;
		my $dr_obj = 10 * $seq;

		my %item = (
			page   => $object->{page},
			tbl	=> $object->{tbl},
			item   => $object->{item},
			xcoord => $object->{xcoord},
			ycoord => $object->{ycoord},
			dr_obj => $dr_obj,
		);

		my $id = $object->{item};

		if ($object->{tbl} eq 'server') {
			$dr_obj++;
			$srvdraw[$id] = $dr_obj;
			$item{dr_obj} = $dr_obj;

			$item{name}	= q_server('name', $id);
			$item{type}	= q_server('type', $id);
			$item{status}	= q_server('status', $id);
			$item{last_up}	= q_server('last_up', $id);
			$item{options}	= q_server('options', $id) // '';
			$item{ostype}	= q_server('ostype', $id);
			$item{os}		= q_server('os', $id);
			$item{processor}  = q_server('processor', $id);
			$item{devicetype} = q_server('devicetype', $id);
			$item{memory}	= q_server('memory', $id);

			my $ifref = query_if_from_host($id);
			$item{interfaces} = [ @$ifref ];

			push @drawing, \%item;
			if ($item{options} =~ /vboxhost[:=](\d+)/) {
				push @vboxes, {
					server => $1,
					client => $item{item},
					dr_obj => $dr_obj,
				};
			}
		}
		elsif ($object->{tbl} eq 'subnet') {
			$dr_obj += 2;
			$item{dr_obj} = $dr_obj;

			$item{name}	= q_subnet('name', $id);
			$item{nwaddress} = q_subnet('nwaddress', $id);
			$item{cidr}	= q_subnet('cidr', $id);
			$item{options}   = q_subnet('options', $id);
			$item{access}	= q_subnet('access', $id);
			$item{scope}	= q_subnet('scope', $id);
			$item{type}	= ($item{nwaddress} eq 'Internet') ? 'internet' : 'subnet';

			push @subnets, \%item;
			push @drawing, \%item;
		}
		elsif ($object->{tbl} eq 'cloud') {
			$dr_obj += 3;
			$item{dr_obj} = $dr_obj;

			$item{name}	= q_cloud('name', $id);
			$item{type}	= q_cloud('type', $id);
			$item{vendor}  = q_cloud('vendor', $id);
			$item{service} = q_cloud('service', $id);

			push @drawing, \%item;
		}
		elsif ($object->{tbl} eq 'switch') {
			$dr_obj += 4;
			$item{dr_obj} = $dr_obj;

			$item{name}   = q_switch('name', $id);
			$item{server} = q_switch('server', $id);
			$item{switch} = q_switch('switch', $id);
			$item{ports}  = q_switch('ports', $id);

			push @drawing, \%item;
		}
	}

	return (\@drawing, \@subnets, \@srvdraw, \@vboxes);
}

# ---------------------------------------------------------
# 2. Add pagelist
# ---------------------------------------------------------
sub add_pagelist_to_objects {
	my ($drawing) = @_;

	for my $object (@$drawing) {
		my @pglist;
		query_pages_tbl_id($object->{tbl}, $object->{item});
		while (my $r = sql_getrow()) {
			push @pglist, $r->{page};
		}
		$object->{pagelist} = \@pglist;
	}
}

# ---------------------------------------------------------
# 3. Add L3 lines
# ---------------------------------------------------------

sub add_l3_lines {
	my ($drawing, $subnets, $vboxes) = @_;

	my $seq = 0;

	my @dr_cpy = @$drawing;

	for my $object (@dr_cpy) {

		# -------------------------
		# SERVER → SUBNET lines
		# -------------------------
		if ($object->{tbl} eq 'server') {
			my $dr_obj	= $object->{dr_obj};
			my $serverid  = $object->{item};
			my $ifref	= query_if_from_host($serverid);
			for my $row (@$ifref) {
				my $ip = $row->{ip};
				for my $net (@$subnets) {
					$seq++;
					my %item;
					$item{dr_obj}	= 10 * $seq + 9;
					$item{tbl}	= 'line';
					$item{servername}= $object->{name};
					$item{serverid}	= $serverid;
					$item{from}	= $object->{dr_obj};
					my $net_obj	= $net->{dr_obj};
					my $nwaddress	= '0.0.0.0';
					if ($net->{nwaddress} =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/) {
						$nwaddress = $1;
					}
					my $cidr = $net->{cidr};
					$item{netname} = $net->{name};
					if (defined $net->{options}) {
						if ($net->{options} =~ /color=([A-Za-z0-9]+)/) {
							$item{color} = $1;
						} else {
							$item{color} = 'black';
						}
					} else {
						$item{color} = 'black';
					}
					if (ip_in_subnet($ip, $nwaddress, $cidr)) {
						$item{from}	= $dr_obj;
						$item{to}	= $net_obj;
						$item{thick}	= 1;
						push @$drawing, \%item;
					}
				}
			}

			# -------------------------
			# VBox lines
			# -------------------------
			for my $vbox (@$vboxes) {
				my %vboxline;
				$vboxline{thick} = 10;
				$vboxline{from}  = $dr_obj;
				$vboxline{color} = q_config('line:color','vbox') // 'royalblue';
				$vboxline{opacity} = 0.5;

				if ($vbox->{server} == $serverid) {
					$seq++;
					$vboxline{to}		= $vbox->{dr_obj};
					$vboxline{server}	= $serverid;
					$vboxline{client}	= $vbox->{client};
					$vboxline{dr_obj}	= 10 * $seq + 9;
					$vboxline{tbl}		= 'line';
					push @$drawing, \%vboxline;
				}
			}
		}

		# -------------------------
		# CLOUD → Internet lines
		# -------------------------
		elsif ($object->{tbl} eq 'cloud') {
			my $dr_obj  = $object->{dr_obj};
			my $cloudid = $object->{item};

			for my $net (@$subnets) {
				$seq++;
				my %item;
				$item{dr_obj}   = 10 * $seq + 9;
				$item{tbl}	= 'line';
				$item{cloudname}= $object->{name};
				$item{cloudid}  = $cloudid;

				my $net_obj  = $net->{dr_obj};
				my $nwaddress= $net->{nwaddress};

				if (($nwaddress =~ /[Ii]nternet/) || ($nwaddress eq '0.0.0.0')) {
					$item{netname} = $net->{name};
					$item{color}   = 'black';

					if (defined $object->{options}) {
						if ($object->{options} =~ /color=([A-Za-z0-9]+)/) {
							$item{color} = $1;
						}
					}

					$item{from} = $dr_obj;
					$item{to}   = $net_obj;
					push @$drawing, \%item;
				}
			}
		}
	}
}


# ---------------------------------------------------------
# 4. Add L2 lines
# ---------------------------------------------------------
sub add_l2_lines {
	my ($drawing, $srvdraw, $page) = @_;
	my $seq=100000;
	return unless q_config('page:type', $page) eq 'l2';

	query_l2();
	while (my $r = sql_getrow()) {
		my $from_tbl = $r->{from_tbl};
		my $to_tbl   = $r->{to_tbl};
		my $from_id  = $r->{from_id};
		my $to_id	= $r->{to_id};
		my $fromserver=undef;
		my $toserver=undef;

		if ($from_tbl eq 'interfaces') { $fromserver = q_interfaces('host', $from_id); }
		elsif ($from_tbl eq 'server') { $fromserver = $from_id; }

		if ($to_tbl   eq 'interfaces') { $toserver   =q_interfaces('host', $to_id); }
		elsif ($to_tbl   eq 'server') { $toserver   =$to_id; }

		next unless defined $fromserver && defined $toserver;

		my $fromdraw = $srvdraw->[$fromserver];
		my $todraw   = $srvdraw->[$toserver];

		next unless defined $fromdraw && defined $todraw;
		$seq++;
		push @$drawing, {
			tbl	=> 'line',
			dr_obj	=> $seq,
			from	=> $fromdraw,
			to	=> $todraw,
			color	=> 'black',
			thick	=> 1,
		};
	}
}
# ---------------------------------------------------------
# 4. Add NFS lines
# ---------------------------------------------------------
sub add_nfs_lines {
	my ($drawing, $srvdraw, $page) = @_;
	my $seq=200000;
	my @client_name;
	my @mountpoint;
	my @server;
	my @export;
	my $nxtfree=0;
	return unless q_config('page:type', $page) eq 'nfs';
	my $color = q_config('line:color','vbox') // 'tangerine';
	query_nfs();
	while (my $r = sql_getrow()) {
		$client_name[$nxtfree]=$r->{client};
		$mountpoint[$nxtfree]=$r->{mountpoint};
		$server[$nxtfree]=$r->{server};
		$export[$nxtfree]=$r->{export};
		$nxtfree++;
	}
	for (my $i=0; $i<$nxtfree; $i++){
		my $fromid=q_server_by_name('id',$client_name[$i]);
		my $toid=q_server_by_name('id',$server[$i]);
		my $fromdraw = $srvdraw->[$fromid];
		my $todraw   = $srvdraw->[$toid];
		$seq++;
		push @$drawing, {
			tbl	=> 'line',
			dr_obj	=> $seq,
			from  	=> $fromdraw,
			to	=> $todraw,
			color 	=> $color,
			thick 	=> 1,
		};
	}
}

1;


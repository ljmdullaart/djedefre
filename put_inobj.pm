my $qobjtypes=4;
my $objtsubnet=0;
my $objtserver=1;
my $objtswitch=2;
my $objtcloud=3;


sub put_netinobj {
	(my $page,my $ar_ref)=@_;
	my $sql;
print "put_netinobj: $page\n";
	if ($page eq 'top'){
		$sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name,options FROM subnet';
	}
	else {
		$sql="	SELECT subnet.id,nwaddress,cidr,pages.xcoord,pages.ycoord,name,subnet.options
			FROM   subnet
			INNER JOIN pages ON pages.item = subnet.id
			WHERE  pages.page='$page' AND pages.tbl='subnet'
		";
	}
print "    $sql\n";
	my $sth = db_dosql($sql);
	while((my $id,my $nwaddress, my $cidr,my $x,my $y,my $name,my $options) = db_getrow()){
print "    my $id,my $nwaddress, my $cidr,my $x,my $y,my $name,my $options\n";
		if ((!defined $x) || !(defined $y)){
			nxttmploc();
			if (! defined $x){ $x=$nw_tmpx; $nw_tmpx=$nw_tmpx+5;}
			if ($nw_tmpx > 800){$nw_tmpx=25; $nw_tmpy=$nw_tmp+5;}
			if (! defined $y){ $y=$nw_tmpy;}
		}
		$name="$nwaddress/$cidr" unless defined $name;
		my $color='black';
		if ($options=~/color=([^;]*);/){$color=$1;}
		push @$ar_ref, {
			newid	=> $id*$qobjtypes+$objtsubnet,
			id	=> $id,
			x	=> $x,
			y	=> $y,
			logo	=> 'subnet',
			name	=> $name,
			nwaddress=> $nwaddress,
			cidr	=> $cidr,
			table	=> 'subnet',
			color	=> $color
		} 
	}
	foreach my $element (@$ar_ref) {
		my $id=$element->{'id'};
		my $table=$element->{'table'};
		my $name=$element->{'name'};
		if($table eq 'subnet'){
			push @{$l2_obj[$i]{pages}},' ';
			splice @{$l2_obj[$i]{pages}};
			my $sql = "SELECT page FROM pages WHERE tbl='subnet' AND item=$id";
			my $sth = db_dosql($sql);
			while ((my $item) = db_getrow()){
				push @{$element{pages}}, $item
			}
		}
	}
}


1;

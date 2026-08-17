#!/usr/bin/perl
use strict;
use warnings;
use Dancer2 appname => 'dancr';


use Dancer2::Plugin::Auth::Tiny;
use dje_db;

sub check_authorized {
	if ( ! session('logged_in') ) {
		status 401;
		halt( to_json({ error => 'Not logged in' }) );
	}
}


######################################################################################
#     API
######################################################################################

get '/api/json/servers' => sub {
	check_authorized();
	api_log ('/api/json/servers');
	my $ref=query_server();
	send_as JSON =>  $ref;
	
};

get '/api/json/config' => sub {
	check_authorized();
	api_log ('/api/json/config');
	my $ref=query_config();
	send_as JSON =>  $ref;
	
};

get '/api/json/subnets' => sub {
	check_authorized();
	api_log ('/api/json/subnets');
	my $ref=query_subnet();
	send_as JSON =>  $ref;
	
};

get '/api/json/clouds' => sub {
	check_authorized();
	api_log ('/api/json/clouds');
	my $ref=query_cloud();
	send_as JSON =>  $ref;
	
};

get '/api/json/interfaces' => sub {
	check_authorized();
	api_log ('/api/json/interfaces');
	my $ref=query_interfaces_extra();
	send_as JSON =>  $ref;
	
};

get '/api/json/nfs' => sub {
	check_authorized();
	api_log ('/api/json/nfs');
	my $ref=query_nfs();
	send_as JSON =>  $ref;
	
};

get '/api/json/dashboard' => sub {
	check_authorized();
	api_log ('/api/json/dashboard');
	my $ref=query_dashboard();
	send_as JSON =>  $ref;
	
};

get '/api/listings' => sub {
	check_authorized();
	api_log ('/api/json/listings');
	my $file = '/tmp/djedefre.listing';
	open my $fh, '<', $file or return send_error("Cannot open $file: $!", 500);
	my $content = do { local $/; <$fh> };
	close $fh;
	return "<pre style='font-family: monospace;'>$content</pre>";
};

get '/api/listingfiles' => sub {
	check_authorized();
	my $target_dir = File::Spec->catdir('', 'tmp', 'djedefre');
	unless (-d $target_dir) {
		status 404;
		return to_json { status => "error", message => "Directory not found" };
	}
	my @files;
	if (opendir(my $dh, $target_dir)) {
		@files = grep { 
			my $full_path = File::Spec->catfile($target_dir, $_);
			-f File::Spec->catfile($target_dir, $_) # Alleen echte bestanden (geen submappen)
			&& $_ !~ /^\./	                      # Sla verborgen bestanden en . / .. over
			&& -s $full_path > 10
		} readdir($dh);
		closedir($dh);
	} else {
		status 500;
		return to_json { status => "error", message => "Cannot open directory: $!" };
	}
	return to_json { 
		status => "ok", 
		files  => [ sort @files ] 
	};
};
get '/api/listingfile/:filename' => sub {
	check_authorized();
	my $filename = route_parameters->get('filename');
	$filename = basename($filename);
	my $file_path = File::Spec->catfile('', 'tmp', 'djedefre', $filename);
	unless (-e $file_path && -f $file_path) {
		status 404;
		return "File not found";
	}
	return send_file(
		$file_path,
		system_path  => 1,
		content_type => 'text/html; charset=UTF-8'
	);
};

get '/api/json/page/:param' => sub {
	check_authorized();
	my $page = route_parameters->get('param');
	
	api_log ("/api/json/page:$page");
	my ($drawing, $subnets, $srvdraw, $vboxes) = load_page_objects($page);

	add_pagelist_to_objects($drawing);
	add_l3_lines($drawing, $subnets, $vboxes);
	add_l2_lines($drawing, $srvdraw, $page);
	add_nfs_lines($drawing, $srvdraw, $page);

	send_as JSON => $drawing;
};


get '/api/pagelist' => sub {
	check_authorized();
	api_log ("/api/pagelist");
	my $outxml="<pages>\n";
	my $ref  = query_pagelist();
	while(my $r = sql_getrow()){
		my $pg=$r->{item};
		my $tp=$r->{value};
		my $comment=$r->{comment};
		$comment='' unless defined $comment;
		if ($comment eq '' ){
			$outxml .= "<page>\n<name>$pg</name>\n<type>$tp</type></page>\n";
		}
		else {
			$outxml .= "<page>\n<name>$pg</name>\n<type>$tp</type><comment>$comment</comment></page>\n";
		}
	}
	$outxml.="</pages>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

get '/api/logolist' => sub {
	check_authorized();
	api_log ("/api/logolist");
	my @files = glob('images/logo_*.png');
	my $outxml="<logos>\n";
	foreach my $file (@files) {
		if ($file=~/logo_(.*)\.png/){
			$outxml .= "<logo>\n<name>$1</name>\n</logo>\n";
		}
	}
	$outxml.="</logos>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};
get '/api/devtypelist' => sub {
	check_authorized();
	api_log ("/api/devtypelist");
	my @devtypes=qw/pc network server printer virtual nas appliance tablet smartphone voip iot security_camera av ups/;
	my $outxml="<devtypes>\n";
	foreach my $devtype (@devtypes) {
		$outxml .= "<devtype>\n<name>$devtype</name>\n</devtype>\n";
	}
	$outxml.="</devtypes>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;

};



post '/api/moveobject' => sub {
	check_authorized();
	my $data = from_json(request->body);

	my $item   = $data->{item};
	my $tbl    = $data->{tbl};
	my $xcoord = int($data->{xcoord});
	my $ycoord = int($data->{ycoord});
	my $page   = $data->{page};
	api_log("/api/moveobject item=$item tbl=$tbl to($xcoord,$ycoord) on page $page");

	my $pageid = q_page_id('page',$page,'tbl',$tbl,'item',$item);
	q_page_update($pageid,'xcoord',$xcoord);
	q_page_update($pageid,'ycoord',$ycoord);
	return to_json { status => "ok" };
};

post '/api/changeobject' => sub {
	check_authorized();
	my $data   = from_json(request->body);
	my $item   = $data->{item};
	my $id     = $data->{id};
	my $tbl    = $data->{tbl};
	my $var    = $data->{var};
	my $val    = $data->{val};
	$tbl='none' unless defined $tbl;
	api_log("/api/changeobject item=$item tbl=$tbl var=$var val=$val");
	if ($tbl eq 'server'){ q_server_update ($item,$var,$val); }
	if ($tbl eq 'subnet'){ q_subnet_update ($item,$var,$val); }
	if ($tbl eq 'cloud') { q_cloud_update  ($item,$var,$val); }
	return to_json { status => "ok" };
};

post '/api/setpagelist' => sub {
	check_authorized();
	my $data   = from_json(request->body);
	my $item   = $data->{item};
	my $tbl    = $data->{tbl};
	my $action = $data->{action};   # add | remove
	my $page   = $data->{page};
	api_log("/api/setpagelist item=$item  tbl=$tbl action=$action page=$page");
	if ($action eq 'remove'){ query_pages_del_obj($page,$tbl,$item); }
	if ($action eq 'add'){ query_pages_add_obj($page,$tbl,$item,100,100); }
	return to_json { status => "ok" };
	
};

post '/api/editpage' =>sub {
	my $data   = from_json(request->body);
	my $action = $data->{action};
	my $name   = $data->{name};
	my $type   = $data->{type};
	my $comment= $data->{comment};
	print "/api/editpage:\n	action =$action\n	name   = $name\n	type   = $type\n	comment= $comment\n";
	if ($action eq "add_page"){
		q_page_add ($name);
	}
	elsif ($action eq "delete_page"){
		q_page_delete ('name',$name);
	}
	elsif ($action eq "update_type"){
		query_set_pagetype($name,$type);
	}
	elsif ($action eq "update_comment"){
		q_config_set_comment('page:type', $name,$comment);
	}
	


	return to_json { status => "ok" };
};

post '/api/deleteobject' => sub {
	check_authorized();
	my $data   = from_json(request->body);
	my $item   = $data->{item};
	my $tbl    = $data->{tbl};
	api_log("/api/deleteobject item=$item  tbl=$tbl ");
	if ($tbl eq 'server'){ query_delete_server ($item); }
	if ($tbl eq 'subnet'){ query_delete_subnet ($item); }
	if ($tbl eq 'cloud' ){ query_delete_cloud  ($item); }
	return to_json { status => "ok" };
};
	
post '/api/konvaupload' => sub {
	check_authorized();
	my $file = upload('konva_image');
	if ($file) {
		my $destination = File::Spec->catfile(config->{appdir}, 'public', 'images', $file->filename);
		$file->copy_to($destination);
		return to_json { status => "ok" };
	}
	status 400;
	return to_json { status => "error" };
};

	
######################################################################################
#     old
######################################################################################
get '/api/servers' =>sub {
	print "OLD: /api/server\n";
	my $outxml="<servers>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,name,xcoord,ycoord,type,interfaces,access,status,last_up,options FROM server";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my @id;
	my @name;
	my @xcoord;
	my @ycoord;
	my @type;
	my @interfaces;
	my @access;
	my @status;
	my @last_up;
	my @options;
	my $ip,
	my $i=0;
	while(($id[$i],$name[$i],$xcoord[$i],$ycoord[$i],$type[$i],$interfaces[$i],$access[$i],$status[$i],$last_up[$i],$options[$i]) = $sth->fetchrow()){
		$id[$i]='EMPYT' unless defined $id[$i];
		$name[$i]='EMPTY' unless defined $name[$i];
		$xcoord[$i]='EMPTY' unless defined 	$xcoord[$i];
		$ycoord[$i]='EMPTY' unless defined 	$ycoord[$i];
		$type[$i]='EMPTY' unless defined	$type[$i];
		$interfaces[$i]='EMPTY' unless defined	$interfaces[$i];
		$access[$i]='EMPTY' unless defined 	$access[$i];
		$status[$i]='EMPTY' unless defined 	$status[$i];
		$last_up[$i]='EMPTY' unless defined $last_up[$i];
		$options[$i]='EMPTY' unless defined $options[$i];
		$i++;
	}
	for (my $j=0; $j<$i; $j++){
		$outxml.= "<server>\n";
		$outxml.= "<id>$id[$j]</id>\n";
		$outxml.= "<name>$name[$j]</name>\n";
		$outxml.= "<xcoord>$xcoord[$j]</xcoord>\n";
		$outxml.= "<ycoord>$ycoord[$j]</ycoord>\n";
		$outxml.= "<type>$type[$j]</type>\n";
		$outxml.= "<interfaces>$interfaces[$j]</interfaces>\n";
		$outxml.= "<access>$access[$j]</access>\n";
		$outxml.= "<status>$status[$j]</status>\n";
		$outxml.= "<lastup>$last_up[$j]</lastup>\n";
		$outxml.= "<options>$options[$j]</options>\n";
		$sql = "SELECT ip FROM interfaces WHERE host=$id[$j]";
		$sth = $db->prepare($sql) ;
		$sth->execute  or die $sth->errstr;
		while (($ip)= $sth->fetchrow()){
			$outxml.= "<ipaddress>$ip</ipaddress>\n";
		}
		$outxml.= "</server>\n";
		
	}
	$outxml.= "</servers>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

get '/api/nmap/id/:param' => sub {
	check_authorized();
	print "OLD: /api/nmap/id/:param\n";
	my $id=0;
	my $param=route_parameters->get('param');
	if ($param=~/([0-9]+)/){
		$id=$1;
	}
	my $txt="<nmap>";
	my $db  = connect_db();
	my $sql = "SELECT ip FROM interfaces WHERE host=$id";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my $iplist='';
	while((my $ip) = $sth->fetchrow()){
		$iplist="$iplist $ip";
	}
	if (open (my $NMAP,"/usr/bin/nmap $iplist  | sed 's/  */ /g'| sort -nu |")){
		while (<$NMAP>){
			if (/(\d+)\/(\w+) +(\w+) +(\w+)/){
				$txt="$txt\n<port>";
				$txt="$txt\n<number>$1</number>";
				$txt="$txt\n<protocol>$2</protocol>";
				$txt="$txt\n<status>$3</status>";
				$txt="$txt\n<service>$4</service>";
				$txt="$txt\n</port>";
			}
		}
	}
	

	$txt="$txt\n</nmap>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$txt;
			
};
get '/api/server/id/:param' => sub {
	check_authorized();
	print "OLD: /api/server/id/:param\n";
	my $id=0;
	my $param=route_parameters->get('param');
	if ($param=~/([0-9]+)/){
		$id=$1;
	}
	my $outxml="<servers>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,name,xcoord,ycoord,type,interfaces,access,status,last_up,options FROM server WHERE id=$id";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my $name;
	my $xcoord;
	my $ycoord;
	my $type;
	my $interfaces;
	my $access;
	my $status;
	my $last_up;
	my $options;
	while(($id,$name,$xcoord,$ycoord,$type,$interfaces,$access,$status,$last_up,$options) = $sth->fetchrow()){
		$id='EMPYT' unless defined $id;
		$name='EMPTY' unless defined $name;
		$xcoord='EMPTY' unless defined 	$xcoord;
		$ycoord='EMPTY' unless defined 	$ycoord;
		$type='EMPTY' unless defined	$type;
		$interfaces='EMPTY' unless defined	$interfaces;
		$access='EMPTY' unless defined 	$access;
		$status='EMPTY' unless defined 	$status;
		$last_up='EMPTY' unless defined $last_up;
		$options='EMPTY' unless defined $options;
		$outxml.= "<server>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<name>$name</name>\n";
		$outxml.= "<xcoord>$xcoord</xcoord>\n";
		$outxml.= "<ycoord>$ycoord</ycoord>\n";
		$outxml.= "<type>$type</type>\n";
		$outxml.= "<interfaces>$interfaces</interfaces>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "<status>$status</status>\n";
		$outxml.= "<lastup>$last_up</lastup>\n";
		$outxml.= "<options>$options</options>\n";
		$outxml.= "</server>\n";
	}
	$outxml.= "</servers>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

	

get '/api/subnets' => sub {
	check_authorized();
	print "OLD: /api/subnets\n";
	my $outxml="<subnets>\n";
	my $db  = connect_db();
	my $sql = 'SELECT id,nwaddress,cidr,xcoord,ycoord,name,options,access FROM subnet';
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my $id;
	my $nwaddress;
	my $cidr;
	my $xcoord;
	my $ycoord;
	my $name;
	my $options;
	my $access;
	while(($id,$nwaddress,$cidr,$xcoord,$ycoord,$name,$options,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$nwaddress='EMPTY' unless defined $nwaddress;
		$cidr='EMPTY' unless defined $cidr;
		$xcoord='EMPTY' unless defined $xcoord;
		$ycoord='EMPTY' unless defined $ycoord;
		$name='EMPTY' unless defined $name;
		$options='EMPTY' unless defined $options;
		$access='EMPTY' unless defined $access;
		$outxml.= "<subnet>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<nwaddress>$nwaddress</nwaddress>\n";
		$outxml.= "<cidr>$cidr</cidr>\n";
		$outxml.= "<xcoord>$xcoord</xcoord>\n";
		$outxml.= "<ycoord>$ycoord</ycoord>\n";
		$outxml.= "<name>$name</name>\n";
		$outxml.= "<options>$options</options>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</subnet>\n";
	}
	$outxml.="</subnets>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

get '/api/subnet/id/:param' => sub {
	check_authorized();
	print "OLD: /api/subnet/id/:param\n";
	my $id=0;
	my $param=route_parameters->get('param');
	if ($param=~/([0-9]+)/){
		$id=$1;
	}
	my $outxml="<subnets>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,nwaddress,cidr,xcoord,ycoord,name,options,access FROM subnet WHERE id=$id";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my $nwaddress;
	my $cidr;
	my $xcoord;
	my $ycoord;
	my $name;
	my $options;
	my $access;
	while(($id,$nwaddress,$cidr,$xcoord,$ycoord,$name,$options,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$nwaddress='EMPTY' unless defined $nwaddress;
		$cidr='EMPTY' unless defined $cidr;
		$xcoord='EMPTY' unless defined $xcoord;
		$ycoord='EMPTY' unless defined $ycoord;
		$name='EMPTY' unless defined $name;
		$options='EMPTY' unless defined $options;
		$access='EMPTY' unless defined $access;
		$outxml.= "<subnet>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<nwaddress>$nwaddress</nwaddress>\n";
		$outxml.= "<cidr>$cidr</cidr>\n";
		$outxml.= "<xcoord>$xcoord</xcoord>\n";
		$outxml.= "<ycoord>$ycoord</ycoord>\n";
		$outxml.= "<name>$name</name>\n";
		$outxml.= "<options>$options</options>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</subnet>\n";
	}
	$outxml.="</subnets>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

get '/api/interfaces' => sub {
	check_authorized();
	print "OLD: /api/sinterface\n";
	my $outxml="<interfaces>\n";
	my $db  = connect_db();
	my $sql = 'SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces';
	my $sth = $db->prepare($sql) ;
	$sth->execute  or die $sth->errstr;
	my $id='';my $macid='';my $ip='';my $hostname='';my $host='';my $subnet='';my $access='';
	while(($id,$macid,$ip,$hostname,$host,$subnet,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$macid='EMPTY' unless defined $macid;
		$hostname='EMPTY' unless defined $hostname;
		$host='EMPTY' unless defined $host;
		$subnet='EMPTY' unless defined $subnet;
		$access='EMPTY' unless defined $access;
		$ip='EMPTY' unless defined $ip;
		if ($hostname eq ''){ $hostname='EMPTY'}
		$outxml.= "<interface>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<macid>$macid</macid>\n";
		$outxml.= "<ip>$ip</ip>\n";
		$outxml.= "<name>$hostname</name>\n";
		$outxml.= "<host>$host</host>\n";
		$outxml.= "<subnet>$subnet</subnet>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</interface>\n";
		$id='';$macid='';$ip='';$hostname='';$host='';$subnet='';$access='';
	}
	$outxml.="</interfaces>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
};

get '/api/interface/id/:param[Int]' => sub {
	check_authorized();
	print "OLD: /api/interface/id/:param[Int]\n";
	my $param=route_parameters->get('param');
	my $id=0; my $macid='';my $ip='';my $hostname='';my $host='';my $subnet='';my $access='';
	if ($param=~/([0-9]+)/){
		$id=$1;
	}
	my $outxml="<interfaces>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces WHERE id=$id";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	while(($id,$macid,$ip,$hostname,$host,$subnet,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$macid='EMPTY' unless defined $macid;
		$hostname='EMPTY' unless defined $hostname;
		$host='EMPTY' unless defined $host;
		$subnet='EMPTY' unless defined $subnet;
		$access='EMPTY' unless defined $access;
		$ip='EMPTY' unless defined $ip;
		if ($hostname eq ''){ $hostname='EMPTY'}
		$outxml.= "<interface>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<macid>$macid</macid>\n";
		$outxml.= "<ip>$ip</ip>\n";
		$outxml.= "<name>$hostname</name>\n";
		$outxml.= "<host>$host</host>\n";
		$outxml.= "<subnet>$subnet</subnet>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</interface>\n";
		$id='';$macid='';$ip='';$hostname='';$host='';$subnet='';$access='';
	}
	$outxml.="</interfaces>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml; 
};
get '/api/interface/host/:param[Int]' => sub {
	check_authorized();
	print "OLD: /api/interface/host/:param[Int]\n";
	my $param=route_parameters->get('param');
	my $id=0; my $macid='';my $ip='';my $hostname='';my $host='';my $subnet='';my $access='';
	if ($param=~/([0-9]+)/){
		$host=$1;
	}
	my $outxml="<interfaces>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces WHERE host=$host";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	while(($id,$macid,$ip,$hostname,$host,$subnet,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$macid='EMPTY' unless defined $macid;
		$hostname='EMPTY' unless defined $hostname;
		$host='EMPTY' unless defined $host;
		$subnet='EMPTY' unless defined $subnet;
		$access='EMPTY' unless defined $access;
		$ip='EMPTY' unless defined $ip;
		if ($hostname eq ''){ $hostname='EMPTY'}
		$outxml.= "<interface>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<macid>$macid</macid>\n";
		$outxml.= "<ip>$ip</ip>\n";
		$outxml.= "<name>$hostname</name>\n";
		$outxml.= "<host>$host</host>\n";
		$outxml.= "<subnet>$subnet</subnet>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</interface>\n";
		$id='';$macid='';$ip='';$hostname='';$host='';$subnet='';$access='';
	}
	$outxml.="</interfaces>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml; 
};
get '/api/interface/hostname/:param[Str]' => sub {
	check_authorized();
	print "OLD: //api/interface/hostname/:param[Str]\n";
	my $param=route_parameters->get('param');
	my $id=0; my $macid='';my $ip='';my $hostname='';my $host='';my $subnet='';my $access='';
	if ($param=~/([a-z0-9\.]+)/){
		$hostname=$1;
	}
	my $outxml="<interfaces>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,macid,ip,hostname,host,subnet,access FROM interfaces WHERE hostname='$hostname'";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	while(($id,$macid,$ip,$hostname,$host,$subnet,$access) = $sth->fetchrow()){
		$id='EMPTY' unless defined $id;
		$macid='EMPTY' unless defined $macid;
		$hostname='EMPTY' unless defined $hostname;
		$host='EMPTY' unless defined $host;
		$subnet='EMPTY' unless defined $subnet;
		$access='EMPTY' unless defined $access;
		$ip='EMPTY' unless defined $ip;
		if ($hostname eq ''){ $hostname='EMPTY'}
		$outxml.= "<interface>\n";
		$outxml.= "<id>$id</id>\n";
		$outxml.= "<macid>$macid</macid>\n";
		$outxml.= "<ip>$ip</ip>\n";
		$outxml.= "<name>$hostname</name>\n";
		$outxml.= "<host>$host</host>\n";
		$outxml.= "<subnet>$subnet</subnet>\n";
		$outxml.= "<access>$access</access>\n";
		$outxml.= "</interface>\n";
		$id='';$macid='';$ip='';$hostname='';$host='';$subnet='';$access='';
	}
	$outxml.="</interfaces>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
	$outxml;
		
};

get '/api/drawing/:param' => sub {
	check_authorized();
	print "OLD: /api/drawing/:param\n";
	my $param=route_parameters->get('param');
	$param='top' unless defined $param;
	my @serverx;
	my @servery;
	my @subnetx;
	my @subnety;
	my $outxml="<drawing>\n";
	my $db  = connect_db();
	my $sql = "SELECT id,name,type,xcoord,ycoord FROM server";
	my $sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	while((my $id,my $name,my $type ,my $x,my $y) = $sth->fetchrow()){
		if ((defined $id)&&(defined $x)&&(defined $y)) {
			$type='server' unless defined $type;
			$outxml .= "<item>\n";
			$outxml .= "<source>server</source>\n";
			$outxml .= "<id>$id</id>\n";
			$outxml .= "<draw>logo</draw>\n";
			$outxml .= "<type>$type</type>\n";
			$outxml .= "<name>$name</name>\n";
			$outxml .= "<x>$x</x>\n";
			$outxml .= "<y>$y</y>\n";
			$outxml .= "</item>\n";
			$serverx[$id]=$x;
			$servery[$id]=$y;
		}
	}
	$sql = "SELECT id,name,nwaddress,xcoord,ycoord FROM subnet";
	$sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	my $type='subnet';
	while((my $id,my $name,my $nwaddress,my $x,my $y) = $sth->fetchrow()){
		$name=$nwaddress unless defined $name;
		if ((defined $id)&&(defined $type)&&(defined $x)&&(defined $y)) {
			$outxml .= "<item>\n";
			$outxml .= "<source>subnet</source>\n";
			$outxml .= "<id>$id</id>\n";
			$outxml .= "<type>$type</type>\n";
			$outxml .= "<name>$name</name>\n";
			$outxml .= "<draw>logo</draw>\n";
			$outxml .= "<x>$x</x>\n";
			$outxml .= "<y>$y</y>\n";
			$outxml .= "</item>\n";
			$subnetx[$id]=$x;
			$subnety[$id]=$y;
		}
	}
	$sql = "SELECT id,host,subnet FROM interfaces";
	$sth = $db->prepare($sql) ;
	$sth->execute  or print $sth->errstr;
	$type='interface';
	while((my $id,my $host,my $subnet) = $sth->fetchrow()){
		if ((defined $id)&&(defined $host)&&(defined $subnet)) {
			if ((defined $serverx[$host]) &&(defined $servery[$host]) && (defined $subnetx[$subnet]) &&($subnety[$subnet])){
				$outxml .= "<item>\n";
				$outxml .= "<source>interfaces</source>\n";
				$outxml .= "<id>$id</id>\n";
				$outxml .= "<draw>line</draw>\n";
				$outxml .= "<type>$type</type>\n";
				$outxml .= "<host>$host</host>\n";
				$outxml .= "<subnet>$subnet</subnet>\n";
				$outxml .= "<x1>$serverx[$host]</x1>\n";
				$outxml .= "<y1>$servery[$host]</y1>\n";
				$outxml .= "<x2>$subnetx[$subnet]</x2>\n";
				$outxml .= "<y2>$subnety[$subnet]</y2>\n";
				$outxml .= "</item>\n";
			}
		}
	}
	$outxml.="</drawing>\n";
	response_header('Content-Type' => 'text/xml');
	response_header('Cache-Control' =>  'no-store, no-cache, must-revalidate');
		

	$outxml;
};

######################################################################################
#	Serve specific file-types from the ./public directory
######################################################################################
# pictures/images
get '/**.gif' => sub {
	check_authorized();
	my $file='images'.request->path ;
	if ( -f $file ) {
		send_file $file;
	}
	else {
		set_flash("Can't open $file");
		redirect '/';

	}
};
get '/**.ico' => sub {
	check_authorized();
	my $file='images'.request->path ;
	if ( -f $file ) {
		send_file $file;
	}
};
get '/**.png' => sub {
	check_authorized();
	my $file='images'.request->path ;
	if ( -f $file ) {
		send_file $file;
	}
	else {
		set_flash("Can't open $file");
		redirect '/';

	}
};
# stylesheets
get '/**.css' => sub {
	check_authorized();
	my $file='css'.request->path ;
	if ( -f $file ) {
		send_file $file;
	}
	else {
		set_flash("Can't open $file");
		redirect '/';

	}
};
# javascripts
get '/**.js' => sub {
	check_authorized();
	my $file='js'.request->path ;
	if ( -f $file ) {
		send_file $file;
	}
	else {
		set_flash("Can't open $file");
		redirect '/';

	}
};
	
######################################################################################
	
 
post '/add' => sub {
	check_authorized();
	if ( not session('logged_in') ) {
		send_error("Not logged in", 401);
	}
 
	my $db  = connect_db();
	my $sql = 'insert into entries (title, text) values (?, ?)';
 
	my $sth = $db->prepare($sql)
		or die $db->errstr;
 
	$sth->execute(
		body_parameters->get('title'),
		body_parameters->get('text')
	) or die $sth->errstr;
 
	redirect '/';
};


######################################################################################


 
1;


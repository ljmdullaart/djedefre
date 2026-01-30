
#INSTALL@ /opt/djedefre/managepages.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;
#                              
#  _ __   __ _  __ _  ___  ___ 
# | '_ \ / _` |/ _` |/ _ \/ __|
# | |_) | (_| | (_| |  __/\__ \
# | .__/ \__,_|\__, |\___||___/
# |_|          |___/    
#

our $buttonframe;
our @pagelist;
our %pagetypes;
our @realpagelist;
our $l3_showpage;
our $l2_showpage;
our $repeat_sub;

our $DEB_FRAME;
our $DEB_DB;
our $DEB_SUB;
our $DEBUG;
our $Message;

our $main_frame;
our $main_window;
our $button_frame;

my $currentpage='Pages';
my $selectedpage='Pages';
my $selectedrealpage='Pages';
my $pageselectframe;
my $realpageselectframe;
my $nDEBUG=0;

sub fill_pagelist {
	debug($DEB_SUB,"fill_pagelist");
	splice @pagelist;
	splice @realpagelist;
	push @pagelist,'Pages';
	$pagetypes{'Pages'}='none';
	push @pagelist,'top';
	$pagetypes{'top'}='l3';
	push @pagelist,'l2-top';
	$pagetypes{'l2-top'}='l2';
        my $sql = "SELECT DISTINCT item,value FROM config WHERE attribute LIKE 'page:%'";
        my $sth =  db_dosql($sql);
        while((my $p, my $t) = db_getrow()){
                push @pagelist,$p;
		$pagetypes{$p}=$t;
                push @realpagelist,$p;

        }
	db_close();
}

sub display_top_page {		# Top-page is L3 drawing of all servers and subnets
	debug($DEB_SUB,"display_top_page");
	$nDEBUG=0;
	$Message='';
	$l3_showpage='top';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	make_l3_plot($main_frame);
}

sub display_other_page {
	debug($DEB_SUB,"display_other_page");
	$nDEBUG=0;
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
print STDERR "pagetypes $pagetypes{$l3_showpage}\n";
	if ($pagetypes{$l3_showpage} eq 'l3'){
		print "display_other_page $l3_showpage L3\n";
		make_l3_plot($main_frame);
	}
	elsif ($pagetypes{$l3_showpage} eq 'l2'){
		print "display_other_page $l3_showpage L2\n";
		$l2_showpage=$l3_showpage;
		make_l2_plot($main_frame);
	}
}

my $manage_pages_change_frame;
my @managepagesgrid;
my $selected_type='l3';
my @managepg_selection;
my @managepg_options;
my @pagetypes;
$pagetypes[0]='l3';
$pagetypes[1]='l2';
my $pagename='Pages';
my $pagetype='l3';

sub manage_pages {
	debug($DEB_SUB,"manage_pages");
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	$main_frame=$main_window->Frame(
	)->pack(-side =>'top');
	my $pagemngtframe=$main_frame->Frame()->pack(-side =>'left');
	my $pagecontentframe=$main_frame->Frame()->pack(-side =>'right');

	fill_pagelist();
	my $pagelistbox=$pagemngtframe->Scrolled("Listbox",-scrollbars=>'e',-height=>20,-width=>28)->pack(-side =>'top');
	$pagelistbox->insert('end',@realpagelist);
	$pagelistbox->bind('<<ListboxSelect>>' => sub {my @sel=$pagelistbox->curselection;$pagename=$realpagelist[$sel[0]];manage_pages();});
	$pagemngtframe->Optionmenu(-variable=>\$pagetype, -options=>\@pagetypes,-width=>27)->pack(-side=>'top');
	$pagemngtframe->Entry ( -width=>32,-textvariable=>\$pagename)->pack(-side=>'top');
	my $buttonpageframe=$pagemngtframe->Frame()->pack(-side=>'top');
	$buttonpageframe->Button (
		-width=>10,
		-text=>'Set type',
		-command=>sub {
			db_dosql("UPDATE config SET value='$pagetype' WHERE attribute='page:type' AND item='$pagename'");
			db_close();
		}
	)->pack(-side=>'left');
	$buttonpageframe->Button (
		-width=>10,
		-text=>'Add page', 
		-command=>sub {
			manage_pages_add_action($pagename);
		}
	)->pack(-side=>'left');
	$buttonpageframe->Button (
		-width=>10,
		-text=>'Delete page',
		-command=>sub {
			manage_pages_del_action($pagename);
		}
	)->pack(-side=>'right');

	my @items;
	splice @items;
	db_dosql("SELECT id,name FROM server ORDER BY name");
	while ((my $id, my $name)=db_getrow()){
		push @items,"server:$id:$name";
	}
	db_close();
	db_dosql("SELECT id,nwaddress,cidr FROM subnet ORDER BY nwaddress");
	while ((my $id, my $nwaddress,my $cidr)=db_getrow()){
		push @items,"subnet:$id:$nwaddress/$cidr";
	}
	db_close();
	db_dosql("SELECT id,name FROM switch ORDER BY name");
	while ((my $id, my $name)=db_getrow()){
		push @items,"switch:$id:$name";
	}
	db_close();
	my @selected;
	splice @selected;
	db_dosql ("	SELECT server.id AS id,name FROM server
			INNER JOIN pages ON pages.item=server.id
			WHERE pages.page='$pagename' AND pages.tbl='server'
			ORDER BY name
	");
	while ((my $id, my $name)=db_getrow()){
		push @selected,"server:$id:$name";
	}
	db_close();
	db_dosql ("	SELECT subnet.id AS id,nwaddress,cidr FROM subnet
			INNER JOIN pages ON pages.item=subnet.id
			WHERE pages.page='$pagename' AND pages.tbl='switch'
			ORDER BY nwaddress
	");
	while ((my $id, my $nwaddress,my $cidr)=db_getrow()){
		push @selected,"subnet:$id:$nwaddress/$cidr";
	}
	db_close();
	db_dosql ("	SELECT switch.id AS id,name FROM switch
			INNER JOIN pages ON pages.item=switch.id
			WHERE pages.page='$pagename' AND pages.tbl='switch'
			ORDER BY name
	");
	while ((my $id, my $name)=db_getrow()){
		push @selected,"switch:$id:$name";
	}
	db_close();
	my $cbfunc=\&mgpg_selector_callback;
	selector({
		options		=> \@items,
		selected	=> \@selected,
		parent		=> $pagecontentframe,
		callback	=> $cbfunc
	});


}

sub mgpg_selector_callback {
	(my $func, my $arg,my $page)=@_;
	debug($DEB_SUB,"mgpg_selector_callback");
	(my $table, my $id, my $name)=split(':',$arg);
	my $x;
	my $y;
	if ($table ne 'switch'){
		db_dosql ("SELECT xcoord,ycoord FROM $table WHERE id=$id");
		($x,$y)=db_getrow();
		db_close();
	}
	$x=100 unless defined $x;
	$y=100 unless defined $y;
	if (defined($page)){$pagename=$page;}
	if ($func eq 'del'){
		db_dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$pagename'");
		db_close();
	}
	elsif ($func eq 'add'){
		db_dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$pagename'");
		db_dosql("INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('$pagename','$table',$id,$x,$y)");
		db_close();
	}
}

sub manage_pages_change_action {
	(my $pgname)=@_;
	debug($DEB_SUB,"manage_pages_change_action");
	#$managepg_pagename=$pgname;
	my @servers;
	my @subnets;
	splice @servers;
	splice @managepg_options;
	my $sth=db_dosql("SELECT id,name FROM server");
	while((my $id,my $name) = db_getrow()){
		$servers[$id]=$name;
		push @managepg_options,"server:$id:$name";
	}
	db_close();
	splice @subnets;
	$sth=db_dosql("SELECT id,name,nwaddress,cidr FROM subnet");
	while((my $id,my $name,my $nwaddress,my $cidr) = db_getrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		$subnets[$id]=$name;
		push @managepg_options,"subnet:$id:$name";
	}
	db_close();
	splice @managepg_selection;
	$sth=db_dosql("SELECT tbl,item FROM pages WHERE page='$pgname'");
	while((my $tbl,my $item) = db_getrow()){
		my $sname='';
		if ($tbl eq 'subnet'){
			$sname=$subnets[$item] if defined $subnets[$item];
		}
		elsif ($tbl eq 'server'){
			$sname=$servers[$item] if defined $servers[$item];
		}
		push @managepg_selection, "$tbl:$item:$sname";
	}
	db_close();
	my $cbfunc=\&mgpg_selector_callback;
	selector({
		options		=> \@managepg_options,
		selected	=> \@managepg_selection,
		parent		=> $manage_pages_change_frame,
		callback	=> $cbfunc
	});
		
}

sub manage_pages_del_action {
	(my $pgname)=@_;
	debug($DEB_SUB,"manage_pages_del_action");
	db_dosql("DELETE FROM config WHERE item='$pgname'");
	db_dosql("DELETE FROM pages  WHERE page='$pgname'");
	db_close();
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}


sub manage_pages_add_action {
	(my $pageadd)=@_;
	debug($DEB_SUB,"manage_pages_add_action");
	fill_pagelist();
	my $flag=0;
	for (@pagelist){ 
		if ($_ eq $pageadd) { $flag=1; }
	}
	if ($flag==0){
        	my $sql = "INSERT INTO config (attribute,item,value) VALUES ('page:type','$pageadd','l3')";
        	my $sth =  db_dosql($sql);
		db_close();
	}
	else {
		$Message="Page $pageadd already exists";
	}
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}
		

my $selected_page='top';

my $OLDDEBUG;
sub repeat_selected_page {
	$OLDDEBUG=$DEBUG;
	if ($nDEBUG > 2){ $DEBUG=0;}
	else {$nDEBUG++;}
	debug($DEB_SUB,"repeat_selected_page");
	db_dosql("SELECT value FROM config WHERE attribute='run:param' AND item='changed'");
	(my $changed)=db_getrow();
	while(db_getrow()){};
	db_close();
	if ($changed eq 'yes'){
		db_dosql("UPDATE config SET value='no' WHERE attribute='run:param' AND item='changed'");
		db_close();
		display_selected_page($selected_page);
	}
	$DEBUG=$OLDDEBUG;
}

sub display_selected_page {	# What to do if a page was selected from the menubar
	(my $pagename)=@_;
	debug($DEB_SUB,"display_selected_page");
	$selected_page=$pagename;
	$repeat_sub=\&repeat_selected_page;
	if ($pagename eq 'none'){ logoframe() ; }
	elsif ($pagename eq 'Pages'){ logoframe() ; }
	elsif ($pagename eq 'top'){ display_top_page ; }
	else {
		$l3_showpage=$pagename;
		display_other_page();
	}
	$selectedpage='Pages';
}

sub make_realpageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	debug($DEB_SUB,"make_realpageselectframe");
	$realpageselectframe->destroy if Tk::Exists($realpageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$realpageselectframe=$parent->Frame()->pack(-side=>'right');
	$realpageselectframe->JBrowseEntry(-variable => \$selectedrealpage, -width=>30, -choices => \@realpagelist, -height=>10)->pack();
	
}
sub make_pageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	debug($DEB_SUB,"make_pageselectframe");
	$pageselectframe->destroy if Tk::Exists($pageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$pageselectframe=$parent->Frame()->pack(-side=>'right');
	$pageselectframe->Optionmenu(
		-variable	=> \$selectedpage,
		-width		=> 15,
		-options	=> \@pagelist,
		-command	=> sub { display_selected_page ($selectedpage);}
	)->pack();
	
}


1;

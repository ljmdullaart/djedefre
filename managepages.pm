
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

#-----------------------------------------------------------------------
# Name        : fill_pagelist
# Purpose     : Fill the pagelist that is used for the drop-down menu
# Arguments   : none
# Returns     : Hashref representing one row, or undef if no rows left.
# Globals     : @pagelist, @realpagelist, %pagetypes
# Side-effects: 
# Notes       : 
#-----------------------------------------------------------------------
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
	query_pagelist();
	while (my $r=sql_getrow()){
		my $p=$r->{item};
		my $t=$r->{value};
                push @pagelist,$p;
		$pagetypes{$p}=$t;
                push @realpagelist,$p;

        }
}

#-----------------------------------------------------------------------
# Name        : display_top_page
# Purpose     : Display the page "top"
# Arguments   : 
# Returns     : 
# Globals     : $l3_showpage,$main_frame,$main_window
# Side-effects: 
# Notes       :  Top-page is L3 drawing of all servers and subnets
#-----------------------------------------------------------------------
sub display_top_page {
	debug($DEB_SUB,"display_top_page");
	$nDEBUG=0;
	$Message='';
	$l3_showpage='top';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	make_l3_plot($main_frame);
}

#-----------------------------------------------------------------------
# Name        : display_other_page
# Purpose     : Display all other pages
# Arguments   : 
# Returns     : 
# Globals     : $l3_showpage,$main_frame,$main_window
# Side-effects: 
# Notes       :  Top-page is L3 drawing of all servers and subnets
#-----------------------------------------------------------------------
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
	if ($pagetypes{$l3_showpage} eq 'l3'){
		make_l3_plot($main_frame);
	}
	elsif ($pagetypes{$l3_showpage} eq 'l2'){
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
	$main_frame=$main_window->Frame()->pack(-side =>'top');
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
			query_set_pagetype($pagename,$pagetype);
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

	query_server();
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		push @items,"server:$id:$name";
	}

	query_subnet();
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $nwaddress=$r->{nwaddress};
		my $cidr=$r->{cidr};
		push @items,"subnet:$id:$nwaddress/$cidr";
	}

	query_switch();
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		push @items,"switch:$id:$name";
	}
	my @selected;
	splice @selected;
	query_obj_on_page($pagename,'server');
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		push @selected,"server:$id:$name";
	}
	query_obj_on_page($pagename,'subnet');
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		my $nwaddress=$r->{nwaddress};
		my $cidr=$r->{cidr};
		push @selected,"subnet:$id:$nwaddress/$cidr";
	}
	query_obj_on_page($pagename,'switch');
	while (my $r=sql_getrow()){
		my $id=$r->{id};
		my $name=$r->{name};
		push @selected,"switch:$id:$name";
	}
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
		($x,$y)=query_coordinates('top',$table,$id);
	}
	$x=100 unless defined $x;
	$y=100 unless defined $y;
	if (defined($page)){$pagename=$page;}
	if ($func eq 'del'){
		query_pages_del_obj($pagename,$table,$id);
	}
	elsif ($func eq 'add'){
		query_pages_del_obj($pagename,$table,$id);
		query_pages_add_obj($pagename,$table,$id,$x,$y);
	}
}

sub manage_pages_change_action {
	(my $pgname)=@_;
	debug($DEB_SUB,"manage_pages_change_action");
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
	if ($pagename eq 'none'){ logoframe($main_frame) ; }
	elsif ($pagename eq 'Pages'){ logoframe($main_frame) ; }
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

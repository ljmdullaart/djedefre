
#                              
#  _ __   __ _  __ _  ___  ___ 
# | '_ \ / _` |/ _` |/ _ \/ __|
# | |_) | (_| | (_| |  __/\__ \
# | .__/ \__,_|\__, |\___||___/
# |_|          |___/    
#

our $buttonframe;
our @pagelist;
our @realpagelist;
our $l3_showpage;
my $currentpage='none';
my $selectedpage='none';
my $selectedrealpage='none';
my $pageselectframe;
my $realpageselectframe;

sub fill_pagelist {
	splice @pagelist;
	splice @realpagelist;
	push @pagelist,'none';
	push @pagelist,'top';
        my $sql = "SELECT DISTINCT item FROM config WHERE attribute LIKE 'page:%'";
        my $sth =  db_dosql($sql);
        while((my $p) = db_getrow()){
                push @pagelist,$p;
                push @realpagelist,$p;

        }
}

sub display_top_page {		# Top-page is L3 drawing of all servers and subnets
	$Message='';
	$l3_showpage='top';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame()->pack(-side =>'top');
	make_l3_plot($main_frame);
}

sub display_other_page {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"11 Create main_frame");
	$main_frame=$main_window->Frame(
		-height      => 1005,
		-width       => 1505
	)->pack(-side =>'top');
	make_l3_plot($main_frame);
}

my $manage_pages_change_frame;
my @managepagesgrid;
my $selected_type='l3';
my @managepg_selection;
my @managepg_options;
sub manage_pages {
	$Message='';
	$main_frame->destroy if Tk::Exists($main_frame);
	debug ($DEB_FRAME,"12 Create main_frame for manage pages");
	$main_frame=$main_window->Frame(
	)->pack(-side =>'top');
	for my $i (0 .. 5){
		for my $j (0 .. 4){
			$managepagesgrid[$i][$j]=$main_frame->Frame();
		}
	}
	for my $i (0 .. 5){
		Tk::grid(@{$managepagesgrid[$i]});
	}
	my @pagetypes;
	$pagetypes[0]='l3';
	$pagetypes[1]='l2';
	my $pagename;
	$managepagesgrid[1][0]->Entry ( -width=>32,-textvariable=>\$pagename)->pack(-side=>'left');
	$managepagesgrid[1][1]->Button ( -width=>10,-text=>'Add page', -command=>sub {$Message='';manage_pages_add_action($pagename);})->pack(-side=>'left');
	make_realpageselectframe($managepagesgrid[1][2]);
	$managepagesgrid[1][3]->Label(-text=>'Select a page')->pack();
	$managepagesgrid[2][2]->JBrowseEntry(
		-variable => \$selected_type, 
		-width=>30, 
		-choices => \@pagetypes, 
		-height=>10
	)->pack();
	$managepagesgrid[2][3]->Button ( -width=>10,-text=>'Change Type', -command=>sub {
		db_dosql("UPDATE config SET value='$selected_type' WHERE attribute='page:type' AND item='$selectedrealpage'");
	})->pack();
	$managepagesgrid[4][3]->Button ( -width=>10,-text=>'Delete page', -command=>sub {
		$Message='';
		manage_pages_del_action($selectedrealpage);
		$selectedrealpage='none';
	})->pack(-side=>'right');
}

sub mgpg_selector_callback {
	(my $func, my $arg)=@_;
	(my $table, my $id, my $name)=split(':',$arg);
	db_dosql ("SELECT xcoord,ycoord FROM $table WHERE id=$id");
	(my $x,my $y)=db_getrow();
	if ($func eq 'del'){
		db_dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$managepg_pagename'");
	}
	elsif ($func eq 'add'){
		db_dosql("DELETE FROM pages WHERE tbl='$table' AND item=$id AND page='$managepg_pagename'");
		db_dosql("INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('$managepg_pagename','$table',$id,$x,$y)");
	}
}

sub manage_pages_change_action {
	(my $pgname)=@_;
	$managepg_pagename=$pgname;
	my @servers;
	my @subnets;
	splice @servers;
	splice @managepg_options;
	my $sth=db_dosql("SELECT id,name FROM server");
	while((my $id,my $name) = db_getrow()){
		$servers[$id]=$name;
		push @managepg_options,"server:$id:$name";
	}
	splice @subnets;
	my $sth=db_dosql("SELECT id,name,nwaddress,cidr FROM subnet");
	while((my $id,my $name,my $nwaddress,my $cidr) = db_getrow()){
		$name="$nwaddress/$cidr" unless defined $name;
		$subnets[$id]=$name;
		push @managepg_options,"subnet:$id:$name";
	}
	splice @managepg_selection;
	my $sth=db_dosql("SELECT tbl,item FROM pages WHERE page='$pgname'");
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
	db_dosql("DELETE FROM config WHERE item='$pgname'");
	db_dosql("DELETE FROM pages  WHERE page='$pgname'");
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}


sub manage_pages_add_action {
	(my $pageadd)=@_;
	fill_pagelist();
	my $flag=0;
	for (@pagelist){ 
		if ($_ eq $pageadd) { $flag=1; }
	}
	if ($flag==0){
        	my $sql = "INSERT INTO config (attribute,item,value) VALUES ('page:type','$pageadd','l3')";
        	my $sth =  db_dosql($sql);
	}
	else {
		$Message="Page $pageadd already exists";
	}
	fill_pagelist();
	make_pageselectframe( $button_frame);
	manage_pages();
}
		

sub display_selected_page {	# What to do if a page was selected from the menubar
	(my $pagename)=@_;
	if ($pagename eq 'none'){ logoframe() ; }
	elsif ($pagename eq 'top'){ display_top_page ; }
	else {
		$l3_showpage=$pagename;
		display_other_page();
	}
}

sub make_realpageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	$realpageselectframe->destroy if Tk::Exists($realpageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$realpageselectframe=$parent->Frame()->pack(-side=>'right');
	$realpageselectframe->JBrowseEntry(-variable => \$selectedrealpage, -width=>30, -choices => \@realpagelist, -height=>10)->pack();
	
}
sub make_pageselectframe {	# drop-down in the menu-bar
	(my $parent)=@_;
	$pageselectframe->destroy if Tk::Exists($pageselectframe);
	fill_pagelist();
	debug ($DEB_FRAME,"18 Create pageselectframe");
	$pageselectframe=$parent->Frame()->pack(-side=>'right');
	$pageselectframe->Label ( -anchor => 'w',-width=>10,-text=>'View page', -anchor=>'e')->pack(-side=>'left');
	$pageselectframe->JBrowseEntry(-variable => \$selectedpage, -width=>25, -choices => \@pagelist, -height=>10, -browsecmd => sub { display_selected_page ($selectedpage);} )->pack();
	
}

1;

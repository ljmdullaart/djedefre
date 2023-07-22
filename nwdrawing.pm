#!/usr/bin/perl

use strict;
use warnings;

use Tk;
use Tk::PNG;
use Tk::Photo;
use Image::Magick;
use Tk::JBrowseEntry;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;
use Data::Dumper;

our %config;
our @colors ;

require selector;

my $NW_DEBUG=1;

sub nw_debug {
	(my $str)=@_;
	if ($NW_DEBUG>0){
		print "$str\n";
	}
}


#######################################################################
#	call-back
#######################################################################

sub dump {
	print Dumper(@_);
}

my $nw_cbmove=\&dump;
my $nw_cbtype=\&dump;
my $nw_cbname=\&dump;
my $nw_cbmerge=\&dump;
my $nw_cbdelete=\&dump;	# delete completely
my $nw_cbpage=\&dump;
my $nw_cbcolor=\&dump;


our @pagelist;
our @realpagelist;

sub nw_callback {
	(my $type, my $func)=@_;
	if (0==1) {}
	elsif ($type eq 'color'){ $nw_cbcolor=$func; }
	elsif ($type eq 'delete'){ $nw_cbdelete=$func; }
	elsif ($type eq 'merge'){ $nw_cbmerge=$func; }
	elsif ($type eq 'move'){ $nw_cbmove=$func; }
	elsif ($type eq 'name'){ $nw_cbname=$func; }
	elsif ($type eq 'page'){ $nw_cbpage=$func; }
	elsif ($type eq 'type'){ $nw_cbtype=$func; }
}


#######################################################################
# Tk objects hierarchy
#######################################################################

my $nw_totalframe;
	my $nw_canvas_frame;	# Created with nw_frame_canvas_create($parent), destroyed with nw_frame_canvas_destroy()
		my $nw_canvas;
	my $nw_info_frame;
		my $nw_info_top;
			my $nw_info_inside;
	my $nw_button_frame;

sub nw_frame {
	(my $parent)=@_;
	$nw_totalframe=$parent;
	$nw_canvas_frame=$nw_totalframe->Frame()->pack(-side =>'left');
	$nw_info_frame=$nw_totalframe->Frame()->pack(-side =>'right');
	nw_frame_canvas_create($nw_canvas_frame);
	nw_drawlines();
	nw_drawobjects();
	$nw_info_frame->Label(-text=>'info', -width=>50)->pack();
}
#######################################################################
# Package variables
#######################################################################
my $Message='';           			# message in the info-frame

my $canvas_xsize=1500;			  # default x-suize of the network drawnin
my $canvas_ysize=1200;			  # default y-suize of the network drawning
#                                
#   ___ __ _ _ ____   ____ _ ___ 
#  / __/ _` | '_ \ \ / / _` / __|
# | (_| (_| | | | \ V / (_| \__ \
#  \___\__,_|_| |_|\_/ \__,_|___/
# 



#######################################################################
# Canvas frame create and destroy
#######################################################################
my $lnw_canvas_frame;
sub nw_frame_canvas_redo{
	nw_frame_canvas_destroy();
	nw_frame_canvas_create($nw_canvas_frame);
	nw_drawlines();
	nw_drawobjects();
}
sub nw_frame_canvas_destroy {
	$lnw_canvas_frame->destroy if Tk::Exists($nw_canvas_frame);
}

sub nw_frame_canvas_create {
	(my $parent)=@_;
	$lnw_canvas_frame->destroy if Tk::Exists($lnw_canvas_frame);
	$lnw_canvas_frame=$parent->Frame(
		-borderwidth => 3,
	)->pack();
	$nw_canvas = $lnw_canvas_frame->Canvas(
		-width      => $canvas_xsize,
		-height     => $canvas_ysize,
	)->pack;
	$nw_canvas->bind( 'draggable', '<1>'                   => sub{ nw_drag_start();});
	$nw_canvas->bind( 'draggable', '<B1-Motion>'           => sub{ nw_drag_during ();});
	$nw_canvas->bind( 'draggable', '<Any-ButtonRelease-1>' => sub{ nw_drag_end ();});
}


sub nw_frame_canvas_export(){
	if (defined $nw_canvas){
		$nw_canvas->postscript(-file => "djedefre_network.ps");
	}
}



#######################################################################
#  logo's for the objects
#######################################################################

my %nw_logos;
	
my @logolist;
sub nw_read_logos {
	(my $parent,my $image_directory)=@_;
	# Get the logo-types in a hash
	my @logo_files=read_dir($image_directory);
	for (@logo_files){
		if (/logo_(.*).png/){
			my $fle="$image_directory/$_";
			if (defined $fle){
				$nw_logos{$1} = $parent->Photo(-file=>$fle);
			}
			else {
				print "LOGO- undefined $fle \n";
			}
		}
	}
	@logolist=sort  keys(%nw_logos);
}

#######################################################################
# The objects: networks, servers etc. Anything with a logo
#######################################################################

my @objects;
my @refobj;

sub nw_objects {
	(my @obj)=@_;
	for my $i (0 .. $#obj){
		push @objects,$obj[$i];
		my $id=$obj[$i]->{'newid'};
		$refobj[$id]=$i;
	}
}

sub nw_del_objects {
	splice @objects;
}

sub nw_move_object {
	(my $id,my $x,my $y)=@_;
	for my $i (0 .. $#objects){
		if ($id == $objects[$i]->{'newid'}){
			$objects[$i]->{'x'}=$x;
			$objects[$i]->{'y'}=$y;
		}
	}
}
sub nw_logo_object {
	(my $id,my $logo)=@_; 
	for my $i (0 .. $#objects){
		if ($id == $objects[$i]>{'newid'}){
			$objects[$i]->{'logo'}=$logo;
		}
	}
	
}
sub nw_name_object {
	(my $id,my $name)=@_; 
	for my $i (0 .. $#objects){
		if ($id == $objects[$i]>{'newid'}){
			$objects[$i]->{'name'}=$name;
		}
	}
}


#######################################################################
#  lines between objects
#######################################################################
	
my @lines;

sub nw_lines {
	(my @lns)=@_;
	for my $i (0 .. $#lns){
		push @lines,$lns[$i];
	}

}

sub nw_del_lines{
	splice @lines;
}

#######################################################################
# do the drawing
#######################################################################
my @text_draw;

sub nw_drawlines {
	for my $i (0 .. $#lines){
		my $obj1=$lines[$i]->{'from'};
		my $obj2=$lines[$i]->{'to'};
		my $linetype=$lines[$i]->{'type'};
		my $obj1_idx=$refobj[$obj1];
		my $obj2_idx=$refobj[$obj2];
		(my $x1,my $x2,my $y1,my $y2)=(0,0,0,0);
		for my $j (0 .. $#objects){
			if (defined $objects[$j]->{'newid'} ){
				if ($objects[$j]->{'newid'}==$obj1){
					$x1=$objects[$j]->{'x'};
					$y1=$objects[$j]->{'y'};
				}
				if ($objects[$j]->{'newid'}==$obj2){
					$x2=$objects[$j]->{'x'};
					$y2=$objects[$j]->{'y'};
				}
			}
		}
		my $line;
		if ($linetype eq 'vbox'){
			$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{'line:color:vbox'},-width => 15,-tags=>['scalable']);
			$lines[$i]->{'draw'}=$line;
		}
	}
	for my $i (0 .. $#lines){
		my $obj1=$lines[$i]->{'from'};
		my $obj2=$lines[$i]->{'to'};
		my $linetype=$lines[$i]->{'type'};
		my $obj1_idx=$refobj[$obj1];
		my $obj2_idx=$refobj[$obj2];
		(my $x1,my $x2,my $y1,my $y2)=(0,0,0,0);
		for my $j (0 .. $#objects){
			if (defined $objects[$j]->{'newid'} ){
				if ($objects[$j]->{'newid'}==$obj1){
					$x1=$objects[$j]->{'x'};
					$y1=$objects[$j]->{'y'};
				}
				if ($objects[$j]->{'newid'}==$obj2){
					$x2=$objects[$j]->{'x'};
					$y2=$objects[$j]->{'y'};
				}
			}
		}
		my $line;
		my $linecolor;
		if ($linetype =~/^([0-9][0-9]*)$/){
			my $num=$1;
			$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{"line:color:vlan$num"},-tags=>['scalable']);
			$lines[$i]->{'draw'}=$line;
		}
		elsif ($linetype=~/^vlan/){
			$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{"line:color:$linetype"},-tags=>['scalable']);
			$lines[$i]->{'draw'}=$line;
		}
		elsif ($linetype=~/^vbox/){
			$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{"line:color:$linetype"},-tags=>['scalable']);
			$lines[$i]->{'draw'}=$line;
		}
		else {
			$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $linetype,-tags=>['scalable']);
			$lines[$i]->{'draw'}=$line;
		}
	}
}

sub nw_undrawlines {
	for my $i (0 .. $#lines){
		if (defined $lines[$i]->{'draw'}){
			if ($lines[$i]->{'draw'}>-1){
				$nw_canvas->delete($lines[$i]->{'draw'});
			}
		}
		$lines[$i]->{'draw'}=-1;
	}
}
	
sub nw_drawobjects {
	for my $i (0 .. $#objects){
		my $x=$objects[$i]->{'x'};
		my $y=$objects[$i]->{'y'};
		my $logo=$objects[$i]->{'logo'};
		my $name=$objects[$i]->{'name'};
		my $objectdraw=$nw_canvas->createImage($x, $y, -image=>$nw_logos{$logo} ,-tags=>['draggable','scalable']);
		$objects[$i]->{'draw'}=$objectdraw;
		$objects[$i]->{'namedraw'}=$nw_canvas->createText($x,$y+25,-text=>$name,-tags=>['scalable']);
		
	}
}
	
sub nw_undrawobjects {
	for my $i (0 .. $#objects) {
		$nw_canvas->delete($objects[$i]->{'draw'});
		$nw_canvas->delete($objects[$i]->{'namedraw'});
	}
}

sub nw_clearall {
	nw_undrawobjects();
	nw_undrawlines();
	$nw_canvas->delete('all');
}
sub nw_drawall {
	nw_drawlines();
	nw_drawobjects();
}

#######################################################################
#	Dragging
#######################################################################
my %draginfo;
my $dragobject;
my $dragindex;
my $dragid;
my $dragname;
sub nw_drag_start {
	my $e = $nw_canvas->XEvent;
	## get the screen position of the initial button press...
	my ( $sx, $sy ) = ( $e->x, $e->y,,, );
	## get the canvas position...
	my ( $cx, $cy ) = ( $nw_canvas->canvasx($sx), $nw_canvas->canvasy($sy) );
	# get the clicked item...
	my $id = $nw_canvas->find( 'withtag', 'current' );
	my ( $x1, $y1, $x2, $y2 ) = $nw_canvas->bbox($id);
	# set up the draginfo...
	$draginfo{id}  = $id;
	my @idarr=@{$id};
	$dragid=$idarr[0];
	for ($dragindex=0; ($dragindex<1+$#objects)&&($objects[$dragindex]->{'newid'}!=$dragid);$dragindex++){};
	$draginfo{startx} = $draginfo{lastx} =$cx;
	$draginfo{starty} = $draginfo{lasty} =$cy;
	for my $i (0 .. $#objects){
		if (! defined $objects[$i]->{'draw'}){print "Object without draw\n"}
		elsif (! defined $dragid){print "No dragid\n"}
		elsif ($objects[$i]->{'draw'}==$dragid){
			$dragobject=$i;
		}
	}
	my $name=$objects[$dragobject]->{'name'};
	$dragname=$objects[$dragobject]->{'namedraw'};
	nw_show_info_redo($dragobject);
}

sub nw_drag_during {
	my $e = $nw_canvas->XEvent;
	# get the screen position of the move...
	my ( $sx, $sy ) = ( $e->x, $e->y,,, );
	# get the canvas position...
	my ( $cx, $cy ) = ( $nw_canvas->canvasx($sx), $nw_canvas->canvasy($sy) );
	# get the amount to move...
	my $dx; my $dy;
	( $dx, $dy ) = ( $cx - $draginfo{lastx}, $cy - $draginfo{lasty} );
	# move it...
	$nw_canvas->move( $draginfo{id}, $dx, $dy );
	$nw_canvas->move($dragname, $dx, $dy );
	#$nw_canvas->move($nw_statusid[$dragindex], $dx, $dy );
	# update last position
	$draginfo{lastx} = $cx;
	$draginfo{lasty} = $cy;
	$objects[$dragobject]->{'x'}=$cx;
	$objects[$dragobject]->{'y'}=$cy;
	my ( $x1, $y1, $x2, $y2 ) = $nw_canvas->bbox( $draginfo{id} );
	nw_undrawlines();
	nw_drawlines();
}
#
sub nw_drag_end {
	# upon drag end, check for valid position and act accordingly...
	my @tags = $nw_canvas->gettags( $draginfo{id} );
	my $nme=$objects[$dragobject]->{'name'};
	my $cx=$objects[$dragobject]->{'x'};
	my $cy=$objects[$dragobject]->{'y'};
	my $table=$objects[$dragobject]->{'table'};
	my $id=$objects[$dragobject]->{'id'};
	$nw_cbmove->($table,$id,$cx,$cy);
	nw_frame_canvas_redo;
}

#        my $nw_info_frame;
#                my $nw_info_top;

#  _        __          __                          
# (_)_ __  / _| ___    / _|_ __ __ _ _ __ ___   ___ 
# | | '_ \| |_ / _ \  | |_| '__/ _` | '_ ` _ \ / _ \
# | | | | |  _| (_) | |  _| | | (_| | | | | | |  __/
# |_|_| |_|_|  \___/  |_| |_|  \__,_|_| |_| |_|\___|
#    
# our @realpagelist;
my $typechoice;

sub nw_show_info_redo {
	my ($obj)=@_;
	nw_show_info_destroy();
	nw_show_info_create($nw_info_frame,$obj);
}

sub nw_show_info_destroy {
	$nw_info_inside->destroy if Tk::Exists($nw_info_inside);
}
	
sub nw_show_info_create {
	(my $parent, my $objidx)=@_;
	my @netcolors;
	my $local_frame;
	$nw_info_inside=$parent->Frame(-borderwidth => 3,-height=>1000 )->pack(-side=>'top' );
	my $name=$objects[$objidx]->{'name'};
	my $merge='';
	my $table=$objects[$objidx]->{'table'};
	my $type=$objects[$objidx]->{'logo'};
	my $id=$objects[$objidx]->{'id'};
	my $drawid=$objects[$objidx]->{'drawid'};
	if ($table eq 'server'){
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>40,-text=>'Server information')->pack(-side=>'left');
		my $os=$objects[$objidx]->{'os'};
		my $ostype=$objects[$objidx]->{'ostype'};
		my $processor=$objects[$objidx]->{'processor'};
		my $memory=$objects[$objidx]->{'memory'};
		my $options;
		if (defined $objects[$objidx]->{'options'}) {
			$options=$objects[$objidx]->{'options'};
		}
		else {
			$options='';
		}
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {$Message='';nw_set_name($name,$id,$table);nw_frame_canvas_redo() })->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
		$typechoice=$objects[$objidx]->{'logo'};
		$local_frame->JBrowseEntry(-variable => \$typechoice, -width=>25, -choices => \@logolist, -height=>10, -browsecmd => sub { nw_set_type($typechoice,$id,$table,$drawid);nw_frame_canvas_redo() } )->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'OS type')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$ostype)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'OS')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$os,-wraplength =>200)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Interfaces')->pack(-side=>'left');
		my @ifarray=@{$objects[$objidx]{interfaces}};
		my @pgarray=@{$objects[$objidx]{pages}};
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$ifarray[0])->pack(-side=>'right');
		for (my $i=1; $i<=$#ifarray; $i++){
			$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'  ')->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$ifarray[$i])->pack(-side=>'right');
		}
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Processor')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$processor,-wraplength =>200)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Memory')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$memory)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Merge', -command=>sub {$Message='';nw_set_merge($name,$id,$table,$merge);nw_frame_canvas_redo() })->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$merge)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		selector({
			options  	=> \@realpagelist,
			selected	=> \@pgarray,
			parent  	=> $local_frame,
			callback 	=> sub {(my $act, my $pg)=@_; nw_page_change($name,$id,$table,$act,$pg);},
			height  	=> 5,
			width   	=> 40,
			title    	=> 'On pages'
		});

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Delete', -command=>sub {$Message='';nw_delete_object($name,$id,$table);nw_frame_canvas_redo() })->pack(-side=>'left');
		
	}
	elsif ($table eq 'subnet'){
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>40,-text=>'subnet information')->pack(-side=>'left');
		my $nwaddress=$objects[$objidx]->{'nwaddress'};
		my $cidr=$objects[$objidx]->{'cidr'};
		$netcolors[$id]=$objects[$objidx]->{'color'};
		$netcolors[$id]='black' unless defined $netcolors[$id];
		my $subn;
		my @pgarray=@{$objects[$objidx]{pages}};
		if (defined $cidr){ $subn="$nwaddress / $cidr";}
		else {  $subn=$nwaddress; }		# for example: nwaddress=Internet
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {$Message='';nw_set_name($name,$id,$table);})->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>'Subnet')->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Subnet')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$subn)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		selector({
			options  	=> \@realpagelist,
			selected	=> \@pgarray,
			parent  	=> $local_frame,
			callback 	=> sub {(my $act, my $pg)=@_; nw_page_change($name,$id,$table,$act,$pg);},
			height  	=> 5,
			width   	=> 40,
			title    	=> 'On pages'
		});

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label(-text=>'Color',-width=>20)->pack(-side=>'left');
		my $this=$local_frame->Label(-text=>' ',-width=>5, -bg => $netcolors[$id])->pack(-side=>'left');
		$local_frame->Optionmenu(
			-variable       => \$netcolors[$id],
			-options        => [@colors],
			-width          => 30,
			-command        => sub {
				$this->configure(-bg=>$netcolors[$id]);
				nw_color_net($name,$id,$table,$netcolors[$id]);
			}
		)->pack(-side=>'left');
			
			
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Delete', -command=>sub {$Message='';nw_delete_object($name,$id,$table);nw_frame_canvas_redo() })->pack(-side=>'left');
	}
	elsif ($table eq 'switch'){
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>40,-text=>'Switch information')->pack(-side=>'left');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {$Message='';nw_set_name($name,$id,$table);})->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');
		my @arr=@{$objects[$objidx]->{'connected'}};
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>40,-text=>'Connections')->pack(-side=>'left');
		for (@arr){
			(my $port,my $to_tbl,my $toname)=split ':';
			$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
			$local_frame->Label ( -anchor => 'w',-width=>20,-text=>"port $port")->pack(-side=>'left');
			$local_frame->Label ( -anchor => 'w',-width=>20,-text=>$toname)->pack(-side=>'right');
		}
			
	}
}

sub nw_set_type {
	(my $tpchoice,my $id,my $table,my $drawid)=@_;
	$nw_cbtype->($table,$id,$tpchoice);

}

sub nw_set_merge {
	(my $name,my $id,my $table,my $merge)=@_;
	$nw_cbmerge->($table,$id,$name,$merge);
}

sub nw_set_name {
	(my $name,my $id,my $table)=@_;
	$nw_cbname->($table,$id,$name);
}

sub nw_color_net {
	(my $name,my $id,my $table,my $color)=@_;
	$nw_cbcolor->($table,$id,$color);
}
	
sub nw_delete_object {
	(my $name,my $id,my $table)=@_;
	$nw_cbdelete->($table,$id,$name);
}
	
sub nw_page_change {
	(my $name,my $id,my $table,my $action,my $page)=@_;
	$nw_cbpage->($table,$id,$name,$action,$page);
}

1;

#!/usr/bin/perl
#INSTALL@ /opt/djedefre/nwdrawing.pm
#INSTALLEDFROM verlaine:/home/ljm/src/djedefre

use strict;
use warnings;

use Tk;
use Tk::PNG;
use Tk::Photo;
use Tk::Checkbox;
use Image::Magick;
use Tk::JBrowseEntry;
use File::Spec;
use File::Slurp;
use File::Slurper qw/ read_text /;
use File::HomeDir;
use Data::Dumper;
use List::Util qw(first);

our %config;
our @colors;
our @devicetypes;
our $locked;

require selector;

my $NW_DEBUG=1;

sub nw_debug {
	(my $str)=@_;
	if ($NW_DEBUG>0){
		print "$str\n";
	}
}

my @usedlocations;

our $showlabels;

#######################################################################
#	Typical use
#######################################################################
#
# nw_del_objects();
#                         delete all the existing objects, if any
# nw_del_lines();
#                         delete all the existing lines, if any
# nw_objects(@nw_obj);
#                         create new objects for the drawing
# nw_lines(@nw);
#                         create new lines for the drawing
# nw_frame($parent_frame);
#                         create the drawing in the parent_frame
# nw_callback ('callback-type',\&callback_function);
#                         Set call-backs for the different call-back types
# 
#######################################################################
#	call-back
#######################################################################
# 
# Call-back functions are called if something important changes in the network
# drawing. Callbacks are set with a call to nw_callback($type,$func).
# $func is a function, for example \&function)name.
# $type is from the following table:
#
# type          arguments                  what
#
# color         table,id. color            The color of id in table is changer to color
# delete        table,id, name             The oblect with the id=id must be deleted from the table table.
# devicetype    table,id,tpchoice          The devicetype id in table is set to tpchoice
# merge         table,id,name,merge        Mergs id=id with merge. Merge can be an ID, a name etc.
# move          table,id,cx,cy             Move object with id to cx, cy.
# name          table,id, name             Give the object id a new name
# page          table,id,name,action,page  action='add' or 'del'. Remove or add the object from a page.
# type          table,id,tpchoice          Set the object's type to tpchoice.
#
# table is the table in the database. This may be subnet,server, clpud etc.
#
#######################################################################
#	Objects
#######################################################################
# Objects are placed in an array of hashes. The objects are created with
# nw_objects(@nw_obj);
#
# The hashes contain the following fields:
#  push @nw_obj, {
#          newid   => $id*$qobjtypes+$objtsubnet,    # always present; must be unique in the array
#          id      => $id,                           # always present; is the id that is used in the callback
#          x       => $x,                            # always present; x-coordinate of the object
#          y       => $y,                            # always present; y-coordinate of the object,
#          logo    => 'subnet',                      # always present; logo used for the object
#          name    => $name,                         # always present; name used for the object
#          table   => 'subnet',                      # always present; table where the object is stored. (table, id) is unique in the array
#          pages   => @pageslist,                    # always present; list of pages where the object is displayed. (push @{$l3_obj[$i]{pages}},'pagename')
#          nwaddress=> $nwaddress,                   # present if table='subnet'; network address of the subnet
#          cidr    => $cidr                          # present if table='subnet'; CIDR-bits of the subnet
#          color   => $color                         # present if table='subnet'; color for the subnet.
#          status  => $status,                       # present if type=server; status of the server ('up', 'down','excluded')
#          options => $options,                      # present if type=server; Possible options, separated by ';'; only vboxhost:$id is used.
#          ostype  => $ostype,                       # present if type=server; os-type
#          os      => $os,                           # present if type=server; detailed OS data
#          processor => $processor,                  # present if type=server; processor type if known
#          memory  => $memory,                       # present if type=server; quantity of memory
#          devicetype => $devicetype,                # present if type=server; device-type (server, network, nas, ....)
#          interfaces=> @if_list                     # present if type=server; list of strings "interface-name ipv4address
#          vendor  => $vendor,                       # present if type=cloud; vendor/provider of the service
#          service => $service                       # present if type=cloud; service provided via this cloud
#  }
#######################################################################
#	Lines
#######################################################################
# Lines are an array of hashes. The lines are set with
#   nw_lines(@l3_line);
#
# The hashes contain the following:
# push @l3_line, {
#    from    => $newid1,
#    to      => $newid2,
#    type    => $color
# }

#            _ _ _                _        
#   ___ __ _| | | |__   __ _  ___| | _____ 
#  / __/ _` | | | '_ \ / _` |/ __| |/ / __|
# | (_| (_| | | | |_) | (_| | (__|   <\__ \
#  \___\__,_|_|_|_.__/ \__,_|\___|_|\_\___/
#   

sub dump {
	print Dumper(@_);
}

my $nw_cbmove=\&dump;
my $nw_cbtype=\&dump;
my $nw_cbdevicetype=\&dump;
my $nw_cbname=\&dump;
my $nw_cbmerge=\&dump;
my $nw_cbdelete=\&dump;	# delete completely
my $nw_cbpage=\&dump;
my $nw_cbcolor=\&dump;

my $last_info='';

our @pagelist;
our @realpagelist;

sub nw_callback {
	(my $type, my $func)=@_;
	if (0==1) {}
	elsif ($type eq 'color'){ $nw_cbcolor=$func; }
	elsif ($type eq 'delete'){ $nw_cbdelete=$func; }
	elsif ($type eq 'devicetype'){ $nw_cbdevicetype=$func; }
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
	if ($last_info eq ''){
		$nw_info_frame->Label(-text=>'info', -width=>50)->pack();
	}
	else {
		nw_show_info_redo($last_info)
	}
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
	my $local_frame=$lnw_canvas_frame->Frame()->pack(-side=>'top');
	$local_frame->Label(-text=>'Labels')->pack(-side=>'left');
	$local_frame->Radiobutton (-text=>'On ',-value=>1,-variable=>\$showlabels,-command => sub { nw_frame_canvas_redo();})->pack(-side=>'right');
	$local_frame->Radiobutton (-text=>'Off',-value=>0,-variable=>\$showlabels,-command => sub { nw_frame_canvas_redo();})->pack(-side=>'right');
	$nw_canvas = $lnw_canvas_frame->Canvas(
		-width      => $canvas_xsize,
		-height     => $canvas_ysize,
	)->pack(-side=>'bottom');
	$nw_canvas->bind( 'draggable', '<1>'                   => sub{ nw_drag_start();$locked=0;});
	$nw_canvas->bind( 'draggable', '<3>'                   => sub{ nw_drag_start();});
	$nw_canvas->bind( 'draggable', '<B1-Motion>'           => sub{ nw_drag_during ();});
	$nw_canvas->bind( 'draggable', '<Any-ButtonRelease-1>' => sub{ nw_drag_end ();$locked=0;});
}


sub nw_frame_canvas_export(){
	if (defined $nw_canvas){
		$nw_canvas->postscript(-file => "djedefre_network.ps");
	}
}



#######################################################################
#  logo's for the objects
#######################################################################

our %nw_logos;
	
our @logolist;
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
my @labelloc;

sub nw_drawlines {
	splice @labelloc;
	for my $i (0 .. $#lines){
		my $obj1=$lines[$i]->{'from'};
		my $obj2=$lines[$i]->{'to'};
		my $linetype=$lines[$i]->{'type'};
		my $obj1_idx=$refobj[$obj1];
		my $obj2_idx=$refobj[$obj2];
		my $tolabel='';
		my $fromlabel='';
		if(defined $lines[$i]->{'fromlabel'}){$fromlabel=$lines[$i]->{'fromlabel'};}
		if(defined $lines[$i]->{'tolabel'}){$tolabel=$lines[$i]->{'tolabel'};}
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
		my $xlfrom=int(4*$x1/5+$x2/5);
		my $ylfrom=int(4*$y1/5+$y2/5);
		my $xlto=int(4*$x2/5+$x1/5);
		my $ylto=int(4*$y2/5+$y1/5);
		while (grep(/^$xlfrom:$ylfrom$/,@labelloc)){
			$ylfrom=$ylfrom+15;
		}
		while (grep(/^$xlto:$ylto$/,@labelloc)){
			$ylto=$ylto+15;
		}
		push @labelloc,"$xlfrom:$ylfrom";
		push @labelloc,"$xlto:$ylto";
		
		$x1=0 unless defined $x1;
		$y1=0 unless defined $y1;
		$x2=0 unless defined $x2;
		$y2=0 unless defined $y2;
		if (($x1*$y1>0) &&($x2*$y2>0)){
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
				$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{"line:color:$linetype"},-width => 15,-tags=>['scalable']);
				$lines[$i]->{'draw'}=$line;
			}
			elsif (defined ($config{"line:color:$linetype"})){
				$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $config{"line:color:$linetype"},-tags=>['scalable']);
				$lines[$i]->{'draw'}=$line;
			}
			else {
				$line=$nw_canvas->createLine($x1,$y1,$x2,$y2,-fill => $linetype,-tags=>['scalable']);
				$lines[$i]->{'draw'}=$line;
			}
			if ($showlabels==1){
				$lines[$i]->{'drawfrom'}=$nw_canvas->createText($xlfrom,$ylfrom, -text=>$fromlabel);
				$lines[$i]->{'drawto'}=$nw_canvas->createText($xlto,$ylto, -text=>$tolabel);
			}
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
		if (defined $lines[$i]->{'drawfrom'}){
			if ($lines[$i]->{'drawfrom'}>-1){
				$nw_canvas->delete($lines[$i]->{'drawfrom'});
			}
		}
		$lines[$i]->{'drawfrom'}=-1;
		if (defined $lines[$i]->{'drawto'}){
			if ($lines[$i]->{'drawto'}>-1){
				$nw_canvas->delete($lines[$i]->{'drawto'});
			}
		}
		$lines[$i]->{'drawto'}=-1;
	}
}
	
sub nw_drawobjects {
	for my $i (0 .. $#objects){
		my $x=$objects[$i]->{'x'};
		my $y=$objects[$i]->{'y'};
		$x=100 unless defined $x;
		$y=100 unless defined $y;
		$x=100 unless $x>0;
		$y=100 unless $y>0;
		my $logo=$objects[$i]->{'logo'};
		$logo='server' unless defined $logo;
		my $name=$objects[$i]->{'name'};
		my $devicetype=$objects[$i]->{'devicetype'};
		$devicetype='server' unless defined $devicetype;
		my $devidx= first { $devicetypes[$_] eq $devicetype} 0..$#devicetypes;
		my $txtcol=$colors[$devidx];
		my $objectdraw=$nw_canvas->createImage($x, $y, -image=>$nw_logos{$logo} ,-tags=>['draggable','scalable']);
		$objects[$i]->{'draw'}=$objectdraw;
		$objects[$i]->{'namedraw'}=$nw_canvas->createText($x,$y+25,-text=>$name,-fill=>$txtcol,-tags=>['scalable']);
		
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
	$locked=1;
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
	#for ($dragindex=0; ($dragindex<1+$#objects)&&($objects[$dragindex]->{'newid'}!=$dragid);$dragindex++){};
	$draginfo{startx} = $draginfo{lastx} =$cx;
	$draginfo{starty} = $draginfo{lasty} =$cy;
	$dragobject=-1;
	for my $i (0 .. $#objects){
 		my $objname=$objects[$i]->{'name'};
		$objname='UNDEFINED' unless defined $objname;
		if (! defined $objects[$i]->{'draw'}){print "Object without draw $objname\n"}
		elsif (! defined $dragid){print "No dragid\n"}
		elsif ($objects[$i]->{'draw'}==$dragid){
			$dragobject=$i;
		}
	}
	if ($dragobject<0){ print "dragobject<0\n"; }
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
	$locked=0;
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
my $devicetypechoice;

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
	$last_info=$objidx;
	my $local_frame;
	$nw_info_inside=$parent->Frame(-borderwidth => 3,-height=>1000 )->pack(-side=>'top' );
	my $name=$objects[$objidx]->{'name'};
	my $merge='';
	my $table=$objects[$objidx]->{'table'};
	$table='' unless defined $table;
	my $type=$objects[$objidx]->{'logo'};
	my $id=$objects[$objidx]->{'id'};
	my $drawid=$objects[$objidx]->{'drawid'};
	if ($table eq 'server'){
		my $options;
		if (defined $objects[$objidx]->{'options'}) {
			$options=$objects[$objidx]->{'options'};
		}
		else {
			$options='';
		}
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>50,-text=>'Server information')->pack(-side=>'left');
		# ID : always present.
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');
		# name: always present and can be changed.
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {
			$Message='';
			nw_set_name($name,$id,$table);
			nw_frame_canvas_redo();
		})->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');

		# type: always present and can be changed.
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
		$typechoice=$objects[$objidx]->{'logo'};
		$local_frame->JBrowseEntry(
			-variable => \$typechoice,
			-width=>25,
			-choices => \@logolist,
			-height=>10,
			-browsecmd => sub {
				nw_set_type($typechoice,$id,$table,$drawid);
				nw_frame_canvas_redo();
			}
		)->pack(-side=>'right');

		# devicetype: always present and can be changed.
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Devicetype')->pack(-side=>'left');
		$devicetypechoice=$objects[$objidx]->{'devicetype'};
		$devicetypechoice='server' unless defined $devicetypechoice;
		$local_frame->JBrowseEntry(
			-variable => \$devicetypechoice, 
			-width=>25, 
			-choices => \@devicetypes,
			-height=>10,
			-browsecmd => sub {
				nw_set_devicetype($devicetypechoice,$id,$table,$drawid);
				nw_frame_canvas_redo();
			}
		)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Interfaces')->pack(-side=>'left');
		my @ifarray=@{$objects[$objidx]{interfaces}} if defined $objects[$objidx]{interfaces};
		my @pgarray=@{$objects[$objidx]{pages}};
		if (defined $ifarray[0]){
			$local_frame->Label ( -anchor => 'w',-width=>26,-text=>' ')->pack(-side=>'right');
			#(my $ifname, my $ifip)=split (' ',$ifarray[0]);
			#$local_frame->Label ( -anchor => 'w',-width=>10,-text=>$ifname)->pack(-side=>'right');
			#$local_frame->Label ( -anchor => 'w',-width=>20,-text=>$ifip)->pack(-side=>'right');
			for (my $i=0; $i<=$#ifarray; $i++){
				(my $ifname, my $ifip)=split (' ',$ifarray[$i]);
				$ifname=' ' unless defined $ifname;
				$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
				$local_frame->Label ( -anchor => 'w',-width=>5,-text=>'  ')->pack(-side=>'left');
				$local_frame->Label ( -anchor => 'w',-width=>20,-text=>$ifname)->pack(-side=>'right');
				$local_frame->Label ( -anchor => 'w',-width=>20,-text=>$ifip)->pack(-side=>'right');
			}
		}
	
		for my $fieldname (qw(ostype os processor memory vendor service)) {
			my $value=$objects[$objidx]->{$fieldname};
			if (defined ($value)){
				$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
				$local_frame->Label ( -anchor => 'w',-width=>10,-text=>$fieldname)->pack(-side=>'left');
				$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$value)->pack(-side=>'right');
			}
		}

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
		$local_frame->Label ( -anchor => 'w',-width=>50,-text=>'subnet information')->pack(-side=>'left');
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
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {
			$Message='';
			nw_set_name($name,$id,$table);
			nw_frame_canvas_redo();
		})->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');

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
			-width          => 15,
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
		$local_frame->Label ( -anchor => 'w',-width=>50,-text=>'Switch information')->pack(-side=>'left');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {
			$Message='';
			nw_set_name($name,$id,$table);
			nw_frame_canvas_redo();
		})->pack(-side=>'left');
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
	elsif ($table eq 'cloud'){
		my @pgarray=@{$objects[$objidx]{pages}};
		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>50,-text=>'Cloud service')->pack(-side=>'left');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'ID')->pack(-side=>'left');
		$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$id)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Button ( -width=>10,-text=>'Name', -command=>sub {
			$Message='';
			nw_set_name($name,$id,$table);
			nw_frame_canvas_redo();
		})->pack(-side=>'left');
		$local_frame->Entry ( -width=>30,-textvariable=>\$name)->pack(-side=>'right');

		$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
		$local_frame->Label ( -anchor => 'w',-width=>10,-text=>'Type')->pack(-side=>'left');
		$typechoice=$objects[$objidx]->{'logo'};
		$local_frame->JBrowseEntry(
			-variable => \$typechoice,
			-width=>25,
			-choices => \@logolist,
			-height=>10,
			-browsecmd => sub {
				nw_set_type($typechoice,$id,$table,$drawid);
				nw_frame_canvas_redo();
			}
		)->pack(-side=>'right');

		for my $fieldname (qw(ostype os processor memory vendor service)) {
			my $value=$objects[$objidx]->{$fieldname};
			if (defined ($value)){
				$local_frame=$nw_info_inside->Frame()->pack(-side=>'top');
				$local_frame->Label ( -anchor => 'w',-width=>10,-text=>$fieldname)->pack(-side=>'left');
				$local_frame->Label ( -anchor => 'w',-width=>30,-text=>$value)->pack(-side=>'right');
			}
		}

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

	}
}

sub nw_set_type {
	(my $tpchoice,my $id,my $table,my $drawid)=@_;
	$nw_cbtype->($table,$id,$tpchoice);
}

sub nw_set_devicetype {
	(my $tpchoice,my $id,my $table,my $drawid)=@_;
	$nw_cbdevicetype->($table,$id,$tpchoice);
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

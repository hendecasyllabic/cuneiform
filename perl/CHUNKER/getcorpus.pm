package CHUNKER::getcorpus;

use base 'CHUNKER';
use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;
# phase one - iterate over oracc and get full list of projects

#this fixes the wide warnings and the numbers not being sub script
binmode STDOUT, ":utf8";

my $dir = "fulllist";

sub getthetexts {
    my $baseresults = shift;
    my $basepath = shift;
    my $rebuild = shift || 0;#should we rebuild or ignore if we have the data already
    my $PQroot = "";
    # phase one - iterate over oracc and get full list of projects
    &spidertheoracc($basepath,"P", "xtf",$baseresults."/".$dir, $rebuild);
    &spidertheoracc($basepath,"Q", "xtf",$baseresults."/".$dir, $rebuild);
    
}

# assume path like /home/varoracc/local/oracc/bld/dcclt/P432/P432448
# if this changes you will need to change this function as it will stop finding the files
sub spidertheoracc {
    my $startdir = shift;
    my $testitem = shift;
    my $fileextension = shift;
    my $baseresults = shift;
    my $rebuild = shift || 0;
    my $subcount = 0;  
    #initialise the count
    my $count = 0;  
    my %projects = ();
    
    if(-d "$startdir"){
	opendir (THISDIR, $startdir) or warn "Could not open the dir ".$startdir.": $!";
	my @allfiles = grep !/^\.\.?$/, readdir THISDIR;
	print "\n folders .".scalar @allfiles;
	closedir THISDIR;
	foreach (@allfiles) {
	    my $file = $_;
	    $subcount++;

	    print "\n this num ".$subcount;
	    # Use a regular expression to ignore files beginning with a period as they aren't important
	    next if ($file =~ m|^\.|);
    #        get project folders
    # use -d to test for a directory
	    if(-d "$startdir/$file"){
		my $filename = $baseresults."/".$testitem."/".$file.".xml";
		    
		if ($rebuild || !(-e $filename)) {
		    print "\n started ".$file;
		    $count = &spiderleveltwo("$startdir/$file",$testitem, $fileextension, $file, \%projects, $count);
                if(exists $projects{$file} && ref($projects{$file}) eq 'ARRAY'){
			my %all = ("opt"=>$projects{$file});
                	&CHUNKER::generic::writetofile($file, \%all, $testitem, $baseresults);		    
		    print "\n finished ".$file;
		}
                else{
                        print "\n $file is empty";
                }
		}
		else{
		    print "\n ignore as already done ".$file;
		}
	    }
	    %projects = ();#null it so it is ready for next one.
	#	write file 
	print "\n count  ".$count;
        }
    }
    else{
	print "\n no such directory ".$startdir;
    }
}
sub spiderleveltwo{
    my $startdir = shift;
    my $testitem = shift;
    my $fileextension = shift;
    my $parentfolder = shift;
    my $projects = shift;
    my $count = shift;
	opendir (THISDIR, $startdir) or warn "Could not open the dir ".$startdir.": $!";
	my @allfiles = grep !/^\.\.?$/, readdir THISDIR;
	closedir THISDIR;
	foreach (@allfiles) {
 		my $file = $_;
        	# Use a regular expression to ignore files beginning with a period as they aren't important
        	next if ($file =~ m|^\.|);
        	# Use -f to test for a file
        	if(-f "$startdir/$file"){
        	    # Ignore all files which don't have the extension we are interested in
        	    	next if($file !~ m|\.${fileextension}$|);
 			# only care about files that have the right prefix
        	      	next if($file !~ m|^${testitem}|);
        		    #this is a file we are interested in.. woo hoo
			#print $file."\n";
			print ".";$count++;
        		if( !(exists $projects->{$parentfolder})) {
                                $projects->{$parentfolder} = [];
                        }
				my %filedata = ();
				$filedata{"name"} = $file;
				$filedata{"path"} = $startdir;
				push(@{$projects->{$parentfolder}},\%filedata);
        	}
            
        	# use -d to test for a directory
        	elsif(-d "$startdir/$file"){
        	    	# only care about folders that have the right prefix
        		next if($file !~ m|^${testitem}|);
           		 # drill down for more.
            		$count = &spiderleveltwo("$startdir/$file", $testitem, $fileextension, $parentfolder, $projects, $count);
        	}
    	}
        return $count;
}


# loop over xml files which list files produced by getthetexts
sub processtexts{
    my $baseresults = shift;
    my $directory = $baseresults."/".$dir."/P";
    if(-d "$directory"){
	opendir (DIR, $directory) or die $!;
	while (my $file = readdir(DIR)) {
	    # We only want files
	    next unless (-f "$directory/$file");
	    # Use a regular expression to find files ending in .txt
	    next unless ($file =~ m/\.xml$/);
	    print "\n starting $file ";
	    open (MYFILE, $directory."/".$file);
	    while (<MYFILE>) {
		chomp;
		my $item = $_;
    #	<opt name="P415909.xtf" path="/home/varoracc/local/oracc/bld/alalakh/P415/P415909" />
		$item=~m|name="([^"]*)" path="([^"]*)"|g;
		my $xtf = $1;
		my $path = $2;
		   
		&CHUNKER::singlefilestats::statasinglefile($path."/".$xtf, $baseresults);
	    }
	    print "\n finishing $file ";
	    close (MYFILE);
	}
    }
    else{
	print "\n no such directory ".$directory;
    }
}
#clean up and remove files so can recreate them
sub removetexts{
    my $baseresults = shift;
    my $directory = $baseresults."/".$dir."/P";
    if(-d "$directory"){
	opendir (DIR, $directory) or die $!;
	while (my $file = readdir(DIR)) {
	    # We only want files
	    next unless (-f "$directory/$file");
	    # Use a regular expression to find files ending in .txt
	    next unless ($file =~ m/\.xml$/);
	    print "\n removing $file ";
	    open (MYFILE, $directory."/".$file);
	    while (<MYFILE>) {
		chomp;
		my $item = $_;
    #	<opt name="P415909.xtf" path="/home/varoracc/local/oracc/bld/alalakh/P415/P415909" />
		$item=~m|name="([^"]*)" path="([^"]*)"|g;
		my $xtf = $1;
		my $path = $2;
		   
		&CHUNKER::singlefilestats::removesinglefile($path."/".$xtf, $baseresults);
	    }
	    print "\n finishing $file ";
	    close (MYFILE);
	    
	}
    }
}
1;

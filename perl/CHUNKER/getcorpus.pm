package CHUNKER::getcorpus;

use base 'CHUNKER';

use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;
# phase one - iterate over oracc and get full list of projects
# scrap important meta data and create structure that can be used later.
# phase two - allow greta to cherry pick the projects that will be offered
# phase three - potentially allow more granualar restrictions so can restrict sub docs of a project
# phase four - show list to users to select
# pashe 5 cache/ speed up queries to make it a better experience - can we separately some of the heavy lifting to happen asyncly

#this fixes the wide warnings and the numbers not being sub script
binmode STDOUT, ":utf8";


my $thisCorpus = "";
my $corpusdesignation = "";



sub getthetexts {
    my $baseresults = shift;
    my $basepath = shift;
    my $rebuild = shift || 0;#should we rebuild or ignore if we have the data already
    my $PQroot = "";
    # phase one - iterate over oracc and get full list of projects
    my $ptexts = &spidertheoracc($basepath,"P", "xtf",$baseresults."/fulllist", $rebuild);
    my $qtexts = &spidertheoracc($basepath,"Q", "xtf",$baseresults."/fulllist", $rebuild);
    
    #write data to file
    
    #&CHUNKER::generic::writetofile("PDATA", $ptexts, "fulllist", $baseresults);
    #&CHUNKER::generic::writetofile("QDATA", $qtexts, "fulllist", $baseresults);
    #
    #print Dumper $ptexts;
    
    #phase 1.5
    #harvest meta data about each item.
    
    
    #foreach my $i (keys %{$ptexts}){
    #        print $i."\n";
    #                foreach my $j (@{$ptexts->{$i}})	{
    #                        $j->{"name"}=~m|^(.*)\.xtf$|;
    #                        my $shortname = $1;
    #                        my $fullfilename = $j->{"path"} ."/".$j->{"name"};
    #                        print $shortname ."\n";
    #                        &ptexts($fullfilename, $shortname, $baseresults);
    #                }
    #}
}

# assume path like /home/varoracc/local/oracc/bld/dcclt/P432/P432448
# killing it at 6000 records to speed up testing - remove when all good at end
# where we are sure that the folders after the project name are prefixed with P or Q
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
    

    opendir (THISDIR, $startdir) or warn "Could not open the dir ".$startdir.": $!";
	my @allfiles = grep !/^\.\.?$/, readdir THISDIR;
	print "\n folders .".scalar @allfiles;
	closedir THISDIR;
	foreach (@allfiles) {
        	my $file = $_;
		$subcount++;
		if($count >6000){
        		next;
		}


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
		my $data = @{$projects{$file}};
		&CHUNKER::generic::writetofile($file, $data, $testitem, $baseresults);
print "\n finished ".$file;
	    }
	    else{
		print "\n ignore as already done ".$file;
	    }
        }
	%projects = ();#null it so it is ready for next one.
#	write file 
print "\n count  ".$count;

    }
   #return \%projects;
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



1;
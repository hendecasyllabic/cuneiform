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
    my $PQroot = "";
    # phase one - iterate over oracc and get full list of projects
    my $count = 0; #bit of a hack to speed up testing
    my $ptexts = &spidertheoracc($basepath,"P", "xtf");
    my $qtexts = &spidertheoracc($basepath,"Q", "xtf");
    
    #print Dumper $ptexts;
    
    #phase 1.5
    #harvest meta data about each item.
    
    
    foreach my $i (keys %{$ptexts}){
            print $i."\n";
                    foreach my $j (@{$ptexts->{$i}})	{
                            $j->{"name"}=~m|^(.*)\.xtf$|;
                            my $shortname = $1;
                            my $fullfilename = $j->{"path"} ."/".$j->{"name"};
                            print $shortname ."\n";
                            &ptexts($fullfilename, $shortname, $baseresults);
                    }
    }
}

# assume path like /home/varoracc/local/oracc/bld/dcclt/P432/P432448
# killing it at 6000 records to speed up testing - remove when all good at end
# where we are sure that the folders after the project name are prefixed with P or Q
# if this changes you will need to change this function as it will stop finding the files
sub spidertheoracc {
    my $startdir = shift;
    my $testitem = shift;
    my $fileextension = shift;
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
print "\n started ".$file;
            $count = &spiderleveltwo("$startdir/$file",$testitem, $fileextension, $file, \%projects, $count);
        }
print "\n finished ".$file;
print "\n count  ".$count;

    }
   return \%projects;
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

sub removetextsspider{
    my $startdir = shift;
    my $testitem = shift;
    opendir (THISDIR, $startdir) or warn "Could not open the dir ".$startdir.": $!";
    my @allfiles = grep !/^\.\.?$/, readdir THISDIR;
    closedir THISDIR;
    foreach (@allfiles) {
        my $file = $_;
        if(-d "$startdir/$file"){
            print "\n started ".$file;
            &removetextsspider("$startdir/$file",$testitem);
        }
        if($file eq $testitem){
            print "\n removing ";
    print $startdir."/".$testitem;
            `rm -f $startdir/$testitem`;
        }
    }
}
sub ptexts {
    my $filename = shift;
    my $shortname = shift;
    my $baseresults = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
    # xtf-file
    my $twigObj = XML::Twig->new(
                                 twig_roots => { 'protocols' => 1, 'object' => 1, 'mds' => 1 }
                                 );
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    # .xmd, metadata-file
    my $twigObjXmd = XML::Twig->new(
                                 twig_roots => { 'cat' => 1 }
                                 );
    my $xmdfile = $filename;
    $xmdfile =~ s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;
    
    my $data = &getMetaData($root, $baseresults, $rootxmd, $shortname, "P");
    $data->{"fullpath"}[0] = $filename;
    CHUNKER::generic::writetofile($shortname, $data, "fulllist", $baseresults);
    
}
sub getMetaData{  # find core metadata fields and add them to each itemfile [$PQdata] + corpus metadata-file [corpusdata]
    my $root = shift;
    my $baseresults = shift;
    my $rootxmd = shift;
    my $PQnumber = shift;
    my $PorQ = shift;
    my %PQdata = ();
    $PQdata{"name"}[0] = $PQnumber;
    
#    delete all previous entries for this item..
#loop over all the dataout folders and remove anything called this...
&removetextsspider($baseresults, $PQnumber.".xml");

    $PQdata{"designation"}[0] = ""; $PQdata{"genre"}[0] = ""; $PQdata{"language"}[0] = ""; $PQdata{"object"}[0] = ""; 
    $PQdata{"period"}[0] = ""; $PQdata{"project"}[0] = ""; $PQdata{"provenance"}[0] = ""; 
    $PQdata{"script"}[0] = ""; $PQdata{"subgenre"}[0] = ""; $PQdata{"writer"}[0] = "";
    
    my $designation = "unspecified"; my $genre = "unspecified"; my $language = "unspecified"; my $object = "unspecified";
    my $period = "unspecified"; my $project = "unspecified"; my $provenance = "unspecified";
    my $script = "unspecified"; my $subgenre = "unspecified"; my $writer = "unspecified"; 
      
    # first check the mds/m fields (period, genre, subgenre and provenience) in the xtf-file    
    my @mfields = $root->get_xpath('mds/m');
    foreach my $i (@mfields){
	if($i->{att}->{k} eq "period"){   # e.g. <m k="period">Hellenistic</m>
	    $PQdata{"period"}[0] = $i->text;
	}
	if($i->{att}->{k} eq "genre"){    # e.g. <m k="genre">administrative letter</m>
	    $PQdata{"genre"}[0] = $i->text;
	}
	if($i->{att}->{k} eq "subgenre"){   
	    $PQdata{"subgenre"}[0] = $i->text;
	}
	if($i->{att}->{k} eq "provenience"){   
	    $PQdata{"provenance"}[0] = $i->text;
	}
    }
    
    if (my @temp = $root->get_xpath('object')) {
	$PQdata{"object"}[0] = $temp[0]->{att}->{type};
    }
        
    # the mds/m fields are not always filled in even if the information is known, hence we may need to check the metadatafile.
    $PQdata{"designation"}[0] = $rootxmd->findvalue('cat/designation');
    
    if($PQdata{"period"}[0] eq ""){
	$PQdata{"period"}[0] = $rootxmd->findvalue('cat/period');

	# no period in SAAo, but <date c="1000000"/> [Neo-Assyrian]
	if($PQdata{"period"}[0] eq ""){
	    my @date = $rootxmd->get_xpath('cat/date');
	    foreach my $i (@date) {
		my $temp = $i->{att}->{c};
		if($temp eq "1000000"){   # Q: Other codes ??? [ask Steve ***]
		    $PQdata{"period"}[0] = "Neo-Assyrian";  
		}
	    }
	}
    }
    
    if ($PQdata{"genre"}[0] eq ""){
	$PQdata{"genre"}[0] = $rootxmd->findvalue('cat/genre');
    }
    
    if ($PQdata{"subgenre"}[0] eq ""){
	$PQdata{"subgenre"}[0] = $rootxmd->findvalue('cat/subgenre');
    }
    
    if ($PQdata{"provenance"}[0] eq ""){
	$PQdata{"provenance"}[0] = $rootxmd->findvalue('cat/provenience');
	if ($PQdata{"provenance"}[0] eq ""){
	    $PQdata{"provenance"}[0] = $rootxmd->findvalue('cat/provenance');
	}
    }
    
    
#http://oracc.museum.upenn.edu/doc/builder/l2/langtags    
    my @temp = $root->get_xpath('xcl');
    $PQdata{"language"}[0] = $temp[0]->{att}->{"langs"}?$temp[0]->{att}->{"langs"}:"";  # with L2!
    if ($PQdata{"language"}[0] eq "") {
	$PQdata{"language"}[0] = $rootxmd->findvalue('cat/language')?$rootxmd->findvalue('cat/language'):""; 
    }
    
    my @protocols = $root->get_xpath('protocols/protocol');
	 # http://oracc.museum.upenn.edu/doc/builder/l2/languages/#Language_codes
    foreach my $i (@protocols) {
	if (($PQdata{"language"}[0] eq "") && ($i->{att}->{type} eq "atf")) { $PQdata{"language"}[0] = $i->text; }
	if ($i->{att}->{type} eq "project") { $PQdata{"project"}[0] = $i->text; }
    }

    if (CHUNKER::generic::langmatrix($PQdata{"language"}[0])) {
        $PQdata{"language"}[0] = CHUNKER::generic::langmatrix($PQdata{"language"}[0]);
    }
    else {
        # append to file NewLangCodes.txt
        CHUNKER::generic::writetoerror ("NewLangCodes.txt", localtime(time)." Project: ".$PQdata{"project"}[0].", text ".$PQnumber.": ".$PQdata{"language"}[0]);
    }
    
#   in SAA not given in metadata, but in xtf-file under
#        <protocols scope="text">
#		<protocol type="project">saao/saa10</protocol>
#		<protocol type="atf">lang nb</protocol>
#		<protocol type="key">file=SAA10/LAS_NB.saa</protocol>
#		<protocol type="key">musno=K 00552</protocol>
#		<protocol type="key">cdli=ABL 0255</protocol>
#		<protocol type="key">writer=A@aredu</protocol>
#		<protocol type="key">L=B</protocol>
#	</protocols>
    
    $PQdata{"script"}[0] = $rootxmd->findvalue('cat/script');
    
    $PQdata{"writer"}[0] = $rootxmd->findvalue('cat/ancient_author'); # SAA; colophon information does not seem to be included in metadata (neither is the scribe especially marked in xtf)
    
    # For corpusdata-file: allow for quick metadata search on PQ-number, period, provenance, genre, language, etc.
    
    #$PQdataBorger{"name"} = $PQnumber;
    
    if ($PQdata{"designation"}[0] ne "") { $designation = $PQdata{"designation"}[0]; } #$PQdataBorger{"designation"} = $designation; }
    if ($PQdata{"genre"}[0] ne "") { $genre = $PQdata{"genre"}[0]; } #$PQdataBorger{"genre"} = $genre; }
    if ($PQdata{"language"}[0] ne "") { $language = $PQdata{"language"}[0]; } #$PQdataBorger{"language"} = $language; }
    if ($PQdata{"object"}[0] ne "") { $object = $PQdata{"object"}[0]; } #$PQdataBorger{"object"} = $object; }
    if ($PQdata{"period"}[0] ne "") { $period = $PQdata{"period"}[0]; } #$PQdataBorger{"period"} = $period; }
    if ($PQdata{"project"}[0] ne "") { $project = $PQdata{"project"}[0]; } #$PQdataBorger{"project"} = $project; }
    if ($PQdata{"provenance"}[0] ne "") { $provenance = $PQdata{"provenance"}[0]; } #$PQdataBorger{"provenance"} = $provenance; }
    if ($PQdata{"script"}[0] ne "") { $script = $PQdata{"script"}[0]; } #$PQdataBorger{"script"} = $script; }
    if ($PQdata{"subgenre"}[0] ne "") { $subgenre = $PQdata{"subgenre"}[0]; } #$PQdataBorger{"subgenre"} = $subgenre; }
    if ($PQdata{"writer"}[0] ne "") { $writer = $PQdata{"writer"}[0]; } #$PQdataBorger{"writer"} = $writer; }
    
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "genre/".$PQdata{"genre"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "language/".$PQdata{"language"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "designation/".$PQdata{"designation"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "object/".$PQdata{"object"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "period/".$PQdata{"period"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "project/".$PQdata{"project"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "provenance/".$PQdata{"provenance"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "script/".$PQdata{"script"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "subgenre/".$PQdata{"subgenre"}[0], $baseresults);
    CHUNKER::generic::writetofile($PQnumber, \%PQdata, "writer/".$PQdata{"writer"}[0], $baseresults);
    
    
    $thisCorpus = $project;
    $corpusdesignation = $thisCorpus."_".$genre;
    if ($subgenre ne "") { $corpusdesignation = $corpusdesignation."_".$subgenre; }
    $corpusdesignation =~ s/\//_/gsi;
    $corpusdesignation =~ s/ /_/gsi;
    return \%PQdata;
}
1;
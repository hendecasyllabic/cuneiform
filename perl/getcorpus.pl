#!/usr/bin/perl -w
use strict;
use lib "/home/varoracc/local/oracc/www/qlab/cuneiform/perl/lib/lib/perl5/";
use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig::XPath;
use utf8;

#this fixes the wide warnings and the numbers not being sub script
binmode STDOUT, ":utf8";


my $thisCorpus = "";
my $corpusdesignation = "";
my %PQdata = ();  # data per text
my %langmatrix; # other codes in use? ask Steve TODO
my $PQroot = "";
my %corpusdata = (); # overview of selected metadata per corpus
# phase one - iterate over oracc and get full list of projects
# phase two - allow greta to cherry pick the projects that will be offered
# phase three - potentially allow more granualar restrictions so can restrict sub docs of a project
# phase four - show list to users to select
# pashe 5 cache/ speed up queries to make it a better experience - can we separately some of the heavy lifting to happen asyncly

# phase one - iterate over oracc and get full list of projects
my $count = 0; #bit of a hack to speed up testing
my $ptexts = &spidertheoracc("/home/varoracc/local/oracc/bld","P", "xtf");
my $qtexts = &spidertheoracc("/home/varoracc/local/oracc/bld","Q", "xtf");
print Dumper $ptexts;
#print Dumper $ptexts;

#phase 1.5
#harvest meta data about each item.

#foreach my $i (keys %{$ptexts}){
#	print $i."\n";
#		foreach my $j (@{$ptexts->{$i}})	{
#			$j->{"name"}=~m|^(.*)\.xtf$|;
#			my $shortname = $1;
#			my $fullfilename = $j->{"path"} ."/".$j->{"name"};
#			print $shortname ."\n";
#		#	&ptexts($fullfilename, $shortname);
#		}
#}



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
    $count = 0;  
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
            &spiderleveltwo("$startdir/$file",$testitem, $fileextension, $file, \%projects );
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
            		&spiderleveltwo("$startdir/$file", $testitem, $fileextension, $parentfolder, $projects);
        	}
    	}
}

sub ptexts {
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
    # xtf-file
    my $twigObj = XML::Twig->new(
                                 twig_roots => { 'transliteration' => 1, 'protocols' => 1, 'object' => 1, 'mds' => 1 }
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
    
    &getMetaData($root, $rootxmd, $shortname, "P");
    
}
sub getMetaData{  # find core metadata fields and add them to each itemfile [$PQdata] + corpus metadata-file [corpusdata]
    my $root = shift;
    my $rootxmd = shift;
    my $PQnumber = shift;
    my $PorQ = shift;

    $PQdata{"name"} = $PQnumber;    
    $PQdata{"designation"} = ""; $PQdata{"genre"} = ""; $PQdata{"language"} = ""; $PQdata{"object"} = ""; 
    $PQdata{"period"} = ""; $PQdata{"project"} = ""; $PQdata{"provenance"} = ""; 
    $PQdata{"script"} = ""; $PQdata{"subgenre"} = ""; $PQdata{"writer"} = "";
    
    my $designation = "unspecified"; my $genre = "unspecified"; my $language = "unspecified"; my $object = "unspecified";
    my $period = "unspecified"; my $project = "unspecified"; my $provenance = "unspecified";
    my $script = "unspecified"; my $subgenre = "unspecified"; my $writer = "unspecified"; 
      
    # first check the mds/m fields (period, genre, subgenre and provenience) in the xtf-file    
    my @mfields = $root->get_xpath('mds/m');
    foreach my $i (@mfields){
	if($i->{att}->{k} eq "period"){   # e.g. <m k="period">Hellenistic</m>
	    $PQdata{"period"} = $i->text;
	}
	if($i->{att}->{k} eq "genre"){    # e.g. <m k="genre">administrative letter</m>
	    $PQdata{"genre"} = $i->text;
	}
	if($i->{att}->{k} eq "subgenre"){   
	    $PQdata{"subgenre"} = $i->text;
	}
	if($i->{att}->{k} eq "provenience"){   
	    $PQdata{"provenance"} = $i->text;
	}
    }
    
    if (my @temp = $root->get_xpath('object')) {
	$PQdata{"object"} = $temp[0]->{att}->{type};
    }
        
    # the mds/m fields are not always filled in even if the information is known, hence we may need to check the metadatafile.
    $PQdata{"designation"} = $rootxmd->findvalue('cat/designation');
    
    if($PQdata{"period"} eq ""){
	$PQdata{"period"} = $rootxmd->findvalue('cat/period');

	# no period in SAAo, but <date c="1000000"/> [Neo-Assyrian]
	if($PQdata{"period"} eq ""){
	    my @date = $rootxmd->get_xpath('cat/date');
	    foreach my $i (@date) {
		my $temp = $i->{att}->{c};
		if($temp eq "1000000"){   # Q: Other codes ??? [ask Steve ***]
		    $PQdata{"period"} = "Neo-Assyrian";  
		}
	    }
	}
    }
    
    if ($PQdata{"genre"} eq ""){
	$PQdata{"genre"} = $rootxmd->findvalue('cat/genre');
    }
    
    if ($PQdata{"subgenre"} eq ""){
	$PQdata{"subgenre"} = $rootxmd->findvalue('cat/subgenre');
    }
    
    if ($PQdata{"provenance"} eq ""){
	$PQdata{"provenance"} = $rootxmd->findvalue('cat/provenience');
	if ($PQdata{"provenance"} eq ""){
	    $PQdata{"provenance"} = $rootxmd->findvalue('cat/provenance');
	}
    }
    
    
#http://oracc.museum.upenn.edu/doc/builder/l2/langtags    
    my @temp = $PQroot->get_xpath('xcl');
    $PQdata{"language"} = $temp[0]->{att}->{"langs"}?$temp[0]->{att}->{"langs"}:"";  # with L2!
    if ($PQdata{"language"} eq "") {
	$PQdata{"language"} = $rootxmd->findvalue('cat/language')?$rootxmd->findvalue('cat/language'):""; 
    }
    
    my @protocols = $root->get_xpath('protocols/protocol');
	 # http://oracc.museum.upenn.edu/doc/builder/l2/languages/#Language_codes
    foreach my $i (@protocols) {
	if (($PQdata{"language"} eq "") && ($i->{att}->{type} eq "atf")) { $PQdata{"language"} = $i->text; }
	if ($i->{att}->{type} eq "project") { $PQdata{"project"} = $i->text; }
    }

    if ($langmatrix{$PQdata{"language"}}) {
        $PQdata{"language"} = $langmatrix{$PQdata{"language"}};
    }
    else {
        # append to file NewLangCodes.txt
        &writetoerror ("NewLangCodes.txt", localtime(time)." Project: ".$PQdata{"project"}.", text ".$PQnumber.": ".$PQdata{"language"});
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
    
    $PQdata{"script"} = $rootxmd->findvalue('cat/script');
    
    $PQdata{"writer"} = $rootxmd->findvalue('cat/ancient_author'); # SAA; colophon information does not seem to be included in metadata (neither is the scribe especially marked in xtf)
    
    # For corpusdata-file: allow for quick metadata search on PQ-number, period, provenance, genre, language, etc.
    
    #$PQdataBorger{"name"} = $PQnumber;
    
    if ($PQdata{"designation"} ne "") { $designation = $PQdata{"designation"}; } #$PQdataBorger{"designation"} = $designation; }
    if ($PQdata{"genre"} ne "") { $genre = $PQdata{"genre"}; } #$PQdataBorger{"genre"} = $genre; }
    if ($PQdata{"language"} ne "") { $language = $PQdata{"language"}; } #$PQdataBorger{"language"} = $language; }
    if ($PQdata{"object"} ne "") { $object = $PQdata{"object"}; } #$PQdataBorger{"object"} = $object; }
    if ($PQdata{"period"} ne "") { $period = $PQdata{"period"}; } #$PQdataBorger{"period"} = $period; }
    if ($PQdata{"project"} ne "") { $project = $PQdata{"project"}; } #$PQdataBorger{"project"} = $project; }
    if ($PQdata{"provenance"} ne "") { $provenance = $PQdata{"provenance"}; } #$PQdataBorger{"provenance"} = $provenance; }
    if ($PQdata{"script"} ne "") { $script = $PQdata{"script"}; } #$PQdataBorger{"script"} = $script; }
    if ($PQdata{"subgenre"} ne "") { $subgenre = $PQdata{"subgenre"}; } #$PQdataBorger{"subgenre"} = $subgenre; }
    if ($PQdata{"writer"} ne "") { $writer = $PQdata{"writer"}; } #$PQdataBorger{"writer"} = $writer; }
    
    if (!defined $corpusdata{"corpus"}) { $corpusdata{"corpus"} = (); }

    push(@{$corpusdata{"corpus"}{$project}{"designation"}{$designation}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"genre"}{$genre}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"language"}{$language}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"object"}{$object}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"period"}{$period}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"provenance"}{$provenance}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"script"}{$script}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"subgenre"}{$subgenre}{$PorQ}}, $PQnumber);
    push(@{$corpusdata{"corpus"}{$project}{"writer"}{$writer}{$PorQ}}, $PQnumber);
    
    $thisCorpus = $project;
    $corpusdesignation = $thisCorpus."_".$genre;
    if ($subgenre ne "") { $corpusdesignation = $corpusdesignation."_".$subgenre; }
    $corpusdesignation =~ s/\//_/gsi;
    $corpusdesignation =~ s/ /_/gsi;
}

#!/usr/bin/perl -w
use warnings;
use strict;

use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use XML::Twig;
use XML::Simple;
use utf8;

my %perioddata = ();
my %langdata = ();
my %output = ();
my %config;
$config{"typename"} = "";
$config{"filehash"} = ();
$config{"filelist"} = ();
$config{"dirlist"} = ();
my $destinationdir = "./stats";
my $startpath = ".";
my $startdir = "xml_xtf_files";
my $errorfile = "./stats";
my $errorpath = "temp_errors";
my $outputtype="text";
my $resultspath = ".";
my $resultsfolder = "/results";

&general_stats();

sub general_stats{    
    &writetoerror("general_stats","starting ".localtime);
    my $ext = "xtf";
    $config{"typename"} = $ext;
    &traverseDir($startpath, $startdir,$config{"typename"},1,$ext);
    my @allfiles = @{$config{"filelist"}{$config{"typename"}}};
    
    
#    loop over each of the files we found 
    foreach(@allfiles){
        my $filename = $_;
        if($filename=~m|/([^/]*).${ext}$|){
            my $shortname = $1;
	    $output{$shortname} = ();
	    &outputtext("\n ShortName_". $shortname);
            if($shortname=~m|^P|gsi){
                &doPstats($filename, $shortname);
            }
            if($shortname=~m|^Q|gsi){
                &doQstats($filename, $shortname);
            }
	}
    }
    
    foreach my $period (keys %perioddata){
	&writetofile("PERIOD_".$period,$perioddata{$period});
    }
    foreach my $lang (keys %langdata){
	&writetofile("LANG_".$lang,$langdata{$lang});
    }
    &outputtext("\n\n");
    
    &writetofile("OUTPUT",\%output);
}

sub doPstats{
   my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes =0;
    my $twigObj = XML::Twig->new(
                                 twig_roots => { 'object' => 1, 'mds' => 1 }
                                 );
    $twigObj->parsefile( $filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    my %localdata = ();
    $localdata{"period"} = "";

    my @mfields = $root->get_xpath('mds/m');
    foreach my $i (@mfields){
	if($i->{att}->{k} eq "period"){
	    $localdata{"period"} = $i->text;
	    if(!defined $perioddata{$localdata{"period"}}){
		$perioddata{$localdata{"period"}} = ();
	    }
	}
	else{
	    #open up the xmd file and find the period form there - it will be in the same folder - promise
#	    write some code...
	}
	#<m k="period">Hellenistic</m>
    }
    
#   for P texts
    my @surfaces = $root->get_xpath('object/surface');
    my $size = scalar @surfaces;
    &outputtext("\n Number of surfaces:". $size);
    
    $localdata{"name"} = $shortname;
    
    $output{$shortname}{"hierarchicalview"}{"surface"} = ();
    
    my $count = 0;
    foreach my $i (@surfaces){
	if(!defined $localdata{"hierarchicalview"}{"surface"}){
	    $localdata{"hierarchicalview"}{"surface"} = ();
	}
        $count++;
        my @columns = $i->get_xpath('column');
        my $csize = scalar @columns;
        #print  $i->print;
	
        &outputtext("\n Number of columns for surface ".$count." :". $csize);
	my %alldata = ("type","","label","","columns",0);
        my $ccount = 0;
        foreach my $j (@columns){
	    if(!defined $alldata{'column'}){
		$alldata{'column'} = ();
	    }
            $ccount++;
            &outputtext("\n Number of lines for surface ".$count."  column ".$ccount." :");
	    
#TODO	    nonX to work out missing lines vs perserved lines
	    my $linedata = &doLineData($j, \%localdata);
	    push (@{$alldata{'column'}}, $linedata)
        }
	$alldata{'type'}=$i->{att}->{type}?$i->{att}->{type}:"";
	$alldata{'label'}=$i->{att}->{label}?$i->{att}->{label}:"";
	$alldata{'columns'}=$ccount;
	
	push (@{$localdata{"hierarchicalview"}{"surface"}}, \%alldata);
	push (@{$output{$shortname}{"surface"}}, \%alldata);
    }
    $output{$shortname}{"alllines"} = $sumlines;
    $output{$shortname}{"allgraphemes"} = $sumgraphemes;
    $output{$shortname}{"surfaces"} = $size;
    
    &writetofile($shortname,\%localdata);
     
    
    
}

#loop over each line and find some stats
sub doLineData{
    my $root = shift;
    my $localdata = shift;
    my %linearray = ();
    my @gruplines = $root->get_xpath('lg');
    my $lgsize = scalar @gruplines;
    &outputtext("\n Number of group lines ".$lgsize);
    my $dcount = 0;
    my $sumlines =0;
    
    foreach my $i (@gruplines){
	my $temp = &doLineData($i,$localdata);
	$sumlines  = &addLines($sumlines, $temp);
	push(@{ $linearray{'linegroups'} }, $temp);
    }
    
    my @lines = $root->get_xpath('l');
    my $lsize = scalar @lines;
    
    my $sumgraphemes =0;
    foreach my $i (@lines){
	my $graphemearray = &dographemeData($i, $localdata);
	push(@{ $linearray{'graphemes'} }, $graphemearray);
    }

    my $total = $sumlines + $lsize;
    #&outputtext("\n Total Number of lines within Groups ".$sumlines);
    &outputtext("\n Number of lines not in groups ".$lsize);
    #&outputtext("\n Total Number of lines ".$total);
    $linearray{'lines'} = $lsize;
    $linearray{'groups'} = $lgsize;
    $linearray{'alllines'} = $total;
    $linearray{'allgraphemes'} = $sumgraphemes;
    
    if(!defined $localdata->{"alllines"}){
	#$localdata->{"alllines"} = ();
    }
    if(!defined $localdata->{'lines'}){
	$localdata->{'lines'} = ();
    }
    if(!defined $localdata->{'lines'}{'count'}){
	$localdata->{'lines'}{'count'}=0;
    }
    if(!defined $perioddata{$localdata->{"period"}}{'count'}){
	$perioddata{$localdata->{"period"}}{'count'}=0;
    }
    $localdata->{'lines'}{'count'} = $localdata->{'lines'}{'count'} + $lsize;
    $perioddata{$localdata->{"period"}}{'count'} = $perioddata{$localdata->{"period"}}{'count'} + $lsize;
    
    push (@{$localdata->{'lines'}{'data'}}, {%linearray});
    push (@{$perioddata{$localdata->{"period"}}{'lines'}{'data'}}, {%linearray});
    
    #print  XMLout($graphemearray);
    return \%linearray;
    
}

sub dographemeData{
    my $root = shift;
    my $localdata = shift;
    my %graphemearraytemp = ();
    
   
    my $sumgraphemes =0;
    my @cells = $root->get_xpath('c');
    my @fields = $root->get_xpath('f');
    my @alignmentgrp = $root->get_xpath('ag');
    
    foreach my $i (@cells){
	my $temp = &dographemeData($i,$localdata);
	#$sumgraphemes = &addgraphemes($sumgraphemes,$temp);
	push(@{ $graphemearraytemp{'cells'} }, $temp);
    }
    foreach my $i (@fields){
	my $temp = &dographemeData($i,$localdata);
	#$sumgraphemes = &addgraphemes($sumgraphemes,$temp);
	$temp->{"type"} = $i->{att}->{"type"};
	push(@{ $graphemearraytemp{'fields'} }, $temp);
    }
    foreach my $i (@alignmentgrp){
	my $temp = &dographemeData($i,$localdata);
	#$sumgraphemes = &addgraphemes($sumgraphemes,$temp);
	$temp->{"form"} = $i->{att}->{"form"};
	push(@{ $graphemearraytemp{'alignmentgrp'} }, $temp);
    }
    
    my @graphemes = $root->get_xpath('g:w');
    my $graphemesize = scalar @graphemes;
    my $name = "words";
    my $lang = "";
    
    
#    TODO  words can be split over 2 lines. if they are split the lines always ready l-r
#    g:w ....  g:swc take the form from g:w not g:swc and only use swc to delve deeper into the word
#    good to have list of what are split words as fun to study P382687
    foreach my $i (@graphemes){
	my $temp = &doInsideGrapheme($i, $localdata);
	my $form = "";
	if($i->{att}->{"form"}){
	    $form = $i->{att}->{"form"};
	}
	if($i->{att}->{"g:break"}){
	    savebroken($name,$lang,$form,$localdata,$i->{att}->{"g:break"} ,$temp,"words");
	}
	else{
	    saveinfo($name,$lang,$form,$localdata ,$temp ,"words");
	}
	
	push(@{ $graphemearraytemp{'graphemes'} }, $temp);
    }
    
    my $total = $sumgraphemes + $graphemesize;
    
    if(!defined $localdata->{'words'}){
	$localdata->{'words'} = ();
    }
    if(!defined $localdata->{'words'}{'count'}){
	$localdata->{'words'}{'count'}=0;
    }
    if(!defined $perioddata{$localdata->{"period"}}{'words'}{'count'}){
	$perioddata{$localdata->{"period"}}{'words'}{'count'}=0;
    }
    
    
    &outputtext("\n Total Number of graphemes within Line ".$sumgraphemes);
    &outputtext("\n Number of graphemes not in sub groups ".$graphemesize);
    &outputtext("\n Total Number of lines ".$total);
    #$graphemearray->{'grapheme'} = $graphemesize;
    #$graphemearray->{'allgraphemes'} = $total;
    return \%graphemearraytemp;
}


sub doInsideGrapheme{
    my $root = shift;
    my $localdata = shift;
    my $lang = shift || ""; #inherit lang if passed
    my %singledata = ();
    if($root->{att}->{"xml:lang"}){
	$lang = $root->{att}->{"xml:lang"};
    }
    my @graphemesN = $root->get_xpath('g:n');
    my @graphemesX = $root->get_xpath('g:x');
    
    #missing elements
    $singledata{"graphemesX"} = &doG("graphemesX",$lang,\@graphemesX, $localdata);
    #numbers elements
    $singledata{"graphemesN"} = &doG("graphemesN",$lang,\@graphemesN, $localdata);
    
    $singledata{"graphemeSingles"} = &doGSingles($lang,$root, $localdata);
    
    #g:c contain g:s,n,x,v
    my @graphemesC = $root->get_xpath('g:c');
    $singledata{"graphemesC"}{"data"} = &doG("graphemesC",$lang,\@graphemesC, $localdata);
    foreach my $i (@graphemesC){
	my $temp = &doInsideGrapheme($i, $localdata, $lang);
	push @{ $singledata{"graphemesC"}{"inner"} } , $temp;
    }
    
    #g:q contain g:s,n,x,c,v
    my @graphemesQ = $root->get_xpath('g:q');
    $singledata{"graphemesQ"}{"data"} = &doG("graphemesQ",$lang,\@graphemesQ, $localdata);
    foreach my $i (@graphemesQ){
	my $temp = &doInsideGrapheme($i, $localdata,  $lang);
	push @{ $singledata{"graphemesQ"}{"inner"} } , $temp;
    }
    
    #g:gg contain g:s,n,x,c,v
    my @graphemesGG = $root->get_xpath('g:gg');
    $singledata{"graphemesGG"}{"data"} = &doG("graphemesGG",$lang,\@graphemesGG, $localdata);
    foreach my $i (@graphemesGG){
	my $temp = &doInsideGrapheme($i, $localdata, $lang);
	push @{ $singledata{"graphemesGG"}{"inner"} } , $temp;
    }
    #g:d contain g:s,n,x,c,v
    my @graphemesD = $root->get_xpath('g:d');
    $singledata{"graphemesD"}{"data"} = &doG("graphemesD",$lang,\@graphemesD, $localdata);
    foreach my $i (@graphemesD){
	my $temp = &doInsideGrapheme($i, $localdata, $lang);
	push @{ $singledata{"graphemesD"}{"inner"} } , $temp;
    };#can be 1st and last
    my @graphemesS = $root->get_xpath('g:s');
    $singledata{"graphemesS"}{"data"} = &doG("graphemesS",$lang,\@graphemesS, $localdata);
    foreach my $i (@graphemesS){
	my $temp = &doInsideGrapheme($i, $localdata, $lang);
	push @{ $singledata{"graphemesS"}{"inner"} } , $temp;
    };#can have things inside
    
    return \%singledata;
}
sub doGSingles{
    my $lang = shift;
    my $root = shift;
    my $localdata = shift;
    my %singledata = ();
    $singledata{"graphemesS"} = &doGsv("graphemesS",$lang,$root,"g:s", $localdata);
    $singledata{"graphemesV"} = &doGsv("graphemesV",$lang,$root,"g:v", $localdata);
    
    #TODO glue B+M together with the S or V that is above it and do not consider separately
    $singledata{"graphemesB"} = &doGsv("graphemesB",$lang,$root,"g:b", $localdata);
    $singledata{"graphemesM"} = &doGsv("graphemesM",$lang,$root,"g:m", $localdata);
    return \%singledata;
}
sub doGsv{
    my $name = shift;
    my $lang = shift;
    my $root = shift;
    my $xpath = shift;
    my $localdata = shift;
    my %singledata = ();
    
    my @graphemes = $root->get_xpath($xpath);
    foreach my $i (@graphemes){
	
	my $form = "";
	if($i->text){
	    $form = $i->text;
	}
	if($i->{att}->{"g:break"}){
	    savebroken($name,$lang,$form,$localdata,$i->{att}->{"g:break"} ,\%singledata);
	}
	else{
	    saveinfo($name,$lang,$form,$localdata ,\%singledata);
	}
    }
    return \%singledata;
}
sub savebroken{
    
    my $name = shift;
    my $lang = shift;
    my $form = shift;
    my $localdata = shift;
    my $break = shift;
    my $singledata = shift;
    my $type = shift;
    if(!defined $break){
	$break = "BROKEN";
    }
    
    if(!defined $type){
	$type = "graphemes";
    }
    push(@{$singledata->{'all'.$type.$break.'Forms'}},$form);
    push(@{$singledata->{'all'.$type.$break.'Forms'}},$form);
    $localdata->{$type}{'count'}++;
    $localdata->{$type}{'broken'}++;
    if($lang eq ""){
	$lang = "noLang";
    }
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'num'}++;
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'num'}++;
    
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'form'}{$form}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'form'}{$form}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'form'}{$form}{'num'}++;
    
    if($localdata->{"period"}){
	$perioddata{$localdata->{"period"}}{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'num'}++;
	$perioddata{$localdata->{"period"}}{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{$break}{'form'}{$form}{'num'}++;
	$perioddata{$localdata->{"period"}}{$type}{'count'}++;
    }
}

sub saveinfo{
    my $name = shift;
    my $lang = shift;
    my $form = shift;
    my $localdata = shift;
    my $singledata = shift;
    my $type = shift;
    
    if(!defined $type){
	$type = "graphemes";
    }
    
    $localdata->{$type}{'count'}++;
    $localdata->{$type}{'preserved'}++;
    push(@{$singledata->{'all'.$type.'Forms'}},$form);
    
    if($lang eq ""){
	$lang = "noLang";
    }
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'num'}++;
    
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'all'}{'form'}{$form}{'num'}++;
    
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'num'}++;
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'num'}++;
    
    $singledata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'form'}{$form}{'num'}++;
    $output{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'form'}{$form}{'num'}++;
    $localdata->{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'form'}{$form}{'num'}++;
    
    
    if($localdata->{"period"}){
	$perioddata{$localdata->{"period"}}{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'num'}++;
	$perioddata{$localdata->{"period"}}{$type}{"type"}{$name}{"lang"}{$lang}{"type"}{'preserved'}{'form'}{$form}{'num'}++;
	$perioddata{$localdata->{"period"}}{$type}{'count'}++;
    }
}

sub doG{
    my $name = shift;
    my $lang = shift;
    my $root = shift;
    my $localdata = shift;
    my %singledata = ();
    foreach my $i (@{$root}){
	my $form = "";
	if($i->{att}->{"form"}){
	    $form = $i->{att}->{"form"};
	}
	if($i->{att}->{"g:break"}){
	    savebroken($name,$lang,$form,$localdata,$i->{att}->{"g:break"} ,\%singledata);
	}
	else{
	    saveinfo($name,$lang,$form,$localdata ,\%singledata);
	    &doGSingles($lang, $i, $localdata);
	}
    }
    return \%singledata;
}


#abstracted so it can become more complex if the Line gets more complex
sub addLines{
    my $data = shift;
    my $adddata = shift;
    return $data + $adddata->{"alllines"};
}

sub doQstats{}




sub outputtext{
    my $data = shift;
    if($outputtype eq "text"){
	print $data;
    }
}
#create the folder if it doesn't already exist -
#issue will ensure if permissions on the parent folder are incorrect
sub makefile{
    my $path = shift;
    my $result = `mkdir $path 2>&1`; 
}

#generic function to write to an file somewhere
sub writetofile{
    my $shortname = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    my $startpath = $resultspath."/".$resultsfolder;
    &makefile($startpath); #pass to function
    my $destinationdir = $startpath;
    print $destinationdir."/".$shortname;
    if(defined $data){
    #    create a file called the shortname - allows sub sectioning of error messages
	open(SUBFILE2, ">".$destinationdir."/".$shortname) or die "Couldn't open: $!";
	binmode SUBFILE2, ":utf8";
	print SUBFILE2 XMLout($data);
	close(SUBFILE2);
    }
}
#generic function to write to an error file somewhere
sub writetoerror{
    my $shortname = shift; #passed in as a parameter
    my $error = shift; #passed in as a parameter
    my $startpath = $errorfile."/".$errorpath;
    &makefile($startpath); #pass to function
    
    my $destinationdir = $startpath;
#    create a file called the shortname - allows sub sectioning of error messages
    open(SUBFILE2, ">>".$destinationdir."/".$shortname) or die "Couldn't open: $!";
    print SUBFILE2 $error."\n";
    close(SUBFILE2);
}
#iterate over folder
sub traverseDir{
    my $path = shift; # filepath to start the search
    my $dirname = shift; #directory to start the search
    my $typename = shift; # parameter used in the global hash %config to save info
    my $ext = shift; # parameter to specify the file extension e.g. xml/ xtf we are interested in 
    my $checkforchildren = shift; # parameter to set whether or not to devel into any folders found
    my @childdir; #this is a local param as it is only useful in the context of it's parent directory
    
    my $dir = $path."/".$dirname;
    
    opendir(DIR, $dir) or die $!;
    while (my $file = readdir(DIR)) {

        # Use a regular expression to ignore files beginning with a period as they aren't important
        next if ($file =~ m/^\./);
        
        # Use -f to test for a file
        if(-f "$dir/$file"){
            # Ignore all files which don't have the extension we are interested in
            next if($file !~m|\.${ext}$|);
            push(@{$config{"filelist"}{$typename}}, "$dir/$file");# places in the global config so we can use the info later
            $config{"filehash"}{$typename}{"$file"} = 1;
        }
            
        # use -d to test for a directory
        elsif(-d "$dir/$file" && $checkforchildren){
            push(@{$config{"dirlist"}{$typename}}, "$dir/$file"); # places in the global config so we can use the info later
            push(@childdir, "$file");
        }
    }

    closedir(DIR);
    
    #recursively drop into folders and get more files
    foreach(@childdir){
        my $thisdir = $_;
    	&traverseDir($dir, $thisdir, $typename, $checkforchildren); #use all same parameters except for child dir.
    }
}
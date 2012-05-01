#!/usr/bin/perl -w
use warnings;
use strict;
use Carp ();
local $SIG{__WARN__} = \&Carp::cluck;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;
binmode STDOUT, ":utf8";

my $PQroot = "";
my %PQdata = ();  # data per text
my %perioddata = (); # data per period
my %langdata = ();   # data per language

#my %output = ();
my %config;
$config{"typename"} = "";
$config{"filehash"} = ();
$config{"filelist"} = ();
$config{"dirlist"} = ();
my $destinationdir = "../dataout";
my $startpath = "..";
my $startdir = "datain";
my $errorfile = "../errors";
my $errorpath = "perlerrors";
my $outputtype="text";
my $resultspath = "..";
my $resultsfolder = "/dataout";



&general_stats();

sub general_stats{    
    &writetoerror("stats","starting ".localtime);
    my $ext = "xtf";
    $config{"typename"} = $ext;
    &traverseDir($startpath, $startdir,$config{"typename"},1,$ext);
    my @allfiles = @{$config{"filelist"}{$config{"typename"}}};
    
#    loop over each of the files we found
# Q-files
    foreach(@allfiles){
        my $filename = $_;
        if($filename=~m|/([^/]*).${ext}$|){
            my $shortname = $1;
	    &outputtext("\nShortName: ". $shortname);
            if($shortname=~m|^Q|gsi){
                &doQstats($filename, $shortname);
            }
	}
    }
    
# Create outputfiles for sign data of Q-files
    foreach my $period (keys %perioddata){
	&writetofile("Q_PERIOD_".$period,$perioddata{$period});
    }
    
    foreach my $lang (keys %langdata){
	&writetofile("Q_LANG_".$lang,$langdata{$lang});
    }
    
# P-files
# empty hashes and restart for P-files
#    %output = ();
    %langdata = ();
    %perioddata = ();

    foreach(@allfiles){
        my $filename = $_;
        if($filename=~m|/([^/]*).${ext}$|){
            my $shortname = $1;
#	    $output{$shortname} = ();
	    &outputtext("\nShortName: ". $shortname);
	    if($shortname=~m|^P|gsi){
		&doPstats($filename, $shortname);
	    }
	}
    }

# Create outputfiles for sign data of P-files
    foreach my $period (keys %perioddata){
	&writetofile("P_PERIOD_".$period,$perioddata{$period});
    }
    
    foreach my $lang (keys %langdata){
	&writetofile("P_LANG_".$lang,$langdata{$lang});
    }
}

#TODO make this better
sub doQstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes =0;
    
    # xtf-file
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    my $twigPQObj = XML::Twig->new(
                                 twig_roots => { 'xcl' => 1 }
                                 );
    $twigPQObj->parsefile($filename);
    $PQroot = $twigPQObj->root;
    $twigPQObj->purge;
    
    # .xmd, metadata-file
    my $twigObjXmd = XML::Twig->new(
                                 twig_roots => { 'cat' => 1 }
                                 );
    my $xmdfile = $filename;
    $xmdfile=~s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;
    
#   Q texts: possibly divided into divs with lines, linegroups and nonx
#   get general stats, graphemes, groups and words
    for (keys %PQdata){
        delete $PQdata{$_};
    }
    
    &getMetaData($root, $rootxmd);
    
    my @divs = $root->get_xpath('div');
    my $dsize = scalar @divs;
    #&outputtext("\n Number of Divs:". $dsize);
    my $dcount = 0;
#    $output{$shortname}{"div"} = ();


#   Find first div, lg, l or nonx    
#    my $element = $root->first_child();
#    my $tag = $element->tag;
#    while (($tag ne "div") and ($tag ne "lg") and ($tag ne "l") and ($tag ne "nonx")) {
#	$element = $element->next_sibling();
#	$tag = $element->tag;
#    }
    
    $PQdata{"generalStats"} = ();

    foreach my $i (@divs){
	$dcount++;
	my $linedata = "";
        #&outputtext("\n Div ".$dcount." of type ".$i->{att}->{type});
#        my %data = &doLineData($i);
#	$sumlines  = &addLines($sumlines, \%data);
#	$sumgraphemes  = &addgraphemes($sumgraphemes,\%data);
	    #my %alldata = ();
	    #$alldata{'type'}=$i->{att}->{type};
	my %statdata = ();
	$statdata{'type'}=$i->{att}->{'type'};
	$statdata{'n'}=$i->{att}->{'n'};
#	$alldata{'lines'}=\%data;
#	push (@{$output{$shortname}{"div"}}, \%alldata);
	
	$linedata = &doLineData($i, \%PQdata);
	if($linedata ne "" && defined($linedata)){
	    #if($broken){
	    #    push (@{$alldata{'brokencolumn'}}, $linedata);
	    #}
	    #else{
	    push (@{$statdata{'div'}}, $linedata);
	    #}
	}
	
	push (@{$PQdata{"generalStats"}{"div"}}, \%statdata);
#	push (@{$output{$shortname}{"div"}}, \%alldata);
    }
    my $linedata = "";
#        my %statdata = ();
    $linedata = &doLineData($root, \%PQdata);
    if($linedata ne "" && defined($linedata)){
#	    push (@{$statdata{'all'}, $linedata);
	push (@{$PQdata{"generalStats"}{notInDiv}}, $linedata);
    }
    #my %data = &doLineData($root);
    #$sumlines  = &addLines($sumlines, \%data);
    
    #$output{$shortname}{"lines"} = \%data;
    
    #$output{$shortname}{"totalLines"} = $sumlines;
    #$output{$shortname}{"allgraphemes"} = $sumgraphemes;
    #$output{$shortname}{"divs"} = $dsize;
    
    &writetofile($shortname,\%PQdata);
}

#sub analyseQ{
#    my $root = shift;
#    my $linedata = shift;
#    my %infoarray = ();
#    $infoarray{"stats"}{"divs"} = 0;
#    $infoarray{"stats"}{"lines"} = 0;
#    $infoarray{"stats"}{"linegroups"} = 0;
#    my @children = $root->children();
#    foreach my $i (@children) {
#	my $tag = $i->tag;
#	if ($tag eq "div") {
#	    my $temp = &analyseQ($i, \%infoarray);
#	    push (@{$infoarray{"div"}}, $temp);
#	    $infoarray{"stats"}{"divs"}++;
#	}
#	elsif ($tag eq "l") {
#	    $linedata = &dographemeData ($i, \%infoarray);
#	    $infoarray{"stats"}{"lines"}++
#	}
#	elsif ($tag eq "lg") {
#	    #$linedata = &LGLine ($i);
#	    $infoarray{"stats"}{"linegroups"}++;
#	}
#	elsif ($tag eq "nonx") {
#	    #my $nonxdata = &NonxLine ($i);
#	    #push (@{$infoarray{"nonx"}}, $nonxdata);
#	}
#	if (($linedata ne "") && (defined($linedata))) {
#	    push (@{$infoarray{"line"}}, $linedata);
#	}
#	}
#    return \%infoarray;
#}


sub doPstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes =0;
    
    # xtf-file
    my $twigObj = XML::Twig->new(
                                 twig_roots => { 'protocols' => 1, 'object' => 1, 'mds' => 1 }
                                 );
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    
    my $twigPQObj = XML::Twig->new(
                                 twig_roots => { 'xcl' => 1 }
                                 );
    $twigPQObj->parsefile($filename);
    $PQroot = $twigPQObj->root;
    $twigPQObj->purge;
    
    
    
    # .xmd, metadata-file
    my $twigObjXmd = XML::Twig->new(
                                 twig_roots => { 'cat' => 1 }
                                 );

    my $xmdfile = $filename;
    $xmdfile=~s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;

    for (keys %PQdata){
        delete $PQdata{$_};
    }

    &getMetaData($root, $rootxmd);
    
#   P texts: divided into surfaces, (columns), lines, linegroups and nonx [*** NOTE: headers and milestones are not included at present - maybe useful when comparing sign use within rituals [incantation and ritual instructions]]
#   get general stats, graphemes, groups and words
    my @surfaces = $root->get_xpath('object/surface');
    my $size = scalar @surfaces;
    #&outputtext("\n Number of surfaces:". $size);
    
    $PQdata{"name"} = $shortname;
    
#    $output{$shortname}{"generalStats"}{"surface"} = ();
    
    my $count = 0;
    foreach my $i (@surfaces){
	if(!defined $PQdata{"generalStats"}{"surface"}){
	    $PQdata{"generalStats"}{"surface"} = ();
	}
        $count++;
	
        my @columns = $i->get_xpath('column');
        my $csize = scalar @columns;
        #&outputtext("\n Number of columns for surface ".$count." :". $csize);

	#my %alldata = ("type","","label","","columns",0);  # alldata is in the process of being replaced by the more compact statdata
	my %statdata = ("type","","label","","columns",0);
        my $ccount = 0;
    
	my @children = $i->children();
	my %nonx = ();
	my $broken = 0;
	my $linedata = "";
	for ( @children ) {
	    my $j = $_;
	    my $type = $j->tag;
	    if($type eq "column"){
		if( $nonx{"extent"} && $nonx{"extent"} eq "start"){ # broken at the start.
		    $broken = 1;
		    %nonx = ();
		}
		$ccount++;
		#&outputtext("\n Number of lines for surface ".$count."  column ".$ccount." :");
		$linedata = &doLineData($j, \%PQdata);
	    }
	    elsif($type eq "nonx"){
		$nonx{"state"} = $_->{att}->{"state"}; # don't think this is useful
		$nonx{"extent"} = $_->{att}->{"extent"}; # need to output this exactly as is.
		$nonx{"scope"} = $_->{att}->{"scope"};
		
		if( $nonx{"extent"} && $nonx{"extent"} eq "rest"){
#		    broken at the end.
		    $broken = 1;
		    %nonx = ();
		}
#		extent =
#		scope can be lines or columns
#      <brokencolumn allgraphemes="0" totalLines="3" brokenline="" groups="0" lines="3">
#TODO cf. P338326, P348776  **P345960 - has them within the columns?
#add in a field for count of known broken lines - which are occasionally mentioned in the nonx
#		also nonx can have a lot of different stuff in extent.
#	if extent == end || rest then applies to the column above else (probably) - greta to CONFIRM
            #<nonx xml:id="P348776.3" strict="1" extent="rest" scope="column" state="missing">start of column broken</nonx>
	    }
	    
    #TODO	    nonX to work out missing lines vs perserved lines - will this work
#    do I need to push the broken value deeper into teh code to change the counts at doLineData

# TODO add nonx into lines as well... maybe
	    if($linedata ne "" && defined($linedata)){
		push (@{$statdata{'column'}}, $linedata);
		#if($broken){
		#    push (@{$alldata{'brokencolumn'}}, $linedata);
		#}
		#else{
		#    if(!defined $alldata{'column'}){
		#	@{$alldata{'column'}} = ();
		#    }
		#    push (@{$alldata{'column'}}, $linedata);
		#    
		#}
	    }
	}
	
        my @nonx = $i->get_xpath('nonx');
#        foreach my $j (@columns){
#	    
#        }
	#$alldata{'type'}=$i->{att}->{type}?$i->{att}->{type}:"";
	#$alldata{'label'}=$i->{att}->{label}?$i->{att}->{label}:"";
	#$alldata{'columns'}=$ccount;

	$statdata{'type'}=$i->{att}->{type}?$i->{att}->{type}:"";
	$statdata{'label'}=$i->{att}->{label}?$i->{att}->{label}:"";
	$statdata{'columns'}=$ccount;
	
#	push (@{$localdata{"generalStats"}{"surface"}}, \%alldata);
	push (@{$PQdata{"generalStats"}{"surface"}}, \%statdata);
#	push (@{$output{$shortname}{"surface"}}, \%alldata);
    }
    #$output{$shortname}{"totalLines"} = $sumlines;
    #$output{$shortname}{"allgraphemes"} = $sumgraphemes;
    #$output{$shortname}{"surfaces"} = $size;
    
    &writetofile($shortname,\%PQdata);
}


sub getMetaData{  # find core metadata fields 
    my $root = shift;
    my $rootxmd = shift;
    
    $PQdata{"period"} = ""; $PQdata{"genre"} = ""; $PQdata{"subgenre"} = ""; $PQdata{"provenience"} = ""; $PQdata{"designation"} = "";
    $PQdata{"language"} = ""; $PQdata{"script"} = ""; $PQdata{"writer"} = ""; $PQdata{"object"} = "";
    
    #get designation, provenience/provenance, period [date], genre, subgenre, language, script
    
    my @mfields = $root->get_xpath('mds/m');
    # mds in xtf-file has 4 fields: period, genre, subgenre and provenience
    foreach my $i (@mfields){
	if($i->{att}->{k} eq "period"){   #<m k="period">Hellenistic</m>
	    $PQdata{"period"} = $i->text;
	    if(!defined $perioddata{$PQdata{"period"}}){
		$perioddata{$PQdata{"period"}} = ();
	    }
	}
	if($i->{att}->{k} eq "genre"){   #<m k="genre">administrative letter</m>
	    $PQdata{"genre"} = $i->text;
	}
	if($i->{att}->{k} eq "subgenre"){   
	    $PQdata{"subgenre"} = $i->text;
	}
	if($i->{att}->{k} eq "provenience"){   
	    $PQdata{"provenience"} = $i->text;
	}
    }
    
    my @temp = $root->get_xpath('object');
    $PQdata{"object"} = $temp[0]->{att}->{type};
        
    # these fields are not always filled in even if the information is known, hence we may need to check the metadatafile.
    
    $PQdata{"designation"} = $rootxmd->findvalue('cat/designation');
    
    if($PQdata{"period"} eq ""){
	$PQdata{"period"} = $rootxmd->findvalue('cat/period');

	# no period in SAAo, but <date c="1000000"/> [Neo-Assyrian]
	if($PQdata{"period"} eq ""){
	    my @date = $rootxmd->get_xpath('cat/date');
	    foreach my $i (@date) {
		my $temp = $i->{att}->{c};
		if($temp eq "1000000"){   # Q: Other codes ???
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
    
    if ($PQdata{"provenience"} eq ""){
	$PQdata{"provenience"} = $rootxmd->findvalue('cat/provenience');
	if ($PQdata{"provenience"} eq ""){
	    $PQdata{"provenience"} = $rootxmd->findvalue('cat/provenance');
	}
    }
    
    $PQdata{"language"} = $rootxmd->findvalue('cat/language');
    if ($PQdata{"language"} eq "") {
	my @protocols = $root->get_xpath('protocols/protocol');
	 # Q: what are the other options? *** maybe obsolete with new L2?
	foreach my $i (@protocols) {
	    if ($i->{att}->{type} eq "atf") {
		my $temp = $i->text;
		if ($temp eq "lang na") { $PQdata{"language"} = "Neo-Assyrian"; }
		elsif ($temp eq "lang nb") { $PQdata{"language"} = "Neo-Babylonian"; }
		elsif ($temp eq "lang akk") { $PQdata{"language"} = "Standard Babylonian"; }
	    }
	}
    }
    # in SAA not given in metadata, but in xtf-file under
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
    
    $PQdata{"writer"} = $rootxmd->findvalue('cat/ancient_author'); # SAA; Q: Greta - how about colophons?
}

#loop over each line and find some stats
sub doLineData{
    my $root = shift;
    my $localdata = shift;
    my %linearray = ();
    my @linegroups = $root->get_xpath('lg');
    my $lgsize = scalar @linegroups;
    #&outputtext("\n Number of group lines ".$lgsize);
    my $dcount = 0;
    my $sumlines = 0;
    
    foreach my $i (@linegroups){ # still think about linegroups (GUS, BIL, NTS, LGS) ***
	my @speciallines = $i->get_xpath('l');
	my $type = "";
	foreach my $j (@speciallines) {
	    if ($type eq "") {
		if ($j->{att}->{"type"}) {
		    $type = $j->{att}->{"type"};
		}
	    }
	}
	#print ("\n lg type ".$type."\n");
	if (($type eq "gus") || ($type eq "bil")) {
	    my $temp = &doLineData($i,$localdata);
	    $sumlines  = &addLines($sumlines, $temp);
	    push(@{ $linearray{'linegroups'} }, $temp);
	}
	elsif ($type eq "lgs") { #disregard l line *** still to be implemented
	    my $temp = &doLineData($i,$localdata);
	    $sumlines  = &addLines($sumlines, $temp);
	    push(@{ $linearray{'linegroups'} }, $temp);
	}
	else { # check anew
	    my $temp = &doLineData($i,$localdata);
	    $sumlines  = &addLines($sumlines, $temp);
	    push(@{ $linearray{'linegroups'} }, $temp);
	}
    }
    
    my @lines = $root->get_xpath('l');
    my $lsize = scalar @lines;
    
    my $sumgraphemes = 0;
    foreach my $i (@lines){
	if (($i->{att}->{"type"}) && ($i->{att}->{"type"} eq "nts")) {
	    # then something to think about
	}
	else {
	    my $graphemearray = &dographemeData($i, $localdata);
	    push(@{ $linearray{'graphemes'} }, $graphemearray);
	}
    }

    my $total = $sumlines + $lsize;
    #&outputtext("\n Total Number of lines within Groups ".$sumlines);
    #&outputtext("\n Number of lines not in groups ".$lsize);
    #&outputtext("\n Total Number of lines ".$total);
    $linearray{'lines'} = $lsize;
    $linearray{'lineGroups'} = $lgsize;
    $linearray{'totalLines'} = $total;
    $linearray{'allgraphemes'} = $sumgraphemes; # always 0 ***, doesn't work yet
    
    if(!defined $localdata->{"totalLines"}){
	$localdata->{"totalLines"} = ();
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
    
    #split words 
    
#    TODO  words can be split over 2 lines. if they are split the lines always ready l-r
#    g:w ....  g:swc take the form from g:w not g:swc and only use swc to delve deeper into the word
#    good to have list of what are split words as fun to study P382687 - not sure best route to attach them to their line above yet...
    my @splitgraphemes = $root->get_xpath('g:swc');
    my $splitgraphemesize = scalar @splitgraphemes;
    my $splitname = "splitwords";
    my $splitlang = "";
    
    foreach my $i (@splitgraphemes){
	my $splitlang = $i->{att}->{'xml:lang'};
	my $temp = &doInsideGrapheme($i, $localdata, $splitlang);
	my $form = "";
	if($i->{att}->{"form"}){
	    $form = $i->{att}->{"form"};
	}
	if($i->{att}->{"g:break"}){
	    saveData($splitname,"","",$splitlang,$form,"","","",$localdata,$i->{att}->{"g:break"} ,$temp,"splitwords");
	}
	else{
	    saveData($splitname,"","",$splitlang,$form,"","","",$localdata,"preserved",$temp,"splitwords");
	}
	
	push(@{ $graphemearraytemp{'splitgraphemes'} }, $temp);
    }
    
    # analyze words
    my @words = $root->get_xpath('g:w');
    my $graphemesize = scalar @words;
    my $name = "words";
    my $lang = "";

    foreach my $word (@words){
	if ($word->{att}->{"form"} ne "o"){ # words with form="o" are not words at all and shouldn't be considered (e.g. SAA 1 10 o 18 = P 334195).
	    $lang = $word->{att}->{'xml:lang'};
	    my $temp = &doInsideGrapheme($word, $localdata, $lang);
	    my $form = "";
	    if ($word->{att}->{"form"}){
	        $form = $word->{att}->{"form"};
	    }
	    my $wordid = $word->{att}->{"xml:id"};
	    my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # problem here  /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
	    my $cf = ""; my $pofs = ""; my $epos = "";
            

                # xtf-file
            #print "\n".$tempvalue."\n";
	    my @wordref = $PQroot->get_xpath($tempvalue); 
            #my @wordref = $PQroot->get_xpath('//l[@ref="Q000003.1.1"]/xff:f');
            
            
	    for (@wordref) {
                my $item = $_;
                if($item->{att}->{"cf"}){
                    $cf = $item->{att}->{"cf"};
                    $pofs = $item->{att}->{"pos"};
                    $epos = $item->{att}->{"epos"};
                    #print $cf;
                }
                
	    }
	    
	    if (($pofs eq "") && ($form ne "")) { # check if PN or not (rough classification)
		if ($form =~ /(^\{1\})|(^\{m\})/) {
		    $pofs = "PN";
		}
	    }
	    
	    if ($pofs eq "RN") {
		$pofs = "PN";  # no use to distinguish royal and other personal names in this analysis, I think
	    }
	    
	    if (($pofs eq "") && ($form ne "")) { # check if DN or not
		if ($form =~ /(^\{d\})/) {
		    $pofs = "DN";
		}
	    }
	    
	    # one could roughly classify geographical names (with {ki}, {kur}, {uru/iri}, {id2}), but I'm not sure how useful this would be
	    
	    #&outputtext("\nWord: ". $form."; lang: ".$lang);
	    my @children = $word->children();
	    my $no_children = scalar @children;
	    my $condition = 0;  # missing (2), damaged (1), preserved (0)
	    # how about marking preserved signs somehow, so that we immediately know how many of each are preserved ***
	    # pofs = part-of-speech (pos is used already for position)
            
#APRIL TODO THINK ABOUT THIS:::     do we mark in determinatives and phonetic complements in the array or have separate arrays for each
           #my %a_withd = {
           #     "preseverd" => [[1,0,1],[1],["d",0,1]],
           #     "damaged" => [[1,0,"x"],["x",0,1]],
           #     "missing" => [[1,0,1],[0,1]]
           #};
           #
           #my %a_positions_preserverd = {
           # "pos1"=>["ssdf"=>4,"sadf"=>6],
           # "pos2"=>["ssdf"=>4,"sadf"=>6],
           # "pos3"=>["ssdf"=>4,"iuy"=>6],
           # "iddy"=>["a"=>6]
           #};
           #my %a_positions_damaged = {
           # "pos1"=>["ssdf"=>4,"sadf"=>6],
           # "pos2"=>["ssdf"=>4,"sadf"=>6],
           # "pos3"=>["ssdf"=>4,"iuy"=>6],
           # "iddy"=>["a"=>6]
           #};
           #my %a_positions_missing = {
           # "pos1"=>["ssdf"=>4,"sadf"=>6],
           # "pos2"=>["ssdf"=>4,"sadf"=>6],
           # "pos3"=>["ssdf"=>4,"iuy"=>6],
           # "iddy"=>["a"=>6]
           #};
#           per text,all texts
           
           
            
	    foreach my $i (@children) {
		my $break = "";
		if ($i->{att}->{"g:break"}) {
		    $break = $i->{att}->{"g:break"};
		}
		if ($break eq "missing") { $condition = $condition + 2; }
		elsif ($break eq "damaged") { $condition++; }
	    }
	    my $state = "damaged";
	    if ($condition == 0) { $state = "preserved"; }
	    elsif ($condition == (2*$no_children))
		{ $state = "missing"; }
	    
	    if ($pofs ne "PN") {
		saveWord($lang,$form,$localdata,$state,$temp,"words",$cf, $pofs, $epos);
	    }
	    else {
		saveWord($lang,$form,$localdata,$state,$temp,"PN",$cf, $pofs, $epos);
	    }
	    
	    push(@{ $graphemearraytemp{'words'} }, $temp);
	}
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
    
    
    #&outputtext("\n Total Number of graphemes within Line ".$sumgraphemes);
    #&outputtext("\n Number of graphemes not in sub groups ".$graphemesize);
    #&outputtext("\n Total Number of lines ".$total);
    #$graphemearray->{'grapheme'} = $graphemesize;
    #$graphemearray->{'allgraphemes'} = $total;
    return \%graphemearraytemp;
}


sub doInsideGrapheme{
    my $root = shift;  # word or sign
    my $localdata = shift;
    my $lang = shift; 
    my $role = shift || "";
    my $pos = shift || "";
    
    my %singledata = ();
    
    #missing elements
    my @graphemesX = $root->get_xpath('g:x');
    my $xtemp =  &doG("graphemesX",$lang,\@graphemesX, $localdata, "", "");
    if (scalar keys %$xtemp){
	    $singledata{"graphemesX"} = $xtemp;
	}
    foreach my $i (@graphemesX) {
	my $temp = &doInsideGrapheme($i, $localdata,  $lang, "gone", "");
	if (scalar keys %$temp){
	    push @{ $singledata{"graphemesX"}{"inner"} } , $temp;
        }
    }
    
    #numbers 
    my @graphemesN = $root->get_xpath('g:n');
    my $ntemp = &doG("graphemesN",$lang,\@graphemesN, $localdata, "number", $pos);
    if (scalar keys %$ntemp){
	    $singledata{"graphemesN"} = $ntemp;
	}
    foreach my $i (@graphemesN){
	my $temp = &doInsideGrapheme($i, $localdata,  $lang, "number", "");
	if (scalar keys %$temp){
	    push @{ $singledata{"graphemesN"}{"inner"} } , $temp;
        }
     }   
     
    # what's the purpose of this? is this the way to handle g:s and g:v?
    my $singletemp = &doGSingles($lang,$root, $localdata, $role, $pos); 
    if (scalar keys %$singletemp){
	$singledata{"graphemeSingles"} = $singletemp;
    }
    
    #g:c contain g:s,n,x,v
    my @graphemesC = $root->get_xpath('g:c');
    my $ctemp = &doG("graphemesC",$lang,\@graphemesC, $localdata, "", "");
    if (scalar keys %$ctemp){
	$singledata{"graphemesC"}{"data"} = $ctemp;
    }
    foreach my $i (@graphemesC){
	my $temp = &doInsideGrapheme($i, $localdata, $lang, "", "");
	if (scalar keys %$temp){
	    push @{ $singledata{"graphemesC"}{"inner"} } , $temp;
	}
    }
    
    #g:q contain g:s,n,x,c,v
    my @graphemesQ = $root->get_xpath('g:q');
    my $qtemp = &doG("graphemesQ",$lang,\@graphemesQ, $localdata, "", "");
    if (scalar keys %$qtemp){
	$singledata{"graphemesQ"}{"data"} = $qtemp;
    }
    foreach my $i (@graphemesQ){
	my $temp = &doInsideGrapheme($i, $localdata,  $lang, "", "");
	if (scalar keys %$temp){
	    push @{ $singledata{"graphemesQ"}{"inner"} } , $temp;
	}
    }
    
    #g:gg contain g:s,n,x,c,v
    # Greta: ? extra information needed to pass on to datafiles ?
    my @graphemesGG = $root->get_xpath('g:gg');
#    my $gtemp = &doG("graphemesGG",$lang,\@graphemesGG, $localdata, "", "");
#    if (scalar keys %$gtemp){
#	$singledata{"graphemesGG"}{"data"} = $gtemp;
#    }
    foreach my $i (@graphemesGG){
	my $temp = &doInsideGrapheme($i, $localdata, $lang, "", "");
	if (scalar keys %$temp){
	    push @{ $singledata{"graphemesGG"}{"inner"} } , $temp;
	}
    }
    #g:d contain g:s,n,x,c,v
#    g:role attribute = phonetic/semantic; g:pos
    my @graphemesD = $root->get_xpath('g:d');
    # QUESTION: should $role and $pos be determined before going to doG ?
    #$singledata{"graphemesD"}{"data"} = &doG("graphemesD",$lang,\@graphemesD, $localdata, $role, $pos);
#    my $dtemp = &doG("graphemesD",$lang,\@graphemesD, $localdata, $role, $pos);
#    if (scalar keys %$dtemp){
#	$singledata{"graphemesD"}{"data"} = $dtemp;
#    }
    foreach my $i (@graphemesD){
	$role = $i->{att}->{"g:role"};
	$pos = $i->{att}->{"g:pos"};
	my $temp = &doInsideGrapheme($i, $localdata, $lang, $role, $pos);
	if (scalar keys %$temp){
    #		TODO - what am I meant to be doing with the semantic/phonetic stuff?
	    push @{ $singledata{$i->{att}->{"g:role"}}{$i->{att}->{"g:pos"}} } , $temp;  # what's the function of this?
	    push @{ $singledata{"graphemesD"}{"inner"} } , $temp;
	}
    };#can be 1st and last
    
    
# in this subroutine there is no section for @graphemesV and these values are correctly gathered;
# the values for @graphemesS, however, are wrong. Hope deleting this helps. Bit better, not yet totally fixed though.
#    my @graphemesS = $root->get_xpath('g:s');
#    my $stemp = &doG("graphemesS",$lang,\@graphemesS, $localdata, $role, $pos);
#    if (scalar keys %$stemp){
#	$singledata{"graphemesS"}{"data"} = $stemp;
#    }
#    foreach my $i (@graphemesS){
#	if (($role eq "") && ($i->{att}->{"g:role"})) {
#	    $role = $i->{att}->{"g:role"};
#	}
#	my $temp = &doInsideGrapheme($i, $localdata, $lang, $role, $pos);
#	if (scalar keys %$temp){
#	    push @{ $singledata{"graphemesS"}{"inner"} } , $temp;
#	}
#    };#can have things inside
    
    return \%singledata;
}
sub doGSingles{
    my $lang = shift;
    my $root = shift;
    my $localdata = shift;
    my $role = shift;
    my $pos = shift;
    my %singledata = ();
    $singledata{"graphemesS"} = &doGsv("graphemesS",$lang,$root,"g:s", $localdata, $role, $pos);
    $singledata{"graphemesV"} = &doGsv("graphemesV",$lang,$root,"g:v", $localdata, $role, $pos);
    
    #$singledata{"graphemesB"} = &doGsv("graphemesB",$lang,$root,"g:b", $localdata);
    #$singledata{"graphemesM"} = &doGsv("graphemesM",$lang,$root,"g:m", $localdata);
    return \%singledata;
}

sub doGsv{ 
    my $name = shift;
    my $lang = shift;
    my $root = shift;
    my $xpath = shift;
    my $localdata = shift;
    my $role = shift;
    my $pos = shift;
    my %singledata = ();
    
    my @graphemes = $root->get_xpath($xpath);
    foreach my $i (@graphemes){
	if ($i->text ne "o") {
	    my %syllables = ();
	    $syllables{"V"} = 1;
	    $syllables{"VC"} = 1;
	    $syllables{"CV"} = 1;
	    $syllables{"CVC"} = 1;
	    my $form = "";
	    
	    if($i->text){
	        $form = $i->text;
	    }
	    
	    if ($role eq "") { 
		if ($i->{att}->{"g:role"}) {
		    $role = $i->{att}->{"g:role"};
		    if (($role eq "semantic") || ($role eq "phonetic")) { $pos = $i->{att}->{"g:pos"}; }
		    else { $pos = ""; }  # position still has to be checked properly
		}
		else { $role = "syll"; $pos = ""; }
	    }
	    #my $role = "syll";
	    #if($i->{att}->{"g:role"} && $i->{att}->{"g:role"} ne ""){
	    #    $role = $i->{att}->{"g:role"};
	    #}
	    #elsif($root->{att}->{"g:role"} && $root->{att}->{"g:role"} ne ""){
	    #    $role = $root->{att}->{"g:role"};
	    #}
	    
	    # The baseform is the basic form without modifiers or the like	
	    my $baseform = "";
	    if($xpath eq "g:s" || $xpath eq "g:v"){
		$baseform = $i->findvalue("g:b");
		#if($i->{att}->{"form"} && $i->{att}->{"form"} eq "TA\@v"){
		#print "\n Not sure what is wrong with this...\ng:s form ".$i->{att}->{"form"};
		#print "\ng:b value ".$baseform;
		#}
	    }
	    
#	TODO: There is still a problem with the detection of the following baseform - no idea why PRIORITY (P224395)
#	<g:w xml:id="P224395.8.3" xml:lang="akk-x-neoass" form="TA@v">
#            <g:s form="TA@v" g:utf8="??" xml:id="P224395.8.3.0" g:break="damaged" g:status="ok" g:role="logo" g:logolang="sux" g:hc="1">
#              <g:b>TA</g:b>
#              <g:m>v</g:m>
#              <g:f>m</g:f>
#            </g:s>
#          </g:w>
	
	#    only for lang:akk aei{O}u
	    my $cvc = ""; my $logo = 0;  
	    if(($xpath eq "g:v") && ($lang=~m|^akk|)){ #extend to other languages later
		my $tempform = $form;
	        if ($baseform ne "") { 
		    $tempform = $baseform;
		}
		$cvc = lc($tempform);
		
		$cvc=~s|(\d)||g;
		$cvc=~s|([aeiou])|V|g;
		$cvc=~s|(\x{2080})||g;
		$cvc=~s|(\x{2081})||g;
		$cvc=~s|(\x{2082})||g;
		$cvc=~s|(\x{2083})||g;
		$cvc=~s|(\x{2084})||g;
		$cvc=~s|(\x{2085})||g;
		$cvc=~s|(\x{2086})||g;
		$cvc=~s|(\x{2087})||g;
		$cvc=~s|(\x{2088})||g;
		$cvc=~s|(\x{2089})||g;
		$cvc=~s|([^V])|C|g;
	    
	    #nuke the subscripts like numbers cf vcvv ia? 2080 - 2089
	    
	    # still have to get rid of words/values = "o"
	    # Greta: what happens to unclear readings? $BA etc.? How marked in SAAo?
	    
		if ($cvc eq "VV") {
		    $cvc = "CV";
		}
	    
		if (!($syllables{$cvc})) {
		    if ($role eq "semantic") {
		        $cvc = ""; 
		    }
		    elsif ($cvc eq "C") {
			if ($form eq "d") { $role = "semantic"; $cvc = ""; }
			elsif ($form eq "m") { $role = "semantic"; $cvc = ""; }
			else { $role = "leftover"; $cvc = ""; }
			
		    } # then the value should be x, so unreadable sign, treat as leftover
		    else { $role = "logo"; $cvc = ""; }
		}
		else {
		    if ($role eq "") {$role = "syll";}
		    if ($form eq "o") { $role = ""; $cvc = ""; }  # latest change - check if this works *** am I finally rid of the o's?
		}

	    }	
#	print $role;
	
	    if($xpath eq "g:s" && $lang =~m|^akk|){ #extend to other languages later
	        $logo = 1;
	    }

#TODO: role should be saved too PRIORITY
	    if($i->{att}->{"g:break"}){
	        saveData($name,$role,$pos,$lang,$form,$baseform,$cvc,$logo,$localdata,$i->{att}->{"g:break"} ,\%singledata);
	    }
	    else{
		saveData($name,$role,$pos,$lang,$form,$baseform,$cvc,$logo,$localdata,"preserved",\%singledata);
	    }
	}
    }
    return \%singledata;
}

sub saveWord{
#    my $name = shift;
    my $lang = shift;
    my $form = shift;
    my $localdata = shift;
    my $break = shift;
    my $singledata = shift;
    my $type = shift;
    my $cf = shift;
    my $pofs = shift;
    my $epos = shift;
    
    if($lang eq ""){
	$lang = "noLang";
    }
    
    $localdata->{$type}{'count'}++;
    $localdata->{$type}{"state"}{$break}{'num'}++;
    
    abstractdata2(\%{$localdata->{"lang"}{$lang}{$type}},$form,$cf,$pofs,$break,$epos,$type);
    
    if($localdata->{"period"}){
	abstractdata2(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}},$form,$cf,$pofs,$break,$epos,$type);
    }
    
    if($lang){
	abstractdata2(\%{$langdata{$lang}{$type}},$form,$cf,$pofs,$break,$epos,$type);
    }
}

sub abstractdata2{
    my $data = shift;
    my $form = shift;
    my $cf = shift;
    my $pofs = shift;
    my $break = shift;
    my $epos = shift;
#    my $name = shift;
    my $type = shift;

    my $totaltype = "total_".$type;
    
    $data->{"type"}{$type}{$totaltype}{$type}{$break}{'num'}++;
    if ($form ne "") {
	if ($cf ne "") {
	    $data->{"type"}{$type}{'form'}{$form}{'cf'}{$cf}{'pofs'}{$pofs}{'epos'}{$epos}{"state"}{$break}{'num'}++;
	    }
	else {
	    $data->{"type"}{$type}{'form'}{$form}{"state"}{$break}{'num'}++;
	}
	$data->{"type"}{$type}{"total"}{$break}{'num'}++;
    }
    $data->{'count'}++;
}



sub saveData{
    my $name = shift;
    my $role = shift;
    my $pos = shift;
    my $lang = shift;
    my $form = shift;
    my $baseform = shift;
    my $cvc = shift;
    my $logo = shift;
    my $localdata = shift;
    my $break = shift;
    my $singledata = shift;
    my $type = shift;
    
    if(!defined $type){
	$type = "graphemes";
    }
    push(@{$singledata->{'all'.$type.$break.'Forms'}},$form);
    
    if($baseform ne "" && $type ne "words"){
	push(@{$singledata->{'all'.$type.$break.'BaseForms'}},$form);
    }
    
    if($lang eq ""){
	$lang = "noLang";
    }
    
    $localdata->{$type}{'count'}++;
    $localdata->{$type}{"state"}{$break}{'num'}++;
    
    $localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"total_grapheme"}{$name}{$break}{'num'}++;
	
    if ($form ne "") { 
	if ($lang=~m|^akk|) {
	    if($cvc ne ""){
		if ($pos eq "") {
		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
		}
		else {
		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
		}
	    }
	    else {
		if ($pos eq "") {
		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
		}
		else {
		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
		}
	    }
	}
	else {
	    if ($pos eq "") {
		abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
	    }
	    else {
		abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
	    }
	}
    }
    
    $localdata->{"lang"}{$lang}{$type}{'count'}++;
 
    # for period-file
    if($localdata->{"period"}){
	$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"total_grapheme"}{$name}{$break}{'num'}++;
	
	if ($form ne "") {
	    if ($pos eq "") {
		if ($lang=~m|^akk|) {
		    if($cvc ne ""){ 
			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
		    }
		    else {
			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
		    }
		}
		else {
		    abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
		}
	    }
	    else {
		if ($lang=~m|^akk|) {
		    if($cvc ne ""){ 
			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
		    }
		    else {
			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
		    }
		}
		else {
		    abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
		}
	    }
	    $perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{'count'}++;
	}
    
    }
    
    # for language-file
    if($lang){
	# reorganized: first type, then form, then break, hope this works.
	# TODO: add information about determinatives/phonetic complements
	$langdata{$lang}{$type}{"type"}{$name}{"total_grapheme"}{$name}{$break}{'num'}++;
	
	if ($form ne "") {
	    if ($pos eq "") {
		if ($lang=~m|^akk|) {
		    if($cvc ne ""){ 
			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
		    }
		    else {
			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
		    }
		}
		else {
		    abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
		}
		$langdata{$lang}{$type}{'count'}++;
	    }
	    else {
		if ($lang=~m|^akk|) {
		    if($cvc ne ""){
			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
		    }
		    else {
			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
		    }
		}
		else {
		    abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
		}
		$langdata{$lang}{$type}{'count'}++;
	    }
	}
    }
}

sub abstractdata{
    my $data = shift;
    my $baseform = shift;
    my $break = shift;
    my $form = shift;
    if($baseform eq ""){
	$data->{'form'}{$form}{"state"}{$break}{'num'}++;
    }
    else {
	#print ("\n Baseform :".$baseform." of form ".$form);
	$data->{'form'}{$baseform}{"state"}{$break}{'num'}++;
	$data->{'form'}{$baseform}{'modform'}{$form}{"state"}{$break}{'num'}++;
    }
    $data->{"total"}{$break}{'num'}++;
}


sub doG{
    my $name = shift;
    my $lang = shift;
    my $root = shift;
    my $localdata = shift;
    my $role = shift;
    my $pos = shift;
    my %singledata = ();
    foreach my $i (@{$root}){
	my $form = "";
	if($i->{att}->{"form"}){
	    $form = $i->{att}->{"form"};
	}
	if ($form=~m|^0|) {
	    $form = substr($form, 1, length($form)-1);
	}
	else {
	    if ($i->{att}->{"g:type"}) {
	    $form = $i->{att}->{"g:type"}; # maybe ellipsis or so
	    }
	}
	
	if (($role eq "") && ($i->{att}->{"g:role"})) {
	    $role = $i->{att}->{"g:role"};
	}
	my $break = "preserved";
	if($i->{att}->{"g:break"}) { $break = $i->{att}->{"g:break"}; }
	
	&saveData($name,$role,$pos,$lang,$form,"","",0,$localdata,$break,\%singledata);
    }
    return \%singledata;
}


#abstracted so it can become more complex if the Line gets more complex
sub addLines{
    my $data = shift;
    my $adddata = shift;
    return $data + $adddata->{"totalLines"};
}

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
    if((defined $data) && ($data ne "")){
    #    create a file called the shortname - allows sub sectioning of error messages
	&outputtext("\n");
	open(SUBFILE2, ">".$destinationdir."/".$shortname.".xml") or die "Couldn't open: $!";
	binmode SUBFILE2, ":utf8";
	print SUBFILE2 XMLout($data);  
	close(SUBFILE2);
	&outputtext("\n");
    }
}

#generic function to write to an error file somewhere
sub writetoerror{
    my $shortname = shift; #passed in as a parameter
    my $error = shift; #passed in as a parameter
    my $startpath = $errorfile."/".$errorpath;
    &makefile($startpath); #pass to function
    
    my $destinationdir = $startpath;
    print $destinationdir."/".$shortname;
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
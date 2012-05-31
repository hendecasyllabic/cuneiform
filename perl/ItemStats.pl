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
my %corpusdata = (); # overview of selected metadata per corpus

my %config;
$config{"typename"} = "";
$config{"filehash"} = ();
$config{"filelist"} = ();
$config{"dirlist"} = ();
my $destinationdir = "../dataoutNEW";
my $startpath = "..";
my $startdir = "datain";
my $errorfile = "../errors";
my $errorpath = "perlerrors";
my $outputtype="text";
my $resultspath = "..";
my $resultsfolder = "/dataoutNEW";

my @testthing = ();

&ItemStats();

sub ItemStats{    
    &writetoerror("ItemStats","starting ".localtime);
    my $ext = "xtf";
    $config{"typename"} = $ext;
    &traverseDir($startpath, $startdir,$config{"typename"},1,$ext);
    my @allfiles = @{$config{"filelist"}{$config{"typename"}}};
    
# loop over each of the xtf-files we found
# Q-files
    foreach(@allfiles){
        my $filename = $_;
        if($filename =~ m|/([^/]*).${ext}$|){
            my $shortname = $1;
	    &outputtext("\nShortName: ". $shortname);
            if($shortname =~ m|^Q|gsi){
                &doQstats($filename, $shortname);
            }
	}
    }
    
# P-files
    foreach(@allfiles){
        my $filename = $_;
        if($filename =~ m|/([^/]*).${ext}$|){
            my $shortname = $1;
	    &outputtext("\nShortName: ". $shortname);
	    if($shortname =~ m|^P|gsi){
		&doPstats($filename, $shortname);
	    }
	}
    }

# Create corpus metadatafile for the whole corpus
    &writetofile("CORPUS_META", \%corpusdata);
}

sub doQstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
    # xtf-file
    my $twigObj = XML::Twig->new(
				 twig_roots => { 'composite' => 1, 'protocols' => 1, 'mds' => 1 }  
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
    $xmdfile =~ s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;
    
#   Q texts: possibly divided into divs with lines, linegroups and nonx
#   get general stats, graphemes, groups and words
    for (keys %PQdata){
        delete $PQdata{$_};
    }
    
    &getMetaData($root, $rootxmd, $shortname, "Q");

    if (!defined $PQdata{"01_Structure"}) { $PQdata{"01_Structure"} = (); }
    
    push(@{$PQdata{"01_Structure"}}, &getStructureData($root, "Q"));

    &checkPQdataStructure;

    &writetofile($shortname, \%PQdata);
}

sub doPstats{
    my $filename = shift;
    my $shortname = shift;
    my $sumlines = 0;
    my $sumgraphemes = 0;
    
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
    $xmdfile =~ s|(\.\w*)$|.xmd|;
    $twigObjXmd->parsefile($xmdfile);
    my $rootxmd = $twigObjXmd->root;
    $twigObjXmd->purge;

    for (keys %PQdata){
        delete $PQdata{$_};
    }

    &getMetaData($root, $rootxmd, $shortname, "P");

    if (!defined $PQdata{"01_Structure"}) { $PQdata{"01_Structure"} = (); }
    
    push(@{$PQdata{"01_Structure"}}, &getStructureData($root, "P"));

    &checkPQdataStructure;

    &writetofile($shortname,\%PQdata);
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
    
    $PQdata{"language"} = $rootxmd->findvalue('cat/language');
    
    my @protocols = $root->get_xpath('protocols/protocol');
	 # http://oracc.museum.upenn.edu/doc/builder/l2/languages/#Language_codes
    foreach my $i (@protocols) {
	if (($PQdata{"language"} eq "") && ($i->{att}->{type} eq "atf")) {
		my $temp = $i->text;
		if (($temp eq "lang a") || ($temp eq "lang akk")) { $PQdata{"language"} = "Akkadian"; }
		if ($temp eq "lang eakk") { $PQdata{"language"} = "Early Akkadian"; } # For pre-Sargonic Akkadian
		if ($temp eq "lang oakk") { $PQdata{"language"} = "Old Akkadian"; }
		if ($temp eq "lang ur3akk") { $PQdata{"language"} = "Ur III Akkadian"; }
		if ($temp eq "lang oa") { $PQdata{"language"} = "Old Assyrian"; }
		if ($temp eq "lang ob") { $PQdata{"language"} = "Old Babylonian"; }
		if ($temp eq "lang ma") { $PQdata{"language"} = "Middle Assyrian"; }
		if ($temp eq "lang mb") { $PQdata{"language"} = "Middle Babylonian"; }
		if ($temp eq "lang na") { $PQdata{"language"} = "Neo-Assyrian"; }
		if ($temp eq "lang nb") { $PQdata{"language"} = "Neo-Babylonian"; }
		if ($temp eq "lang sb") { $PQdata{"language"} = "Standard Babylonian"; }
		if ($temp eq "lang ca") { $PQdata{"language"} = "Conventional Akkadian"; } # The artificial form of Akkadian used in lemmatisation Citation Forms.
		
		if ($temp eq "lang n") { $PQdata{"language"} = "normalised"; } # Used in lexical lists and restorations; try to avoid wherever possible.
		if ($temp eq "lang g") { $PQdata{"language"} = "transliterated (graphemic) Akkadian"; } # Only for use when switching from normalised Akkadian.
		if (($temp eq "lang h") || ($temp eq "lang hit")) { $PQdata{"language"} = "Hittite"; }
		if (($temp eq "lang s") || ($temp eq "lang sux") || ($temp eq "lang eg")) { $PQdata{"language"} = "Sumerian"; } # The abbreviation eg stands for Emegir (main-dialect Sumerian)
		if (($temp eq "lang e") || ($temp eq "lang es")) { $PQdata{"language"} = "Emesal"; }
		if ($temp eq "lang sy") { $PQdata{"language"} = "Syllabic"; }
		if ($temp eq "lang u") { $PQdata{"language"} = "Udgalnun"; }
	    }
	if ($i->{att}->{type} eq "project") {
	    $PQdata{"project"} = $i->text;
	}
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
    
    $PQdata{"writer"} = $rootxmd->findvalue('cat/ancient_author'); # SAA; colophon information does not seem to be included in metadata [check L2]
    
    # For corpusdata-file: allow for quick metadata search on PQ-number, period, provenance, genre, language, etc.
    
    if ($PQdata{"designation"} ne "") { $designation = $PQdata{"designation"}; }
    if ($PQdata{"genre"} ne "") { $genre = $PQdata{"genre"}; }
    if ($PQdata{"language"} ne "") { $language = $PQdata{"language"}; }
    if ($PQdata{"object"} ne "") { $object = $PQdata{"object"}; }
    if ($PQdata{"period"} ne "") { $period = $PQdata{"period"}; }
    if ($PQdata{"project"} ne "") { $project = $PQdata{"project"}; }
    if ($PQdata{"provenance"} ne "") { $provenance = $PQdata{"provenance"}; }
    if ($PQdata{"script"} ne "") { $script = $PQdata{"script"}; }
    if ($PQdata{"subgenre"} ne "") { $subgenre = $PQdata{"subgenre"}; }
    if ($PQdata{"writer"} ne "") { $genre = $PQdata{"writer"}; }
    
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
}

sub getStructureData{
    my $root = shift;
    my $PorQ = shift;
    my %structdata = ();
    my $localdata = {};
    my $label = "";
    
    # P-texts: surfaces, columns, divisions [milestones], lines # CHECK ORACC: what happens now with milestones/colophons ???
    # Q-texts: divisions, lines

    my @nonxes = $root->get_xpath('nonx');
    foreach my $n (@nonxes) {
	$localdata->{'extent'} = $n->{att}->{extent}?$n->{att}->{extent}:"";
	$localdata->{'scope'} = $n->{att}->{scope}?$n->{att}->{scope}:"";
	$localdata->{'state'} = $n->{att}->{state}?$n->{att}->{state}:"";
	$localdata->{'text'} = $n->text;
	
	push(@{$structdata{"nonx"}}, $localdata);
	$localdata = {};
    }

    my @surfaces = $root->get_xpath('object/surface');
    my $no_surfaces = scalar @surfaces;
    foreach my $s (@surfaces) {
	if (!defined $structdata{"surface"}) {
	    $structdata{"surface"} = ();
	    $structdata{"no_surfaces"} = $no_surfaces;
	}

	$localdata = &getStructureData($s, $PorQ);
	$localdata->{'type'} = $s->{att}->{type}?$s->{att}->{type}:"";    
	$localdata->{'label'} = $s->{att}->{label}?$s->{att}->{label}:"";

        push(@{$structdata{"surface"}}, $localdata);
	$localdata = {};
    }
    
    my @columns = $root->get_xpath('column');
    my $no_columns = scalar @columns;
    foreach my $c (@columns) {
	if (!defined $structdata{"column"}) {
	    $structdata{"column"} = ();
	    $structdata{"no_columns"} = $no_columns;
	}
	
	$localdata = &getStructureData($c, $PorQ);
	my $col = $c->{att}->{n}; $localdata->{'no'} = $col;
	
        push(@{$structdata{"column"}}, $localdata);
	$localdata = {};
    }
    
    my @divs = $root->get_xpath('div');
    my $no_divs = scalar @divs;
    foreach my $d (@divs) {
	if (!defined $structdata{"div"}) {
	    $structdata{"div"} = ();
	    $structdata{"no_divs"} = $no_divs;
	}
	
	$localdata = &getStructureData($d, $PorQ);
	$localdata->{'type'} = $d->{att}->{type}?$d->{att}->{type}:"";    
	$localdata->{'n'} = $d->{att}->{n}?$d->{att}->{n}:"";

	push (@{$structdata{"div"}}, $localdata);
	$localdata = {};
    }
    
    my @linegroups = $root->get_xpath('lg');
    my $no_lgs = scalar @linegroups;
    if ($no_lgs != 0) { $structdata{'no_lgs'} += $no_lgs; }
    
    #The second line in a linegroup doesn't get its own line number; however, the line is physical in the case of bilinguals and glosses.
    
    #Glosslines (Gloss Underneath Stream, GUS): 2 lines (one with normal text, one with gloss), both lines lemmed, both lines physical
    #Bilingual: 2 lines (one in standard language, one in other language), both lines lemmed, both lines physical
    
    #Linearized Grapheme Stream (LGS): order on tablet, no words, just signs, not lemmed; this is actually the physical line, whereas l is interpretation
    #Normalized Transliteration Stream (NTS): not a physical line, nts lines are interpretations; if present the lemmatization is given here
    
    foreach my $lg (@linegroups) {
	my @speciallines = $lg->get_xpath('l');
	my $type = ""; $label = ""; 
	foreach my $j (@speciallines) { # check type of lg
	    if ($type eq "") {
		if ($j->{att}->{"type"}) { $type = $j->{att}->{"type"}; }
	    }
	    if ($label eq "") {
		if ($j->{att}->{"label"}) { $label = $j->{att}->{"label"}; }
	    }
	}

	# if bil or gus -> 2 lines, read both with &getLineData
	if (($type eq "gus") || ($type eq "bil")) {
	    $structdata{'no_lines'} += scalar @speciallines; 
	    my $number = 0;
	    foreach my $j (@speciallines) {
		$number++;
		my $speciallabel = $label." (".$number.")";
		$localdata = &getLineData($j, $speciallabel);
		$localdata->{"type"} = $type;
		$localdata->{"label"} = $speciallabel;
		push (@{$structdata{"line"}}, $localdata);
		$localdata = {};
	    }
	}
	elsif ($type eq "lgs") { #disregard l line *** still to be implemented *** still has to go through getLineData TODO
	    $localdata->{"type"} = $type;
	    $localdata->{"label"} = $label;
	    push (@{$structdata{"line"}}, $localdata);
	    $structdata{'no_lines'}++;
	    $localdata = {};
	}
	else { # nts check anew *** still has to go through getLineData TODO
	    $localdata->{"type"} = $type;
	    $localdata->{"label"} = $label;
	    push (@{$structdata{"line"}}, $localdata);
	    $structdata{'no_lines'}++;
	    $localdata = {};
	    # still to be implemented
	}
    }
   
    my @lines = $root->get_xpath('l');
    my $no_lines = scalar @lines;
    if ($no_lines != 0) {
	$structdata{'no_lines'} += $no_lines;
	
    }
    foreach my $l (@lines) {
	if (!defined $structdata{"line"}) {
	    $structdata{"line"} = ();
	}
	
	$label = $l->{att}->{"label"};
	$localdata = &getLineData($l, $label);
	$localdata->{"label"} = $label;
	push (@{$structdata{"line"}}, $localdata);
	$localdata = {};
    }
    return \%structdata;
}

sub getLineData {
    my $root = shift;
    my $label = shift;
    my %linedata = ();
    my $localdata = {};
    
    # cells, fields, alignment groups, l.inner
    my $sumgraphemes =0;
    
    my @cells = $root->get_xpath('c');
    foreach my $c (@cells){
	$localdata = &getLineData($c, $label);
	$localdata->{"span"} = $c->{att}->{"span"};
	push(@{$linedata{'cells'}}, $localdata);
	$localdata = {};
    }
    
    my @fields = $root->get_xpath('f');
    foreach my $f (@fields){
	$localdata = &getLineData($f, $label);
	$localdata->{"type"} = $f->{att}->{"type"};
	push(@{$linedata{'fields'}}, $localdata);
	$localdata = {};
    }
    
    my @alignmentgrp = $root->get_xpath('ag');
    foreach my $ag (@alignmentgrp) {
	$localdata = &getLineData($ag, $label); 
	$localdata->{"form"} = $ag->{att}->{"form"};
	push(@{$linedata{'alignmentgroup'}}, $localdata);
	$localdata = {};
    }
   
    # l.inner
    # l.inner = words, normwords??, surro??, gloss?? *** CHECK ORACC: FILES with examples of these?
        
    my @nonw = $root->get_xpath('g:nonw');
    my $no_nonw = scalar @nonw;
    foreach my $nw (@nonw) {
	$localdata->{"type"} = $nw->{att}->{"type"}; # "comment" | "dollar" | "excised" | "punct" | "vari" *** CHECK ORACC: FILES with examples of these? (I've only found "punct" so far)
	my $sign = "";
	
	if ($nw->get_xpath('g:p')) {  # punctuation
	    $sign = ($nw->get_xpath('g:p'))[0]->{att}->{"g:type"};
	}

	if ($nw->get_xpath('g:v')) {  # does this actually happen?
	    $sign = ($nw->get_xpath('g:v'))[0]->text;
	}

	$localdata->{"sign"} = $sign;
	
	push (@{$linedata{'nonw'}}, $localdata);
	# saveSign # TODO
	$localdata = {};
    }
    
    # get the nonw-signs also in the other list [not just under structure]

    # Words: g:w; g:w sword.head; g:swc sword.cont; g:nonw; g:x
    # split words: (1st part) g:w headform; (2nd part) g:swc
    # find no_words, no_signs per line, no_nonwords; preserved, damaged, missing
    # plus track words, signs, etc.
    my @words = $root->get_xpath('g:w');
    foreach my $word (@words) {
	my @children = $word->children(); my $no_children = scalar @children;
	my $tag = $children[0]->tag;
	if (($tag eq "g:x") && ($no_children == 1)) { # I don't want to count an ellipsis as 1 word [could be more or (even) less]
		if ($children[0]->{att}->{"g:type"}) { $localdata->{"kind"} = $children[0]->{att}->{"g:type"}; }
		if ($children[0]->{att}->{"g:break"}) { $localdata->{"state"} = $children[0]->{att}->{"g:break"}; }
		push (@{$linedata{'x'}}, $localdata);
	    }
	else  {
	    $linedata{'words'}++;
	    if ($word->{att}->{headform}) { # beginning of split word
		$localdata = &analyseWord($word, $label, "splithead");
		$localdata->{"split"}++;
	    }
	    elsif ($word->{att}->{"form"} ne "o"){ # words with form="o" are not words at all and shouldn't be considered (e.g. SAA 1 10 o 18 = P 334195)
		# normal words
		# analyse words - collect all sign information (position, kind, delim, state)
		#print "\nAnalyse ". $word->{att}->{"form"};
		$localdata = &analyseWord($word, $label);
	    }
	#push (@{$linedata{'words'}}, $localdata); TODO	# statistical data
	}
	$localdata = {};
    }
    
    my @splitends = $root->get_xpath('g:swc');
    my $no_split = scalar @splitends;
    if ($no_split > 0) {
	foreach my $split (@splitends) { # end of split word - not counted extra in wordcount TODO
	    # use headref
	    $localdata = &analyseWord($split, $label, "splitend"); #-> needs to get the form it belongs to
	    $localdata->{"split"}++;
	}
	#push (@{$linedata{'words'}}, $localdata); TODO	# statistical data
	$localdata = {};
    }
    
    my @xes = $root->get_xpath('g:x');
    foreach my $x (@xes) {
	$localdata->{"kind"} = $x->{att}->{"g:type"}; 	# "disambig" | "empty" | "newline" | "user" | "ellipsis" | "word-absent" | "word-broken" | "word-linecont"
	# *** CHECK ORACC: FILES with examples of these? (I've only found "ellipsis" so far)
	if ($x->{att}->{"g:break"}) { $localdata->{"state"} = $x->{att}->{"g:break"}; }
	push (@{$linedata{'x'}}, $localdata);
	$localdata = {};
    }
    
    return \%linedata;
}

sub checkPQdataStructure{
    my $no_surfaces = 0; my $no_columns = 0; 
    if ($PQdata{"01_Structure"}[0]{"no_surfaces"}) {
	$no_surfaces = $PQdata{"01_Structure"}[0]{"no_surfaces"};
	my $cnt = 0; my $no_lines_surface = 0;
	while ($cnt < $no_surfaces) {
	    if ($PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_columns"}) {
		$no_columns = $PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_columns"};
		my $cnt2 = 0; my $no_lines = 0;
		while ($cnt2 < $no_columns) {
		    if ($PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"column"}[$cnt2]{"no_lines"}) {
			$no_lines += $PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"column"}[$cnt2]{"no_lines"};
		    }
		    $cnt2++;
		}
		$PQdata{"01_Structure"}[0]{"surface"}[$cnt]{"no_lines"} = $no_lines;
		$no_lines_surface += $no_lines;
	    }
	    $cnt++;
	    $PQdata{"01_Structure"}[0]{"no_lines"} = $no_lines_surface;
	}
    }
    
    my $no_divs = 0;
    if ($PQdata{"01_Structure"}[0]{"no_divs"}) {
	$no_divs = $PQdata{"01_Structure"}[0]{"no_divs"};
	my $cnt = 0; my $no_lines_div = 0;
	while ($cnt < $no_divs) {
	    if ($PQdata{"01_Structure"}[0]{"div"}[$cnt]{"no_lines"}) {
		$no_lines_div += $PQdata{"01_Structure"}[0]{"div"}[$cnt]{"no_lines"}
	    }
	    $cnt++;
	}
	if ($PQdata{"01_Structure"}[0]{"no_lines"}) {
	    $PQdata{"01_Structure"}[0]{"no_lines"} += $no_lines_div;
	}
	else {
	    $PQdata{"01_Structure"}[0]{"no_lines"} = $no_lines_div;
	}
    }
}

sub analyseWord{
    my $word = shift;
    my $label = shift;
    my $split = shift || "";
    my %worddata = ();
    
# return data as number of words, number of signs etc.
# save data as words, signs, etc. in PQdata{"words"} and PQdata{"signs"}
    my $lang = $word->{att}->{'xml:lang'};
    my $form = "";
    if ($word->{att}->{"form"}){ $form = $word->{att}->{"form"}; }
    #print "\n".$form;
    my $wordid = $word->{att}->{"xml:id"};
    my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
    my $cf = ""; my $pofs = ""; my $epos = "";
            
    # xtf-file
    #print "\n".$tempvalue."\n";
    my @wordref = $PQroot->get_xpath($tempvalue); 
    foreach my $item (@wordref) {
        if($item->{att}->{"cf"}){  # word is lemmatized
            $cf = $item->{att}->{"cf"};
            $pofs = $item->{att}->{"pos"}; # pofs = part-of-speech (pos is used already for position)
            $epos = $item->{att}->{"epos"};
            #print $cf;
        }
    }
    
    my $wordtype = $pofs;
    # PERSONAL and ROYAL NAMES
    if ($wordtype eq "RN") { $wordtype = "PersonalNames"; } 
    
    # http://oracc.museum.upenn.edu/doc/builder/linganno/QPN/
    # GEOGRAPHICAL DATA: GN, WATERCOURSE, ETHNIC (GENTILICS), AGRICULTURAL, FIELD, QUARTER, SETTLEMENT, LINE, TEMPLE 
    if (($wordtype eq "GN") || ($wordtype eq "WN") || ($wordtype eq "EN") || ($wordtype eq "AN") || ($wordtype eq "FN") || ($wordtype eq "QN") || ($wordtype eq "SN") || ($wordtype eq "LN") || ($wordtype eq "TN")) {
	$wordtype = "Geography"
    }
    
    # DIVINE and CELESTIAL NAMES
    if (($wordtype eq "DN") || ($wordtype eq "CN")) {
	$wordtype = "DivineCelestial"; 
    }
    
    # mul2 and id2 may not work - use of special coding ?? check ***
    # ROUGH CLASSIFICATION IF NOT LEMMATIZED
    if (($wordtype eq "") && ($form ne "")) { # can these be given in capital letters???
	my $formsmall = lc ($form);
	if ($formsmall =~ /(^\{1\})|(^\{m\})/) { $wordtype = "PersonalNames"; }
	if (($formsmall =~ /(^\{d\})/) || ($formsmall =~ /(^\{mul\})/) || ($formsmall =~ /(^\{mul2\})/)) { $wordtype = "DivineCelestial"; }  
	if (($formsmall =~ /(\{ki\})/) || ($wordtype =~ /(\{kur\})/) || ($form =~ /(\{uru\})/) || ($form =~ /(\{iri\})/) || ($form =~ /(\{id2\})/))  { $pofs = "Geography"; }
    }    

    if (($wordtype ne "PersonalNames") && ($wordtype ne "DivineCelestial") && ($wordtype ne "Geography")) { $wordtype = "OtherWords"; }
    
    # how about marking preserved signs somehow, so that we immediately know how many of each are preserved ***
    # make temporary array of each word including information about determinative [det]/phonetic [phon], syllabic [syll], logographic [logo], logographic suffixes [logosuff]
    # 
#Split: d
#
#Split: AMARUTU
#$VAR1 = [
#          [
#            {
#              '1' => {
#                       'value' => 'd',
#                       'type' => 'semantic',
#                       'tag' => 'g:v',
#                       'pos' => 1,
#                       'prePost' => 'pre',
#                       'state' => 'damaged'
#                     }
#            }
#          ],
#          [
#            {
#              '2' => {
#                       'group' => 'logo',
#                       'value' => 'AMAR',
#                       'tag' => 'g:s',
#                       'pos' => 2,
#                       'delim' => '.',
#                       'state' => 'damaged'
#                     }
#            },
#            {
#              '3' => {
#                       'group' => 'logo',
#                       'value' => 'UTU',
#                       'tag' => 'g:s',
#                       'pos' => 3,
#                       'state' => 'damaged'
#                     }
#            }
#          ]
#        ];
#    
    
    my @arrayWord = ();
    
    my @children = $word->children();
    
    @testthing= ();
    my $no_children = scalar @children;
    my $position = 0; my $temp = {}; my $localdata = {}; my $cnt = 0;
    foreach my $i (@children) { # check each element of a word
	print "\nSplit: ".$i->text."\n";
	$position++;
	&splitWord (\@testthing, $i, $position);
	#push (@{$arrayWord[$cnt]}, $temp);
	$cnt++;
	$temp = {};
    }
    my $testword = "";
    my $lastdelim = "";
    my $lastend = "";
    foreach(@testthing){
	my $thing = $_;
	my $startbit = "";
	my $endbit = "";
	my $value = $thing->{'value'};
	#print Dumper $thing;
	if($thing->{"type"} && ( $thing->{"type"} eq "semantic" || $thing->{"type"} eq "phonetic") ){
#	    value gets {}
	    $value = "{".$value."}";
	}
	if($thing->{"state"} && $thing->{"state"} eq "missing"){
#	    value gets []
	    if($lastend ne "]"){
		$startbit = "[" ;
	    }
	    else{$lastend = "";}
	    $endbit = "]";
	}
	elsif($thing->{"state"} && $thing->{"state"} eq "damaged"){
#	    value gets half[]
	    if($lastend ne "\x{02FA}"){
		$startbit = "\x{02F9}" ;
	    }
	    else{$lastend = "";}
	    $endbit = "\x{02FA}";
	}
	my $delim = "";
	if($thing->{"delim"}){
#	    value gets {}
	    $delim = $thing->{"delim"};
	}
	$testword .= $lastend.$lastdelim.$startbit.$value;
	$lastend = $endbit;
	$lastdelim = $delim;
	
    }
    $testword .= $lastend.$lastdelim;
    my %testdata;
    $testdata{"word"} = $testword;
    $testdata{"bits"} = \@testthing;
    push (@{$localdata->{"word"}}, \%testdata);
    
    push (@arrayWord, $localdata->{"word"});
    print Dumper(@arrayWord);
    
    # try to go through @arrayWord and make the writtenWord; also determine the condition of the word
    my $writtenWord = ""; my $condition = 0;# missing (2), damaged (1), preserved (0)
#    my $no_array_els = scalar @arrayWord; $cnt = 0;		FIX THIS - ask CHRIS
#    while ($cnt < $no_array_els) {
#	print "\n";
#	my $pos = 1; # how do I get these values ??? TODO
#	if ($arrayWord[$cnt][0]{"1"}) { print $arrayWord[$cnt][0]{"1"}{"value"}; }
#	if ($arrayWord[$cnt][0]{"1"}{"delim"}) { print $arrayWord[$cnt][0]{"1"}{"delim"}; }
#	$cnt++;
#    }
    
    my $break;
    if ($condition == 0) { $break = "preserved"; }
    elsif ($condition == 1) { $break = "damaged"; }
    elsif ($condition == 2) { $break = "missing"; }
    # save the relevant data into \%worddata: probably only statistical information
    
    # saveWord
    &saveWord($lang, $form, $break, $wordtype, $cf, $pofs, $epos, $writtenWord, $label, $split);

    # saveSign

# fill in worddata: number of preserved signs, etc. TODO

    return \%worddata;
}


sub splitWord {
    my $splitdata = shift;
    my $root = shift;
    my $position = shift;
    my $type = shift || "";
    my $prepost = shift || "";
    my $break = shift || "preserved";
    my $delim = shift || "";
    my $group = shift || "";
    
    my $localdata = {};
    my $tag = $root->tag;
    
    my $value = "";
    my $base = "";
    
    # http://oracc.museum.upenn.edu/ns/gdl/1.0/grapheme.rnc.html
    
    # Single elements: g:x (missing), g:n (number), g:v (small letters), g:s (capital)
    if (($tag eq "g:x") || ($tag eq "g:n") || ($tag eq "g:v") || ($tag eq "g:s")) {
	$localdata = {};
	if ($root->{att}->{form}) {
	    $value = $root->{att}->{form};
	    if ($root->{att}->{"g:b"}) {
		$base = $root->{att}->{"g:b"};
	    }
	}  
	elsif ($root->text) { $value = $root->text; }

	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }
	
	$localdata->{"pos"} = $position; $localdata->{"tag"} = $tag; $localdata->{"value"} = $value; $localdata->{"state"} = $break;
	if ($base ne "") { $localdata->{"base"} = $base; }
	if ($prepost ne "") { $localdata->{"prePost"} = $prepost; }
	if ($type ne "") { $localdata->{"type"} = $type; }
	if ($delim ne "") { $localdata->{"delim"} = $delim; }
	if ($group ne "") { $localdata->{"group"} = $group; }

	push(@{$splitdata},$localdata);
	return $splitdata;
    }

    # Determinatives and phonetic complements: g:d with g:role and g:pos
    if ($tag eq "g:d") {
	my @det_elements = $root->children();
	$type = $root->{att}->{"g:role"};
	$prepost = $root->{att}->{"g:pos"};
	my @temp = ();
	foreach my $j (@det_elements) {
	    $splitdata = &splitWord($splitdata, $j, $position, $type, $prepost);
	    $position++;
	}
	
	    #print Dumper $splitdata;
	    #die;
	#return $temp;
    }
    
    # Compounds: g:c { form? , g.meta , c.model , mods* }
    # and: g:g { g.meta , c.model , mods* }
    # -> n | s | c | (g,mods*) | q
    #	    <g:c form="|BAD×DIŠ@t|" xml:id="Q000003.12.2.0" g:status="ok">
#                <g:s>BAD</g:s>
#                <g:o g:type="containing"/> 
#                <g:s form="DIŠ@t">
#                    <g:b>DIŠ</g:b>
#                    <g:m>t</g:m>
#                </g:s>
#            </g:c>

#	    <g:c form="|EN.PAP.IGI@g.NUN.ME.EZEN×KASKAL|">
#                    <g:s>EN</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>PAP</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s form="IGI@g">
#                        <g:b>IGI</g:b>
#                        <g:m>g</g:m>
#                    </g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>NUN</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>ME</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>EZEN</g:s>
#                    <g:o g:type="containing"/>
#                    <g:s>KASKAL</g:s>
#                </g:c>

#	g:g ??   
#	    <g:c form="|(SAL.TUG..).PAP.IGI@g.ME.EZEN×KASKAL|">
#                    <g:g>
#                        <g:s>SAL</g:s>
#                        <g:o g:type="beside"/>
#                        <g:s g:accented="TÚG">TUG..</g:s>
#                    </g:g>
#                    <g:o g:type="beside"/>
#                    <g:s>PAP</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s form="IGI@g">
#                        <g:b>IGI</g:b>
#                        <g:m>g</g:m>
#                    </g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>ME</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>EZEN</g:s>
#                    <g:o g:type="containing"/>
#                    <g:s>KASKAL</g:s>
#                </g:c>
	    
#	    <g:c form="|MUŠ&amp;KAK&amp;MUŠ|" xml:id="Q000003.121.1.0" g:status="ok">
#                    <g:s>MUŠ</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>KAK</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>MUŠ</g:s>
#                </g:c>

    if (($tag eq "g:c") || ($tag eq "g:g")) {
	my @c_elements = $root->children();
	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }

	my $temp = ();
	foreach my $c (@c_elements) { # elements with "containing" !! g:o
	    if ($c->tag eq "g:o") {
		my $punct = "";
		my $type = $c->{att}->{"g:type"};
		if ($type eq "beside") { $punct = "."; }
		elsif ($type eq "containing") { $punct = "x"; }
		elsif ($type eq "above") { $punct = "&amp;"; }  # other types = joining, reordered, crossing, opposing; how marked ??
		$localdata->{"combo"} = $type;
		$localdata->{"delim"} = $punct;
		my $lastone = scalar @{$splitdata};
		if(defined($splitdata->[$lastone - 1]->{"delim"})){
#		 TODO   if g:c is followed by a g:s then put oldelim after last element of g:c see: Q00003 GA2GAR
		    $splitdata->[$lastone - 1]->{"olddelim"} = $splitdata->[$lastone - 1]->{"delim"};
		    #print print Dumper $splitdata;
		    #die print Dumper $localdata;
		}
		$splitdata->[$lastone - 1]->{"delim"} = $punct;
		$splitdata->[$lastone - 1]->{"combo"} = $type;
		}
	    else {
		$splitdata = &splitWord($splitdata, $c, $position, "", "", $break, $delim);
		$position++; 
	    }
	}
	&listCombos($root);
    }
    
    # Qualified graphemes: g:q { form? , g.meta , (v|s|c) , (s|c|n) }
    # 2 parts: interpretation and sign combination
    # g:q -> take $value = form ["NERGALx(|U.GUR|)"]; $type = type of first element [g:s]
	    # <g:q form="NERGALx(|U.GUR|)" xml:id="P363524.30.1.1" g:status="ok"> # unicode lower x
              #  <g:s>NERGALx</g:s>
              #  <g:c form="|U.GUR|">
              #    <g:s>U</g:s>
              #    <g:o g:type="beside"/>
              #    <g:s>GUR</g:s>
              #  </g:c>
              #</g:q>
    if ($tag eq "g:q") {
        my $firstpart = $root->getFirstChild();
	if ($firstpart->{att}->{"g:delim"}) { $delim = $firstpart->{att}->{"g:delim"}; }
	if ($firstpart->{att}->{"g:break"}) { $break = $firstpart->{att}->{"g:break"}; }
	$splitdata = &splitWord($splitdata, $firstpart, $position, "", "", $delim, $break);
	
	my $secondpart = $firstpart->getNextSibling();
	&listCombos($root);
    }
    
    # Groups: g:gg
    # http://oracc.museum.upenn.edu/ns/gdl/1.0/words.rnc.html
#    group = element g:gg {
#			attribute g:type { 
#					"correction" | "alternation" | "group" | "reordering" | "ligature" | "implicit-ligature" | "logo" | "numword"
#			} ,
#	    g.meta , (group | grapheme)+   }

# g:gg -> all elements matter; type of gg may matter 
#	    <g:gg g:type="correction" g:status="ok" g:hc="1">
#              <g:v g:accented="ù" g:utf8=" xml:id="P338566.6.2.0" g:break="damaged" g:remarked="1" g:ho="1">u...</g:v>
#              <g:c form="|DI.LU|" g:utf8="">
#                <g:s>DI</g:s>
#                <g:o g:type="beside"/>
#                <g:s>LU</g:s>
#              </g:c>
#            </g:gg>

#	    <g:gg g:type="reordering">
#                <g:v xml:id="Q000003.13.1.0" g:status="ok" g:delim=":">en</g:v>
#                <g:s xml:id="Q000003.13.1.1" g:status="ok">IB</g:s>
#            </g:gg>

#	    <g:gg g:type="logo">
#              <g:s xml:id="P338566.6.4.0" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">IGI</g:s>
#              <g:s xml:id="P338566.6.4.1" g:status="ok" g:role="logo" g:logolang="sux">IGI</g:s>
#              <g:d g:role="phonetic" g:pos="post">
#                <g:v g:utf8="" xml:id="P338566.6.4.2" g:status="ok">mar</g:v>
#              </g:d>
#            </g:gg>

#	gg within gg!
#	    <g:gg g:type="logo">
#                <g:s g:accented="..." xml:id="P363524.24.4.0" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">E...</g:s>
#                <g:s xml:id="P363524.24.4.1" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">I</g:s>
#                <g:s g:accented="..." xml:id="P363524.24.4.2" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">BI...</g:s>
#                <g:d g:role="semantic" g:pos="pre">
#                  <g:v xml:id="P363524.24.4.3" g:status="ok">d</g:v>
#                </g:d>
#                <g:gg g:type="correction" g:status="ok">
#                  <g:c form="|A.NUM|" xml:id="P363524.24.4.4" g:remarked="1" g:role="logo" g:logolang="sux">
#                    <g:s>A</g:s>
#                    <g:o g:type="beside"/>
#                    <g:s>NUM</g:s>
#                  </g:c>
#                  <g:s>RU</g:s>
#                </g:gg>
#              </g:gg>

    if ($tag eq "g:gg") { # "correction" | "alternation" | "group" | "reordering" | "ligature" | "implicit-ligature" | "logo" | "numword"
	my @gg_elements = $root->children();
	$group = $root->{att}->{"g:type"}; 
	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }
	my @temp = ();
	if ($group eq "correction") { # only first element matters - how about other groupings??? (not in my test-examples)
	    my $gg = $root->getFirstChild();
	    $splitdata = &splitWord($splitdata, $gg, $position, "", "", $break, $delim, $group);
	    $position++;
	}
	else { # good for "logo", "reordering"
	    foreach my $gg (@gg_elements) {
	        $splitdata = &splitWord($splitdata, $gg, $position, "", "", $break, $delim, $group);
	        $position++; 
	    }
	}
	&listCombos($root);
    }
    
    return $splitdata;
}
   

sub listCombos { # TODO
    my $root = shift;
}

sub saveWord { 
    my $lang = shift;
    my $form = shift;
    my $break = shift;
    my $wordtype = shift;
    my $cf = shift;
    my $pofs = shift;
    my $epos = shift;
    my $writtenWord = shift;  # TODO: add line number
    my $label = shift;
    my $split = shift;
    
    if($lang eq "") { $lang = "noLang"; }
    
    my $totaltype = "total_".$wordtype;
    $PQdata{"03_Words"}{$lang}{$wordtype}{$totaltype}{'count'}++;
    $PQdata{"03_Words"}{$lang}{$wordtype}{$totaltype}{$break}{'num'}++;
    if ($form ne "") {
	if ($cf ne "") {  # what happens when a word has different cfs? or is not always lemmatized?
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'cf'} = $cf;
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'pofs'} = $pofs;
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'epos'} = $epos;
	    if ($split ne "") {
		$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{$split}++;
	    }
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'num'}++;
	    if ($break eq "damaged") {
		$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'writtenform'}{$writtenWord}{'num'}++;
		push (@{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'writtenform'}{$writtenWord}{'line'}}, $label);
		}
	    else {
		push (@{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'line'}}, $label);
	    }
	    
	    #$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'cf'}{$cf}{'pofs'}{$pofs}{'epos'}{$epos}{"state"}{$break}{'num'}++;
	    #if ($break eq "damaged") { $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'cf'}{$cf}{'pofs'}{$pofs}{'epos'}{$epos}{"state"}{$break}{"written"}{$writtenWord}{'num'}++; }
	    }
	else {
	    $PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'num'}++;
    	    if ($split ne "") {
		$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{$split}++;
	    }
	    if ($break eq "damaged") {
		$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{"writtenform"}{$writtenWord}{'num'}++;
		push (@{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{"writtenform"}{$writtenWord}{'line'}}, $label);
	    }
	    else {
		push (@{$PQdata{"03_Words"}{$lang}{$wordtype}{'form'}{$form}{'state'}{$break}{'line'}}, $label);
	    }
	}
    }
    $PQdata{"03_Words"}{'count'}++;
}

sub saveSign { # TODO, LANGUAGE-dependent
    my @arrayWord = shift;
}


sub dographemeData{ # DELETE
    my $root = shift;
    my $localdata = shift;
    my %graphemearraytemp = ();
    
    my $sumgraphemes =0;
    
    
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
	    
	    #&outputtext("\nWord: ". $form."; lang: ".$lang);
	    
            
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
           
           
            
	    
	}
    }
    
    return \%graphemearraytemp;
}


sub doInsideGrapheme{ # DELETE
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
    
    return \%singledata;
}
sub doGSingles{ # DELETE
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

sub doGsv{  # DELETE
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
	    if(($xpath eq "g:v") && ($lang =~ m|^akk|)){ #extend to other languages later
		my $tempform = $form;
	        if ($baseform ne "") { 
		    $tempform = $baseform;
		}
		$cvc = lc($tempform);
		
		$cvc =~ s|(\d)||g;
		$cvc =~ s|([aeiou])|V|g;
		$cvc =~ s|(\x{2080})||g;
		$cvc =~ s|(\x{2081})||g;
		$cvc =~ s|(\x{2082})||g;
		$cvc =~ s|(\x{2083})||g;
		$cvc =~ s|(\x{2084})||g;
		$cvc =~ s|(\x{2085})||g;
		$cvc =~ s|(\x{2086})||g;
		$cvc =~ s|(\x{2087})||g;
		$cvc =~ s|(\x{2088})||g;
		$cvc =~ s|(\x{2089})||g;
		$cvc =~ s|([^V])|C|g;
	    
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
	
	    if($xpath eq "g:s" && $lang =~ m|^akk|){ #extend to other languages later
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



sub saveData{ #DELETE
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
	if ($lang =~ m|^akk|) {
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
#    if($localdata->{"period"}){
#	$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"total_grapheme"}{$name}{$break}{'num'}++;
#	
#	if ($form ne "") {
#	    if ($pos eq "") {
#		if ($lang =~ m|^akk|) {
#		    if($cvc ne ""){ 
#			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
#		    }
#		    else {
#			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
#		    }
#		}
#		else {
#		    abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
#		}
#	    }
#	    else {
#		if ($lang =~ m|^akk|) {
#		    if($cvc ne ""){ 
#			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
#		    }
#		    else {
#			abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#		    }
#		}
#		else {
#		    abstractdata(\%{$perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#		}
#	    }
#	    $perioddata{$localdata->{"period"}}{"lang"}{$lang}{$type}{'count'}++;
#	}
#    
#    }
#    
#    # for language-file
#    if($lang){
#	# reorganized: first type, then form, then break, hope this works.
#	# TODO: add information about determinatives/phonetic complements
#	$langdata{$lang}{$type}{"type"}{$name}{"total_grapheme"}{$name}{$break}{'num'}++;
#	
#	if ($form ne "") {
#	    if ($pos eq "") {
#		if ($lang =~ m|^akk|) {
#		    if($cvc ne ""){ 
#			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
#		    }
#		    else {
#			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
#		    }
#		}
#		else {
#		    abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}},$baseform,$break,$form);
#		}
#		$langdata{$lang}{$type}{'count'}++;
#	    }
#	    else {
#		if ($lang =~ m|^akk|) {
#		    if($cvc ne ""){
#			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
#		    }
#		    else {
#			abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#		    }
#		}
#		else {
#		    abstractdata(\%{$langdata{$lang}{$type}{"type"}{$name}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#		}
#		$langdata{$lang}{$type}{'count'}++;
#	    }
#	}
#    }
}

sub abstractdata{ # DELETE
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


sub doG{ # DELETE
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
	if ($form =~ m|^0|) {
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
sub addLines{ # DELETE
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
sub traverseDir{  # TODO: check if this works over directory structure
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
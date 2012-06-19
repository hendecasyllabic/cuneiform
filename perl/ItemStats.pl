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

my @splitrefs; # list of xml:id/headref; keep track of the split words that have been analysed through headform, so that they're not analysed twice.

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
                                 twig_roots => { 'composite' => 1, 'xcl' => 1 }
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
                                 twig_roots => { 'transliteration' => 1, 'protocols' => 1, 'object' => 1, 'mds' => 1 }
                                 );
    $twigObj->parsefile($filename);
    my $root = $twigObj->root;
    $twigObj->purge;
    
    my $twigPQObj = XML::Twig->new(
                                 twig_roots => { 'transliteration' => 1, 'xcl' => 1 }
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

    if (!(defined $PQdata{"01_Structure"})) { $PQdata{"01_Structure"} = (); }
    
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
    
    if ($rootxmd->findvalue('cat/language')) { $PQdata{"language"} = $rootxmd->findvalue('cat/language'); }
    else { my @temp = $PQroot->get_xpath('xcl'); $PQdata{"language"} = $temp[0]->{att}->{"langs"}?$temp[0]->{att}->{"langs"}:""; } # in ETCSRI - also other projects?? check TODO 
    
    if ($PQdata{"language"} eq "sux") { $PQdata{"language"} = "Sumerian"; }
    
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
		if ($temp eq "lang akk-x-stdbab") { $PQdata{"language"} = "Standard Babylonian"; }
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
    my $preservedWords = 0; my $damagedWords = 0; my $missingWords = 0;
    my $preservedSigns = 0; my $damagedSigns = 0; my $missingSigns = 0;
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
	    my $tempdata = {};
	    if ($word->{att}->{headform}) { # beginning of split word
		my $headref = $word->{att}->{"xml:id"};
		$tempdata = &analyseWord($word, $label, "splithead");
		$linedata{"split"}++;
		push (@splitrefs, $headref);
	    }
	    elsif ($word->{att}->{"form"} ne "o"){ # words with form="o" are not words at all and shouldn't be considered (e.g. SAA 1 10 o 18 = P 334195)
		# normal words
		# analyse words - collect all sign information (position, kind, delim, state)
		#print "\nAnalyse ". $word->{att}->{"form"};
		$tempdata = &analyseWord($word, $label);
	    }
	    if ($tempdata->{"stateWord"} eq "preserved") { $preservedWords++; }
	    elsif ($tempdata->{"stateWord"} eq "damaged") { $damagedWords++; }
	    elsif ($tempdata->{"stateWord"} eq "missing") { $missingWords++; }
	    if ($tempdata->{"preservedSigns"}) { $preservedSigns += $tempdata->{"preservedSigns"}; }
	    elsif ($tempdata->{"damagedSigns"}) { $damagedSigns += $tempdata->{"damagedSigns"}; }
	    elsif ($tempdata->{"missingSigns"}) { $missingSigns += $tempdata->{"missingSigns"}; }
	}
	$localdata = {};
    }
    
    my @splitends = $root->get_xpath('g:swc');
    my $no_split = scalar @splitends;
    if ($no_split > 0) {
	foreach my $split (@splitends) { # end of split word 
	    # if the beginning of this word is preserved, then this end will have been treated together with the beginning
	    # what happens here should only occur when only the end of the word is preserved (and the beginning is not reconstructed)
	    if (!($split->{att}->{"headref"})) {
		my $tempdata = {};
		$tempdata = &analyseWord($split, $label, "splitend"); 
		$linedata{"split"}++;
		$linedata{'words'}++;
		if ($tempdata->{"stateWord"} eq "preserved") { $preservedWords++; }
		elsif ($tempdata->{"stateWord"} eq "damaged") { $damagedWords++; }
	        elsif ($tempdata->{"stateWord"} eq "missing") { $missingWords++; }
	        if ($tempdata->{"preservedSigns"}) { $preservedSigns += $tempdata->{"preservedSigns"}; }
	        elsif ($tempdata->{"damagedSigns"}) { $damagedSigns += $tempdata->{"damagedSigns"}; }
	        elsif ($tempdata->{"missingSigns"}) { $missingSigns += $tempdata->{"missingSigns"}; }
	    }
	    #else { print "found ".$split->{att}->{"headref"}; }
	}
    }
    
    if ($preservedWords > 0) { $linedata{'words_preserved'} = $preservedWords; }
    if ($damagedWords > 0) { $linedata{'words_damaged'} = $damagedWords; }
    if ($missingWords > 0) { $linedata{'words_missing'} = $missingWords; }
    if ($preservedSigns > 0) { $linedata{'signs_preserved'} = $preservedSigns; }
    if ($damagedSigns > 0) { $linedata{'signs_damaged'} = $damagedSigns; }
    if ($missingSigns > 0) { $linedata{'signs_missing'} = $missingSigns; }
    $linedata{'signs'} = $preservedSigns + $damagedSigns + $missingSigns;
    
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
    my $lang = $word->{att}->{'xml:lang'}?$word->{att}->{'xml:lang'}:"noLang";
    my $form = $word->{att}->{"form"}?$word->{att}->{"form"}:""; 
    my $wordid = $word->{att}->{"xml:id"}?$word->{att}->{"xml:id"}:"";
    my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
    my $cf = ""; my $pofs = ""; my $epos = ""; my $wordbase = ""; my $gw = "";
            
    # xtf-file
    #print "\n".$tempvalue."\n";
    my @wordref = $PQroot->get_xpath($tempvalue); 
    foreach my $item (@wordref) {
        $cf = $item->{att}->{"cf"}?$item->{att}->{"cf"}:"";
        $pofs = $item->{att}->{"pos"}?$item->{att}->{"pos"}:""; # pofs = part-of-speech (pos is used already for position)
        $epos = $item->{att}->{"epos"}?$item->{att}->{"epos"}:"";
	$gw = $item->{att}->{"gw"}?$item->{att}->{"gw"}:"";
	$wordbase = $item->{att}->{"base"}?$item->{att}->{"base"}:"";
    }
    
    my $wordtype = $pofs;
    # PERSONAL and ROYAL NAMES
    if ($wordtype eq "RN") { $wordtype = "PersonalNames"; } 
    
    # http://oracc.museum.upenn.edu/doc/builder/linganno/QPN/
    # GEOGRAPHICAL DATA: GN, WATERCOURSE, ETHNIC (GENTILICS), AGRICULTURAL, FIELD, QUARTER, SETTLEMENT, LINE, TEMPLE 
    if (($wordtype eq "GN") || ($wordtype eq "WN") || ($wordtype eq "EN") || ($wordtype eq "AN") || ($wordtype eq "FN") || ($wordtype eq "QN") || ($wordtype eq "SN") || ($wordtype eq "LN") || ($wordtype eq "TN")) {
	$wordtype = "Geography";
    }
    
    # DIVINE and CELESTIAL NAMES
    if (($wordtype eq "DN") || ($wordtype eq "CN")) {
	$wordtype = "DivineCelestial"; 
    }
    
    # check if mul2 and id2 work *** TODO
    # ROUGH CLASSIFICATION IF NOT LEMMATIZED
    if (($wordtype eq "") && ($form ne "")) { 
	my $formsmall = lc ($form);
	if ($formsmall =~ /(^\{1\})|(^\{m\})/) { $wordtype = "PersonalNames"; }
	if (($formsmall =~ /(^\{d\})/) || ($formsmall =~ /(^\{mul\})/) || ($formsmall =~ /(^\{mul\x{2082}\})/)) { $wordtype = "DivineCelestial"; }  
	if (($formsmall =~ /(\{ki\})/) || ($formsmall =~ /(\{kur\})/) || ($formsmall =~ /(\{uru\})/) || ($formsmall =~ /(\{iri\})/) || ($formsmall =~ /(\{id\x{2082}\})/))  { $wordtype = "Geography"; }
	if ($formsmall =~ /^\d/) { $wordtype = "Numerical"; }
    }    

    if (($wordtype ne "PersonalNames") && ($wordtype ne "DivineCelestial") && ($wordtype ne "Geography") && ($wordtype ne "Numerical")) {
	if ($form =~ /^\$/) { $wordtype = "UncertainReading"; }
	else { $wordtype = "OtherWords"; }
    }
    
#Split: d
#Split: AMARUTU
#$VAR1 = {
#          'value' => 'd',
#          'type' => 'semantic',
#          'tag' => 'g:v',
#          'pos' => 1,
#          'prePost' => 'pre',
#          'state' => 'damaged'
#        };
#$VAR2 = {
#          'group' => 'logo',
#          'value' => 'AMAR',
#          'tag' => 'g:s',
#          'pos' => 2,
#          'delim' => '.',
#          'state' => 'damaged'
#        };
#$VAR3 = {
#          'group' => 'logo',
#          'value' => 'UTU',
#          'tag' => 'g:s',
#          'pos' => 3,
#          'state' => 'damaged'
#        };
    
    my @arrayWord = ();
    
    my @children = $word->children();
 
    my $no_children = scalar @children;
    my $position = 1; my $localdata = {}; my $cnt = 0; my $tempdata = {};
    foreach my $i (@children) { # check each element of a word
	($tempdata, $position) = &splitWord (\@arrayWord, $i, $position);
	$cnt++;
    }
    
    if ($split eq "splithead") {
	my $ref = $word->{att}->{"xml:id"};
	# look for splitend
	my $tempvalue = '//g:swc[@headref="'.$ref.'"]'; 
	my @splitenz = $PQroot->findnodes($tempvalue); 
	if (@splitenz) {
	    my $lastSoFar = scalar @arrayWord;
	    $arrayWord[$lastSoFar - 1]->{"split"} = "split";
	    my @endchildren = $splitenz[0]->children();
	    $localdata = {}; $cnt = 0;
	    foreach my $j (@endchildren) { 
	        ($tempdata, $position) = &splitWord (\@arrayWord, $j, $position);
	        $cnt++;
	    }
	    # add extra line number; find parent of swc
	    my $parent = $splitenz[0]->parent();
	    if ($parent->{att}->{"label"}) { my $extraLabel = $parent->{att}->{"label"}; $label .= "-".$extraLabel; }
	}
	#print Dumper @arrayWord;
    }
    
    my $writtenWord = ""; 
    my $preservedSigns = 0; my $damagedSigns = 0; my $missingSigns = 0;
    my $lastdelim = ""; my $lastend = "";
    foreach(@arrayWord){
	my $thing = $_;
	my $startbit = ""; my $endbit = "";
	my $value = $thing->{'value'};
	if ($thing->{"type"} && ( $thing->{"type"} eq "semantic" || $thing->{"type"} eq "phonetic")) { # value gets {}
	    $value = "{".$value."}";
	    #if ($thing->{"delim"}) { print "\nValue = ".$value." delim = ".$thing->{"delim"}; die; }
	}
	
	if($thing->{"state"} && $thing->{"state"} eq "missing"){ # value gets []
	    if ($lastend ne "]") { $startbit = "[" ; }
	    else { $lastend = ""; }
	    $endbit = "]";
	    $missingSigns++;
	}
	elsif ($thing->{"state"} && $thing->{"state"} eq "damaged"){ # value gets half[]
	    if ($lastend ne "\x{02FA}") { $startbit = "\x{02F9}" ; }
	    else { $lastend = ""; }
	    $endbit = "\x{02FA}";
	    $damagedSigns++;
	}
	my $delim = "";
	if ($thing->{"delim"}) { $delim = $thing->{"delim"}; }
	$writtenWord .= $lastend.$lastdelim.$startbit.$value;
	$lastend = $endbit;
	$lastdelim = $delim;
    }
    $writtenWord .= $lastend.$lastdelim;
    my $no_signs = scalar @arrayWord;
    $preservedSigns = $no_signs - $damagedSigns - $missingSigns;
    
    # fill in worddata: number of preserved signs, etc.
    my $break = "damaged";
    if ($no_signs == $preservedSigns) { $break = "preserved"; $worddata{"stateWord"} = "preserved"; }
    elsif ($no_signs == $missingSigns) { $break = "missing"; $worddata{"stateWord"} = "missing"; }
    else { $worddata{"stateWord"} = "damaged"; }
    
    if ($preservedSigns > 0) { $worddata{"preservedSigns"} = $preservedSigns; }
    if ($damagedSigns > 0) { $worddata{"damagedSigns"} = $damagedSigns; }
    if ($missingSigns > 0) { $worddata{"missingSigns"} = $missingSigns; }

    &saveWord($lang, $form, $break, $wordtype, $cf, $pofs, $epos, $writtenWord, $label, $split, $wordbase, $gw);

    # words that comprise several parts should be treated as such e.g. KUR--MAR.TU{ki} and personal names
    
    my $count = 0; my $beginpos = 0; my $endpos = $no_signs - 1; my $severalParts = 0;
    while ($count < $no_signs) {
	if (($arrayWord[$count]->{'delim'}) && ($arrayWord[$count]->{'delim'} eq "--")) {
	    $endpos = $count; $severalParts++;
	    &determinePosition($beginpos, $endpos, \@arrayWord);
	    $beginpos = $endpos+1; $endpos = $no_signs - 1;
	}
	$count++;
    }
    &determinePosition($beginpos, $endpos, \@arrayWord);
    
    my %allWordData;
    $allWordData{"word"}->{"written"} = $writtenWord; $allWordData{"word"}->{"cf"} = $cf;
    $allWordData{"word"}->{"form"} = $form; $allWordData{"word"}->{"lang"} = $lang;
    $allWordData{"word"}->{"no_signs"} = $no_signs; $allWordData{"word"}->{"label"} = $label;
    $allWordData{"word"}->{"wordtype"} = $wordtype; $allWordData{"word"}->{"wordbase"} = $wordbase;
    $allWordData{"word"}->{"gw"} = $gw;
    #$allWordData{"signs"} = \@arrayWord; 
    
    #push (@{$localdata->{"word"}}, \%allWordData);
#    if ($wordtype ne "OtherWords") {
#	print "\n\nArrayWord";
#	print Dumper (@arrayWord);
#    }
#    
    &saveSigns(\%allWordData, \@arrayWord);
    
    # make temporary array of each word including information about determinative [det]/phonetic [phon], syllabic [syll], logographic [logo], logographic suffixes [logosuff]

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
	$position++;
	return ($splitdata, $position);
    }

    # Determinatives and phonetic complements: g:d with g:role and g:pos
    if ($tag eq "g:d") {
	my @det_elements = $root->children();
	$type = $root->{att}->{"g:role"};
	$prepost = $root->{att}->{"g:pos"};
	$delim = $root->{att}->{"g:delim"};
	my @temp = ();
	foreach my $j (@det_elements) {
	    ($splitdata, $position) = &splitWord($splitdata, $j, $position, $type, $prepost, "", $delim);
	}
    }
    
    # Compounds: g:c { form? , g.meta , c.model , mods* }
    # and: g:g { g.meta , c.model , mods* }
    # -> n | s | c | (g,mods*) | q
    #	    <g:c form="|BAD?DI?@t|" xml:id="Q000003.12.2.0" g:status="ok">
#                <g:s>BAD</g:s>
#                <g:o g:type="containing"/> 
#                <g:s form="DI?@t">
#                    <g:b>DI?</g:b>
#                    <g:m>t</g:m>
#                </g:s>
#            </g:c>

#	    <g:c form="|EN.PAP.IGI@g.NUN.ME.EZEN?KASKAL|">
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
#	    <g:c form="|(SAL.TUG..).PAP.IGI@g.ME.EZEN?KASKAL|">
#                    <g:g>
#                        <g:s>SAL</g:s>
#                        <g:o g:type="beside"/>
#                        <g:s g:accented="T?G">TUG..</g:s>
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
	    
#	    <g:c form="|MU?&amp;KAK&amp;MU?|" xml:id="Q000003.121.1.0" g:status="ok">
#                    <g:s>MU?</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>KAK</g:s>
#                    <g:o g:type="above"/>
#                    <g:s>MU?</g:s>
#                </g:c>

    if (($tag eq "g:c") || ($tag eq "g:g")) {
	my @c_elements = $root->children();
	my $c_delim = "";
	if ($root->{att}->{"g:delim"}) { $c_delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }

	my $cnt = 0; my $no_els = scalar @c_elements;
	foreach my $c (@c_elements) { 
	    if ($c->tag eq "g:o") {
		my $punct = "";
		my $type = $c->{att}->{"g:type"};
		if ($type eq "beside") { $punct = "."; }
		elsif ($type eq "containing") { $punct = "x"; } # should elements with containing have the same position?? ***
		elsif ($type eq "above") { $punct = "&amp;"; }  # other types = joining, reordered, crossing, opposing; how marked ??
		# add info to previous element
		my $lastone = scalar @{$splitdata};
		$splitdata->[$lastone - 1]->{"delim"} = $punct;
		$splitdata->[$lastone - 1]->{"combo"} = $type;
		}
	    else {
		($splitdata, $position) = &splitWord($splitdata, $c, $position, "", "", $break, $delim);
	    }
	    $cnt++;
	    if ($cnt == $no_els) {
		if ($c_delim ne "") {
		    my $lastone = scalar @{$splitdata};
		    $splitdata->[$lastone - 1]->{"delim"} = $c_delim;
		}
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
	($splitdata, $position) = &splitWord($splitdata, $firstpart, $position, "", "", $delim, $break);
	
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
#              <g:v g:accented="?" g:utf8=" xml:id="P338566.6.2.0" g:break="damaged" g:remarked="1" g:ho="1">u...</g:v>
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
	    ($splitdata, $position) = &splitWord($splitdata, $gg, $position, "", "", $break, $delim, $group);
	}
	else { # good for "logo", "reordering"
	    foreach my $gg (@gg_elements) {
	        ($splitdata, $position) = &splitWord($splitdata, $gg, $position, "", "", $break, $delim, $group);
	    }
	}
	&listCombos($root);
    }
    
    return ($splitdata, $position);
}
   

sub determinePosition { # seems to work with words with 2 determinatives in a row; what about several phonetic complements (a word longer than 1 sign) *** TODO
    my $beginpos = shift;
    my $endpos = shift;
    my @arrayWord = @{$_[0]};
    
    my $cnt = $beginpos; my $no_signs = $endpos - $beginpos + 1;
    my $no_pre = 0; my $no_post = 0;
    while ($cnt < $endpos + 1) {
	if ($arrayWord[$cnt]->{'prePost'}) {
	   if  ($arrayWord[$cnt]->{'prePost'} eq "pre") { $no_pre++; }
	   else { $no_post++; }
	}
	$cnt++;
    }
    
    $cnt = $beginpos;
    if (($no_pre == 0) && ($no_post == 0)) { # word without determinatives or phonetic complements
	while ($cnt < $endpos + 1) {
	    my $pos = $arrayWord[$cnt]->{'pos'}; 
	    if ($no_signs == 1) { $arrayWord[$cnt]->{'position'} = 'alone'; }
	    elsif ($pos == $beginpos + 1) { $arrayWord[$cnt]->{'position'} = 'initial'; }
	    elsif ($pos == $endpos + 1) { $arrayWord[$cnt]->{'position'} = 'final'; }
	    else { $arrayWord[$cnt]->{'position'} = 'medial'; }
	    $cnt++;
	}
    }
    elsif ($no_signs - $no_pre - $no_post == 1) { # only one sign with determinative(s) or phonetic complement(s)
	while ($cnt < $endpos + 1) {
	    $arrayWord[$cnt]->{'position'} = "alone";
	    $cnt++;
	}
    }
    else {
        $cnt = $beginpos; my $earlierPrePost = "";
        while ($cnt < $endpos + 1) {
	    my $pos = $arrayWord[$cnt]->{'pos'}; 
	    my $prePost = $arrayWord[$cnt]->{'prePost'}?$arrayWord[$cnt]->{'prePost'}:""; # pre or post-position
	    if (!($arrayWord[$cnt]->{'position'})) {
	        if ($pos == $beginpos + 1) { $arrayWord[$cnt]->{'position'} = 'initial'; }
	        elsif ($pos == $endpos + 1) { $arrayWord[$cnt]->{'position'} = 'final'; }
	        else { $arrayWord[$cnt]->{'position'} = 'medial'; }
	    }
	    if ($earlierPrePost eq "pre") { $arrayWord[$cnt]->{'position'} = $arrayWord[$cnt-1]->{'position'}; $earlierPrePost = ""; }
	    
	    if ($prePost) {
	        if ($prePost eq "pre") { $earlierPrePost = "pre"; } 
	        else { $arrayWord[$cnt-1]->{'position'} = $arrayWord[$cnt]->{'position'};
		}
	    }
	    $cnt++;
	}
    }
}

sub listCombos { # TODO, save in a separate file?
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
    my $writtenWord = shift;  
    my $label = shift;
    my $split = shift;
    my $wordbase = shift;  # TODO: save wordbase if present (esp. Sumerian)
    my $gw = shift; # TODO
    
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

sub saveSigns { # TODO, LANGUAGE-dependent
    my $allWordData = shift;
    my @arrayWord = @{$_[0]};

    my $writtenWord = $allWordData->{"word"}->{"written"}?$allWordData->{"word"}->{"written"}:"";
    my $cf = $allWordData->{"word"}->{"cf"}?$allWordData->{"word"}->{"cf"}:"";
    my $form = $allWordData->{"word"}->{"form"}?$allWordData->{"word"}->{"form"}:"";
    my $lang = $allWordData->{"word"}->{"lang"}?$allWordData->{"word"}->{"lang"}:"noLang";
    my $no_signs = $allWordData->{"word"}->{"no_signs"}?$allWordData->{"word"}->{"no_signs"}:0;
    my $label = $allWordData->{"word"}->{"label"}?$allWordData->{"word"}->{"label"}:"";
    my $wordtype = $allWordData->{"word"}->{"wordtype"}?$allWordData->{"word"}->{"wordtype"}:"";
    my $wordbase = $allWordData->{"word"}->{"wordbase"}?$allWordData->{"word"}->{"wordbase"}:"";
    my $gw = $allWordData->{"word"}->{"gw"}?$allWordData->{"word"}->{"gw"}:""; 
    my $category = "";
    
    if ($form =~ m|^\$|gsi) { $category = "uncertainReading"; }
    #print "\n\nIn signs: \n";
    #print Dumper(@arrayWord);
    #print "\nWritten Word: \n";
    #print Dumper($writtenWord);

    # Greta: what happens to unclear readings? $BA etc.? How marked in SAAo? *** TODO
    # TODO: logographic suffixes ***
    foreach my $sign (@arrayWord) {
	if ($category eq "") { $category = $sign->{'tag'}?$sign->{'tag'}:"unknown"; }
	my $state = $sign->{'state'}; 
	my $value = $sign->{'value'}; my $pos = $sign->{'pos'}; my $position = $sign->{'position'};
	my $role = $sign->{'type'}?$sign->{'type'}:""; # semantic or phonetic
	my $prePost = $sign->{'prePost'}?$sign->{'prePost'}:""; # pre or post-position
	my $base = $sign->{'base'}?$sign->{'base'}:""; # baseform if present
	my $syllabic = "";
	
	if ($category eq 'g:n') {
	    $category = "number";
	}
	
	elsif ($category eq 'g:x') {
	    #print "\n Value = ".$value." label = ".$label;
	    $category = "x";
	}
	
	elsif ($lang =~ m|^akk|) {
	    if ($category eq 'g:v') { # syllabic signs, unless {d}, {m}
		$category = "syllabic";
		my %syllables = ();
		$syllables{"V"} = 1; $syllables{"VC"} = 1;
		$syllables{"CV"} = 1; $syllables{"CVC"} = 1;

		my $tempvalue = $sign->{'base'}?$sign->{'base'}:$value;
		
		$syllabic = lc($tempvalue);
		
		# determine what kind of syllabic sign we're dealing with: V, CV, VC, CVC, other (ana/ina/arba/CVCV)
		$syllabic =~ s|(\d)||g;
		$syllabic =~ s|([aeiou])|V|g;
	# nuke the subscripts like numbers (unicode 2080 - 2089) 
		$syllabic =~ s|(\x{2080})||g; $syllabic =~ s|(\x{2081})||g; $syllabic =~ s|(\x{2082})||g; $syllabic =~ s|(\x{2083})||g; $syllabic =~ s|(\x{2084})||g;
		$syllabic =~ s|(\x{2085})||g; $syllabic =~ s|(\x{2086})||g; $syllabic =~ s|(\x{2087})||g; $syllabic =~ s|(\x{2088})||g; $syllabic =~ s|(\x{2089})||g;
		$syllabic =~ s|(\x{2093})||g; # subscript x
		$syllabic =~ s|([^V])|C|g;
		
		if ($syllabic eq "VV") { # e.g., ia
		    $syllabic = "CV";
		}
		
		if ($syllabic eq "CVCV") { # check again TODO - V should be the same
		    $syllabic = "CVC";
		}
		
		if (!($syllables{$syllabic})) { # not V, CV, VC, or CVC
		    if ($role eq "semantic") {
		        $syllabic = ""; $category = "determinative";
		    }
		    elsif ($syllabic eq "C") {
			if (($tempvalue eq "d") || ($tempvalue eq "m")) { $category = "determinative"; $syllabic = ""; }
			else { $category = "x"; $syllabic = ""; } # then the value should be x, so unreadable sign, treat as "x"
		    } 
		    else { $category = "logogram"; $syllabic = ""; } # logosyllabic ?? *** TODO, eg. ana/ina/arba/CVCV
		}
		else {
		    if ($tempvalue eq "o") { $category = ""; $syllabic = ""; }  
		}
	    }
	    elsif ($category eq 'g:s') {
		$category = "logogram";
	    }
	}
        elsif ($lang =~ m|^sux|) {
	    if ($category eq 'g:v') {
		# check if part of wordbase or not.
		# how about base/different signs in base with their position? somehow done, but may be improved TODO (?)
		if ($wordbase =~ /$value/) { $category = "base"; }
		else { $category = "nonbase"; }
	    }
	    if ($role eq "semantic") { 	$category = "determinative"; }
        }
        else {
	
        }
    &saveData($lang, $category, $value, $base, $role, $prePost, $position, $syllabic, $state, $label, $cf, $writtenWord, $wordtype, $gw, $wordbase);
    if ($category ne "uncertainReading") { $category = ""; }
    }
}


sub saveData { 
    my $lang = shift;
    my $category = shift;
    my $value = shift;
    my $base = shift;
    my $role = shift;
    my $prePost = shift;
    my $pos = shift;
    my $syllabic = shift;
    my $break = shift;
    my $label = shift;
    my $cf = shift;
    my $writtenWord = shift;
    my $wordtype = shift;
    my $gw = shift; 
    my $wordbase = shift; # TODO
    my %temp = ();
    
    if($lang eq ""){
	$lang = "noLang";
    }

    if ($role eq "semantic") {
	$category = "determinative";
    }

    $PQdata{"02_Signs"}{'count'}++; # total number of signs
    $PQdata{"02_Signs"}{"ztotal_state"}{$break}{'count'}++;
    $PQdata{"02_Signs"}{$lang}{'count'}++; # total number of signs per language
    $PQdata{"02_Signs"}{$lang}{"zlang_total_state"}{$break}{'count'}++;
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{'count'}++; # total number of signs per language and category
    $PQdata{"02_Signs"}{$lang}{"category"}{$category}{"state"}{$break}{'count'}++;

# TODO: try to make shorter, sth like below but example is already outdated. Print and check.

#    if ($cf ne "") {
#	    push (@{$temp{$role}{"prepost"}{$prePost}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"writtenWord"}{$writtenWord}{"line"}}, $label);
#    push (@{$PQdata{"02_Signs"}{$lang}}, \%temp);

    if (($category eq "syllabic") && ($syllabic ne "")) { # we can further categorize the signs into V, CV, VC, CVC
	$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{'count'}++; # total number of signs
        $PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{"state"}{$break}{'count'}++;
	if ($cf ne "") {
	    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}{"writtenWord"}{$writtenWord}{"line"}}, $label);
	}
	else {
	    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"type"}{$syllabic}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"writtenWord"}{$writtenWord}{"line"}}, $label);
	}
    }
    else { # count determinatives separately ***
	if (($role ne "semantic") && ($role ne "phonetic")) {
	    if ($wordbase eq "") {
		if ($cf ne "") {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
		else {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
	    }
	    else {
		if ($cf ne "") {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"wordbase"}{$wordbase}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
		else {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"wordbase"}{$wordbase}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
		
	    }
	}
	else {
	    if ($role eq "semantic") {
		$PQdata{"02_Signs"}{$lang}{"category"}{$category}{$prePost}{"count"}++;
		$PQdata{"02_Signs"}{$lang}{"category"}{$category}{$prePost}{"state"}{$break}{"count"}++;
		if ($cf ne "") {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{$prePost}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
		else {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{$prePost}{"value"}{$value}{"wordtype"}{$wordtype}{"pos"}{$pos}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
	    }
	    else {
		if ($cf ne "") {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$value}{"wordtype"}{$wordtype}{"role"}{$role}{"prepost"}{$prePost}{"pos"}{$pos}{"cf"}{$cf}{"gw"}{$gw}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
		else {
		    push (@{$PQdata{"02_Signs"}{$lang}{"category"}{$category}{"value"}{$value}{"wordtype"}{$wordtype}{"role"}{$role}{"prepost"}{$prePost}{"pos"}{$pos}{"writtenWord"}{$writtenWord}{"line"}}, $label);
		}
	    }
	}
    }
    
    
#    $localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"total_grapheme"}{$category}{$break}{'num'}++;
#	
#    if ($form ne "") { 
#	if ($lang =~ m|^akk|) {
#	    if($cvc ne ""){
#		if ($pos eq "") {
#		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}{'cvc'}{$cvc}},$baseform,$break,$form);
#		}
#		else {
#		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}{"pos"}{$pos}{'cvc'}{$cvc}},$baseform,$break,$form);
#		}
#	    }
#	    else {
#		if ($pos eq "") {
#		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}},$baseform,$break,$form);
#		}
#		else {
#		    abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#		}
#	    }
#	}
#	else {
#	    if ($pos eq "") {
#		abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}},$baseform,$break,$form);
#	    }
#	    else {
#		abstractdata(\%{$localdata->{"lang"}{$lang}{$type}{"type"}{$category}{"role"}{$role}{"pos"}{$pos}},$baseform,$break,$form);
#	    }
#	}
#    }
    

 
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
# xtf and xmd-files: /home/varoracc/local/oracc/bld/saao/saa19/P224/P224381/P224381.xtf and .xmd
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
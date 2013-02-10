package CHUNKER::word;

use strict;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use utf8;

my $thisCorpus = "";
my $thisText = "";
my %worddata = ();

sub returnData{
    return \%worddata;
}

sub initialise{
    $thisCorpus = shift;
    $thisText = shift;
    %worddata = ();
}
sub determinePosition { # seems to work with words with 2 determinatives in a row; what about several phonetic complements (a word longer than 1 sign) *** TODO check (not in my examples so far)
    my $beginpos = shift;
    my $endpos = shift;
    my @arrayWord = @{$_[0]};
    
    &CHUNKER::generic::writetoerror("timestamping","determinePosition - starting ".localtime);
    
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

    &CHUNKER::generic::writetoerror("timestamping","determinePosition - ending ".localtime);
}

sub analyseWord{
    my $root = shift;
    my $word = shift;
    my $label = shift;
    my $note = shift;
    my $split = shift || "";
    my %worddata = ();
    
    &CHUNKER::generic::writetoerror("timestamping","analyseWord - starting ".$word." ".localtime);
    
# return data as number of words, number of signs etc.
# save data as words, signs, etc. in PQdata{"words"} and PQdata{"signs"}
    my $lang = $word->{att}->{'xml:lang'}?$word->{att}->{'xml:lang'}:"noLang";
    my $form = $word->{att}->{"form"}?$word->{att}->{"form"}:""; 
    my $wordid = $word->{att}->{"xml:id"}?$word->{att}->{"xml:id"}:"";
    my $tempvalue = './/l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
    my $cf = ""; my $pofs = ""; my $epos = ""; my $wordbase = ""; my $gw = "";
            
    # xtf-file
    #print "\n".$tempvalue."\n";
    my @wordref = $root->get_xpath($tempvalue); 
    foreach my $item (@wordref) {
        $cf = $item->{att}->{"cf"}?$item->{att}->{"cf"}:"";
        $pofs = $item->{att}->{"pos"}?$item->{att}->{"pos"}:""; # pofs = part-of-speech (pos is used already for position)
        $epos = $item->{att}->{"epos"}?$item->{att}->{"epos"}:"";
	$gw = $item->{att}->{"gw"}?$item->{att}->{"gw"}:"";
	$wordbase = $item->{att}->{"base"}?$item->{att}->{"base"}:"";
    }
    
    my $wordtype;
    if ($form ne '') { $wordtype = &typeWord ($form, $pofs); }
    else { $wordtype = &typeWord ($word, $pofs); }
    
#Split: d
#Split: AMARUTU
#$VAR1 = {
#          'value' => 'd',
#          'type' => 'semantic',
#          'tag' => 'g:v',
#          'pos' => 1,
#          'prePost' => 'pre',
#          'break' => 'damaged'
#        };
#$VAR2 = {
#          'group' => 'logo',
#          'value' => 'AMAR',
#          'tag' => 'g:s',
#          'pos' => 2,
#          'delim' => '.',
#          'break' => 'damaged'
#        };
#$VAR3 = {
#          'group' => 'logo',
#          'value' => 'UTU',
#          'tag' => 'g:s',
#          'pos' => 3,
#          'break' => 'damaged'
#        };
    
    my @arrayWord = ();
    
    my @children = $word->children();
 
    my $no_children = scalar @children;
    my $position = 1; my $localdata = {}; my $cnt = 0; my $tempdata = {};
    foreach my $i (@children) { # check each element of a word
	($tempdata, $position) = &splitWord (\@arrayWord, $i, $label, $position);
	$cnt++;
    }
    
    if ($split eq "splithead") {
	my $ref = $word->{att}->{"xml:id"};
	# look for splitend
	my $tempvalue = '//g:swc[@headref="'.$ref.'"]'; 
	my @splitenz = $root->findnodes($tempvalue); 
	if (@splitenz) {
	    my $lastSoFar = scalar @arrayWord;
	    $arrayWord[$lastSoFar - 1]->{"split"} = "split";
	    my @endchildren = $splitenz[0]->children();
	    $localdata = {}; $cnt = 0;
	    foreach my $j (@endchildren) { 
	        ($tempdata, $position) = &splitWord (\@arrayWord, $j, $label, $position);
	        $cnt++;
	    }
	    # add extra line number; find parent of swc
	    my $parent = $splitenz[0]->parent();
	    if ($parent->{att}->{"label"}) { my $extraLabel = $parent->{att}->{"label"}; $label .= "-".$extraLabel; }
	}
	#print Dumper @arrayWord;
    }
    
    my $writtenWord = ""; 
    my $preservedSigns = 0; #my $damagedSigns = 0; my $missingSigns = 0;
    my $signs = (); my $conditionWord = "";
    ($writtenWord, $signs, $conditionWord) = &formWord(\@arrayWord);
    $worddata{"conditionWord"} = $conditionWord;
    my $no_signs = scalar @arrayWord;
    
    # fill in worddata: number of preserved signs, etc.
    #$worddata{"stateWord"} = $conditionWord;
    
    if ($signs->{'preserved'} > 0) { $worddata{"preservedSigns"} = $signs->{'preserved'}; }
    if ($signs->{'damaged'} > 0) { $worddata{"damagedSigns"} = $signs->{'damaged'}; }
    if ($signs->{'missing'} > 0) { $worddata{"missingSigns"} = $signs->{'missing'}; }
    if ($signs->{'implied'} > 0) { $worddata{"impliedSigns"} = $signs->{'implied'}; }
    if ($signs->{'supplied'} > 0) { $worddata{"suppliedSigns"} = $signs->{'supplied'}; }
    if ($signs->{'erased'} > 0) { $worddata{"erasedSigns"} = $signs->{'erased'}; }
    if ($signs->{'excised'} > 0) { $worddata{"excisedSigns"} = $signs->{'excised'}; }

    my $writtenAs = "";
    foreach my $i (@arrayWord) {
	if ($i->{'group'}) {
	    $note = $i->{'group'};
	    if ($note eq "correction") {
		#$writtenAs = $writtenWord without brackets
		$writtenAs = $writtenWord; 
		$writtenAs =~ s|\[||g; $writtenAs =~ s|\]||g; $writtenAs =~ s|\x{2E22}||g; $writtenAs =~ s|\x{2E23}||g;
	    }
	}
	if ($i->{'newline'}) {
	    $note = "newline";
	}
    }

    &saveWord($lang, $form, $conditionWord, $wordtype, $cf, $pofs, $epos, $writtenWord, $label, $split, $wordbase, $gw, $note, $writtenAs);

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
    $allWordData{"word"}->{"gw"} = $gw; $allWordData{"word"}->{"condition"} = $conditionWord;
    #$allWordData{"signs"} = \@arrayWord; 
    
    #push (@{$localdata->{"word"}}, \%allWordData);
#    if ($wordtype ne "OtherWords") {
#	print "\n\nArrayWord";
#	print Dumper (@arrayWord);
#    }
#
    &CHUNKER::punct::saveSigns( \%allWordData, \@arrayWord);
    
    # make temporary array of each word including information about determinative [det]/phonetic [phon], syllabic [syll], logographic [logo], logographic suffixes [logosuff]

    &CHUNKER::generic::writetoerror("timestamping","analyseWord - ending ".localtime);
    return \%worddata;
}

sub typeWord {
    my $form = shift;
    my $pofs = shift || "";
    
    &CHUNKER::generic::writetoerror("timestamping","typeWord - starting ".localtime);
    my $wordtype = "";
    
    if (($form eq "x") || ($form eq "X")) {
	$wordtype = "XWord";
    }
    
    # PERSONAL and ROYAL NAMES
    if (($pofs eq "RN") || ($pofs eq "PN")) { $wordtype = "PersonalNames"; } 
    
    # http://oracc.museum.upenn.edu/doc/builder/linganno/QPN/
    # GEOGRAPHICAL DATA: GN, WATERCOURSE, ETHNIC (GENTILICS), AGRICULTURAL, FIELD, QUARTER, SETTLEMENT, LINE, TEMPLE 
    if (($pofs eq "GN") || ($pofs eq "WN") || ($pofs eq "EN") || ($pofs eq "AN") || ($pofs eq "FN") || ($pofs eq "QN") || ($pofs eq "SN") || ($pofs eq "LN") || ($pofs eq "TN")) {
	$wordtype = "Geography";
    }
    
    # DIVINE and CELESTIAL NAMES
    if (($pofs eq "DN") || ($pofs eq "CN")) {
	$wordtype = "DivineCelestial"; 
    }
    
    # ROUGH CLASSIFICATION IF NOT LEMMATIZED
    if (($wordtype eq "") && ($form ne "")) { 
	my $formsmall = lc ($form);
	if ($formsmall =~ /(^\{1\})|(^\{m\})|(^\{f\})|(^\{di\x{0161}\})/) { $wordtype = "PersonalNames"; }
	if (($formsmall =~ /(^\{d\})/) || ($formsmall =~ /(^\{mul\})/) || ($formsmall =~ /(^\{mul\x{2082}\})/)) { $wordtype = "DivineCelestial"; }  
	if (($formsmall =~ /(\{ki\})/) || ($formsmall =~ /(\{kur\})/) || ($formsmall =~ /(\{uru\})/) || ($formsmall =~ /(\{iri\})/) || ($formsmall =~ /(\{id\x{2082}\})/))  { $wordtype = "Geography"; }
	if ($formsmall =~ /^\d/) { $wordtype = "Numerical"; }
    }    

    if (($wordtype ne "PersonalNames") && ($wordtype ne "DivineCelestial") && ($wordtype ne "Geography") && ($wordtype ne "Numerical") && ($wordtype ne "XWord")) {
	if ($form =~ /^\$/) { $wordtype = "UncertainReading"; }
	else { $wordtype = "OtherWords"; }
    }

    &CHUNKER::generic::writetoerror("timestamping","typeWord - ending ".localtime);
    return $wordtype;
}

sub formWord{
    my @arrayWord = @{$_[0]};
    
    &CHUNKER::generic::writetoerror("timestamping","formWord - starting ".localtime);
    my $writtenWord = "";
    my $signs = ();
    $signs->{'preserved'} = scalar @arrayWord;
    # status of signs
    $signs->{'ok'} = 0; $signs->{'missing'} = 0; $signs->{'damaged'} = 0;
    $signs->{'maybe'} = 0; $signs->{'implied'} = 0; $signs->{'supplied'} = 0; $signs->{'erased'} = 0; $signs->{'excised'} = 0;
    
    # break of signs
    $signs->{'damaged'} = 0; $signs->{'missing'} = 0; $signs->{'undetermined'} = 0;
    
    my $lastdelim = ""; my $lastend = "";
    
    # g:status: "ok" - g:o and g:c 
    # "maybe": (...) # in breaks
    # "excised": <<...>> : &lt;&lt;    &gt;&gt; # superfluous sign on tablet
    # "supplied": <...> # forgotten by the scribe, not on tablet
    # "erased": <{...}>
    # "implied": <(...)> #  graphemes are implied because the scribe has left a blank space on the tablet. Right, this means that there's actually nothing on the tablet, just blank space. Ignore?
    
    #my $open = ""; my $closed = "";
    
    my $notASign = 0; my $previousStatus = "ok";
    my $previousClosedSym = "";
    my $conditionWord = "";
    #my $print = "no";
    my $no_elements = scalar @arrayWord;
    
    foreach(@arrayWord){
	my $thing = $_;
	my $status = $thing->{'status'}?$thing->{'status'}:"";
	my $break = $thing->{"break"}?$thing->{"break"}:"undetermined";
	
	# "maybe" will normally be missing or damaged; rarely no break given (e.g. P363582 (x)), if x then damaged? (obviously difficult to see on photo whether there is a sign or not)
	#if (($status eq "maybe") && !(($break eq "missing") || ($break eq "damaged"))) {
	#    &writetoerror ("Words", "Project: ".$thisCorpus.", text ".$thisText.": status: ".$status." break: ".$break);
	#}
	
	my $openSym = ""; my $closedSym = "";
	$signs->{$status}++;
	if ($status eq "maybe") { $openSym = "("; $closedSym = ")"; }
	elsif ($status eq "implied") { $openSym = "&lt;("; $closedSym = ")&gt;"; }
	elsif ($status eq "supplied") { $openSym = "&lt;"; $closedSym = "&gt;"; }
	elsif ($status eq "erased") { $openSym = "&lt;{"; $closedSym = "}&gt;"; }
	elsif ($status eq "excised") { $openSym = "&lt;&lt;"; $closedSym = "&gt;&gt;"; }
	
	$signs->{$break}++;
	
	my $startbit = ""; my $endbit = "";
	my $value = $thing->{'value'};
	if (($value eq "") || ($value eq ";")) { $notASign++; } # signs with no value shouldn't be counted (are probably newlines!!!) 
	
	if ($thing->{"type"} && ($thing->{"type"} eq "semantic")) { # determinatives get {}
	    $value = "{".$value."}";
	}
	
	if ($thing->{"type"} && ($thing->{"type"} eq "phonetic")) { # phonetic complements get {+}
	    $value = "{+".$value."}";
	}
	
	if (($previousStatus eq "ok") && ($status eq "ok")) {
	    # nothing needs to happen
	}
	elsif (($previousStatus eq "ok") && ($status ne "ok")) {
	    # we need openSym before word
	    $value = $openSym.$value;
	}
	
	if ($break eq "missing"){ # value gets []
	    if ($lastend ne "]") { $startbit = "[" ; }
	    else { $lastend = ""; }
	    $endbit = "]";
	}
	elsif ($break eq "damaged"){ # value gets half[]
	    if ($lastend ne "\x{2E23}") { $startbit = "\x{2E22}" ; }
	    else { $lastend = ""; }
	    $endbit = "\x{2E23}";
    	}
	
	if (($previousStatus ne "ok") && ($status eq "ok")) {
	    # we need to close before next sign with $previousClosedSym, adding $lastend before that
	    $lastend = $previousClosedSym.$lastend;
	}
	elsif (($previousStatus ne "ok") && ($status ne "ok")) {
	    # same or different status?
	    if ($previousStatus eq $status) {
		# nothing happens [maybe not true: how about break?] # TODO: check again with other examples
	    }
	    else {
		# close first bit; and next value will need opening after delim if not ok
		$lastend = $previousClosedSym.$lastend;
		$lastdelim .= $openSym;
	    }
	}
	
	my $delim = "";
	if ($thing->{"delim"}) { $delim = $thing->{"delim"}; }
	$writtenWord .= $lastend.$lastdelim.$startbit.$value;
	$lastend = $endbit;
	$lastdelim = $delim;
	$previousClosedSym = $closedSym;
	$previousStatus = $status;
    }
    
    $no_elements = $no_elements - $notASign;
    # always correct? OK for all my examples so far. # TODO check again
    if ($no_elements > 1) { $writtenWord .= $lastend.$previousClosedSym.$lastdelim; }
    else { $writtenWord .= $previousClosedSym.$lastend.$lastdelim; }
    
    # $conditionWord
    # signs can have g:status and/or g:break (or neither)
    # e.g. a sign can have break = missing/damaged/[nothing] and status = erased
    
    # g:break = missing or damaged (otherwise not given) - however, words existing out of implied signs do not seem to have a break (e.g. P247848 (um-mar)),
    # though these implied signs are NOT present!
    # signs have g:status = ok, excised, supplied, maybe, implied, erased -> ok, excised and erased are present on the tablet; maybe may be too. 
    # supplied are, however, forgotten signs; and implied is blank space.
    
    # condition of word:
    # preserved: all signs have no break and status = ok
    # damaged: less than all signs are missing or damaged
    # missing: all signs have break = missing and the word isn't completely "erased", "excised", "supplied" or "implied"
    # erased: all signs have status = erased
    # excised: all signs have status = excised
    # supplied: all signs have status = supplied
    # implied: all signs have status = implied
    
    # Note: there is no condition "maybe". "maybe" will normally be missing or damaged; rarely there is no g:break given (e.g. P363582 (x))
    # => damaged (obviously difficult to see on photo whether there is a sign or not)

    if ($no_elements == $signs->{'erased'}) { $conditionWord = "erasedWord"; }
    elsif ($no_elements == $signs->{'excised'}) { $conditionWord = "excisedWord"; }
    elsif ($no_elements == $signs->{'supplied'}) { $conditionWord = "suppliedWord"; }
    elsif ($no_elements == $signs->{'implied'}) { $conditionWord = "impliedWord"; }
    elsif ($no_elements == $signs->{'missing'}) { $conditionWord = "missingWord"; }
    elsif (($signs->{'damaged'} > 0) || ($signs->{'missing'} > 0)) { $conditionWord = "damagedWord"; }
    else { $conditionWord = "preservedWord"; }
    #elsif ($no_elements == $signs->{'ok'}) { $conditionWord = "preservedWord"; }
    #else { $conditionWord = "damagedWord"; }
    
    # well preserved signs:
    # = NOT damaged signs, NOT missing signs, NOT implied signs [because blank space], NOT supplied signs [because forgotten], NOT erased signs [because, though present, not intended to be read and 'deleted']
    # = ok signs + excised signs [present on tablet and not deleted] + rest
    $signs->{'preserved'} = $signs->{'preserved'} - $signs->{'missing'} - $signs->{'damaged'} - $signs->{'implied'} - $signs->{'supplied'} - $signs->{'erased'};
    
    #if ($print eq "yes") { &writetoerror ("Words", "Project: ".$thisCorpus.", text ".$thisText.": word: ".$writtenWord); }
    
    &CHUNKER::generic::writetoerror("timestamping","formWord - ending ".localtime);
    return ($writtenWord, $signs, $conditionWord);
}

sub splitWord {
    my $splitdata = shift;
    my $root = shift;
    my $label = shift;
    my $position = shift;
    my $type = shift || "";
    my $prepost = shift || "";
    my $break = shift || "";
    my $delim = shift || "";
    my $group = shift || "";
    my $for = shift || "";
    my $status = shift || "";
    
    &CHUNKER::generic::writetoerror("timestamping","splitWord - starting ".localtime);
    my $localdata = {};
    my $tag = $root->tag;
    
    my $value = "";
    my $base = ""; my $allo = ""; my $formvar = ""; my $modif = ""; 
    my $newline = "";
    my $open = ""; my $closed = "";
    # http://oracc.museum.upenn.edu/ns/gdl/1.0/grapheme.rnc.html
    
    # Single elements: g:x (missing), g:n (number), g:v (small letters), g:s (capital)
    if (($tag eq "g:x") || ($tag eq "g:n") || ($tag eq "g:v") || ($tag eq "g:s")) {
	$localdata = {};
	
	if ($tag eq "g:x") {
	    $newline = $root->{att}->{'g:type'}; #possible in split words
	}
	$value = $root->{att}->{form}?$root->{att}->{form}:"";
	
	if (($value eq "1") && ($type eq "semantic")) { $value = "m"; }
	
	my @bases = $root->get_xpath("g:b");
	$base = $bases[0]?$bases[0]->text:"";
	# variants with g:a (allograph), g:f (formvar) or g:m (modifier)
	# see http://oracc.museum.upenn.edu/ns/gdl/1.0/#schemawords
	
	my @allos = $root->get_xpath("g:a"); $allo = $allos[0]?$allos[0]->text:"";
	my @formvars = $root->get_xpath("g:f"); $formvar = $formvars[0]?$formvars[0]->text:"";
	my @mods = $root->get_xpath("g:m"); $modif = $mods[0]?$mods[0]->text:"";
	
	if ((($allo ne "") && ($formvar ne "")) || (($allo ne "") && ($modif ne "")) || (($modif ne "") && ($formvar ne ""))) {
	    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": allo ".$allo." formvar ".$formvar." modif ".$modif);
	}
	
	if (($value eq "") && ($root->text)) { $value = $root->text; }
	if (($value eq "") && ($tag eq "g:n")) {
            my @grs = $root->get_xpath('g:r'); $value = $grs[0]?$grs[0]->text:"";
            }
	if (($value eq "") && ($newline eq "newline")) {
	    $value = ";";
	}
	
	if ($status eq "") {
	    $status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:"";
	    #if ($status ne "ok") { &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": sign status ".$status." value ".$value); }
	    }
	if ($status ne "ok") {
	    $open = $root->{att}->{'g:o'}?$root->{att}->{'g:o'}:"";
	    $closed = $root->{att}->{'g:c'}?$root->{att}->{'g:c'}:"";
	}

	if ($root->{att}->{"g:delim"}) {
	    $delim = $root->{att}->{"g:delim"};
	}
	$break = $root->{att}->{"g:break"}?$root->{att}->{"g:break"}:"undetermined"; 
	
	# g:break = missing or damaged (otherwise not given) - however, words existing out of implied signs do not seem to have a break (e.g. P247848 (um-mar)),
	# though these implied signs are NOT present!
	# signs have g:status = ok, excised, supplied, maybe, implied, erased -> ok, excised and erased are present on the tablet; maybe may be too. 
	# supplied are, however, forgotten signs; and implied is blank space.
	# SO: state = preserved (ok, excised), damaged, missing (incl. maybe, supplied and implied?), erased
	
	$localdata->{"pos"} = $position; $localdata->{"tag"} = $tag; $localdata->{"value"} = $value;
	if ($break ne "") { $localdata->{"break"} = $break; }
	if ($base ne "") { $localdata->{"base"} = $base; }
	if ($allo ne "") { $localdata->{"allograph"} = $allo; }
	if ($formvar ne "") { $localdata->{"formvar"} = $formvar; }
	if ($modif ne "") { $localdata->{"modifier"} = $modif; }
	if ($prepost ne "") { $localdata->{"prePost"} = $prepost; }
	if ($type ne "") { $localdata->{"type"} = $type; }
	if ($delim ne "") { $localdata->{"delim"} = $delim; }
	if ($group ne "") { $localdata->{"group"} = $group; }
	if ($for ne "") { $localdata->{"for"} = $for; }
	if ($status ne "") { $localdata->{"status"} = $status; }
	if ($newline eq "newline") { $localdata->{"newline"} = $newline; }
	if ($open ne "") { $localdata->{"open"} = $open; }
	if ($closed ne "") { $localdata->{"closed"} = $closed; }

	push(@{$splitdata},$localdata);
	$position++;
	return ($splitdata, $position);
    }

    # Determinatives and phonetic complements: g:d with g:role and g:pos
    if ($tag eq "g:d") {
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
	my @det_elements = $root->children();
	$type = $root->{att}->{"g:role"};
	$prepost = $root->{att}->{"g:pos"};
	$delim = $root->{att}->{"g:delim"};
	my @temp = ();
	foreach my $j (@det_elements) {
	    ($splitdata, $position) = &splitWord($splitdata, $j, $label, $position, $type, $prepost, "", $delim, $group, $for, $status);
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
	my $c_delim = $root->{att}->{"g:delim"}?$root->{att}->{"g:delim"}:""; 
	$break = $root->{att}->{"g:break"}?$root->{att}->{"g:break"}:"";
	if ($status eq "") { $status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; }

	my $cnt = 0; my $no_els = scalar @c_elements;
	foreach my $c (@c_elements) { 
	    if ($c->tag eq "g:o") {
		my $punct = "";
		my $type = $c->{att}->{"g:type"};
		if ($type eq "beside") { $punct = "."; }
		elsif ($type eq "containing") { $punct = "x"; } # should elements with containing have the same position?? ***
		elsif ($type eq "above") { $punct = "&amp;"; }  # other types = joining, reordered, crossing, opposing; how marked ??
		# add info to previous element
		my $lastone =0;
		if(scalar @{$splitdata}){
		    $lastone = scalar @{$splitdata}  - 1;
		    $splitdata->[$lastone - 1]->{"delim"} = $punct;
		    $splitdata->[$lastone - 1]->{"combo"} = $type;
		}
	    }
	    else {
		($splitdata, $position) = &splitWord($splitdata, $c, $label, $position, "", "", $break, $delim, $group, $for, $status);
	    }
	    $cnt++;
	    if ($cnt == $no_els) {
		if ($c_delim ne "") {
		    my $lastone = scalar @{$splitdata};
		    $splitdata->[$lastone - 1]->{"delim"} = $c_delim;
		}
	    }
	}
	&listCombos($root, $label);
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
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
        my $firstpart = $root->getFirstChild();
	if ($firstpart->{att}->{"g:delim"}) { $delim = $firstpart->{att}->{"g:delim"}; }
	if ($firstpart->{att}->{"g:break"}) { $break = $firstpart->{att}->{"g:break"}; }
	($splitdata, $position) = &splitWord($splitdata, $firstpart, $label, $position, "", "", $break, $delim, $group, $for, $status);
	
	my $secondpart = $firstpart->getNextSibling();
	&listCombos($root, $label);
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
	# ligature: P336601; P313917; P313837; P335915 # strange ligatures - only x+x # 
	# logo: P336601; P348706; P313917; P365126; P335915
	# correction: P348706; P365126; P363582
	# reordering: P335915; Q000003
	
	$status = $root->{att}->{"g:status"}?$root->{att}->{"g:status"}:""; 
	my @gg_elements = $root->children();
	$group = $root->{att}->{"g:type"};
	my $no_els = scalar @gg_elements;
	
	if (($group ne "logo") && ($group ne "correction") && ($group ne "reordering") && ($group ne "ligature")) {
	    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": g:gg of type ".$group); # - keep checking ***
	}
	
	if ($root->{att}->{"g:delim"}) { $delim = $root->{att}->{"g:delim"}; }
	if ($root->{att}->{"g:break"}) { $break = $root->{att}->{"g:break"}; }
	my @temp = ();
	if ($group eq "correction") { # only second(!) element matters 
	    # e.g. written RI instead of rum
	    #	<g:gg g:type="correction" g:status="ok">
            #		<g:v xml:id="P365126.5.1.2" g:remarked="1">rum</g:v>
            #    	<g:s>RI</g:s>
            #	</g:gg>
	    
#	<g:w xml:id="P365126.48.4" xml:lang="akk-x-oldbab" form="UNUG{ki}">
#		<g:gg g:type="correction" g:status="ok">
#			<g:s xml:id="P365126.48.4.0" g:remarked="1" g:role="logo" g:logolang="sux">UNUG</g:s>
#			<g:c form="|TAB.BA|">
#				<g:s>TAB</g:s>
#				<g:o g:type="beside" />
#				<g:s>BA</g:s>
#			</g:c>
#		</g:gg>
#		<g:d g:role="semantic" g:pos="post">
#			<g:v xml:id="P365126.48.4.1" g:status="ok">ki</g:v>
#		</g:d>
#	</g:w>
	    my $gg1 = $root->getFirstChild(); # corrected reading
	    $for = $gg1->text;
	    my $gg2 = $gg1->getNextSibling(); # written sign
	    ($splitdata, $position) = &splitWord($splitdata, $gg2, $label, $position, "", "", $break, $delim, $group, $for, $status);
	}
	elsif (($group eq "logo") || ($group eq "reordering")) {
	    $for = "";
	    my $gg_delim = $root->{att}->{"g:delim"}?$root->{att}->{"g:delim"}:""; 
	    my $cnt = 0;
	#    <g:w xml:id="P348890.18.1" xml:lang="akk-x-ltebab" form="KI.KAL-MEŠ{+uʾ}" g:delim=" ">
	#					<g:gg g:type="logo" g:delim="-">
	#						<g:s xml:id="P348890.18.1.0" g:break="damaged" g:ho="1" g:status="ok" g:role="logo" g:logolang="sux" g:delim=".">KI</g:s>
	#						<g:s xml:id="P348890.18.1.1" g:break="damaged" g:status="ok" g:role="logo" g:logolang="sux" g:hc="1">KAL</g:s>
	#					</g:gg>
	#					<g:s xml:id="P348890.18.1.2" g:status="ok" g:role="logo" g:logolang="sux">MEŠ</g:s>
	
	# the deliminator of the last element in the group can be given in the g:gg! TODO ***
	    
	    foreach my $gg (@gg_elements) {
		($splitdata, $position) = &splitWord($splitdata, $gg, $label, $position, "", "", $break, $delim, $group, $for, $status);
		$cnt++;
		if ($cnt == $no_els) {
		    if ($gg_delim ne "") {
			my $lastone = scalar @{$splitdata};
			$splitdata->[$lastone - 1]->{"delim"} = $gg_delim;
		    }
		}
	    }
	}
	elsif ($group eq "ligature") { # this may be OK, but check with more normal ligatures...
	    $for = "";
	    foreach my $gg (@gg_elements) {
	        ($splitdata, $position) = &splitWord($splitdata, $gg, $label, $position, "", "", $break, $delim, $group, $for, $status);
	    }
	}
	else { # some uncovered situation?
	    &writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.": group of type ".$group); # - keep checking ***
	}
	&listCombos($root, $label);
    }
    
    
    &CHUNKER::generic::writetoerror("timestamping","splitWord - ending ".localtime);
    return ($splitdata, $position);
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
    my $wordbase = shift;  
    my $gw = shift; 
    my $note = shift || "";
    my $writtenAs = shift || "";
    &CHUNKER::generic::writetoerror("timestamping","saveWord - starting ".localtime);
    
    $lang = CHUNKER::generic::langmatrix($lang);
    
    if($lang eq "") { $lang = "noLang"; }
    if ($note eq "logo") { $note = ""; }
    
    my $totaltype = "total_".$wordtype;
    $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'total'}++;
    $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'state'}{$break}{'num'}++;
    $worddata{'lang'}{$lang}{'state'}{$break}{'num'}++;
    
    if ($form ne "") {
	$worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'total'}++;
	if ($cf ne "") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'cf'} = $cf; }
	if ($gw ne "") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'gw'} = $gw; }
	if ($wordbase ne "") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'wordbase'} = $wordbase; }
	if ($pofs ne "") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'pofs'} = $pofs; }
	if ($epos ne "") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'epos'} = $epos; }
	if ($split ne "") {
	    #&writetoerror ("PossibleProblems.txt", localtime(time)."Project: ".$thisCorpus.", text ".$thisText.", ".$label.": split words.");
	    $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'splitWord'}++; } 
	if (($note ne "") && ($note ne "correction")) {
	    if ($note eq "gloss") { $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'num_gloss'}++; }
	    $worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'note'}{$note}{'num'}++;
	    }
	
	if ($note eq "") {
	    &abstractWorddata(\%{$worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}}, $break, $writtenWord, $label);
	}
	elsif (($note eq "correction") && ($writtenAs ne "")) {
	    &abstractWorddata(\%{$worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'wronglyWrittenAs'}{$writtenAs}}, $break, $writtenWord, $label);
	}
	else { 
	    &abstractWorddata(\%{$worddata{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'note'}{$note}}, $break, $writtenWord, $label);
	}
    }
    
    my $wordstate = substr($break, 0, length($break)-4);
    $worddata{'total'}++;
    $worddata{'total_'.$break}++;
    $worddata{$totaltype}++;
    $worddata{$totaltype.'_'.$wordstate}++;
    $worddata{'lang'}{$lang}{'total'}++;
    ##do this at the end and not on the go
    #$compilationERWords{"D_Words"}{'total'}++;
    #$compilationERWords{"D_Words"}{$totaltype}++;
    #$compilationERWords{"D_Words"}{$totaltype.'_'.$wordstate}++;
    #$compilationERWords{"D_Words"}{'lang'}{$lang}{'total'}++;
    #$compilationERWords{"D_Words"}{'total_'.$break}++;
    #$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'total'}++;
    #$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'state'}{$break}{'num'}++;
    #$compilationERWords{"D_Words"}{'lang'}{$lang}{'state'}{$break}{'num'}++;
    #
#    if ($form ne "") {
#	$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'total'}++;
#	if ($cf ne "") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'cf'} = $cf; }
#	if ($gw ne "") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'gw'} = $gw; }
#	if ($wordbase ne "") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'wordbase'} = $wordbase; }
#	if ($pofs ne "") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'pofs'} = $pofs; }
#	if ($epos ne "") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'epos'} = $epos; }
#	if ($split ne "") {
#	    $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'splitWord'}++; } 
#	if (($note ne "") && ($note ne "correction")) {
#	    if ($note eq "gloss") { $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'num_gloss'}++; }
#	    $compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'note'}{$note}{'num'}++;
#	    }
#	
#	if ($note eq "") {
#	    &abstractWorddata(\%{$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}}, $break, $writtenWord, $label);
#	}
#	elsif (($note eq "correction") && ($writtenAs ne "")) {
#	    &abstractWorddata(\%{$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'wronglyWrittenAs'}{$writtenAs}}, $break, $writtenWord, $label);
#	}
#	else { 
#	    &abstractWorddata(\%{$compilationERWords{"D_Words"}{'lang'}{$lang}{'wordtype'}{$wordtype}{'form'}{$form}{'note'}{$note}}, $break, $writtenWord, $label);
#	}
#    }
    

    &CHUNKER::generic::writetoerror("timestamping","saveWord - ending ".localtime);
}

sub abstractWorddata{ 
    my $data = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $shortlabel = shift;
    &CHUNKER::generic::writetoerror("timestamping","abstractWorddata - starting ".localtime);
    
    my $label = $thisText." ".$shortlabel;
    
    if ($break eq "damaged") {
	$data->{'break'}{$break}{'writtenform'}{$writtenWord}{'num'}++;
	push (@{$data->{'break'}{$break}{'writtenform'}{$writtenWord}{'line'}}, $label);
    }
    else {
	push (@{$data->{'break'}{$break}{'line'}}, $label);
    }
    $data->{'break'}{$break}{'num'}++;
    &CHUNKER::generic::writetoerror("timestamping","abstractWorddata - ending ".localtime);
}




sub listCombos { # Chris: how can I get the root structure saved in combos ????
    my $root = shift;
    my $label = shift;
    my $realLabel = $thisCorpus.".".$thisText." ".$label;
    
    &CHUNKER::generic::writetoerror("timestamping","listCombos - starting ".localtime);
    #TODO  my $clone = $root->sprint; # TODO
    #$clone = unescape($clone);
    #push (@{$combos{"combo"}}, unescape($clone)); still needs to be unescaped! 
    
    #push (@{$clone->{'label'}}, $realLabel);
    #
    #
    &CHUNKER::generic::writetoerror("timestamping","listCombos - ending ".localtime);
}




1;
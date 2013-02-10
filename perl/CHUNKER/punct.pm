package CHUNKER::punct;

use strict;
use CHUNKER::Borger;
use Data::Dumper;
use XML::Twig::XPath;
use XML::Simple;
use Scalar::Util qw(looks_like_number);
use utf8;

my %signsData = ();
my $thisCorpus = "";
my $thisText = "";

sub initialise{
    $thisCorpus = shift;
    $thisText = shift;
    %signsData = ();
    $signsData{'lang'} = ();
}

sub returnPunct {
    return \%signsData;
}

sub savePunct { 
    my $sign = shift;
    my $break = shift;
    my $lang = shift;
    my $label = shift;
    my $ditto = shift || ""; # ditto or excised?
    my $cf = shift || "";
    my $gw = shift || "";
    my $category = "punct";
    
    &CHUNKER::generic::writetoerror("timestamping","savePunct - starting ".localtime);
    
    $lang = CHUNKER::generic::langmatrix($lang);
    
    &CHUNKER::Borger::saveBorger($lang, $category, $sign, "", "", "", "", "", "", "alone", "", $break, $label, $cf, "", "Punct", $gw, "", "", "");
    
    $signsData{'total'}++; # total number of signs
    $signsData{"total_".$break}++;
    #$$signsData{"ztotal_state"}{$break}{'total'}++;
    $signsData{'lang'}[0]{$lang}{'total'}++; # total number of signs per language
    $signsData{'lang'}[0]{$lang}{"total_".$break}++;
    #$signsData{'lang'}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
    #$signsData{'lang'}{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
    if ($ditto eq "") {
	push (@{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"value"}{$sign}{"state"}{$break}{"line"}}, $label);
    }
    else { # as gw can be a bit nonsensical (esp. if existing of several words), I'm not yet including it. Don't yet know if there's any need. Maybe check again later ***
	push (@{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"value"}{$sign}{$ditto}{$cf}{"state"}{$break}{"line"}}, $label);
    }
    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{'All_attested'}++;
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{'Punct_attested'}++;
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"value"}{$sign}{'All_attested'}++;
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"value"}{$sign}{'Punct_attested'}++;
    }
    
#    can do $compilationERSigns at the end rather than on the go
#    my $PQ = substr($thisText, 0, 1);
#    #$compilationERSigns{"B_Signs"}{'total'}++; # total number of signs
#    #$compilationERSigns{"B_Signs"}{"ztotal_state"}{$break}{'total'}++;
#    $compilationERSigns{$PQ}{'lang'}{$lang}{'total'}++; # total number of signs per language
#    $compilationERSigns{$PQ}{'lang'}{$lang}{"total_".$break}++;
#    #$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
#    #$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
#    if ($ditto eq "") {
#	push (@{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{"state"}{$break}{"line"}}, $label);
#	}
#    else { # as gw can be a bit nonsensical (esp. if existing of several words), I'm not yet including it. Don't yet know if there's any need. Maybe check again later ***
#	push (@{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{$ditto}{$cf}{"state"}{$break}{"line"}}, $label);
#    }
#    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{'All_attested'}++;
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{'Punct_attested'}++;
#       $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{'All_attested'}++;
#       $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{'Punct_attested'}++;
#    }

    
#    $compilationERSigns{"B_Signs"}{'lang'}{$lang}{'total'}++; # total number of signs per language
#    $compilationERSigns{"B_Signs"}{'lang'}{$lang}{"state"}{$break}{'total'}++;
#    $compilationERSigns{"B_Signs"}{'lang'}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
#    $compilationERSigns{"B_Signs"}{'lang'}{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
#    if ($ditto eq "") {
#	push (@{$compilationERSigns{"B_Signs"}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{"state"}{$break}{"line"}}, $label);
#	}
#    else { # as gw can be a bit nonsensical (esp. if existing of several words), I'm not yet including it. Don't yet know if there's any need. Maybe check again later ***
#	push (@{$compilationERSigns{"B_Signs"}{'lang'}{$lang}{"category"}{$category}{"value"}{$sign}{$ditto}{$cf}{"state"}{$break}{"line"}}, $label);
#    }
    &CHUNKER::generic::writetoerror("timestamping","savePunct - ending ".localtime);
}


sub abstractSigndata{ 
    my $data = shift;
    my $value = shift;
    my $base = shift;
    my $allo = shift;
    my $formvar = shift;
    my $modif = shift;
    my $wordtype = shift;
    my $pos = shift;
    my $gw = shift;
    my $cf = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    my $group = shift || "";
    my $for = shift || "";
    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata - starting ".localtime);
    #if ($gw eq "1") { $gw = ""; } # personal names etc.

    # An allograph, or systemic sign variant, is introduced by the tilde-prefix (~)
    # The at-sign (@) precedes each modifier
    # Form variants is the GDL name for minor differences in the construction of signs which may be of interest in analysis of a corpus for handwritings, but which are not important enough to be displayed or included in the version of the writing used for linguistic analysis. Form variants are preceded by the backslash character (\) and consist of lowercase letters and or digits.
    
    my $variantType = ""; my $variantMod = $base; # first allograph, then modifier, then formvar...
    # can be a combination!!! eg P314339
    # in form, however, the formvars are not marked. Hence I make my own form existing of the base + allograph (preceded by tilde) + modifier (preceded by at-sign) + formvar (preceded by backslash)
    if ($base ne "") {
	if ($allo ne "") { $variantType = "allograph"; $variantMod .= "~".$allo; }
	if ($modif ne "") {
	    if ($variantType ne "") { $variantType .= "_and_"; }
	    $variantType .= "modifier";
	    $variantMod .= "@".$modif;
	}
	if ($formvar ne "") {
	    if ($variantType ne "") { $variantType .= "_and_"; }
	    $variantType .= "formvar";
	    $variantMod .= "\\".$formvar;
	}
    }
    
    # add Borger info? maybe then general sign list can be made from the compilation file as long as there's no alternative
    # from here - x'es not taken into list
    # find out signname in ogsl.xml ($OgslRoot)
    if (($value ne "x") && ($value ne "X") && ($value ne ";")) { # split word with ;
	my $BorgerNo; my $BorgerVal; my $Cuneicode = "-"; my $signname = "-";
	my $basis = ($base ne "")?$base:$value;
	if (looks_like_number($basis)) {
	    $BorgerNo = "Number"; $BorgerVal = $value; 
	} 
	else {
	    my $smallValue = lc ($basis); # and convert capital tsade, shin and thet to small ones
	    $smallValue =~ s/\x{1E62}/\x{1E63}/g;
	    $smallValue =~ s/\x{0160}/\x{0161}/g;
	    $smallValue =~ s/\x{1E6C}/\x{1E6D}/g;
	    $smallValue =~ s/\@/\\@/gsi;
	    $smallValue =~ s/"//gsi;
	    
	    my $ogsls = &CHUNKER::Borger::getOgslValue($smallValue);
	    $signname = $ogsls->{'signname'};
	    $Cuneicode = $ogsls->{'cuneicode'};
	    
	    # combine with data from Borger.xml ($BorgerRoot)
	    if ($signname ne "-") {
		my $borgdata  = &CHUNKER::Borger::getBorgerValues($signname);
		
		$BorgerNo = $borgdata->{'BorgerNo'};
		$BorgerVal = $borgdata->{'BorgerVal'};
		$Cuneicode = $borgdata->{'Cuneicode'};
		
	    # save the data with each value
	    # also works on punctuation
	    }
	}
	$data->{"value"}{$basis}{"BorgerNo"} = $BorgerNo;
	$data->{"value"}{$basis}{'BorgerVal'} = $BorgerVal;
	$data->{"value"}{$basis}{'Cuneicode'} = $Cuneicode;
	$data->{"value"}{$basis}{'Signname'} = $signname;
    }
    # to here
    
    if ($base eq "") { # normal values
        $data->{"value"}{$value}{'num'}++;
	$data->{"value"}{$value}{"state"}{$break}{'num'}++;
	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	   $data->{"value"}{$value}{'All_attested'}++;
	   $data->{"value"}{$value}{$wordtype.'_attested'}++;
	   $data->{"value"}{$value}{"position"}{$pos}{'All_attested'}++;
	   $data->{"value"}{$value}{"position"}{$pos}{$wordtype.'_attested'}++;
	}
	&abstractSigndata2(\%{$data->{"value"}{$value}{"standard"}{$value}{"pos"}{$pos}{"wordtype"}{$wordtype}}, $cf, $gw, $break, $writtenWord, $label, $group, $for); 
    }
    else { # variant values; treat base as value and work with variants: allograph, modifier, formvar
	$data->{"value"}{$base}{'num'}++;
	$data->{"value"}{$base}{"state"}{$break}{'num'}++;
	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	   $data->{"value"}{$base}{'All_attested'}++;
	   $data->{"value"}{$base}{$wordtype.'_attested'}++;
	   $data->{"value"}{$base}{"position"}{$pos}{'All_attested'}++;
	   $data->{"value"}{$base}{"position"}{$pos}{$wordtype.'_attested'}++;
	}
	# variant types...: form; allo, modif and/or formvar
	&abstractSigndata2(\%{$data->{"value"}{$base}{$variantType}{$variantMod}{"pos"}{$pos}{"wordtype"}{$wordtype}}, $cf, $gw, $break, $writtenWord, $label, $group, $for); 
    }

    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata - ending ".localtime);
}

sub abstractSigndata2 {
    my $data = shift;
    my $gw = shift;
    my $cf = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $label = shift;
    my $group = shift || "";
    my $for = shift || "";
    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata2 - starting ".localtime);
    
    if ($cf eq "1") { $cf = ""; } # personal names etc.
    
    if (($gw ne "") && ($cf ne "")) { &abstractSigndata3(\%{$data->{"gw"}{$gw}{"cf"}{$cf}}, $break, $writtenWord, $label, $group, $for); }
    elsif ($gw ne "") { &abstractSigndata3(\%{$data->{"gw"}{$gw}}, $break, $writtenWord, $label, $group, $for); }
    elsif ($cf ne "") { &abstractSigndata3(\%{$data->{"cf"}{$cf}}, $break, $writtenWord, $label, $group, $for); }
    else { &abstractSigndata3(\%{$data}, $break, $writtenWord, $label, $group, $for); }
    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata2 - ending ".localtime);
}


sub abstractSigndata3{
    my $data = shift;
    my $break = shift;
    my $writtenWord = shift;
    my $shortlabel = shift;
    my $group = shift || "";
    my $for = shift || "";
    my $standsfor = "";
    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata3 - starting ".localtime);
    
    my $label = $thisText." ".$shortlabel;
    
    if ($group eq "logo") { $group = ""; }
    elsif (($group eq "correction") && ($for ne "")) { $standsfor = $for; }
    
    if ($group eq "") {
	$data->{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'state'}{$break}{"line"}}, $label); }
    }
    elsif ($standsfor ne "") {
	$data->{'standsFor'}{$standsfor}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'standsFor'}{$standsfor}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'standsFor'}{$standsfor}{'state'}{$break}{"line"}}, $label); }
    }
    elsif ($group eq "reordering") {
	$data->{'group'}{$group}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'group'}{$group}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'group'}{$group}{'state'}{$break}{"line"}}, $label); }
    }
    else { # ??
	$data->{'group'}{$group}{'state'}{$break}{'num'}++;
	if ($writtenWord ne "") { push(@{$data->{'group'}{$group}{'state'}{$break}{"writtenWord"}{$writtenWord}{"line"}}, $label); }
	else { push(@{$data->{'group'}{$group}{'state'}{$break}{"line"}}, $label); }
    }

    &CHUNKER::generic::writetoerror("timestamping","abstractSigndata3 - ending ".localtime);
}

sub saveSigns {
    my $allWordData = shift;
    my @arrayWord = @{$_[0]};
    &CHUNKER::generic::writetoerror("timestamping","saveSigns - starting ".localtime);

    my $writtenWord = $allWordData->{"word"}->{"written"}?$allWordData->{"word"}->{"written"}:"";
    my $cf = $allWordData->{"word"}->{"cf"}?$allWordData->{"word"}->{"cf"}:"";
    my $form = $allWordData->{"word"}->{"form"}?$allWordData->{"word"}->{"form"}:"";
    my $lang = $allWordData->{"word"}->{"lang"}?$allWordData->{"word"}->{"lang"}:"noLang";
    my $no_signs = $allWordData->{"word"}->{"no_signs"}?$allWordData->{"word"}->{"no_signs"}:0;
    my $label = $allWordData->{"word"}->{"label"}?$allWordData->{"word"}->{"label"}:"";
    my $wordtype = $allWordData->{"word"}->{"wordtype"}?$allWordData->{"word"}->{"wordtype"}:"";
    my $wordbase = $allWordData->{"word"}->{"wordbase"}?$allWordData->{"word"}->{"wordbase"}:"";
    my $conditionWord = $allWordData->{"word"}->{"conditionWord"}?$allWordData->{"word"}->{"conditionWord"}:"";
    
    my $gw = $allWordData->{"word"}->{"gw"}?$allWordData->{"word"}->{"gw"}:""; 
    my $category = "";
    
    if ($form =~ m|^\$|gsi) { $category = "uncertainReading"; }
    
    my $group = ""; my $for = "";
    # Greta: what happens to unclear readings? $BA etc.? not marked in SAAo - ask Mikko *** TODO
    # TODO: logographic suffixes ***
    foreach my $sign (@arrayWord) {
	if ($category eq "") { $category = $sign->{'tag'}?$sign->{'tag'}:"unknown"; }
	
	my $condition = $sign->{'status'}?$sign->{'status'}:"";
	my $break = $sign->{'break'}?$sign->{'break'}:""; 
	if (($condition ne "erased") && ($condition ne "excised") && ($condition ne "supplied") && ($condition ne "implied")) {
	    if ($break eq "missing") { $condition = "missing"; }
	    elsif (($break eq "damaged") || ($condition eq "maybe")) { $condition = "damaged"; }
	    else { $condition = "preserved"; }
	}
	
	my $value = $sign->{'value'}; my $pos = $sign->{'pos'}; my $position = $sign->{'position'};
	my $role = $sign->{'type'}?$sign->{'type'}:""; # semantic or phonetic
	my $prePost = $sign->{'prePost'}?$sign->{'prePost'}:""; # pre or post-position
	my $base = $sign->{'base'}?$sign->{'base'}:""; # baseform if present
	my $allo = $sign->{'allograph'}?$sign->{'allograph'}:""; # variant forms if present
	my $formvar = $sign->{'formvar'}?$sign->{'formvar'}:"";
	my $modif = $sign->{'modifier'}?$sign->{'modifier'}:"";
	
	$group = $sign->{'group'}?$sign->{'group'}:"";
	$for = $sign->{'for'}?$sign->{'for'}:"";
	
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
		$syllables{"CVC"} = 1; $syllables{"CVCV"} = 1; # taken out, maybe better to treat them together in chart program 
		$syllables{"VCV"} = 1; 
		# I'd like to treat CVCV and VCV together with CVC and VC to avoid confusion (then there won't be too much problem with the differing opinions of scholars).
		# Moreover, on CVC instead of CVCV in NA, cf. HŠmeen-Anttila par. 1.2.1

		my $tempvalue = $sign->{'base'}?$sign->{'base'}:$value;
		
		$syllabic = lc($tempvalue);
		
		# determine what kind of syllabic sign we're dealing with: V, CV, VC, VCV, CVC, CVCV, other (ana/ina/arba/CVCV)
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
	    
		#if (($syllabic eq "CVCV") && (substr($tempvalue, 1, 1) eq substr($tempvalue, 3, 1))){  
		#    $syllabic = "CVC";
		#    #print "\nCVCV: ".$tempvalue;
		#}
		#
		#if (($syllabic eq "VCV") && (substr($tempvalue, 0, 1) eq substr($tempvalue, 2, 1))){ 
		#    if ($tempvalue ne "ana") { $syllabic = "VC"; }
		#    #print "\nVCV".$tempvalue;
		## check IGI as ini ***  cf. HŠmeen-Anttila
		#}
		
		if ($role eq "semantic") { $syllabic = ""; $category = "determinative"; }
		elsif ($role eq "phonetic") { $category = "phonetic"; }
		
		elsif (!($syllables{$syllabic})) { 
		    if ($syllabic eq "C") {
			if (($tempvalue eq "d") || ($tempvalue eq "m") || ($tempvalue eq "f")) { $category = "determinative"; $syllabic = ""; }
			else { $category = "x"; $syllabic = ""; } # then the value should be x, so unreadable sign, treat as "x"
		    } 
		    else { $category = "syllabic"; $syllabic = "other"; }
			#&writetoerror ("PossibleProblems.txt", localtime."Project: ".$thisCorpus.", text ".$thisText.": other syllabic value ".$value); }
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
	    elsif ($role eq "phonetic") { $category = "phonetic"; }
	    elsif ($category eq 'g:s') { $category = "logogram"; }
        }
        else {
	# TODO different languages ***
        }
    
	if ($category ne "") {
	    &saveSign($lang, $category, $value, $base, $allo, $formvar, $modif, $role, $prePost, $position, $syllabic, $condition, $label, $cf, $writtenWord, $wordtype, $gw, $wordbase, $group, $for);
	}
    if ($category ne "uncertainReading") { $category = ""; }
    }

    &CHUNKER::generic::writetoerror("timestamping","saveSigns - ending ".localtime);
}

sub saveSign { 
    my $lang = shift || "unknown";
    my $category = shift;
    my $value = shift;
    my $base = shift;
    my $allo = shift;
    my $formvar = shift;
    my $modif = shift;
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
    my $wordbase = shift;
    my $group = shift || "";
    my $for = shift || "";
    my %temp = ();

    &CHUNKER::generic::writetoerror("timestamping","saveSign - starting ".localtime);
    $lang = CHUNKER::generic::langmatrix($lang);

    if($lang eq ""){ $lang = "noLang"; }
    if ($role eq "semantic") { $category = "determinative"; }

    &CHUNKER::Borger::saveBorger($lang, $category, $value, $base, $allo, $formvar, $modif, $role, $prePost, $pos, $syllabic, $break, $label, $cf, $writtenWord, $wordtype, $gw, $wordbase, $group, $for);
    
    $signsData{'total'}++; # total number of signs
    $signsData{"total_".$break}++;
    $signsData{'lang'}[0]{$lang}{'total'}++; # total number of signs per language
    $signsData{'lang'}[0]{$lang}{"total_".$break}++;
    #$signsData{'lang'}[0]{$lang}{"zlang_total_wordtype"}{$wordtype}{'total'}++;
    #$signsData{'lang'}[0]{$lang}{"zlang_total_wordtype"}{$wordtype}{'state'}{$break}{'num'}++;
    $signsData{'lang'}[0]{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	   $signsData{'lang'}[0]{$lang}{"category"}{$category}{'All_attested'}++;
	   $signsData{'lang'}[0]{$lang}{"category"}{$category}{$wordtype.'_attested'}++;
	}
    
    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
    
    if (($category eq "syllabic") && ($syllabic ne "")) {
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"type"}{$syllabic}{'total'}++; # total number of signs
        if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"type"}{$syllabic}{'All_attested'}++;
	    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"type"}{$syllabic}{$wordtype.'_attested'}++;
	}
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"type"}{$syllabic}{"state"}{$break}{'num'}++;
	&CHUNKER::punct::abstractSigndata(\%{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"type"}{$syllabic}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
    }
    elsif (($role eq "semantic") || ($role eq "phonetic")) {
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"total"}++;
	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
	    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"All_attested"}++;
	    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{$wordtype.'_attested'}++;
    	}
	if ($syllabic ne "") {
	    $signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{"state"}{$break}{"num"}++;
	    &abstractSigndata(\%{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
	    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
		$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{"All_attested"}++;
		$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{$wordtype.'_attested'}++;
	    }
        }
        else {
          &abstractSigndata(\%{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
        }
	$signsData{'lang'}[0]{$lang}{"category"}{$category}{"prePost"}{$prePost}{"state"}{$break}{"num"}++;
    }
    else {
	# wordbase only here if Sumerian
	if (($wordbase eq "") || ($category eq "nonbase")) { &abstractSigndata(\%{$signsData{'lang'}[0]{$lang}{"category"}{$category}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
	else { &abstractSigndata(\%{$signsData{'lang'}[0]{$lang}{"category"}{$category}{"wordbase"}{$wordbase}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
    }
    
    #$compilationERSigns{"B_Signs"}{'total'}++; # total number of signs
    #$compilationERSigns{"B_Signs"}{"ztotal_state"}{$break}{'total'}++;
    # Note: {"B_Signs"} consistently replaced by {$PQ}
    
    
##    do this after we have done all the files rather than whilst we do all the files
#    my $PQ = substr($thisText, 0, 1);
#    $compilationERSigns{$PQ}{'lang'}{$lang}{'total'}++; # total number of signs per language
#    $compilationERSigns{$PQ}{'lang'}{$lang}{"total_".$break}++;
#    #$compilationERSigns{$PQ}{'lang'}{$lang}{"zlang_total_wordtype"}{$wordtype}{'total'}++;
#    #$compilationERSigns{$PQ}{'lang'}{$lang}{"zlang_total_wordtype"}{$wordtype}{'state'}{$break}{'num'}++;
#    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{'total'}++; # total number of signs per language and category
#    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
#	   $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{'All_attested'}++;
#	   $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{$wordtype.'_attested'}++;
#	}
#    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"state"}{$break}{'num'}++;
#    
#    if (($category eq "syllabic") && ($syllabic ne "")) {
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"type"}{$syllabic}{'total'}++; # total number of signs
#        if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
#	    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"type"}{$syllabic}{'All_attested'}++;
#	    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"type"}{$syllabic}{$wordtype.'_attested'}++;
#	}
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"type"}{$syllabic}{"state"}{$break}{'num'}++;
#	&abstractSigndata(\%{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"type"}{$syllabic}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
#    }
#    elsif (($role eq "semantic") || ($role eq "phonetic")) {
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"total"}++;
#	if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
#	    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"All_attested"}++;
#	    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{$wordtype.'_attested'}++;
#    	}
#	$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"state"}{$break}{"num"}++;
#	if ($syllabic ne "") {
#	    $compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{"state"}{$break}{"num"}++;
#	    if (($break eq "preserved") || ($break eq "damaged") || ($break eq "excised")) {
#		$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{"All_attested"}++;
#		$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}{$wordtype.'_attested'}++;
#	    }
#	    &abstractSigndata(\%{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}{"type"}{$syllabic}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
#        }
#        else {
#	    &abstractSigndata(\%{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"prePost"}{$prePost}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for);
#        }
#    }
#    else {
#	# wordbase only here if Sumerian
#	if (($wordbase eq "") || ($category eq "nonbase")) { &abstractSigndata(\%{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
#	else { &abstractSigndata(\%{$compilationERSigns{$PQ}{'lang'}{$lang}{"category"}{$category}{"wordbase"}{$wordbase}}, $value, $base, $allo, $formvar, $modif, $wordtype, $pos, $gw, $cf, $break, $writtenWord, $label, $group, $for); }
#    }

    &CHUNKER::generic::writetoerror("timestamping","saveSign - ending ".localtime);
}    





1;
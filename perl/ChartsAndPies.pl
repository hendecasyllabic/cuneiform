#!/usr/bin/perl -w
use strict;
use CGI qw(:all *table *Tr *td);
use Data::Dumper;
use XML::Twig;
use XML::Simple;
use utf8;
#this fixes the wide warnings and the numbers not being sub script
binmode STDOUT, ":utf8";

#http://perlmeme.org/tutorials/cgi_script.html
#charts with http://www.highcharts.com/

# Question: is it possible to represent everything between curly brackets in superscript in html ? TODO Chris?

# with logograms:
# ? plural markers (-MESZ, -ME, -DIDLI), dual (-MIN, .2), and ditto signs distinguished somehow in Oracc? not really
# TODO: logographic suffixes ***

my $projname = "***";
my $projdir = "../dataoutNEW/";
my $ogslfile = "../resources/ogsl.xml";

my $kind = "All_attested"; # can be any of the word categories too, e.g. Numerical_attested, etc.

my @vowels = ("a", "e", "i", "u");
my @consonants = ("\x{02BE}", "b", "d", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "\x{1E63}", "\x{0161}", "t", "\x{1E6D}", "z");
my @finalconsonants = ("\x{02BE}", "b/p", "d/t/\x{1E6D}", "g/k/q", "h", "l", "m", "n", "r", "\x{0161}", "z/s/\x{1E63}");
my @finalConsonantsNoAleph = ("b/p", "d/t/\x{1E6D}", "g/k/q", "h", "l", "m", "n", "r", "\x{0161}", "z/s/\x{1E63}");
#my @finalConsonantsNoAleph = ("b", "d", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "\x{1E63}", "\x{0161}", "t", "\x{1E6D}", "z");
my @tableheaders = ("V", "CV", "CVC", "VC", "VCV", "CVC", "CVCV", "other");

my %groups = ();
my %signdata = ();
my $PQSignsRoot = "";
my $PQWordsRoot = "";

my %sylldata = (); 
my %syllsign = (); 
my %logodata = (); 
my %deterdata = (); 
my %variousSignsPerValue = ();
my %numberdata = (); # not yet, needed?
my %totals = (); # ?

#colours for the different categories in the charts
my %colours;
$colours{"logogram"} = 1; # red
$colours{"number"} = 3; # purple
$colours{"punct"} = 2; # green
$colours{"syllabic"} = 0; # blue
$colours{"uncertainReading"} = 5; # orange
$colours{"determinative"} = 7; 
$colours{"x"} = 8;
$colours{"base"} = 9;
$colours{"nonbase"} = 4;
$colours{"phonetic"} = 6;

my $tempcounter = 0;

my $logoForms = 0;
my $logoTotal = 0;
my $deterForms = 0;
my $deterTotal = 0;

my $language = "Standard_Babylonian"; #should go through many languages though ***
#my $language = "Sumerian";
my $file = $projdir."SIGNS_P_LANG_".$language.".xml";
#was a parameter passed...

if($#ARGV==2){
    my $filepath = $ARGV[0];
    my $sysdir = $ARGV[1];
    my $filename = $ARGV[2];
    $ogslfile = $sysdir."resources/ogsl.xml";
    $filename=~m|SIGNS_P_LANG_(.*).xml|;
    $language = $1;
    $projdir = $sysdir."dataoutNEW/".$filepath."/";
    
    $file = $projdir.$filename;
}
else{
    print   header({-charset => 'utf-8'}),
        start_html(
                       -title => 'Cuneiform literacy',
                       -script => [ {-language=>'javascript',
                                   -src=>"http://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js"},
				    {-language=>'javascript',
                                   -src=>"../www/js/highcharts.js"},
				    {-language=>'javascript',
                                   -src=>"../www/js/genericchart.js"}
				    ]
                       ),
}

h1('Corpus '.$projname),
h2('Language: '.$language.' with data: '.$kind),
p ('Note that only actually attested signs are taken into account (thus: preserved, damaged and excised signs); missing, supplied, implied, maybe and erased signs are not.');
h1('Corpus');
# P_LANG_...xml; Q_LANG_...xml TODO

#&getGlobalSignData($projdir."SIGNS_P_global.xml");
#&compileSignData;
#&getSigns($projdir."SIGNS_P_LANG_akk.xml");
#&getWords($projdir."WORDS_P_LANG_akk.xml");

#&getGlobalWordData($projdir."WORDS_P_global.xml"); # TODO: generate global file
  
my $twigCat = XML::Twig->new(
			    twig_roots => { 'category' => 1 }
			    );
$twigCat->parsefile($file);
my $CatRoot = $twigCat->root;
$twigCat->purge;

my $twigType = XML::Twig->new(
				twig_roots => { 'type' => 1 }
				);
$twigType->parsefile($file);
my $TypeRoot = $twigType->root;
$twigType->purge;

# for each language... TODO
# all languages at the moment in CompilationSigns and CompilationWords!!!
my @data;	#create an array of stuff
push(@data, &makeCategoryDonut($CatRoot, $kind));
push(@data, &makeSignsPerCategoryDonut($CatRoot, $kind));
push(@data, &makeLogogramChart($CatRoot, $kind));
push(@data, &makeDeterminativeChart($CatRoot, $kind));

foreach my $i (@data){
    print $i->{'script'};
}

foreach my $i (@data){
    print "<div class='piechart'>";
    print h2($i->{'h2'});
    print $i->{'div'};
    print "</div>";
}

print "\n <script> \$(document).ready(function() {";
foreach my $i (@data){
    print $i->{'onready'};
}
print "\n }); </script>";

    #$data{'h2'} =  "\nDeterminative sign use";
    #$data{'div'} = "\n<div id='container4' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    #$data{'script'} = $pielogo;
    #$data{'onready'} = $pieready;
    
&prepareSyllabicTable($CatRoot, $kind);
&printSyllabicTables($kind);
&makePhoneticList($CatRoot, $kind);

#
#&makeCategoryDonut($CatRoot);
#&makeSignsPerCategoryDonut($CatRoot);
#&makeSyllabicTable($file);

	#p({-style => 'text-indent:50px' },'- '.$preservedwords.' fully preserved words;'),
	#p({-style => 'text-indent:50px' },'- '.$damagedwords.' partially preserved words;'),
	#p({-style => 'text-indent:50px' },'- '.$missingwords.' restored words.'),
	#p('Disregarding the restored signs, '.$signcount.' signs are attested with '.$valuecount.' readings.');

sub getGlobalWordData {
    my $globalWords = shift;
    
    my $twigObjWords = XML::Twig->new();
    $twigObjWords->parsefile($globalWords);
    my $globalWordsRoot = $twigObjWords->root;
    $twigObjWords->purge;
    
    my $total = ($globalWordsRoot->get_xpath('Words'))[0]->{att}->{'total'};
    my @languages = $globalWordsRoot->get_xpath('Words/lang');
    my $no_lang = scalar (@languages);
    
    if ($no_lang == 1) {
	my $lang = $languages[0]->{att}->{name};
	print	p('The analyzed corpus comprises '.$total.' words in the '.$lang.' language/dialect.');
    }
    else {
	print p('The analyzed corpus comprises '.$total.' words in '.$no_lang.' language(s)/dialect(s):');
	foreach my $l (@languages) {
	    my $lang = $l->{att}->{name};
	    my $no_words = $l->{att}->{'total'};
	    print p({-style => 'text-indent:50px' },' - '.$no_words.' words in '.$lang);
	}		
    }

    print p('Their state of preservation: '); # TODO
    
    #my @states = $PQWordsRoot->get_xpath('lang');
}

# makeCategoryDonut charts the total number of signs per category (excluding the missing ones)
# with subdivisions for syllabic signs and determinatives
sub makeCategoryDonut {
    my $CatRoot = shift;
    my $wordtype = shift; # should be possible to do! TODO
    #print h2("\nGeneral distribution of the different categories of signs across the corpus");
    
    # prepare Donut    
    my $donut = "<script>";
    $donut .= "\n var currentdata1 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    #my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	my $totalCat = &totalNum ($cat, $wordtype);
	#print p("category ".$name." totalCat ".$totalCat);
	push(@mainCategories, $name);
	
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @catdata;
	if (($name eq "determinative") || ($name eq "phonetic")) { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p, $wordtype);
		#print p("category ".$n." totalCat ".$t);
		push(@subCategories, $n." (".$t.")");
		push(@catdata, $t);
	    }
	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p, $wordtype);
		#print p("category ".$n." totalCat ".$t);
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n." (".$t.")");
		push(@catdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &totalNum($cat, $wordtype);
	    #print p("category ".$n." totalCat ".$t);
	    push(@subCategories, $n." (".$t.")");
	    push(@catdata, $t);
	}
	
	# TODO: Question: for some reason really small categories are not printed on screen (e.g. category CVCV attested 0.02%)
	# TODO: how to get the actual numbers of attestations printed along the percentages?
	
	#if (!($colours{$name})) { print " no colour for ".$name.". "; $colours{$name} = "0";}
	
	my $writeme = "\n{   y: ".$totalCat.",";
	$writeme .= "      color: colors[".$colours{$name}."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@catdata)."],";
	$writeme .= "                   color: colors[".$colours{$name}."]";
	$writeme .= "      }";
	$writeme .= "\n  }";
    
	push(@output,$writeme);
	
	#$count++;
    }
    
    #print Dumper @output;
    
    $donut .= join(",",@output);
    $donut .= " ]";
    #$donut .= "\n; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    #$donut .= "\n makeDonut(currentdata1,'Distribution across corpus (attestations)','title2', ['".$catlist."'],'container1');";
    #$donut .= "\n });";
    $donut .= "</script>";
  
    my %data;
    $data{'h2'} =  "\nGeneral distribution of the different categories of signs across the corpus";
    $data{'div'} = "\n<div id='container1' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    $data{'script'} = $donut;
    $data{'onready'} = "\n makeDonut(currentdata1,'Distribution across corpus (attestations)','title2', ['".$catlist."'],'container1');";
    
    return \%data;
}

# calculate total minus missing ones.
sub totalNum {
    my $i = shift;
    my $wordtype = shift;
    
    # total number of signs is built up as a sum of the preserved, damaged and excised signs
    # signs that are missing, implied, supplied, maybe or erased are not considered for this analysis as they're not present on the tablet
    # OK, erased signs may still be readable, but as the scribe realised his mistake in time, they were probably not meant to be written on the tablet and are thus left out of this analysis
#    my $total = 0; #$i->{att}->{"total"}; # minus missing signs! Missing signs are not taken into account
#    my @states = $i->get_xpath('state');
#    foreach my $m (@states) {
#	my $kind = $m->{att}->{name};
#	if (($kind eq "preserved") || ($kind eq "damaged") || ($kind eq "excised")) {
#	    my $temp = 0;
#	    if ($m->{att}->{'num'}) { $temp = $m->{att}->{'num'}; }
#	    elsif ($m->{att}->{'total'}) { $temp = $m->{att}->{'total'}; }
#	    $total += $temp;
#	}
#    }

    my $total = $i->{att}->{$wordtype}?$i->{att}->{$wordtype}:0;
    return $total;    
}

# makeSignsPerCategoryDonut charts the different categories and subcategories according to the number of distinct signs in each
sub makeSignsPerCategoryDonut {
    my $CatRoot = shift;
    my $wordtype = shift; # should be possible to do! TODO
    
    #print h2("\nDistribution of the different categories and subcategories according to the number of distinct signs in each");
    
    # prepare Donut    
    #my $donut = "<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    my $donut = "<script>";
    $donut .= " var currentdata2 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    #my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	push(@mainCategories, $name);
	
	my $totalForms = 0;
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @signsPerCatdata;
	
	if (($name eq "determinative") || ($name eq "phonetic")) { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p, $wordtype);
		$totalForms += $t;
		push(@subCategories, $n." (".$t.")");
		push(@signsPerCatdata, $t);
		if ($name eq "determinative") { $deterForms += $totalForms; }
	    }
	    if ($name eq "determinative") {
		$deterTotal = &totalNum($cat, $wordtype);
		#print p("category ".$name." deterTotal ".$deterTotal);
	    }
    	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p, $wordtype);
		$totalForms += $t;
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n." (".$t.")");
		push(@signsPerCatdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &diffForms($cat, $wordtype);
	    $totalForms += $t;
	    push(@subCategories, $n." (".$t.")");
	    push(@signsPerCatdata, $t);
	    if ($name eq "logogram") {
		$logoForms = $totalForms;
		$logoTotal = &totalNum($cat, $wordtype);
		#print p("category ".$name." totalCat ".$logoTotal);
		#print ("\n Logograms: total = ".$logoTotal." diff forms = ".$logoForms);
	    }
	}
	
	#if (!($colours{$name})) { print " no colour for ".$name.". "; $colours{$name} = "0";}
	
	my $writeme = "{   y: ".$totalForms.",";
	$writeme .= "      color: colors[".$colours{$name}."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@signsPerCatdata)."],";
	$writeme .= "                   color: colors[".$colours{$name}."]";
	$writeme .= "      }";
	$writeme .= "  }";
	   
	push(@output,$writeme);
	
	#$count++;
    }
    
    $donut .= join(",",@output);
    $donut .= " ]";
    #$donut .= "; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    #$donut .= " makeDonut(currentdata2,'Distribution across corpus (categories)','title2', ['".$catlist."'],'container2');";
    #$donut .= "});";
    $donut .= "</script>";

  
    my %data;
    $data{'h2'} =  "\nDistribution of the different categories and subcategories according to the number of distinct signs in each";
    $data{'div'} = "\n<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    $data{'script'} = $donut;
    $data{'onready'} = "\n makeDonut(currentdata2,'Distribution across corpus (categories)','title2', ['".$catlist."'],'container2');";
    
    return \%data;
    #print $donut;
}

sub diffForms {
    my $i = shift;
    my $wordtype = shift;
    
    my $temp = $i->{att}->{name};
    
    my $no_forms = 0;
    my @forms = $i->get_xpath("value");
    #print p("\nTime: ".localtime); 
    foreach my $f (@forms) {
	if ($f->{att}->{$wordtype}) { $no_forms++; }
    }
    #print p("\nCategory ".$temp." no_forms ".$no_forms);
    return $no_forms;
}

# everything by PN, GN, etc.

sub makeLogogramChart {
    my $LogoRoot = shift;
    my $wordtype = shift; 

    my $logograms = ($LogoRoot->get_xpath('category[@name="logogram"]'))[0];
    if($LogoRoot->get_xpath('category[@name="logogram"]')){
	my @values = $logograms->get_xpath('value');
	foreach my $v (@values) {
	    my $test = $v->{att}->{$wordtype}?$v->{att}->{$wordtype}:"no";
	    if ($test ne "no") {
		my $value = $v->{att}->{name};
		my $number = $test;
		push(@{$logodata{"num"}{$number}{"value"}}, $value);
	    }
	}    
    }
        
    #print h1('Logographic sign use');

    #my $pielogo = "<div id='container5' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    my $pielogo = "<script>";
    $pielogo .= " var currentdata3 = [";

    my $i = 0;
    my $rest = $logoTotal;
    my $remlogo = $logoForms;
    
    foreach my $n (sort { $b <=> $a } keys %{$logodata{"num"}}) {
        if (($i < 10) && ($rest > 0)) {
	    foreach my $s (@{$logodata{"num"}{$n}{"value"}}) {
		#print p($s." ".$n);
		$i++;
	    $pielogo .= " ['"."$s"." (".$n.")"."',   ".$n."],";
	    $rest -= $n;
	    }
	}
    }
    $remlogo -= ($i + 1);
    if ($remlogo > 0) { $pielogo .= " ['Remaining ".$remlogo." logogram(s) (".$rest.")"."',   ".$rest."],"; }

    $pielogo = substr($pielogo,0,length($pielogo)-1);
    $pielogo .= " ];";

    my $pieready = "";
    $pieready .= "   var alldata3 = pieoptions;";
    $pieready .= "   alldata3.chart.renderTo = 'container5';"; 
    $pieready .= "   alldata3.title.text = 'Logographic distribution across corpus';";
    $pieready .= "   alldata3.series[0].data = currentdata3;";
    $pieready .= "	chart3 = new Highcharts.Chart(alldata3);";
    
    $pielogo .= "</script>";

    my %data;
    $data{'h2'} =  "\nLogographic sign use";
    $data{'div'} = "\n<div id='container5' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    $data{'script'} = $pielogo;
    $data{'onready'} = $pieready;
    
    return \%data;
    
    #print $pielogo;
}

sub makeDeterminativeChart {
    my $DetRoot = shift;
    my $wordtype = shift; 

    my $determinatives = ($DetRoot->get_xpath('category[@name="determinative"]'))[0];
    if($determinatives){
	my @prePosts = $determinatives->get_xpath('prePost');
	foreach my $p (@prePosts) {
	    my @values = $p->get_xpath('value');
	    foreach my $v (@values) {
		my $test = $v->{att}->{$wordtype}?$v->{att}->{$wordtype}:0;
		if ($test > 0) {
		    my $value = $v->{att}->{name};
		    my $number = $test;
		    push(@{$deterdata{"num"}{$number}{"value"}}, $value);
		}
	    }
	}
    }
        
    #print h1('Determinative sign use');
#<div id='container4' style='min-width: 400px; height: 400px; margin: 0 auto'></div>
    my $pielogo = "\n<script>";
    $pielogo .= "\n var currentdata4 = [  ";

    my $i = 0;
    my $rest = $deterTotal;
    my $remdeter = $deterForms;
    
    foreach my $n (sort { $b <=> $a } keys %{$deterdata{"num"}}) {
        if (($i < 10) && ($rest > 0)) {
	    foreach my $s (@{$deterdata{"num"}{$n}{"value"}}) {
		#print p("determinative ".$s." ".$n);
		$i++;
		$pielogo .= " ['"."$s"." (".$n.")"."',   ".$n."],";
		$rest -= $n;
	    }
	}
    }
    $remdeter -= ($i + 1);
    if ($remdeter > 0) { $pielogo .= "\n ['Remaining ".$remdeter." determinative(s) (".$rest.")"."',   ".$rest."],"; }

    $pielogo = substr($pielogo,0,length($pielogo)-1);
    $pielogo .= " ];";

    my $pieready = "\n   var alldata4 = pieoptions;";
    $pieready .= "\n   alldata4.chart.renderTo = 'container4';"; 
    $pieready .= "\n   alldata4.title.text = 'Determinative distribution across corpus';";
    $pieready .= "\n   alldata4.series[0].data = currentdata4;";
    $pieready .= "\n	chart4 = new Highcharts.Chart(alldata4);";
    $pielogo .= "</script>";

    my %data;
    $data{'h2'} =  "\nDeterminative sign use";
    $data{'div'} = "\n<div id='container4' style='min-width: 400px; height: 400px; margin: 0 auto'></div>";
    $data{'script'} = $pielogo;
    $data{'onready'} = $pieready;
    
    return \%data;
    #print $pielogo;
}


sub prepareSyllabicTable {
    my $CatRoot = shift;
    my $wordtype = shift; 
    
    my @categories = $CatRoot->get_xpath('category');
    my @types = ("V", "CV", "VC", "VCV", "CVC", "CVCV", "other");
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	if ($name eq "syllabic") {
	    # make tables of all types of syllabic values in the order given in @types
	    my @typesSyll = $cat->get_xpath('type');
	    foreach my $t (@typesSyll) {
		my $type = $t->{att}->{name};
		my @values = $t->get_xpath('value');
		foreach my $i (@values) {
		    if ($i->{att}->{$wordtype}) {
			# put values in table 
			my $value = $i->{att}->{'name'};
			my $syllable = $value; # without index number and without distinction of I and E in CV and CVC(V)
			# nuke the subscripts like numbers (unicode 2080 - 2089) 
			$syllable =~ s|(\x{2080})||g; $syllable =~ s|(\x{2081})||g; $syllable =~ s|(\x{2082})||g; $syllable =~ s|(\x{2083})||g; $syllable =~ s|(\x{2084})||g;
			$syllable =~ s|(\x{2085})||g; $syllable =~ s|(\x{2086})||g; $syllable =~ s|(\x{2087})||g; $syllable =~ s|(\x{2088})||g; $syllable =~ s|(\x{2089})||g;
			$syllable =~ s|(\x{2093})||g; # subscript x
			if (($type eq "CV") || ($type eq "CVC") || ($type eq "CVCV")) { $syllable =~ s/[ie]/I/gsi; }
			my $first = substr($value, 0, 1);
			my $second = (length($type)>=2)?substr($value,1,1):"";
			my $third = (length($type)>=3)?substr($value,2,1):"";
			my $fourth = (length($type)>=4)?substr($value,3,1):"";
			if (length($type)<=4) { push(@{$sylldata{$type}{$first.$second.$third.$fourth}},$value); }
			else { push(@{$sylldata{$type}{$value}},$value); }
			#my $cunname = $signdata{$value};
			#print $cunhex;
			#push(@{$syllsign{$type}{"sign"}{$cunname}{"value"}},$value);
			push (@{$variousSignsPerValue{$type}{"syllable"}{$syllable}{"value"}}, $value);
			my $tempvalue = '//type[@name="'.$type.'"]'; 
			#my $node = ($cat->get_xpath($tempvalue))[0];
			#if ($node){
			#    #print p('tempvalue = '.$tempvalue);
			#    my @values = $node->get_xpath('value');
			#    foreach my $i (@values) {
			#	my $v = $i->{att}->{name};
			#	print p ('value = '.$v);
			#	my $test = $i->{att}->{$wordtype}?$i->{att}->{$wordtype}:"no";
			#	if ($test ne "no") {
			#	    &findAttestations($file, $wordtype, "syllabic", "", $type, $v);
			#	    # put value in table - make hash TODO HIER
			#        }
			#    }
			#}
		    }
		    
		}
	    }
	}
    }
}



sub printSyllabicTables {
    my $wordtype = shift; 
    
    my @types = ("V", "CV", "VC", "VCV", "CVC", "CVCV", "other");
    
    print h1('Syllabic sign use');

    foreach my $t (@types) {
	if ($sylldata{$t}) {
	    my @type = split("",$t);
	    my $numSyll = scalar (@type);
	    
	    my @alldata = ();
	    my @lastone = ();
	    my @lastbutone = ();
	    my $cnt = 0;
	    my $lastone = "";
	    my $string = "";
	    foreach my $j (@type){
		$string .= $j;
		$lastone = $j;
		my @tempdata = ();
		@lastbutone = ();
		if ($cnt == 0){#this is the first time around
		    if ($j eq 'C'){
			foreach my $c (@consonants){
			    push(@tempdata,$c);
			    push(@alldata,$c);
			}
		    }
		    elsif ($j eq 'V'){
		        foreach my $v (@vowels){
		            push(@tempdata,$v);
		            push(@alldata,$v);
		        }
		    }
		}
		else {
		    foreach my $key (@alldata){
			if($j eq 'C'){
			    foreach my $c (@consonants){
			        push(@tempdata,$key.$c);
			    }
			}
			elsif($j eq 'V'){
			    foreach my $v (@vowels){
			        push(@tempdata,$key.$v);
			    }
			}
		    }
		}
	
		$cnt++;
		if ($cnt == $numSyll){#this is the last but one
		    @lastbutone = @alldata;
		}
		@alldata = @tempdata;
	    }
    
	    if (($numSyll <= 3) && ($t ne "VCV")) {
		print h2($t);
	        print start_table({-border=>1, -cellpadding=>3}), start_Tr, th([$t]);
	        if ($numSyll == 1) {
		    print end_Tr;
		    foreach my $v (@vowels) {
		        print start_Tr, td($v);
		        my $string = ref($sylldata{$t}{$v}) eq 'ARRAY' ? join(", ",@{$sylldata{$t}{$v}}):" ";
		        print td([$string]);
		    }
		    print end_Tr;
		}
		else {
		    if ($lastone eq 'C'){
			if ($t eq 'CVC') {
			    foreach my $c (@finalConsonantsNoAleph){
				print th([$c]);   # still have to get rid of aleph in CVC
			    }
			}
			else {
			    foreach my $c (@finalconsonants){
				print th([$c]);   # still have to get rid of aleph in CVC
			    }    
			}
			
		    }
		    elsif ($lastone eq 'V'){
			foreach my $v (@vowels){
			    print th([$v]);
			}
		    }
		    print end_Tr;
    		    foreach my $key (@lastbutone){
		        if($lastone eq 'C'){
			    # check if there are values beginning with $key when checking CVCs, otherwise no use to print them
			    my $thereis = 0;
			    foreach my $c (@consonants){  # must be possible to do this easier
			        if (exists($sylldata{$t}{$key.$c})) {
				    $thereis++;
				}
			    }
			    if ($thereis != 0) {
			        print start_Tr, td([$key]);
				my @final = @finalconsonants;
				if ($t eq 'CVC') {
				    @final = @finalConsonantsNoAleph;
				}
				foreach my $c (@final){
				    if (length($c) == 1) {
					my $string = ref($sylldata{$t}{$key.$c}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$c}}):" ";
					print td([$string]);
				    }
				    else {
					my @letter = split("/",$c);
					my $string = "";
					foreach my $j (@letter){
					    my $temp = ref($sylldata{$t}{$key.$j}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$j}}):" ";
					    if ($temp ne " ") {
						if ($string eq "") { $string = $temp; }
						else { $string = $string."; ".$temp; }   
					    }
					}
					print td([$string]);
				}
			    }
			}
			}
			elsif ($lastone eq 'V'){
			    print start_Tr, td([$key]);
			    foreach my $v (@vowels){
			        my $string = ref($sylldata{$t}{$key.$v}) eq 'ARRAY' ?join(", ",@{$sylldata{$t}{$key.$v}}):" ";
			        print td([$string]);
			    }
			}
		    }
		    
		}
		print end_table;
	    }
	    else { # CVCV and others are given as a list instead of a table
		print h2($t);
	        foreach my $value (sort keys %{$sylldata{$t}}) {
		    print p($value);
		}
	    }
	    
	    foreach my $l (sort keys %{$variousSignsPerValue{$t}{"syllable"}}) {
		my $number = scalar @{$variousSignsPerValue{$t}{"syllable"}{$l}{"value"}};
		if ($number > 1) { # several signs used to write this syllable
		    print h4('Multiple values for:');
		    print start_table({-border=>1, -cellpadding=>3}), start_Tr, th([$l]), th(['initial']), th(['medial']), th(['final']), th(['alone']);
		    #print p("Syllable ".$l." written as ");
		    my %tempdata = ();
		    foreach my $v (@{$variousSignsPerValue{$t}{"syllable"}{$l}{"value"}}) {
			&findPositionData($TypeRoot, $wordtype, $t, $v);
		    }
		    print end_table;
		    
		    my @positions = ("initial", "medial", "final", "alone");
		    
		    foreach my $v (@{$variousSignsPerValue{$t}{"syllable"}{$l}{"value"}}){
			print h4("Attestations of ".$v.": ");
			print start_table({-border=>1, -cellpadding=>3}), start_Tr, th(['Position']), th(['Wordtype']), th(['Guide word']), th(['Citation form']), th(['Spelling']), th(['Attestation(s)']);
			foreach my $p (@positions) {
			 #   if (defined ($variousSignsPerValue{$t}{"syllable"}{$l}{"value"}{$p} )) {
				&findPartialAttestations($CatRoot, $wordtype, "syllabic", "", $t, $v, $p);
			  #  }
			}
			print end_table;
		    }
		}
	    }
	}
    }
}

sub findPositionData {  
    my $TypeRoot = shift;
    my $wordtype = shift; 
    my $type = shift; # CV, etc.
    my $value = shift;
    
    my @positions = ("initial", "medial", "final", "alone");
    
    my @start = $TypeRoot->get_xpath('type');
    my %data = ();
    
    print start_Tr, td([$value]);
    foreach my $s (@start) {
	if ($s->{att}->{name} eq $type) {
	    $data{"initial"} = " "; $data{"medial"} = " "; $data{"final"} = " "; $data{"alone"} = " ";
	    my $tempvalue = 'value[@name="'.$value.'"]';
	    my $valueNode = ($s->get_xpath($tempvalue))[0]; 
	    if (defined($valueNode)) {
	        my @results = $valueNode->get_xpath('position');
	        if (scalar @results > 0) {
		    foreach my $r (@results) {
			my $position = $r->{att}->{name};
			my $total = $r->{att}->{$wordtype}?$r->{att}->{$wordtype}:" ";
			$data{$position} = $total;
			#print "Type ".$type." value ".$value." position ".$position." total ".$total;
		    }
		}
	    }
	}
    }

    foreach my $p (@positions) {
	print td([$data{$p}]);
    }
    
    #return \%data;
}


sub findPartialAttestations { # list all attestations of the value $value in position $position
    my $FileRoot = shift;
    my $wordtype = shift;
    my $category = shift;
    my $prePost = shift; # can be empty (only used for determinative and phonetic)
    my $type = shift; # can be empty (used for syllabic and phonetic)
    my $value = shift; # should always be given
    my $position = shift; # should always be given
    
    my $tempvalue = 'category[@name="'.$category.'"]';
    my @root = $FileRoot->get_xpath($tempvalue);
    my $node = $root[0];
    if ($prePost ne "") {
	$tempvalue = $tempvalue = 'prePost[@name="'.$prePost.'"]';
	$node = ($node->get_xpath($tempvalue))[0]; # there should only be one pre or post in determinative and phonetic
    }
    if ($type ne "") {
	$tempvalue = 'type[@name="'.$type.'"]';
	$node = ($node->get_xpath($tempvalue))[0];
    }
    $tempvalue = 'value[@name="'.$value.'"]';
    $node = ($node->get_xpath($tempvalue))[0];
    
    #my $numberattested = $node->{att}->{'All_attested'};
    #print p('Category = '.$category.'; prePost = '.$prePost.'; type = '.$type.'; value = '.$value.'; All attested = '.$numberattested);
    #print p('Position = '.$position);

    # check if attested for wanted wordtype in this position    
    $tempvalue = 'position[@name="'.$position.'"]';
    my @tempnode = $node->get_xpath($tempvalue);
    if (scalar @tempnode > 0) {
	my $test = $tempnode[0]->{att}->{$wordtype};
	#print p($wordtype." = ".$test);
	if ($test > 0) {
	    #if ($test < 21) { # now really list attestations, starting from $node again
		$tempvalue = './/pos[@name="'.$position.'"]';
		my @atts = $node->get_xpath($tempvalue);
		foreach my $a (@atts) {
		    my $kind = substr($wordtype, 0, length($wordtype)-9);
		    #print p('kind = '.$kind);
		    if ($kind ne "All") { $tempvalue = './/wordtype[@name="'.$kind.'"]'; }
		    else { $tempvalue = './/wordtype'; }
		    my @wtypes = $a->get_xpath($tempvalue);
		    foreach my $wt (@wtypes) {
			my $wtype = $wt->{att}->{name};
			#print p($wtype);
			my @gws = $wt->get_xpath('.//gw');
			my $gw = ""; my $cf = "";
					
			if (defined($gws[0])) {			    
			    foreach my $g (@gws) {
				$gw = $g->{att}->{name};
				my @cfs = $g->get_xpath("cf");
				if (defined($cfs[0])) {
				    foreach my $c (@cfs) { # gw and cf
					$cf = $c->{att}->{name};
					&attestationsStates ($c, $prePost, $position, $wtype, $gw, $cf);
				    }
				}
				else { &attestationsStates ($g, $prePost, $position, $wtype, $gw, ""); } #gw, but no cf
			    }
			}
			else { # no gw known, possibly a cf or just the attestation
			    my @cfs = $wt->get_xpath("cf");
			    if (defined($cfs[0])) {
				foreach my $c (@cfs) {
				    $cf = $c->{att}->{name}; # cf, no gw
				    &attestationsStates ($c, $prePost, $position, $wtype, "", $cf);
				}
			    }
			    else { &attestationsStates ($wt, $prePost, $position, $wtype, "", ""); } #no gw, no cf
			}
		    }
		}
	    #}
	    #else { # common value, attested more than 20 times (this variable may have to change ***)
	    #
	    #}
	}
    }
}

sub attestationsStates {
    my $root = shift;
    my $prePost = shift;
    my $position = shift;
    my $wordtype = shift;
    my $gw = shift;
    my $cf = shift;
    
    if ($prePost ne "") { $position = $prePost; } # when pre or post is known, the position is irrelevant
    
    my @states = $root->get_xpath('state');
    foreach my $s (@states) {
	my $name = $s->{att}->{name};
	# only attested values are taken into account
	if (($name eq "preserved") || ($name eq "damaged") || ($name eq "excised")) {
	    my @written = $s->get_xpath('writtenWord');
	    my $attest;
	    my $word = "";
	    foreach my $w (@written) {
		$word = $w->{att}->{name};
		$attest = "";
		my @lines = $w->get_xpath('line');
		foreach my $l (@lines) {
		    my $temp = $l->text;
		    $attest = $attest.$temp.", ";
		}
		$attest = substr($attest, 0, length($attest)-2);
		print start_Tr, td($position), td($wordtype), td($gw), td($cf), td($word), td($attest), end_Tr;
	    }
	}
    }
}
    
sub makePhoneticList {
    my $FileRoot = shift;
    my $wordtype = shift;
    
    my $phonetics = ($FileRoot->get_xpath('category[@name="phonetic"]'))[0];
    if($phonetics){
	my @prePosts = $phonetics->get_xpath('prePost');
	my %phoneticdata = ();
	foreach my $p (@prePosts) {
	    my $pre = $p->{att}->{name};
	    my @types = $p->get_xpath('type');
	    foreach my $t (@types) {
		my @values = $t->get_xpath('value');
		my $type = $t->{att}->{name};
		foreach my $v (@values) {
		    my $test = $v->{att}->{$wordtype}?$v->{att}->{$wordtype}:0;
		    if ($test > 0) {
			my $value = $v->{att}->{name};
			#print p("value ".$value);
			#my $number = $test;
			push(@{$phoneticdata{"prePost"}{$pre}{"type"}{$type}{"value"}}, $value);
		    }
		}
	    }
	}
	
	my @positions = ("initial", "medial", "final", "alone");
    
    # alphabetically organized list of phonetic values within pre/post and CV etc.
	print h1("Phonetic complements");
	foreach my $p (keys %{$phoneticdata{"prePost"}}) {
	    print h3($p);
	    foreach my $t (sort keys %{$phoneticdata{"prePost"}{$p}{"type"}}) {
		print h3("Type ".$t);
		if($phoneticdata{"prePost"}{$p}{"type"}{$t}{"value"}){
		    
		    my @data = @{$phoneticdata{"prePost"}{$p}{"type"}{$t}{"value"}};
		    
		    foreach my $v (@data){
			print h4("Phonetic value: ".$v);  # HIER
			print start_table({-border=>1, -cellpadding=>3}), start_Tr, th(['Position']), th(['Wordtype']), th(['Guide word']), th(['Citation form']), th(['Spelling']), th(['Attestation(s)']);
			foreach my $pos (@positions) {
			    &findPartialAttestations($CatRoot, $wordtype, "phonetic", $p, $t, $v, $pos);
			}
			print end_table;
		    }
		}
	    }
	}
    }
}

sub getGlobalSignData {
    my $globalSigns = shift;
    
    my $twigObjSigns = XML::Twig->new();
    $twigObjSigns->parsefile($globalSigns);
    my $globalSignsRoot = $twigObjSigns->root;
    $twigObjSigns->purge;
    
    
    
}


sub compileSignData{
    # get signinfo from ogsl
    my $twigObjCun = XML::Twig->new();
    $twigObjCun->parsefile($ogslfile);
    my $rootCun = $twigObjCun->root;
    $twigObjCun->purge;
    
    my @signs = $rootCun->get_xpath('sign');
    foreach my $sign (@signs){
	#my @utf8 = $sign->get_xpath("utf8");
	my @unames = $sign->get_xpath("uname"); # why doesn't this work??? HIER
	my $uname = "undef";
	if (scalar (@unames) > 0) {
	    $uname = $unames[0]->text;
	}
	else {
	    $uname = $sign->{att}->{"n"};
	}
	
	#my $hex = $utf8[0]->{att}->{"hex"};
	#my $cunsign = $sign->findvalue('utf8');
	#print p($cunsign);
	my @vs = $sign->get_xpath("v");
	foreach my $thing (@vs){
	    #$signdata{$thing->{att}->{"n"}} = $hex;
	    $signdata{$thing->{att}->{"n"}} = $uname;
	}
#	print p("uname ".$uname);
    }
}

sub getSigns{
    my $filename = shift;
   
    # get data from SIGNS datafile
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    $PQSignsRoot = $twigObj->root;
    $twigObj->purge;
    
    my %alldata;
    
    my @categories = $PQSignsRoot->get_xpath('category');
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	my $tot = $cat->{att}->{'total'};
	
    }
}

sub getWords{
    my $filename = shift;
   
    # get data from SIGNS datafile
    my $twigObj = XML::Twig->new();
    $twigObj->parsefile($filename);
    $PQWordsRoot = $twigObj->root;
    $twigObj->purge;
    
    my %wordData;
}
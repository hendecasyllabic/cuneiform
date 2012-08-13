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

# with logograms:
# ? plural markers (-MESZ, -ME, -DIDLI), dual (-MIN, .2), and ditto signs distinguished somehow in Oracc? not really
# TODO: logographic suffixes ***

my $projname = "SAA ***";
my $projdir = "../dataoutNEW/";
my $ogslfile = "../resources/ogsl.xml";

my @vowels = ("a", "e", "i", "u");
my @consonants = ("\x{02BE}", "b", "d", "g", "h", "i", "k", "l", "m", "n", "p", "q", "r", "s", "\x{1E63}", "\x{0161}", "t", "\x{1E6D}", "z");
my @finalconsonants = ("\x{02BE}", "b/p", "d/t/\x{1E6D}", "g/k/q", "h", "l", "m", "n", "r", "\x{0161}", "z/s/\x{1E63}");
my @tableheaders = ("V", "CV", "CVC", "VC", "VCV", "CVC", "CVCV", "other");

my %groups = ();
my %signdata = ();
my $PQSignsRoot = "";
my $PQWordsRoot = "";

my %sylldata = ();
my %logodata = ();
my %deterdata = ();
my %numberdata = ();
my %totals = ();

# P_LANG_...xml; Q_LANG_...xml TODO

#&getGlobalSignData($projdir."SIGNS_P_global.xml");
#&compileSignData;
#&getSigns($projdir."SIGNS_P_LANG_akk.xml");
#&getWords($projdir."WORDS_P_LANG_akk.xml");

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
        h1('Corpus');

#&getGlobalWordData($projdir."WORDS_P_global.xml"); # TODO: generate global file

# for each language... TODO
# all languages at the moment in CompilationSigns and CompilationWords!!!
my $file = $projdir."SIGNS_P_LANG_Standard Babylonian.xml";
&makeCategoryDonut($file);
&makeSignsPerCategoryDonut($file);
&makeSyllabicTable($file);

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
    my $file = shift;
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;

    print h2("\nChart: General distribution of the different categories of signs across the corpus (excluding missing signs)");
    
    # prepare Donut    
    my $donut = "<div id='container1' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $donut .= " var currentdata1 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	my $totalCat = &totalNum ($cat);
	push(@mainCategories, $name);
	
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @catdata;
	if ($name eq "determinative") { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p);
		push(@subCategories, $n);
		push(@catdata, $t);
	    }
	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &totalNum($p);
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n);
		push(@catdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &totalNum($cat);
	    push(@subCategories, $n);
	    push(@catdata, $t);
	}
	
	# TODO: Question: for some reason really small categories are not printed on screen (e.g. category CVCV attested 0.02%)
	
	my $writeme = "{   y: ".$totalCat.",";
	$writeme .= "      color: colors[".$count."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@catdata)."],";
	$writeme .= "                   color: colors[".$count."]";
	$writeme .= "      }";
	$writeme .= "  }";
    
	push(@output,$writeme);
	
	$count++;
    }
    
    #print Dumper @output;
    
    $donut .= join(",",@output);
    $donut .= " ]";
    $donut .= "; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    $donut .= " makeDonut(currentdata1,'Distribution across corpus (attestations)','title2', ['".$catlist."'],'container1');";
    $donut .= "});</script>";

    print $donut;
}

# calculate total minus missing ones.
sub totalNum {
    my $i = shift;
    # total number of signs is built up as a sum of the preserved, damaged and excised signs
    # signs that are missing, implied, supplied, maybe or erased are not considered for this analysis as they're not present on the tablet
    # OK, erased signs may still be readable, but as the scribe realised his mistake in time, they were probably not meant to be written on the tablet and are thus left out of this analysis
    my $total = 0; #$i->{att}->{"total"}; # minus missing signs! Missing signs are not taken into account
    my @states = $i->get_xpath('state');
    foreach my $m (@states) {
	my $kind = $m->{att}->{name};
	if (($kind eq "preserved") || ($kind eq "damaged") || ($kind eq "excised")) {
	    my $temp = 0;
	    if ($m->{att}->{'num'}) { $temp = $m->{att}->{'num'}; }
	    elsif ($m->{att}->{'total'}) { $temp = $m->{att}->{'total'}; }
	    $total += $temp;
	}
    }
    return $total;    
}

# makeSignsPerCategoryDonut charts the different categories and subcategories according to the number of distinct signs in each
sub makeSignsPerCategoryDonut {
    my $file = shift;
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;
    
    print h2("\nChart: Distribution of the different categories and subcategories according to the number of distinct signs in each (excluding missing signs)");
    
    # prepare Donut    
    my $donut = "<div id='container2' style='min-width: 400px; height: 400px; margin: 0 auto'></div><script>";
    $donut .= " var currentdata2 = [";
    
    my @categories = $CatRoot->get_xpath('category');
    my @mainCategories;
    my $count = 0;
    my @output;
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	push(@mainCategories, $name);
	
	my $totalForms = 0;
	my @subCategories; # determinatives and syllabic signs may have subcategories
	my @signsPerCatdata;
	
	if ($name eq "determinative") { # subdivision of pre- and postdeterminatives
	    my @prePost = $cat->get_xpath('prePost');
	    foreach my $p (@prePost) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p);
		$totalForms += $t;
		push(@subCategories, $n);
		push(@signsPerCatdata, $t);
	    }
    	}
	elsif ($name eq "syllabic") { # subdivision of different syllabic categories
	    my @types = $cat->get_xpath('type');
	    foreach my $p (@types) {
		my $n = $p->{att}->{name};
		my $t = &diffForms($p);
		$totalForms += $t;
		#if ($n eq "CVCV") { print "\nCVCV = ".$t; }
		push(@subCategories, $n);
		push(@signsPerCatdata, $t);
	    }
	}
	else {
	    my $n = $cat->{att}->{name};
	    my $t = &diffForms($cat);
	    $totalForms += $t;
	    push(@subCategories, $n);
	    push(@signsPerCatdata, $t);
	}
	
	my $writeme = "{   y: ".$totalForms.",";
	$writeme .= "      color: colors[".$count."],";
	$writeme .= "          drilldown: {";
	$writeme .= "                   name: '".$cat."',";
	$writeme .= "                   categories: ['".join("','",@subCategories)."'],";
	$writeme .= "                   data: [".join(",",@signsPerCatdata)."],";
	$writeme .= "                   color: colors[".$count."]";
	$writeme .= "      }";
	$writeme .= "  }";
	   
	push(@output,$writeme);
	
	$count++;
    }
    
    $donut .= join(",",@output);
    $donut .= " ]";
    $donut .= "; \$(document).ready(function() {";
    
    my $catlist = join("','",@mainCategories);
    $donut .= " makeDonut(currentdata2,'Distribution across corpus (categories)','title2', ['".$catlist."'],'container2');";
    $donut .= "});</script>";

    print $donut;
}

sub diffForms {
    my $i = shift;
    
    my $temp = $i->{att}->{name};
    
    my $no_forms = 0;
    my @forms = $i->get_xpath("value");
    #print p("\nTime: ".localtime); 
    foreach my $f (@forms) {
	if ($f->{att}->{'there'}) { $no_forms++; }
    }
    print p("\nCategory ".$temp." no_forms ".$no_forms);
    return $no_forms;
}

sub makeSyllabicTable {
    my $file = shift;
    
    my $twigCat = XML::Twig->new(
				twig_roots => { 'category' => 1 }
				);
    $twigCat->parsefile($file);
    my $CatRoot = $twigCat->root;
    $twigCat->purge;
    
    my @categories = $CatRoot->get_xpath('category');
    my @types = ("V", "CV", "VC", "VCV", "CVC", "CVCV", "other");
    foreach my $cat (@categories) {
	my $name = $cat->{att}->{name};
	if ($name eq "syllabic") {
	    # make tables of all types of syllabic values in the order given in @types
	    foreach my $type (@types) {
		#my $tempvalue = '//l[@ref="'.$wordid.'"]/xff:f'; # /xtf:transliteration//xcl:l[@ref=$wordid]/xff:f/@cf
		my $tempvalue = '//type[@name="'.$name.'"]'; 
		my $node = $cat->get_xpath($tempvalue);
		my @values = $node->get_xpath('value');
		foreach my $i (@values) {
		    if ($i->{att}->{'there'}) {
			# put value in table - make hash TODO HIER
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
	my @utf8 = $sign->get_xpath("utf8");
	my $hex = $utf8[0]->{att}->{"hex"};
	#my $cunsign = $sign->findvalue('utf8');
	#print p($cunsign);
	my @vs = $sign->get_xpath("v");
	foreach my $thing (@vs){
	    $signdata{$thing->{att}->{"n"}} = $hex;
	}
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



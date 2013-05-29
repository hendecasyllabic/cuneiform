package CHUNKER::generic;
use Data::Dumper;
use lib "/home/qlab/02www/cuneiform/perl/lib/lib/perl5/";
use JSON;

my $base = "/home/qlab/02www/cuneiform/";
my $errorfile = $base."/errors";
my $errorpath = "perlerrors";
my $outputtype = "text";

my %langmatrix; # other codes in use? ask Steve TODO
$langmatrix{"lang akk"} = "Akkadian"; $langmatrix{"lang a"} = "Akkadian"; $langmatrix{"akk"} = "Akkadian";
$langmatrix{"lang eakk"} = "Early Akkadian"; $langmatrix{"akk-x-earakk"} = "Early Akkadian"; # For pre-Sargonic Akkadian
$langmatrix{"lang oakk"} = "Old Akkadian"; $langmatrix{"akk-x-oldakk"} = "Old Akkadian";
$langmatrix{"lang ur3akk"} = "Ur III Akkadian"; $langmatrix{"akk-x-ur3akk"} = "Ur III Akkadian"; # akk-x-ur3akk may not exist ?? (check when Steve sends language list - Steve TODO)
$langmatrix{"lang oa"} = "Old Assyrian"; $langmatrix{"akk-x-oldass"} = "Old Assyrian";
$langmatrix{"lang ob"} = "Old Babylonian"; $langmatrix{"akk-x-oldbab"} = "Old Babylonian";
$langmatrix{"akk-x-obperi"} = "Peripheral Old Babylonian";
$langmatrix{"lang ma"} = "Middle Assyrian"; $langmatrix{"akk-x-midass"} = "Middle Assyrian";
$langmatrix{"lang mb"} = "Middle Babylonian"; $langmatrix{"akk-x-midbab"} = "Middle Babylonian";
$langmatrix{"lang na"} = "Neo-Assyrian"; $langmatrix{"akk-x-neoass"} = "Neo-Assyrian";
$langmatrix{"lang nb"} = "Neo-Babylonian"; $langmatrix{"akk-x-neobab"} = "Neo-Babylonian";
$langmatrix{"akk-x-ltebab"} = "Late Babylonian";
$langmatrix{"lang sb"} = "Standard Babylonian"; $langmatrix{"lang akk-x-stdbab"} = "Standard Babylonian"; $langmatrix{"akk-x-stdbab"} = "Standard Babylonian";
$langmatrix{"lang ca"} = "Conventional Akkadian"; $langmatrix{"akk-x-conakk"} = "Conventional Akkadian"; # The artificial form of Akkadian used in lemmatisation Citation Forms.

$langmatrix{"lang n"} = "normalised"; $langmatrix{"ANY-x-normal"} = "normalised"; # Used in lexical lists and restorations; try to avoid wherever possible.
$langmatrix{"lang g"} = "transliterated (graphemic) Akkadian"; # Only for use when switching from normalised Akkadian.
$langmatrix{"lang h"} = "Hittite"; $langmatrix{"lang hit"} = "Hittite"; 
$langmatrix{"lang s"} = "Sumerian"; $langmatrix{"lang sux"} = "Sumerian"; $langmatrix{"sux"} = "Sumerian"; $langmatrix{"lang eg"} = "Sumerian"; $langmatrix{"sux-x-emegir"} = "Sumerian"; # The abbreviation eg stands for Emegir (main-dialect Sumerian)

$langmatrix{"sux akk"} = "Sumerian - Akkadian";
$langmatrix{"sux-x-emesal sux akk"} = "Emesal - Sumerian - Akkadian";
$langmatrix{"sux-x-emesal"} = "Emesal";
$langmatrix{"akk-x-stdbab sux"} = "Standard Babylonian - Sumerian"; 
$langmatrix{"unknown"} = "unknown";

sub langmatrix{
    my $lang = shift;
    if($langmatrix{$lang}){
	return $langmatrix{$lang};
    }
    else{
	   # append to file NewLangCodes.txt
	&writetoerror ("NewLangCodes.txt", localtime(time)." ".$lang);
	return "ERROR";
    }
}

#generic function to write to an error file somewhere
sub writetoerror{
    my $shortname = shift; #passed in as a parameter
    my $error = shift; #passed in as a parameter
    my $extradir = shift; #passed in as a parameter
    my $startpath = $errorfile."/".$errorpath;
    &makefile($startpath); #pass to function
    my $destinationdir = $startpath;
    if($extradir && $extradir ne ""){
	$destinationdir .= "/".$extradir;
	
	&makefile($destinationdir);
    }
#    create a file called the shortname - allows sub sectioning of error messages
    open(SUBFILE2, ">>".$destinationdir."/".$shortname) or die "Couldn't open:".$destinationdir."/".$shortname." $!";
    binmode SUBFILE2, ":utf8";
    print SUBFILE2 $error."\n";
    close(SUBFILE2);
}

#generic function to write to file as json rather than xml
sub writetojson{
    my $shortname = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    my $extradir = shift; #passed in as a parameter
    my $startpath = shift; #$resultspath."/".$resultsfolder;
    &makefile($startpath); #pass to function
    my $destinationdir = $startpath;
    if($extradir && $extradir ne ""){
        $extradir =~s|( \|-)|_|gsi;
        #$extradir =~s|(\W*)|_|gsi;
	$destinationdir .= "/".$extradir;
	&makefile($destinationdir);
    }
    
    if((defined $data) && ($data ne "")){
	my $json = to_json($data, {utf8 => 1, pretty => 1});
	open(SUBFILE2, ">".$destinationdir."/".$shortname.".json") or die "Couldn't open: $!";
	binmode SUBFILE2, ":utf8";
	print SUBFILE2 $json; 
	close(SUBFILE2);
    }
    
}
#generic function to write to an file somewhere
sub writetofile{
    my $shortname = shift; #passed in as a parameter
    my $data = shift; #passed in as a parameter
    my $extradir = shift; #passed in as a parameter
    my $startpath = shift; #$resultspath."/".$resultsfolder;
    &makefile($startpath); #pass to function
    my $destinationdir = $startpath;
    if($extradir && $extradir ne ""){
        $extradir =~s|( \|-)|_|gsi;
        #$extradir =~s|(\W*)|_|gsi;
	$destinationdir .= "/".$extradir;
	&makefile($destinationdir);
    }
    
    if((defined $data) && ($data ne "")){
    #    create a file called the shortname - allows sub sectioning of error messages
    
	my $xs = new XML::Simple(keeproot => 1,forcecontent => 1,forcearray => 0, keyattr =>  ['name', 'key', 'id']);
	open(SUBFILE2, ">".$destinationdir."/".$shortname.".xml") or die "Couldn't open:".$destinationdir."/".$shortname.".xml $!";
	binmode SUBFILE2, ":utf8";
        my $xml = $xs->XMLout($data, rootname => 'data');
        print SUBFILE2 $xml;  # Use of uninitialized value ?
#	print SUBFILE2 XMLout($data);  
	close(SUBFILE2);
	
    }
}


#create the folder if it doesn't already exist -
#issue will ensure if permissions on the parent folder are incorrect
sub makefile{
    my $path = shift;
    my $result = `mkdir -p $path 2>&1`;
    print $result;
}
sub outputtext{
    my $data = shift;
    if($outputtype eq "text"){
	print $data;
    }
}

1;

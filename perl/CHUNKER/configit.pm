package CHUNKER::configit;

use strict;
use utf8;

#all the shared data that is needed

sub getConfigItems{
    my $config;
    $config->{"base"} = "/home/varoracc/local/oracc/www/qlab/cuneiform";
    #$config->{"base"} = "/Users/csm22/Work/Cuneiform/git/cuneiform";
    
#my $base = "/home/qlab/02www/cuneiform";#/Users/csm22/Work/Cuneiform/git/cuneiform";

    $config->{"basepath"} = $config->{"base"}."/datain";
    $config->{"baseresults"} = $config->{"base"}."/dataout4";
    $config->{"buildpath"} = "/home/varoracc/local/oracc/bld";
    return $config;
}
1;
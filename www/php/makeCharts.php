<?php

require_once 'config.php';
require_once("sharedHandlers.php");

require_once 'auth.php';

$errors = new myErrorHandling();
$renderer = new myRenderer();
$python = new myPythonHandler($sysdir);

$dataaffix = "outNEW";

$data = $_POST;
$response = array();

switch($_SERVER['REQUEST_METHOD'])
{
case 'GET':
break;
case 'POST':
//do post
doPOST($data);
break;
case 'DELETE':
    break;
}
$payload = array();

function doPOST(){
    global $data,$dataaffix,$sysdir,$errors, $python, $renderer, $pypath, $logfile;
    
    $forcerebuild = $data["rebuild"];

//what do you want
    $filename = $data['payload'];
    if(get_magic_quotes_gpc()) {
        $filename = $filename;
    }
    
    $langcheck = array();
    $response["langs"] = array();
    
    if ($handle = opendir($sysdir."data".$dataaffix."/datasubset/".$filename)) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            //how does this translate into a file name?
            if(preg_match('/^SIGNS_P_LANG_(.*).xml$/',$file,$m)) {
                $lang = $m[1];
                $returnlang = preg_replace("/ /","_", $lang);
                $response["langs"][] = $returnlang;
                if(!is_file($sysdir."data".$dataaffix."/datasubset/".$filename."/LANG_".$lang.".html") || $forcerebuild){
//                    only create if doesn't exist already or been force to rebuild
                    $pyerrors = $python->doit("perl ".$sysdir."perl/ChartsAndPies.pl datasubset/".$filename." ".getcwd()."/".$sysdir." SIGNS_P_LANG_".$lang.".xml", $errors);
                    file_put_contents($sysdir."data".$dataaffix."/datasubset/".$filename."/LANG_".$returnlang.".html",$pyerrors);
                }
            }
            if(preg_match('/^SIGNS_Q_LANG_(.*).xml$/',$file,$m)) {
                $lang = $m[1];
                $returnlang = preg_replace("/ /","_", $lang);
                $response["langs"][] = $returnlang;
                if(!is_file($sysdir."data".$dataaffix."/datasubset/".$filename."/QLANG_".$lang.".html") || $forcerebuild){
//                    only create if doesn't exist already or been force to rebuild
                    $pyerrors = $python->doit("perl ".$sysdir."perl/ChartsAndPies.pl datasubset/".$filename." ".getcwd()."/".$sysdir." SIGNS_Q_LANG_".$lang.".xml", $errors);
                    file_put_contents($sysdir."data".$dataaffix."/datasubset/".$filename."/QLANG_".$returnlang.".html",$pyerrors);
                }
            }
        }    
        closedir($handle);
    }
    
    
    $response["filepath"] = $filename;
//go to the correct results folder and return the data
//do the magic
    

//return results
    $renderer->renderpage(json_encode($response), $errors);
}
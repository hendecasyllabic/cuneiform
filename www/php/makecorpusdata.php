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
//who are you

$forcerebuild = $data["rebuild"];

//what do you want
    $payload3 = $data['payload'];
    if(get_magic_quotes_gpc()) {
        $payload3 = $payload3;
    }
    $payload = json_decode($payload3,true);
    sort($payload);
    $size = count($payload);
    
    $alreadyExists = false;
    $existingFileName = "";
    
//save as a json payload and iterate over a files with payloads and compare if we have one already?
//filename_numofitems_timestamp
    if ($handle = opendir($sysdir."data".$dataaffix."/datasubset")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            //how does this translate into a file name?
            if(preg_match('/^num_'.$size.'_(.*).json$/',$file,$m)) {
                
                $test = json_decode(file_get_contents($sysdir."data".$dataaffix."/datasubset/num_".$size."_".$m[1].".json"),TRUE);
                sort($test);
                //do we already have this data?
                if(!$alreadyExists){ //only try and find a match until we find a matching one
                    $diff = false;
                    foreach($test as $i=>$l){ 
                        if($payload[$i] != $l){
                            $diff = true;
                            break; 
                        }
                    }
                    if(!$diff){//we found a matching element
                        $alreadyExists = true;
                        $existingFileName = "num_".$size."_".$m[1];
                        break;
                    }
                }
            } 
        }    
        closedir($handle);
    
    }

    if($forcerebuild && $alreadyExists){
        //delete old data
        unlink($sysdir."data".$dataaffix."/".$existingFileName.".json");
        rrmdir($sysdir."data".$dataaffix."/".$existingFileName);
        $alreadyExists=null;
    }
//do we already have this data?
    if(!$alreadyExists){
        
        $existingFileName = "num_".$size."_".date('Ymd_H_i_s');
        file_put_contents($sysdir."data".$dataaffix."/datasubset/".$existingFileName.".json",json_encode($payload));
        $vardata = implode(",",$payload);
//send the data to perl
        $pyerrors = $python->doit("perl ".$sysdir."perl/ItemStats.pl ".$existingFileName." ".$vardata. " ".getcwd()."/".$sysdir, $errors);
    }
    
    $response["filepath"] = $existingFileName;
    $response["dataitems"] = $payload;
//go to the correct results folder and return the data
//do the magic
    

//return results
    $renderer->renderpage(json_encode($response), $errors);
}

function rrmdir($dir) {
    foreach(glob($dir . '/*') as $file) {
        if(is_dir($file))
            rrmdir($file);
        else
            unlink($file);
    }
    rmdir($dir);
}

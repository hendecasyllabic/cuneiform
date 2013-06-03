<?php

require_once 'config.php';
require_once("sharedHandlers.php");

require_once 'auth.php';

$errors = new myErrorHandling();
$renderer = new myRenderer();
$python = new myPythonHandler($sysdir);

$dataaffix = "out4/compilation";

$data = $_POST;
$response = array();

switch($_SERVER['REQUEST_METHOD'])
{
case 'GET':
break;
case 'POST':
    if($data["delete"]){doDelete();}
    else{doPOST();}
//do post

break;
case 'DELETE':

break;
}
$payload = array();

function doDelete(){
    global $data,$dataaffix,$sysdir,$errors, $python, $renderer, $pypath, $logfile;
    
    $forcerebuild = $data["rebuild"];
    $existingFileName = $data['payload'];
    $corpusname = $data["corpusname"];
    $username = $data["username"];
    
    $removeall = array();
    //remove from saved searched?
    $userdata = array();
    if(file_exists($sysdir."data".$dataaffix."/subset/user_".$username.".json")){
        $userdata = json_decode(file_get_contents($sysdir."data".$dataaffix."/subset/user_".$username.".json"),TRUE);
    }
    //remove unused items
    foreach( $userdata as $i=>$l){
        if(!file_exists($sysdir."data".$dataaffix."/subset/".$userdata[$i]["filepath"].".json")){
            $removeall[$userdata[$i]["filepath"]] = 1;
            if(isset($userdata[$corpusname])){
                unset($userdata[$corpusname]);
            }
        }
        
    }
    if ($handle = opendir($sysdir."data".$dataaffix."/subset")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            //how does this translate into a file name?
            if(preg_match('/^'.$existingFileName.'(.*)$/',$file,$m)) {
                //echo $file;
                //var_dump($m);
                unlink($file);
            }
            else{ //clean up any left over bits
                if(preg_match('/^(num_\d+_\d+_\d+_\d+_\d+)[^\d]*$/',$file,$m)){
                    if($removeall[$m[1]]){
                    //    echo $file;
                        unlink($file);
                    }
                }
            }
        }
    }
    
    if(isset($userdata[$corpusname])){
        unset($userdata[$corpusname]);
    }
    file_put_contents($sysdir."data".$dataaffix."/subset/user_".$username.".json",json_encode($userdata));
    
    $response["filepath"] = $existingFileName;
    $response["dataitems"] = $payload;
    $response["userdata"] = $userdata;
    
    $renderer->renderpage(json_encode($response), $errors);
}


function doPOST(){
    global $data,$dataaffix,$sysdir,$errors, $python, $renderer, $pypath, $logfile;
//who are you

    $forcerebuild = $data["rebuild"];
    $corpusname = $data["corpusname"];
    $username = $data["username"];

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
    if($size>0){
        
        $existingFileName = "num_".$size."_".date('Ymd_H_i_s');
    //save as a json payload and iterate over a files with payloads and compare if we have one already?
    //filename_numofitems_timestamp
        if ($handle = opendir($sysdir."data".$dataaffix."/subset")) {
            /* This is the correct way to loop over the directory. */
            while (false !== ($file = readdir($handle))) {
                //how does this translate into a file name?
                if(preg_match('/^num_'.$size.'_(.*).json$/',$file,$m)) {
                    
                    $test = json_decode(file_get_contents($sysdir."data".$dataaffix."/subset/num_".$size."_".$m[1].".json"),TRUE);
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
        //does this user have some saved searches?
        $userdata = array();
        if(file_exists($sysdir."data".$dataaffix."/subset/user_".$username.".json")){
            $userdata = json_decode(file_get_contents($sysdir."data".$dataaffix."/subset/user_".$username.".json"),TRUE);
        }
        if(isset($userdata[$corpusname])){
            $parray = $test[$corpusname]["files"];
            sort($parray);
            $diff = false;
            foreach($parray as $i=>$l){ //is it the same array as the one we are passing?
                if($payload[$i] != $l){
                    $diff = true;
                    break; 
                }
            }
            if($diff){
                //overwrite the data
                $userdata[$corpusname]["files"] = $payload;
                $userdata[$corpusname]["filepath"] = $existingFileName;
            }
            else{
                //all fine - don't need to change anything just make sure the name is good.
                $userdata[$corpusname]["filepath"] = $existingFileName;
            }
        }
        else{//doesn't exist - add it.
            $userdata[$corpusname] = array();
            $userdata[$corpusname]["files"] = $payload;
            $userdata[$corpusname]["filepath"] = $existingFileName;
        }
           
        //finish making user file now we havethe file name
        file_put_contents($sysdir."data".$dataaffix."/subset/user_".$username.".json",json_encode($userdata));
        
    
        if($forcerebuild && $alreadyExists){
            //delete old data
            unlink($sysdir."data".$dataaffix."/subset/".$existingFileName.".json");
            rrmdir($sysdir."data".$dataaffix."/subset/".$existingFileName);
            $alreadyExists=null;
        }
    //do we already have this data?
        if(!$alreadyExists){
            file_put_contents($sysdir."data".$dataaffix."/subset/".$existingFileName.".json",json_encode($payload));
            $vardata = implode(",",$payload);
    //send the data to perl
            $pyerrors = $python->doit("perl ".$sysdir."perl/doSome.pl ".$existingFileName." ".$vardata. " ".getcwd()."/".$sysdir, $errors);
        }
    
        $response["filepath"] = $existingFileName;
        $response["dataitems"] = $payload;
        $response["userdata"] = $userdata;
    //go to the correct results folder and return the data
    //do the magic
    
    }
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

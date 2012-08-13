<?php
require_once 'config.php';
require_once("sharedHandlers.php");

require_once 'auth.php';

$errors = new myErrorHandling();
$renderer = new myRenderer();
$python = new myPythonHandler($sysdir);

$data = $_REQUEST;
$response = array();


switch($_SERVER['REQUEST_METHOD'])
{
case 'GET':
    $adminid = $data['adminid'];
    if($adminid == "all"){
        
    //loop over all files that start admin_
        $out = Array();
        if ($handle = opendir($sysdir."data")) {
            /* This is the correct way to loop over the directory. */
            while (false !== ($file = readdir($handle))) {
                if(preg_match('/^admin_(.+).json$/',$file,$m)) {
                    $response = getsingle("data/admin_".$m[1].".json");
                    $data = Array();
                    $data["crsid"] = $m[1];
                    $data["data"] = json_decode($response,true);
                    $out[] = $data;
                }
            }    
            closedir($handle);
        }
    }
    else{
        $response = getsingle("data/admin_".$adminid.".json");
        $out[] = $response;
    }
   $renderer->renderpage(json_encode($out), $errors);
break;
case 'POST':
//do post
    doPOST();
break;
case 'DELETE':
    if(!is_person_type(current_user(),"admin")) {
        header("HTTP/1.0 500 Security Check Failed");
        return;
    }   
        
    if($adminid == "all"){
        $errors->addErrors("Delete failed: You don't really want to delete this: ");
    }
    else{
        $file = $sysdir."data/admin_".$adminid.".json";
        if (file_exists($file)) {
            unlink($file);
            $response["msg"] = "Delete successfull: ".$file."\"";
        }
        else{
            $errors->addErrors("Delete failed: file does not exist: ".$file);
        }
    }
    $renderer->renderpage("", $errors);

break;

default:
}

function getsingle($filename){
    global $sysdir,$error;
    $file = $sysdir.$filename;
    if (file_exists($file)) {
        $jsonstuff = file_get_contents($file);
        $response = $jsonstuff;
    }
   else{
	$errors->addErrors("Get failed: file does not exist: ".$file);
   }
   return $response;
}

function doPOST(){
    global $data,$sysdir,$errors, $renderer, $logfile;
    
    $adminid = $data['adminid'];
    $payload3 = $data['payload'];
    $payload = json_decode($payload3,true);  

    if(!is_person_type(current_user(),"admin")) {
        header("HTTP/1.0 500 Security check failed");
        return;
    }
    
    if($adminid=="all"){
	//delete everything first
        if ($handle = opendir($sysdir."data")) {
            /* This is the correct way to loop over the directory. */
            while (false !== ($file = readdir($handle))) {
                if(preg_match('/^admin_(.+).json$/',$file,$m)) {
		    $file = $sysdir."data/admin_".$m[1].".json";
		    unlink($file);
                }
            }    
            closedir($handle);
        }
	
        foreach($payload as $admin) {
            file_put_contents($sysdir."data/admin_".$admin['crsid'].".json",json_encode($admin['data']));
        }
    }
    else{
        file_put_contents($sysdir."data/admin_".$adminid.".json",json_encode($payload));
    }
    $renderer->renderpage(json_encode($payload), $errors);
}
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
$file = $sysdir."data/info.json";
if (file_exists($file)) {
    $jsonstuff = file_get_contents($file);
    $response = $jsonstuff;
}
   else{
	$errors->addErrors("Get failed: file does not exist: ".$file);
   }
   $renderer->renderpage($response, $errors);
break;
case 'POST':
//do post
    doPOST();
break;
case 'DELETE':
   $errors->addErrors("Delete failed: You don't really want to delete this: ");
   $renderer->renderpage("", $errors);

break;

default:
}

function doPOST(){
    global $data,$sysdir,$errors, $python, $renderer, $pypath, $logfile;
    
    $payload3 = $data['payload'];
    $payload = json_decode($payload3,true);  

    if(!is_person_type(current_user(),"admin")) {
        header("HTTP/1.0 500 Security check failed");
        return;
    }
	
    file_put_contents($sysdir."data/info.json",json_encode($payload));
    $renderer->renderpage(json_encode($payload), $errors);
}
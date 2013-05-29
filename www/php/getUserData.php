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

    $username = $data["username"];

    //does this user have some saved searches?
    $userdata = array();
    if(file_exists($sysdir."data".$dataaffix."/datasubset/user_".$username.".json")){
        $userdata = json_decode(file_get_contents($sysdir."data".$dataaffix."/datasubset/user_".$username.".json"),TRUE);
    }
    
    $response["dataitems"] = $userdata;
//return results
    $renderer->renderpage(json_encode($response), $errors);
}


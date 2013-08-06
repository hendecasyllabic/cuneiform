<?php

require_once 'config.php';
require_once("sharedHandlers.php");

require_once 'auth.php';

$errors = new myErrorHandling();
$renderer = new myRenderer();
$python = new myPythonHandler($sysdir);

$dataaffix = "out4/compilation/subset";

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
    $forcepurge = $data["purge"];

//what do you want
    $filename = $data['payload'];
    
    $response["filepath"] = $filename;

//return results
    $renderer->renderpage(json_encode($response), $errors);
}
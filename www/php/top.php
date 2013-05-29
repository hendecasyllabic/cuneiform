<?php

require_once("sharedHandlers.php");
require_once 'config.php';

$errors = new myErrorHandling();
$renderer = new myRenderer();
$python = new myPythonHandler($sysdir);

$dataaffix = "out4/projectList";

$debugit = false;
if(isset($_REQUEST['debug'])){
	$debugit = $_REQUEST['debug']; // get the debugstatus
}
/*
ALLstudents
ALLcolleges
ALLpapers
config
*/

$data = $_REQUEST;
$file1 = $sysdir."data".$dataaffix."/CORPUS_META.xml";

$response = array();
$response{'root'} = get_config('base');

if (file_exists($file1)) {
	$stuff = xmlstr_to_array(file_get_contents($file1));
	$response{"ALLCorpora"} = $stuff;
}
else{
	$errors->addErrors("View failed: file does not exist: ".$file1);
}

$renderer->renderpage(json_encode($response), $errors);
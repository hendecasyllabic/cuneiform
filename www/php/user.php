<?php

require_once 'auth.php';
require_once 'config.php';

session_start();
$out = Array();
$perms = null;

if($_POST['username'] && $_POST['password']){
    $out = Array();
    $user = $_POST['username'];
    if(file_exists($sysdir."data/".$user.".json")){
        $userdata = json_decode(file_get_contents($sysdir."data/".$user.".json"), $assoc = TRUE);
        if($userdata["password"] == $_POST['password']){
            $_SESSION['ID_cuneiform'] = $user;
        }
        else{
            $_SESSION['ID_cuneiform'] = "";
            $out['message'] = "invalid password";
        }
    }
    else{
        $out['message'] = "invalid username";
        $_SESSION['ID_cuneiform'] = "";
    }
}

set_user($_SESSION['ID_cuneiform']);
//bodge so I can test....
//    set_user("csm22");
$user = test_user();
if($user) {
    $out['loggedin'] = true;
    $out['user'] = current_user();
    $perms = get_perms($out['user']);
    $out['perms'] = $perms;
} else {
    $out['loggedin'] = false;
}


$out['perms'] = $perms;

header('Cache-Control: no-cache, must-revalidate');
header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
header('Content-type: application/json');

echo json_encode($out);

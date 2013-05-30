<?php

require_once 'config.php';

function get_perms($user, $type) {
    global $sysdir;
    //first test if an admin
    //then see if a student
    $data = Array();
    if(file_exists($sysdir."data/".$user.".json")){
	$data = json_decode(file_get_contents($sysdir."data/".$user.".json"),$assoc = TRUE);
    }

   
    return $data;
}

function save_perms($user,$data, $type) {
    global $sysdir;
    file_put_contents($sysdir."data/".$type."_".$user.".json",json_encode($data));
}

function college_name($id) {
    global $sysdir;
    $top = json_decode(file_get_contents($sysdir."data/colleges.json"),$assoc = TRUE);
    if($top{$id}){
        return $top[$id]["name"];
    }
    return null;
}

function get_colleges($list) {
    global $sysdir;
    $top = json_decode(file_get_contents($sysdir."data/colleges.json"),$assoc = TRUE);
    $data = $top;
    $out = Array();
    if($list) {
        foreach($data as $college) {
            if($list === true || in_array($college['shortname'],$list)) {
                $out[$college['shortname']] = $college['name'];
            }
        }
    }
    return $out;
}

function student_name($id) {
    global $sysdir;
    $top = json_decode(file_get_contents($sysdir."data/student_".$id.".json"),$assoc = TRUE);
    if($top['students']{$id}){
        return $top["name"];
    }
    return null;
}

//get all student_ files
function get_students($list) {
    global $sysdir;
    //loop over all files that start student_
    
    $out = Array();
    if ($handle = opendir($sysdir."data")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            if(preg_match('/^student_(.+).json$/',$file,$m)) {
	        if($list === true || in_array($m[1],$list)) {
		    $data = get_perms($m[1],"student");
		    $out[$m[1]] = $data;
		}
            }
        }    
        closedir($handle);
    }

    return $out;
}
//needed so we can list all the students for a college or array of colleges - used by admins
function get_students_by_college($collegelist) {
    global $sysdir;
    
    //loop over all files that start student_
    $out = Array();
    if ($handle = opendir($sysdir."data")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            if(preg_match('/^student_(.+).json$/',$file,$m)) {
                $data = get_perms($m[1],"student");
		//if($collegelist) {
		    if($collegelist === true || in_array($data["college"], $collegelist)) {
			$out[$m[1]] = $data;
		    }
		//}
            }
        }    
        closedir($handle);
    }
    return $out;
}
function get_allstudents(){
    global $sysdir;
    $out = Array();
    if ($handle = opendir($sysdir."data")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            if(preg_match('/^student_(.+).json$/',$file,$m)) {
                $data = get_perms($m[1],"student");
		$out[$m[1]] = $data;
            }
        }    
        closedir($handle);
    }
    return $out;
}
function sort_students_by_college($collegelist, $studentlist) {
    global $sysdir;
    $out = Array();
//    foreach($studentlist as $student) {//don't think this is used anywhere?
//	if($collegelist === true || in_array($student["college"], $collegelist)) {
//	    $out[] = $student;
//	}
//   }
    //loop over all files that start student_
    if ($handle = opendir($sysdir."data")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            if(preg_match('/^student_(.+).json$/',$file,$m)) {
                $data = get_perms($m[1],"student");
		//if($collegelist) {
		    if($collegelist === true || in_array($data["college"], $collegelist)) {
			$out[$m[1]] = $data;
		    }
		//}
            }
        }    
        closedir($handle);
    }
    return $out;
}

function log_it($what) {
    global $sysdir;
    
    $user = current_user();
    $daytime = date("Y-m-d H:i:s");
    $msg = "$user\t$daytime\t$what\n";
    file_put_contents($sysdir."data/log.txt",$msg,FILE_APPEND);
}

function get_log() {
    global $sysdir;
    
    $log = file_get_contents($sysdir."data/log.txt");
    // reverse log
    $log = join("\n",array_reverse(preg_split('/[\\n\\r]+/',$log)));
    return $log;    
}

function get_delegations() {
    global $sysdir;
    $out = Array();
    if ($handle = opendir($sysdir."data")) {
        /* This is the correct way to loop over the directory. */
        while (false !== ($file = readdir($handle))) {
            if(preg_match('/^dos_(.+).json$/',$file,$m)) {
                $data = get_perms($m[1]);
                $tout = Array();
                foreach($data['colleges'] as $t) {
                    $tout[] = college_name($t);
                }                
                sort($tout);
                $out[$m[1]] = Array('colleges' => $tout, 'all' => $data['all']);
            }
        }    
        closedir($handle);
    }
    return $out;
}

function delegate($college,$from_u,$to_u) {
    $out = false;
    $from = get_perms($from_u,"");
    $to = get_perms($to_u,"dos");
    if($to["type"]!="dos"){
	return $out;
    }
    if($from['all'] || in_array($college,$from['admin']['colleges'])) {
	    # ok, but is it there?
	    if(!in_array($college,$to['admin']['colleges'])) {
		    $to['admin']['colleges'][] = $college;
	    }
	    $out = true;
    }
    save_perms($to_u,$to["admin"],$to["type"]);
    return $out;
}

function rescind($college,$by_u,$from_u) {
    $out = false;
    $by = get_perms($by_u,"");
    $from = get_perms($from_u,"dos");
    if($from["type"]!="dos"){
	return $out;
    }
    if($by['all'] || in_array($college,$by["admin"]['colleges'])) {
        foreach($from["admin"]['colleges'] as $i => $t) {
            if($t == $college) {
                unset($from["admin"]['colleges'][$i]);
            }
        }
        $from['colleges'] = array_values($from["admin"]['colleges']);
        $out = true;
    }
    save_perms($from_u,$from["admin"],$from["type"]);
    return $out;
}

function can_edit($who,$student) {
    $user = get_perms($who,"");
    return $user["admin"]['all'] || in_array($student,$user["admin"]['students']);
}
function can_edit_perms($perms,$student) {
    return $perms["admin"]['all'] || in_array($student,$perms["admin"]['students']);
}
function can_edit_college_perms($perms, $college){
    return $perms["admin"]['all'] || in_array($college,$perms["admin"]['colleges']);
}

//full info on a dos and their students
function getsingledos($dosid, $studentlist){
    global $sysdir,$error;
    $filename = "data/dos_".$dosid.".json";
    if($dosid == "_new"){
	$filename = "data/blank_dos.json";
    }
    $file = $sysdir.$filename;
    if (file_exists($file)) {
        $jsonstuff = file_get_contents($file);
	$data = json_decode($jsonstuff,true);
	$collegelist = $data["colleges"];
	$data["get_students_by_college"] = sort_students_by_college($collegelist, $studentlist);
        $response = $data;
    }
   else{
	$errors->addErrors("Get failed: file does not exist: ".$file);
   }
   return $response;
}
/**
 * diferentiate between dos and admin
 */
function is_person_type($who,$type) {
    $user = get_perms($who,"");
    if($user["type"] == $type){
	return true;
    }
	if(array_key_exists('all', $user)){
	    return $user['all'];
	}
return false;
}
/**
 * is this person a god on the system
 */
function is_super() {
    $user = get_perms(current_user(True),"");
    return $user["admin"]['all'];	
}

function set_impersonate($who) {
    start_session_if_not_started();
    $_SESSION['impersonate'] = $who;
}

function start_session_if_not_started() {
 if (!isset ($_SESSION)) {
    session_start();
  }
}

function current_user($real = False) {
    start_session_if_not_started();
    if(!test_user())
            return '';
    if(isset($_SESSION['impersonate']) && !$real)
            return $_SESSION['impersonate'];
    return $_SESSION['user'];
}

function set_user($whom) {
    start_session_if_not_started();
    $_SESSION['user'] = $whom;
}

function unset_user() {
    start_session_if_not_started();
    if(test_user())
            unset($_SESSION['user']);
}

function test_user() {
    start_session_if_not_started();
    return array_key_exists('user',$_SESSION) && $_SESSION['user']!="";	
}

function generate_hmac($who,$time) {
    global $keyfile;
    $key = trim(file_get_contents($keyfile));
    
    // We need to ensure that we get some data from the keyfile to salt the hmac
    // generation with, otherwise anyone could create their own valid MACs.
    if(strlen($key) == 0) {
            throw new RuntimeException("No salt available. Check that the "
                    . "configured keyfile exists and is not empty.");
    }
    
    $key = pack("H".strlen($key),$key);
    return hash_hmac('sha1',"$who:$time",$key);
}

function test_hmac($in) {
    $parts = split(':',trim($in));
    if($parts[1]<time())
            return FALSE;
    if(generate_hmac($parts[0],$parts[1]) != $parts[2])
            return FALSE;
    return $parts[0];
}

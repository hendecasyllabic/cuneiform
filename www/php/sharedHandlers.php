<?php
require_once('config.php');

session_start();

class myPythonHandler {
        
	public function __construct($arg) {
		$this->sysdir = $arg;
	}
	public function doit($cmd, $errors){
		return $this->my_exec($cmd, $errors, $this->sysdir, $input='');
	}
	
	function my_exec($cmd, $errors, $sysdir, $input='') {
		$proc=proc_open($cmd, array(0=>array('pipe', 'r'), 1=>array('pipe', 'w'), 2=>array('pipe', 'w')), $pipes); 
		fwrite($pipes[0], $input);fclose($pipes[0]); 
		$stdout=stream_get_contents($pipes[1]);fclose($pipes[1]); 
		$stderr=stream_get_contents($pipes[2]);fclose($pipes[2]); 
		$rtn=proc_close($proc);
		if($stderr !=""){
			$myFile = $sysdir."error/stdout.txt";
			$fh = fopen($myFile, 'a+') or $errors->addErrors("can't open file: ".$myFile) ;
			
			if(!$errors->hasError()){
				$stringData = 'CMD:'.$cmd."\n";
				fwrite($fh, $stringData);
				$stringData = 'stdout:'.$stdout."\n";
				fwrite($fh, $stringData);
				$stringData = 'stderr:'.$stderr."\n";
				fwrite($fh, $stringData);
				$stringData = 'return:'.$rtn."\n";
				fwrite($fh, $stringData);
				fclose($fh);
			}
			$errors->addErrors("Python failed: ".$cmd.": ".$stderr);
		}
		return array('stdout'=>$stdout, 
			'stderr'=>$stderr, 
			'return'=>$rtn 
		); 
	} 
}

class myRenderer{
	public function __construct() {
	}
	function doHeader(){
		header('Cache-Control: no-cache, must-revalidate');
		header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
		header('Content-type: application/json');
	}
	function doExcelHeader(){
		$filename = "website_data_" . date('Ymd') . ".xls";
		header('Content-type: application/vnd.ms-excel');
		header("Content-Disposition: attachment; filename=\"$filename\"");
		header("Pragma: no-cache");
	}
	public function renderpage($data, $errors){	    
	    if($errors->hasError()){
		header("Status: 500 Internal Server Error", false, 500);
		echo $errors->showFriendlyErrors();
	    }
	    else{
		$this->doHeader();
		echo $data;
	    }
	}
	public function renderexcel($data, $errors){
            if($errors->hasError()){
                header("Status: 500 Internal Server Error", false, 500);
                echo $errors->showFriendlyErrors();
            }
            else{
		$this->doExcelHeader();
		$flag = false;
		foreach($data as $row){
			if(!$flag){
				echo implode("\t", array_keys($row))."\r\n";
				$flag = true;
			}
			array_walk($row, 'cleanData');
			echo implode("\t", array_values($row)). "\r\n";
		}
	    }
	}
	public function cleanData(&$newstr){
		$str = $newstr;
		if(is_array($newstr)){
			$str = implode(",",$newstr);
		}
		$str = preg_replace("/\t/", "\\t", $str);
		$str = preg_replace("/\r?\n/", "\\n", $str);
		if(strstr($str, '"')) $str = '"' . str_replace('"', '""', $str) . '"';
	}
}

    
class myErrorHandling {
        
	public function __construct() {
		$this->errormsgs =  array();
	}
    
	public function hasError(){
            if(sizeof($this->errormsgs) > 0){
                return true;
            }
	    return false;
	}
	
	public function showStringErrors(){
		$stng = "";
		foreach($this->errormsgs as $data){
			$stng .= $data["msg"]. "\n";
		}
		return $stng;
	}
    
	public function showErrors(){
		return $this->errormsgs;		
	}

	public function showFriendlyErrors() {
		$stng = $this->showStringErrors();
		if(preg_match('/{{(.*)}}/',$stng,$match))
			$stng = $match[1];
		return $stng;
	}
    
	public function addErrors($msg){
            $this->errormsgs[] = array( "msg" => $msg);
	}
    
    
	public function clearErrors(){
            $this->errormsgs = array();		
	}
}


// Undo damage done by magic quotes
if (get_magic_quotes_gpc()) {
    $process = array(&$_GET, &$_POST, &$_COOKIE, &$_REQUEST);
    while (list($key, $val) = each($process)) {
        foreach ($val as $k => $v) {
            unset($process[$key][$k]);
            if (is_array($v)) {
                $process[$key][stripslashes($k)] = $v;
                $process[] = &$process[$key][stripslashes($k)];
            } else {
                $process[$key][stripslashes($k)] = stripslashes($v);
            }
        }
    }
    unset($process);
}
function load_config() {
	global $sysdir;
	
	$out = Array();
	$data = file_get_contents("$sysdir/config/config.txt");
	$lines = explode("\n",$data);
	foreach($lines as $line) {
		$eq = split('=',$line,2);
		if(count($eq)<2)
			continue;
		$out[trim($eq[0])] = trim($eq[1]);
	}
	return $out;
}

function get_config($key) {
	// XXX do it more efficiently
	$config = load_config();
	if(array_key_exists($key,$config))
		return $config[$key];
	else
		return false;
}

//https://github.com/gaarf/XML-string-to-PHP-array/
/**
  * convert xml string to php array - useful to get a serializable value
  *
  * @param string $xmlstr
  * @return array
  *
  * @author Adrien aka Gaarf & contributors
  * @see http://gaarf.info/2009/08/13/xml-string-to-php-array/
*/

function xmlstr_to_array($xmlstr) {
  $doc = new DOMDocument();
  $doc->loadXML($xmlstr);
  $root = $doc->documentElement;
  $output = domnode_to_array($root);
  $output['@root'] = $root->tagName;
  return $output;
}

function domnode_to_array($node) {
  $output = array();
  switch ($node->nodeType) {

    case XML_CDATA_SECTION_NODE:
    case XML_TEXT_NODE:
      $output = trim($node->textContent);
    break;

    case XML_ELEMENT_NODE:
      for ($i=0, $m=$node->childNodes->length; $i<$m; $i++) {
        $child = $node->childNodes->item($i);
        $v = domnode_to_array($child);
        if(isset($child->tagName)) {
          $t = $child->tagName;
          if(!isset($output[$t])) {
            $output[$t] = array();
          }
          $output[$t][] = $v;
        }
        elseif($v || $v === '0') {
          $output = (string) $v;
        }
      }
      if($node->attributes->length && !is_array($output)) { //Has attributes but isn't an array
        $output = array('@content'=>$output); //Change output into an array.
      }
      if(is_array($output)) {
        if($node->attributes->length) {
          $a = array();
          foreach($node->attributes as $attrName => $attrNode) {
            $a[$attrName] = (string) $attrNode->value;
          }
          $output['@attributes'] = $a;
        }
        foreach ($output as $t => $v) {
          if(is_array($v) && count($v)==1 && $t!='@attributes') {
            $output[$t] = $v[0];
          }
        }
      }
    break;
  }
  return $output;
}
?>
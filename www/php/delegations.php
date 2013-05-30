<?php

require_once 'auth.php';

$dele = get_delegations();

$out = Array();
foreach($dele as $user => $data) {
    $text = '';
    if($data['all']) {
        $text = "$user can edit all data";
    } elseif(count($data['colleges'])) {
        $text = "$user can edit ".join(", ",$data['colleges']).".";
    }
    if($text)
        $out[] = $text;
}

echo json_encode(Array( 'data' => $out));

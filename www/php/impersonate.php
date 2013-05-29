<?php

require_once 'auth.php';

if(!is_super()) {
	echo "You do not have sufficient permission to impersonate";
	return;
}

set_impersonate($_REQUEST['who']);

echo "impersonating ".current_user();
echo " really ".current_user(True);
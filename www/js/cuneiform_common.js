/*
 * CUNEIFORM: Common JS
 * Functionality which is general, used across many pages within the app
 *
 * Note that this file has poorer error reporting than most files because it contains the error reporting code. So many syntax errors here will not be reported.
 * XXX that error reporting should really be moved to another file.
 */

if(!$) {
	alert("Your browser is too old to use this application. It is probably at risk from attacks on the internet to, so it's a good idea to upgrade. Otherwise, why not try a different browser on this computer?");
}

// Namespaces
var cuneiform = window.cuneiform || {};         // Root namespace
cuneiform.data = {};                          // Data - calendar data in memory, state, etc...
cuneiform.c = {};                             // jQuery object cache

cuneiform.config = {};

// Config


// Config > UI things
cuneiform.config.messageTimeToLive = 4000; // Time for how long the Growl like messages appear in msec

// Config > URLs
cuneiform.config.urlUser = "php/user.php";
cuneiform.config.urlError = "php/error.php";
cuneiform.config.urlTop = "php/top.php";
cuneiform.config.urlRescind = "php/rescind.php";
cuneiform.config.urlDelegate = "php/delegate.php";
cuneiform.config.urlDelegations = "php/delegations.php";
cuneiform.config.urlLog = "php/log.php";
cuneiform.config.urlExport = "php/ExportExcel.php";
cuneiform.config.urlPapers = "php/papers.php";
cuneiform.config.urlColleges = "php/colleges.php";
cuneiform.config.urlInfo = "php/info.php";
cuneiform.config.urlDos = "php/dos.php";
cuneiform.config.urlStudent = "php/student.php";
cuneiform.config.urlAdmin = "php/admin.php";
cuneiform.config.urlDosStudents = "php/dosstudent.php";
cuneiform.config.urlReports = "php/reports.php";
cuneiform.config.urlClashics = "php/clashics.php";
cuneiform.config.urlExtraClashics = "php/rawdata.php";


// Console object declaration for browsers which don't support it
if (!window.console) {
    window.console = {};
    window.console.log = function(){};
    window.console.dir = function(){};
    window.console.time = function(){};
    window.console.timeEnd = function(){};
};

// global to prevent error cascade on abort
var aborting = false;

// Transforms top data into a form which is more suitable to drive the selectors from
cuneiform.processTopData = function(rawTop) {
 //TODO
 //   return selector;
};

// General ajax error handler
function ajaxError(event, jqXHR, ajaxSettings, thrownError, error_msg){

    // The local error handler passes the local context, so 'this' refers to the originating $.ajax object
    if (jqXHR.status == 409) {
		if(!aborting)
			alert("Unfortunately, someone updated this data before you had a chance: please reload this page to get the most recent version and then make your changes again.");
    }
    else if(jqXHR.status==500){
        // Display an error message, provided by the local ajax error handler
        var serverMsg = (jqXHR.responseText) ? jqXHR.responseText : "You did not have permissions to perform this action";
        if(!aborting)
	        alert(serverMsg);
    }
    else {
        // Display an error message, provided by the local ajax error handler
        var serverMsg = (jqXHR.responseText) ? jqXHR.responseText : "An undescribed error occurred";
        if(!aborting)
	        alert(serverMsg);
    }

};




cuneiform.common = {};

cuneiform.common.login_user = function(cont) {
	$.ajax({
		type: "POST",
		url: cuneiform.config.urlUser,
		dataType: "json",
		data: {
			'username': jQuery('#username').val(),
			'password': jQuery('#pass').val()
		},

		success: function(data, textStatus, jqXHR) {
			cuneiform.common.user = data;
			if(data['colour'])
				jQuery('#header').css('background',data['colour']);
			
			cont(cuneiform.common.user);			
		},
		error: function(jqXHR, textStatus, errorThrown) {
			var error_msg = "Could not load username!";
			ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		}
	});
	
}
// Stuff common to every page
cuneiform.common.get_user = function(cont) {
	if(cuneiform.common.user) {
		cont(cuneiform.common.user);
	}
	// Fetch top feed
	$.ajax({
		type: "GET",
		url: cuneiform.config.urlUser,
		dataType: "json",

		success: function(data, textStatus, jqXHR) {
			cuneiform.common.user = data;
			if(data['colour'])
				jQuery('#header').css('background',data['colour']);
			
			cont(cuneiform.common.user);			
		},
		error: function(jqXHR, textStatus, errorThrown) {
			var error_msg = "Could not load username!";
			ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		}
	});

};

cuneiform.common.delegate = function(whom,what,cont) {
	$.ajax({
		type: "POST",
		url: cuneiform.config.urlDelegate,
		dataType: "json",
		data: {
			'whom': whom,
			'what': what
		},
        success: function(data, textStatus, jqXHR) {
			if(!data.success) {
				if(!aborting)
		            alert("Could not delegate!");
			}
        	cont(data.success);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            var error_msg = "Could not delegate!";
            ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
            cont(false);
        }
	});
}

cuneiform.common.rescind = function(whom,what,cont) {
    $.ajax({
        type: "POST",
        url: cuneiform.config.urlRescind,
        dataType: "json",
        data: {
            'whom': whom,
            'what': what
        },
        success: function(data, textStatus, jqXHR) {
            if(!data.success) {
				if(!aborting)
	                alert("Could not rescind!");
            }
            cont(data.success);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            var error_msg = "Could not rescind!";
            ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
            cont(false);
        }
    });
}
//login
cuneiform.common.login_link = function() {

	// Populate login etc
	cuneiform.common.get_user(function(user) {

		// TITLE BAR

		var out = '';
		var home = "<a href='index.html'>home</a>";
		var adminfunctions = "";
		if(user.perms.type == "admin"){
			home = "<a href='index_admin.html'>Admin Dashboard</a>";
		}
		else if(user.perms.type=="dos"){
			home = "<a href='dos.html'>home</a>";
			adminfunctions = " <a class='user_delegate' href='javascript:;'>delegate</a>"+
				" <a class='user_rescind' href='javascript:;'>rescind</a>";
		}
		else if(user.perms.type=="student"){
			home = "<a href='student.html'>view/edit my choices</a>";
			adminfunctions = "";
		}
		
		if(/index.html($|#)/.test(document.URL)) {
			home = "";
		}
		
		if(user.loggedin) {
			out = "Hello "+user.perms.type+" "+user.user+".  "+home+" <a href='php/logout.php'>logout</a>"+
				adminfunctions;
		} else {
			out = "<a href='list.html#front=1&amp;forcefront=1'>intro</a> "+home+" <a href='php/login.php'>admin login</a>";
		}

		// dialog common
		function dialog(name,options) {
		    out = '<div id="<<_dialog" title="<>"><p>Which college: <select name="which" id="<<_which">'+options+'</select></p><p>Whom: <input type="text" id="<<_whom" name="whom"></p><button id="<<_button"><>!</button></div>';
		    name = name.toLowerCase();
		    out = out.replace(/<</g,name);
		    uname = name.charAt(0).toUpperCase() + name.substr(1);
		    out = out.replace(/<>/g,uname);
		    return out;
		}
		
		function post_dialog(name,cont) {
		    jQuery('#'+name+'_dialog').dialog({ 'autoOpen': false, 'width': 600, 'modal': true});
	
		    jQuery('.user_'+name).click(function() {         
			jQuery('#'+name+'_dialog').dialog('open');
		    });
				
		    jQuery('#'+name+'_button').click(function() {
			jQuery('#'+name+'_dialog').dialog('close');
			cont(jQuery('#'+name+'_whom').val(),jQuery('#'+name+'_which').val());
		    });
		}

		// PREPARE DIALOGS

		var options = '';
		// Sorted list
		var tkeys = [];
		for(var k in user.colleges) { tkeys.push(k) };
		tkeys = tkeys.sort(function(a,b) {
			if(user.colleges[a]<user.colleges[b]) return -1;
			return user.colleges[a]>user.colleges[b];	
		});
		for(var i=0;i<tkeys.length;i++) {
			k = tkeys[i];
			options += '<option value="'+k+'">'+user.colleges[k]+'</option>';
		}
		out += dialog('delegate',options);		
		out += dialog('rescind',options);
			
		// INSERT
		jQuery('#link_login').html(out);
	
		post_dialog('delegate',function(whom,which) {
		    clashics.common.delegate(whom,which,function(success) {
			if(success) {
			    jQuery.gritter.add({'title':'Success','text':'Delegation successful'});
			}
		    });            
		});
		post_dialog('rescind',function(whom,which) {
		    cuneiform.common.rescind(whom,which,function(success) {
			if(success) {
			    jQuery.gritter.add({'title':'Success','text':'Rescinding successful', time: 1000});
			}
		    });            
		});
	});
};



//sessions
cuneiform.common.session = undefined;
cuneiform.common.get_session = function() {
	if(cuneiform.common.session) { return cuneiform.common.session; }
	cuneiform.common.session = $.cookie('jssession');
	if(cuneiform.common.session) { return cuneiform.common.session; }
	cuneiform.common.session = Math.floor(Math.random()*100000000);
	$.cookie('jssession',cuneiform.common.session,{ 'path': '/' });
	return cuneiform.common.session;
};

//error handling
cuneiform.common.report_error = function(level,message,report) {
    $.ajax({
        type: "POST",
        url: cuneiform.config.urlError,
        dataType: "json",
        data: {
			'session': cuneiform.common.get_session(),
			'url': window.location.href,
			//'parent': clashics.common.parent_url(),
			'time': new Date().getTime(),
			'origin': 'client-javascript-nos', // XXX allow explicit specifcaiton
			'message': message,
			'report': report || message,
			'level': level,
			'browser': navigator.userAgent
        },
        success: function(data, textStatus, jqXHR) {
        },
        error: function(jqXHR, textStatus, errorThrown) {
        }
    });
};

//spinner
cuneiform.common.spinner_init = function() {
	var spinner_text = "<p>working...</p><p><img src='images/ajax-loader.gif'/></p>";
	var spinner_box = jQuery('<div></div>').append(spinner_text);
	spinner_box.attr('style','text-align: center; margin: auto; width: 130px');
	var spinner = jQuery('<div></div>').append(spinner_box);
	spinner.attr('id','spinner');
	spinner.dialog({
		'autoOpen': false, 
		'modal': true,
		'width': 150,
		'height': 120	
	});
};

cuneiform.common.spin_on = function() {
	jQuery('#spinner').dialog('open');
};

cuneiform.common.spin_off = function() {
	jQuery('#spinner').dialog('close');
};





cuneiform.common.viewpapers = function() {
            
    // Render event groups
    var vghtml = '';
    //TODO
   return vghtml;
};

cuneiform.common.viewdos = function(dosdata,dosid, slist){
	
        // TODO
        var vghtml = '<div class="eg" data-num="'+dosid+'"></div>';
	return vghtml;
}
cuneiform.common.editdos = function(dosdata,dosid){
	//TODO
        var eghtml = '<div class="eg" data-num="'+dosid+'">';
        eghtml += '<hr/></div>';
	return eghtml;
}
cuneiform.common.viewstudent = function(studata,stuid){
	//name, college, year, papers, comments
        var name = studata.name;
        var college = studata.college;
        var type = studata.type;
        var papers = studata.papers;
        var shtml = '';
        shtml += "<div><h3>"+name+" ("+college+") "+type;

        return shtml;
}

cuneiform.common.editstudent = function(studata,stuid, isSingle){
        // Paper 
	return eghtml;
}

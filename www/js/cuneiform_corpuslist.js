
var cuneiform = cuneiform || {};
cuneiform.config.sendData = "../www/php/makecorpusdata.php";
cuneiform.config.chartData = "../www/php/makeCharts.php";
cuneiform.config.userData = "../www/php/getUserData.php";

cuneiform.corpuslist = {};
//cuneiform.c.$viewgroup_container = $("#show_view");
cuneiform.c.$select_corpuslist = $("#show_view");
cuneiform.c.$select_userlist = $("#show_list");
cuneiform.corpuslist.results = "";

cuneiform.corpuslist.init = function() {
    cuneiform.common.spinner_init();
    cuneiform.common.spin_on();
    cuneiform.common.get_user(function(user) {
        cuneiform.data.user = user;
        cuneiform.common.spin_off();
        if(!user || !user.loggedin){
            window.location = "../www/login.html";
            //alert(user.perms.fullname+":"+user.perms.crsid+":"+user.loggedin);
        }
        else{
              cuneiform.corpuslist.page_init();
        }
    });
};
cuneiform.corpuslist.getUserData = function(){
              cuneiform.common.spin_on();
              $.ajax({
		type: "POST",
		url: cuneiform.config.userData,
		dataType: "json",
		data: {
			'username': cuneiform.data.user.perms.crsid
		},
		success: function(data, textStatus, jqXHR) {
			cuneiform.common.spin_off();
                        var chtml ="";
                        //userdata
                        if(data && data.dataitems){
                            for(var i in data.dataitems){
                                chtml += "<div id='"+data.dataitems[i].filepath+"'>";
                                chtml += "<a href='javascript://' onclick='cuneiform.corpuslist.charts(\""+data.dataitems[i].filepath+"\")'>";
                                chtml += i+":"+data.dataitems[i].files.join(",")+"</a><br/> ";
                                chtml += "<div class=\"langs\"></div></div><div class='alllang'></div></div>";
                            }
                        }
                        cuneiform.c.$select_userlist.html(chtml);
			
		},
		error: function(jqXHR, textStatus, errorThrown) {
			cuneiform.common.spin_off();
			var error_msg = "Could not load corpus data!";
			ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		}
	});
};
cuneiform.corpuslist.sendData = function(dataarray, cont){
              cuneiform.common.spin_on();
              var corpusname = jQuery(".corpusname").val();
              var testpayload = [];
              for(var i in dataarray){
                            if(i!=""){
                            testpayload.push(i);  
                            }
              }
	if(dataarray){
		$.ajax({
		    type: "POST",
		    url: cuneiform.config.sendData,
		    dataType: "json",
		    data: {
			    'username': cuneiform.data.user.perms.crsid,
			    'rebuild': 0,//set to 1 if you want to force rebuild stuff.
			    'payload': JSON.stringify(testpayload),
			    'corpusname': corpusname
		    },
    
		    success: function(data, textStatus, jqXHR) {
				cuneiform.common.spin_off();
			    cuneiform.corpuslist.results = data;
			    var chtml ="";
			    if(data && data.dataitems){
				chtml += "<div id='"+data.filepath+"'>";
				chtml += "<a href='javascript://' onclick='cuneiform.corpuslist.charts(\""+data.filepath+"\")'>";
				chtml += data.dataitems.join(",")+"</a><br/> ";
				chtml += "<div class=\"langs\"></div><div class='alllang'></div></div>";
			    
			    }
			    cuneiform.c.$select_corpuslist.html(chtml);
			    
			    //userdata
			    var uhtml = "";
			    if(data && data.userdata){
				for(var i in data.userdata){
				    uhtml += "<div id='"+data.userdata[i].filepath+"'>";
				    uhtml += "<h3>"+"<a href='javascript://' onclick='cuneiform.corpuslist.charts(\""+data.userdata[i].filepath+"\")'>";
				    uhtml += i+":"+data.userdata[i].files.join(",")+"</a></h3> ";
				    uhtml += "<div class=\"langs\"></div><div class='alllang'></div></div>";
				}
			    }
			    cuneiform.c.$select_userlist.html(uhtml);
			    
			    if(cont){
			      cont(cuneiform.corpuslist.results);
			    }
		    },
		    error: function(jqXHR, textStatus, errorThrown) {
				cuneiform.common.spin_off();
			    var error_msg = "Could not load corpus data!";
			    ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		    }
	    });

	}
}

cuneiform.corpuslist.showhtml = function(lang, filepath){
        cuneiform.common.spin_on();
  	$.ajax({
		type: "POST",
		url: "../dataout4/compilation/subset/"+filepath+"LANG_"+lang+".html",
		dataType: "text",

		success: function(data, textStatus, jqXHR) {
		    cuneiform.common.spin_off();
		    var name = lang;
		    name = name.replace(/\s+/g, '');
		    //should show multiple of these but we have namespace issue
		    jQuery("#langjquery").html("<h2>"+lang+"</h2>"+data);
		},
		error: function(jqXHR, textStatus, errorThrown) {
		    cuneiform.common.spin_off();
		    var error_msg = "Could not load charts!";
		    ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		}
	});
}

cuneiform.corpuslist.charts = function(filepath){
  	$.ajax({
		type: "POST",
		url: cuneiform.config.chartData,
		dataType: "json",
		data: {
			'username': cuneiform.data.user.perms.crsid,
			'rebuild': 0,
			'payload': filepath
		},

		success: function(data, textStatus, jqXHR) {
			cuneiform.corpuslist.results = data;
			//alert(data.filepath);
			var html = "";
			
			jQuery(data.langs).each(function(){
			  var name = this;
			  name = name.replace(/\s+/g, '');
			  html +="<a href='javascript://' onclick='cuneiform.corpuslist.showhtml(\""+this+"\", \""+data.filepath+"\" )'>"+this+"</a><div class=\"lang_"+name+"\"></div>";
			});
			if(html == ""){
			    html +="No lang data found";
			}
			jQuery("#"+data.filepath).find(".langs").html(html);
			
			jQuery(cuneiform.c.$select_userlist).accordion({
			     active: false,
			     fillspace: true,
			     autoHeight: false,
			     collapsible: true,
			     header: "h3"
		       });
		},
		error: function(jqXHR, textStatus, errorThrown) {
			var error_msg = "Could not load charts!";
			ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		}
	});
  
}

cuneiform.corpuslist.page_init = function() {
    // Fetch top feed
    $.ajax({
        type: "GET",
        url: cuneiform.config.urlTop,
        dataType: "json",
        success: function(data, textStatus, jqXHR) {

            if (data !== null) {
                // Save data in memory
                cuneiform.data.top = data;
		
		//send corpus hash list to function
		cuneiform.corpuslist.sendData();
                
                cuneiform.corpuslist.getUserData();
                // Transform top data into a form which is easier to drive selectors from
//                cuneiform.data.selector = cuneiform.processTopData(cuneiform.data.top);
                // Read URL hash
//                var hash = $.deparam.fragment();

                // Read state stored in local storage
                //var storedState = ($.jStorage.get("mercury-list-selection") || false);
                
                //not used
//                cuneiform.corpuslist.pushState();

                // Wire up - not used
//                cuneiform.corpuslist.wire();
                
                // Render selector area - not used
//		cuneiform.corpuslist.renderSelectors();
                
                //Render collegesedit
//                clashics.corpuslist.AllInit();
                //Bind buttons
                //clashics.corpuslist.buttons_bind();
                
            } else {
                alert("The following data feed did not produce any data: "+clashics.config.urlTop);
                cuneiform.data.top = {};
            }

        },
        error: function(jqXHR, textStatus, errorThrown) {
            var error_msg = "Could not load data from the feed!";
            ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
            cuneiform.data.top = {};
        }
    });

    cuneiform.common.login_link();
        
};

        // Start with calling  page init function
$(document).ready(function() {
        try {
            cuneiform.corpuslist.init();
        } catch(err) {
            var error = 'Javascript error on page caught by list init try/catch  :' + err;
              cuneiform.common.report_error('error',error);
              alert("An error occurred loading this page. Perhaps you are using an unsupported browser? I suggest the basic javascript-free version, linked below.");
        }
});
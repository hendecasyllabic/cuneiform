
var cuneiform = cuneiform || {};
cuneiform.config.sendData = "../www/php/makecorpusdata.php";
cuneiform.config.chartData = "../www/php/makeCharts.php";
cuneiform.config.userData = "../www/php/getUserData.php";

cuneiform.corpuslist = {};
//cuneiform.c.$viewgroup_container = $("#show_view");
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
        }
        else{
              cuneiform.corpuslist.page_init();
        }
    });
};
cuneiform.corpuslist.getUserData = function(){
    var chtml ="";
    //userdata
    var data = cuneiform.data.user.lists;
    if(data && data != ""){
	for(var i in data){
	    chtml += "<div id='"+data[i].filepath+"'>";
	    chtml += "<h3 onclick='cuneiform.corpuslist.charts(\""+data[i].filepath+"\")'><a href='javascript://' >";
	    chtml += i+":"+data[i].files.join(",")+"</a></h3>";
	    chtml += "<div class=\"langs\"></div></div>";
	}
    }
    cuneiform.c.$select_userlist.html(chtml);
    jQuery("div#show_list").accordion('destroy').accordion({
	active: false,
	autoHeight: false,
	collapsible: true,
	header: "h3"
    });
    //show_list
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
			    'username': cuneiform.data.user.user,
			    'rebuild': 0,//set to 1 if you want to force rebuild stuff.
			    'payload': JSON.stringify(testpayload),
			    'corpusname': corpusname
		    },
    
		    success: function(data, textStatus, jqXHR) {
				cuneiform.common.spin_off();
			    cuneiform.corpuslist.results = data;
			    
			    //userdata
			    var uhtml = "";
			    if(data && data.userdata){
				for(var i in data.userdata){
				    uhtml += "<div id='"+data.userdata[i].filepath+"'>";
				    uhtml += "<h3 onclick='cuneiform.corpuslist.charts(\""+data.userdata[i].filepath+"\")'><a href='javascript://' >";
				    uhtml += i+":"+data.userdata[i].files.join(",")+"</a></h3>";
				    uhtml += "<div class=\"langs\"></div></div>";
				}
			    }
			    cuneiform.c.$select_userlist.html(uhtml);
			    
			    jQuery("div#show_list").accordion('destroy').accordion({
				active: false,
				autoHeight: false,
				collapsible: true,
				header: "h3"
			    });
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
	else{
	    
              cuneiform.common.spin_off();
	}
	
}

//show html page with all the nice pie charts
cuneiform.corpuslist.showhtml = function(lang, filepath){
        cuneiform.common.spin_on();
  	$.ajax({
		type: "GET",
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
    //have we already got the langs?
    if (cuneiform.corpuslist.charts && cuneiform.corpuslist.charts[filepath]) {
	var data = cuneiform.corpuslist.charts[filepath];
	jQuery(data.langs).each(function(){
	    var name = this;
	    name = name.replace(/\s+/g, '');
	    html +="<a href='javascript://' onclick='cuneiform.corpuslist.showhtml(\""+this+"\", \""+data.filepath+"\" )'>"+this+"</a><br/>"; 
	});
	if(html == ""){
	    html +="No lang data found";
	}
	jQuery("#"+data.filepath).find(".langs").html(html);
	
	jQuery("div#show_list").accordion('destroy').accordion({
	    active: false,
	    autoHeight: false,
	    collapsible: true,
	    header: "h3"
	});
			
    }
    else{
	//get it
  	$.ajax({
		type: "POST",
		url: cuneiform.config.chartData,
		dataType: "json",
		data: {
			'username': cuneiform.data.user.user,
			'rebuild': 0,
			'payload': filepath
		},

		success: function(data, textStatus, jqXHR) {
		    cuneiform.corpuslist.charts[filepath] = data;
		    //cuneiform.corpuslist.results = data;
		    var html = "";
		    
		    jQuery(data.langs).each(function(){
			var name = this;
			name = name.replace(/\s+/g, '');
			html +="<a href='javascript://' onclick='cuneiform.corpuslist.showhtml(\""+this+"\", \""+data.filepath+"\" )'>"+this+"</a><br/>"; 
		    });
		    if(html == ""){
			html +="No lang data found";
		    }
		    jQuery("#"+data.filepath).find(".langs").html(html);
		    
		    jQuery("div#show_list").accordion('destroy').accordion({
			active: false,
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
  
}
cuneiform.corpuslist.showCorpora = function(){
    var count = 0;
    var data = cuneiform.data.top.ALLCorpora;
    jQuery.each(data.opt.corpus, function() {
	var corpusitem = "<div class=\"jointparent\">";
	count++;
	corpusitem += "<h2  style=\"text-indent:30px; text-transform: capitalize;\">"+this.name+"</h2>";
	corpusitem += "<div style=\"height:300px; \" class=\"subitems\" >"
	jQuery.each(this, function(k, v) {
	    if (k != "name") {
		corpusitem += '<h3 style="text-transform: capitalize;">';
		corpusitem += k;
		corpusitem += '</h3> ';
		if (v.item) {
		    jQuery.each(v.item, function (l, w){
			if (w.name) {
			    corpusitem += '<div class="attempt">';
			    corpusitem += '<input type="checkbox" name="tickbox" class="cclass'+count+'" value="'+k+' - '+w.name+'" onclick="check(this)"></input>';
			    corpusitem += '<span class="subInfo" name="subInfo">'+w.name+'<br/></span>';
			    jQuery.each(w.ps, function(m,x){
				corpusitem += '<a class="ps" id="subSubInfo" style="font-size:13px; text-transform: capitalize;"> Number: <span class="littlebit">';
				corpusitem += x;//number
				corpusitem += '</span></a><br/>';
			    });
			    corpusitem += '</div>';
			}
		    });
		}   
	    }
	});
	corpusitem +="</div>"
	corpusitem +="</div>";
	jQuery("div#accordion").append(corpusitem);
    });
    jQuery("div#accordion").accordion('destroy').accordion({
	active: false,
	fillspace: true,
	autoHeight: false,
	collapsible: true,
	header: "h2"
    });
    
}
cuneiform.corpuslist.page_init = function() {
    // Fetch top feed
    if (cuneiform.data.top) {
	//get list of all Corpora
	cuneiform.corpuslist.showCorpora();
	
	//send corpus hash list to function
	cuneiform.corpuslist.sendData();
	
	
	cuneiform.corpuslist.getUserData();
    }
    else{
	$.ajax({
	    type: "GET",
	    url: cuneiform.config.urlTop,
	    dataType: "json",
	    success: function(data, textStatus, jqXHR) {
    
		if (data !== null) {
		    // Save data in memory
		    cuneiform.data.top = data;
		    
		    //get list of all Corpora
		    cuneiform.corpuslist.showCorpora();
		    
		    //send corpus hash list to function
		    cuneiform.corpuslist.sendData();
		    
		    
		    cuneiform.corpuslist.getUserData();
		    
		} else {
		    alert("The following data feed did not produce any data: "+cuneiform.config.urlTop);
		    cuneiform.data.top = {};
		}
    
	    },
	    error: function(jqXHR, textStatus, errorThrown) {
		var error_msg = "Could not load data from the feed!";
		ajaxError.apply(this, [null, jqXHR, $.ajaxSettings, errorThrown, error_msg]);
		cuneiform.data.top = {};
	    }
	});
    }
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
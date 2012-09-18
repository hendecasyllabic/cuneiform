
   
$(document).ready(function(){

        jQuery("#accordion").accordion({
              active: false,
              fillspace: true,
              autoHeight: false,
              collapsible: true,
              header: "h2"
        });
});
var submitdata = {};
var dataToShow = {};
function togglechkbk(inter, status) {
              jQuery(".cclass"+inter).each( function() {
                            jQuery(this).attr("checked",status);
                            check(this);
              })
}
        
function check(tickbox){
              var corpus = jQuery(tickbox).parents('.jointparent').children('h2').text();
              var p = jQuery(tickbox).parents('.attempt').find('span.littlebit').text();
              var thingy = {};
              thingy.checked = tickbox.checked == true;
              thingy.name = tickbox.value;
              thingy.corpus = corpus;
              thingy.p = jQuery.trim(p);
              dataToShow[thingy.corpus+":"+tickbox.value] = thingy;
              showDataOnScreen(dataToShow);
}

function showDataOnScreen(dataToShow){
              var strng = "Corpus Name:<input type='text' name='corpusname' class='corpusname'><br/>";
              submitdata = {};
              jQuery.each(dataToShow,function(name,val){
                  if(val.checked){
                            strng += "<li style=font-size:15px; text-transform:capitalize;>"+val.corpus+"<br/>"+val.name+"<br/>"+"<a class='number' style=font-weight:bold;>"+
                            val.p+"</a>"
                            +"<br />";
                            
                            var bits = val.p.split(" ");
                            for(var i in bits){
                                          submitdata[jQuery.trim(bits[i])] = 1;
                            }
                  }
              });
              jQuery("#list").html(strng);
}



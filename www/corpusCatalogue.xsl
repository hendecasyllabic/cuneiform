<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">



<xsl:template match="/">
  <html>
    <head>
        <title>corpus</title>
         <link rel="stylesheet" href="http://code.jquery.com/ui/1.8.22/themes/pepper-grinder/jquery-ui.css" type="text/css" media="all" /> 
        <!-- CSS -->
        <!-- <link rel="stylesheet" href="../www/css/custom-theme/jquery-ui-1.8.14.custom.css" type="text/css" media="screen, print" /> -->
        <link rel="stylesheet" href="../www/css/jquery.gritter.css" type="text/css" media="screen" />
        <link rel="stylesheet" href="../www/css/cuneiform.css?1" type="text/css" media="screen" />

    </head>
  <body id="body" style="background-image:url(/html/cuneiform/resources/brown.jpg);">
    
<div id="spinner" class="spinner"></div>
  <table>
    <tr>
      <td>
  <div id="accordion" style="width:500px; display: block;">
  <xsl:for-each select="opt/corpus">
    <xsl:variable name="posn" select="position()" />
    <a href="javascript://" onclick="togglechkbk('{$posn}',true)">Check All</a>
    <a href="javascript://" onclick="togglechkbk('{$posn}',false)">UnCheck All</a>
    <div class="jointparent">
          <div id="checkBox" name="corpus" style="display:none;"></div>

          <h2 style="text-indent:30px; text-transform: capitalize;"><xsl:value-of select="@name"/> </h2>
        
          <div style="height:300px; "  >
          <xsl:for-each select="*">
          <div style="font-size:20px; font-family:Calibri; text-decoration:underline;"> </div>
          <span name="SubHeading" id="subHeading" style="text-decoration:underline; font-size:19px; width:20px; text-transform: capitalize;"><xsl:value-of select="name(.)"/></span><br/> 
          <span style="font-size:15px; "></span>
          <xsl:for-each select="item">
          <div class="attempt">
            <input type="checkbox" name="tickbox" class="cclass{$posn}" value="{name}" onclick="check(this)"></input>
          <span class="subInfo" name="subInfo"><xsl:value-of select="name"/><br/></span>
            <a class="ps" id="subSubInfo" value="{name}" style="font-size:13px; text-transform: capitalize;"> Number: <span class="littlebit"><xsl:value-of select="ps"/></span></a><br/>
          </div>
          </xsl:for-each>
          </xsl:for-each>
          
          </div>
      </div>
  </xsl:for-each>
  </div>
      </td>
      <td id="items" style="vertical-align:top"><div style="height:26px;"></div><div id="list" style="background-image:url('/html/cuneiform/resources/PepperGrinder/css/pepper-grinder/images/ui-bg_fine-grain_15_eceadf_60x60.png');
      border-radius:5px; text-indent:5px; font-family:Trebuchet MS, Tahoma, Verdana, Arial, sans-serif;"></div></td>
      
      <td style="vertical-align:bottom;">
  <div style="background-image:url('/html/cuneiform/resources/PepperGrinder/css/pepper-grinder/images/ui-bg_fine-grain_10_f8f7f6_60x60.png'); border-color:black;
  border-width:1px; border-style:solid; border-radius:7px; width:200px;
  font-family:Trebuchet MS, Tahoma, Verdana, Arial, sans-serif; font-size:1.1em;
  font-weight:bolder; color:black; height:23px; display: inline-block; position:absolute; top:10px;">Selected Items:</div>

  <!-- Button and Selected Items div seem to like moving about, would be nice fix -->
      </td>
      <tr>
      </tr>
    </tr>
  </table>
    <input type="button" value="Submit Items" id="button" onclick='cuneiform.corpuslist.sendData(submitdata)'></input>
    
     <div >
            <div id="show_list" class="show_list">
                <!-- Filled by JS -->
            </div>
            <hr/>
            <div id="show_view" class="show_view">
                <!-- Filled by JS -->
            </div>
            
            <div id="langjquery" class="langjquery">
            </div>
        </div>
     
      
        <!-- Libs JS-->
        <script src="../www/lib/common-libs.js" type="text/javascript"></script>
        <script src="../www/lib/jstorage.min.js" type="text/javascript"></script>
        
        <!-- Common Lib JS-->
        <script src="../www/js/cuneiform_common.js" type="text/javascript"></script>
        <script src="../www/js/cuneiform_corpuslist.js" type="text/javascript"></script>
        <script src="../www/js/highcharts.js" type="text/javascript"></script>
        <script src="../www/js/genericchart.js" type="text/javascript"></script>
        <script src="../www/js/small.js?3" type="text/javascript"></script>
        
        <script src="../www/lib/jquery-1.5.1.min.js"></script>
        <script src="../www/lib/jquery-ui-1.8.13.custom.min.js"></script>
  <script>
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
</script>
  </body>

  </html>
</xsl:template>
</xsl:stylesheet>


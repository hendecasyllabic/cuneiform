<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xtf="http://oracc.org/ns/xtf/1.0"
		xmlns:gdl="http://oracc.org/ns/gdl/1.0"
    xmlns:xmd="http://oracc.org/ns/xmd/1.0"
    xmlns:xff="http://oracc.org/ns/xff/1.0"
    xmlns:xcl="http://oracc.org/ns/xcl/1.0"
    exclude-result-prefixes="xtf gdl xmd xff xcl"
>
    <xsl:output method="xml" indent="yes"/>

  <xsl:param name="LANGroot" select="."/>

  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
      <head>
        <link rel="stylesheet" type="text/css" href="qlab.css"/>
        <title>Language stats</title>
      </head>
      <body>
        <div id="main_content">
          <xsl:apply-templates/>
        </div>
      </body>
    </html>
  </xsl:template>

  <xsl:template match=""> <!-- match all children of opt-->
    
  </xsl:template>
  
  
</xsl:stylesheet>

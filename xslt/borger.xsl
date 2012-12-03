<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    exclude-result-prefixes="xs fn"
    version="2.0">

   
   <!-- Note that numbers are NOT in the list YET -->
   
    <!-- download Saxon -->
    <!-- run with: Transform ..\dataoutNEW\P...-Borger.xml borger.xsl > Output.html -->
    
    <!-- Identity transformation -->
     <xsl:template match="*">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="@*">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <!-- root -->
    <xsl:template match="/">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                <title>Borger Sign List</title>
		<style type="text/css">
                    @font-face {
                       font-family: 'Cuneiform NA';
                       font-style: normal;
                       font-weight: 400;
                       src: url(CuneiformNA.woff);
                    }
                    .cuneiform {
                        font-family: 'Cuneiform NA';
                    }
                </style>
            </head>
            <body>                
                <xsl:apply-templates/> <!-- for BorgerNo and splitWords-->
            </body>
        </html>
    </xsl:template>
    
    <xsl:template match="BorgerNo">
        <table>
            <thead>
            <tr>
                <td>
                    <h1><xsl:value-of select="@name"/></h1>
                </td>
                <td>
                    <h1>
                    <xsl:variable name="cun" select="@Cuneicode"/>
                    <xsl:choose>
                        <xsl:when test="contains($cun, '#004C;')">
                            <xsl:value-of select="$cun"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <strong class="cuneiform">
                                <xsl:value-of select="$cun"/>
                            </strong>
                        </xsl:otherwise>
                    </xsl:choose>
                    </h1>
                </td>
                <td>
                    <h1><xsl:value-of select="@BorgerVal"/></h1>
                </td>
            </tr>
            </thead>
            <tbody>
                <xsl:apply-templates select="lang/category" mode="general"/>   
                <xsl:apply-templates select="formvar"/>  <!-- to be added; not in Hammurabi TODO -->
            </tbody>
        </table>
        <h3>Summary of usage</h3>
        <table>
            <thead>
                <tr>
                    <td>Category</td>
                    <td>Value</td>
                    <td>Initial</td>
                    <td>Medial</td>
                    <td>Final</td>
                    <td>Alone</td>
                    <td>Total</td>
                </tr>
            </thead>
            <tbody>
                <xsl:apply-templates select="lang/category" mode="summary"/>
            </tbody>
        </table>
        <h3>Attestations</h3>
        <xsl:apply-templates select="lang/category" mode="detail"/>
    </xsl:template>
    
    
    <xsl:template match="category" mode="general">
        <tr>
            <xsl:variable name="cat"><xsl:value-of select="@name"/></xsl:variable>
            <td></td>
            <td>
                <xsl:value-of select="$cat"/>
            </td>
            <td>
                <xsl:apply-templates select="abstract" mode="general"/>
                <xsl:apply-templates select="value" mode="general"/>
            </td>
            <td>
                <xsl:if test="$cat eq 'logogram'">
                    <xsl:apply-templates select=".//pos" mode="general"/>
                </xsl:if>
            </td>
        <!--<xsl:apply-templates/>-->
        </tr>
    </xsl:template>
    
    <xsl:template match="abstract" mode="general">
        <xsl:apply-templates select="value" mode="general"/>
    </xsl:template>
    
    <xsl:template match="value" mode="general">
        <xsl:value-of select="@name"/> <!-- needs comma when more than one -->
        <xsl:text>, </xsl:text>
    </xsl:template>
    
    <xsl:template match="pos" mode="general">
        <xsl:variable name="pos"><xsl:value-of select="@name"/></xsl:variable>
        <xsl:if test="$pos eq 'alone'">
            <xsl:variable name="currentValue" select="../../@name"/>
            <xsl:apply-templates select=".//gw" mode="general">
                <xsl:with-param name="var1" select="$currentValue" tunnel="yes"/>
            </xsl:apply-templates>
            <!--ok <xsl:value-of select="$currentValue"/>-->
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="gw" mode="general">
        <xsl:param name="var1" tunnel="yes"/>
        <xsl:value-of select="$var1"/>
        = <xsl:value-of select="@name"></xsl:value-of>
        <xsl:apply-templates select="cf" mode="general"/>
    </xsl:template>
    
    <xsl:template match="cf" mode="general">
        <xsl:variable name="citation"><xsl:value-of select="@name"/></xsl:variable>
        <xsl:if test="$citation ne ''">
            = <xsl:value-of select="$citation"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="category" mode="summary">
        <xsl:variable name="cat"><xsl:value-of select="@name"/></xsl:variable>
        <xsl:choose>
            <xsl:when test="$cat eq 'syllabic'">
                <xsl:apply-templates select="abstract" mode="summary">
                    <xsl:with-param name="var2" select="$cat" tunnel="yes"/>
                </xsl:apply-templates>        
            </xsl:when>
            <xsl:when test="$cat eq 'punct'">
                <!-- TODO: fill in total in alone column!!! -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select=".//value" mode="summary">
                    <xsl:with-param name="var3" select="$cat" tunnel="yes"/>
                </xsl:apply-templates>        
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="abstract" mode="summary">
        <xsl:param name="var2" tunnel="yes"/>
        
        <!-- check how many values there are under abstract; if more than one: give stats, otherwise forget about this -->
        <xsl:choose>
            <xsl:when test="count(value) &gt; 1">
		<tr>
                    <td><strong><xsl:value-of select="$var2"/></strong></td>
                    <td><strong><xsl:value-of select="@name"/></strong></td>
                    <td><strong>
                        <xsl:variable name="val1">
                            <xsl:value-of select="attested[@name='All_attested']/@initial"/>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$val1 ne ''">
                                <xsl:value-of select="$val1"/>
                            </xsl:when>
                            <xsl:otherwise>0</xsl:otherwise>    
                        </xsl:choose>
                        </strong>
                    </td>
                    <td>
                        <strong>
                        <xsl:variable name="val1">
                            <xsl:value-of select="attested[@name='All_attested']/@medial"/>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$val1 ne ''">
                                <xsl:value-of select="$val1"/>
                            </xsl:when>
                            <xsl:otherwise>0</xsl:otherwise>    
                        </xsl:choose>
                        </strong>
                    </td>
                    <td>
                        <strong>
                        <xsl:variable name="val1">
                            <xsl:value-of select="attested[@name='All_attested']/@final"/>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$val1 ne ''">
                                <xsl:value-of select="$val1"/>
                            </xsl:when>
                            <xsl:otherwise>0</xsl:otherwise>    
                        </xsl:choose>
                        </strong>
                    </td>
                    <td>
                        <strong>
                        <xsl:variable name="val1">
                            <xsl:value-of select="attested[@name='All_attested']/@alone"/>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$val1 ne ''">
                                <xsl:value-of select="$val1"/>
                            </xsl:when>
                            <xsl:otherwise>0</xsl:otherwise>    
                        </xsl:choose>
                        </strong>
                    </td>
                    <td>
                        <strong>
                        <xsl:variable name="val1">
                            <xsl:value-of select="attested[@name='All_attested']/@total"/>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$val1 ne ''">
                                <xsl:value-of select="$val1"/>
                            </xsl:when>
                            <xsl:otherwise>0</xsl:otherwise>    
                        </xsl:choose>
                        </strong>
                    </td>
                </tr>   
            </xsl:when>
            <xsl:otherwise>
                
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:apply-templates select=".//value" mode="summary">
            <xsl:with-param name="var3" select="$var2" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="value" mode="summary">
        <xsl:param name="var3" tunnel="yes"/>
        <tr>
            <td><xsl:value-of select="$var3"/></td>
            <td><xsl:value-of select="@name"/></td>
            <td>
                <xsl:variable name="val1">
                    <xsl:value-of select="attested[@name='All_attested']/@initial"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$val1 ne ''">
                        <xsl:value-of select="$val1"/>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>    
                </xsl:choose>
            </td>
            <td>
                <xsl:variable name="val1">
                    <xsl:value-of select="attested[@name='All_attested']/@medial"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$val1 ne ''">
                        <xsl:value-of select="$val1"/>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>    
                </xsl:choose>
            </td>
            <td>
                <xsl:variable name="val1">
                    <xsl:value-of select="attested[@name='All_attested']/@final"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$val1 ne ''">
                        <xsl:value-of select="$val1"/>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>    
                </xsl:choose>
            </td>
            <td>
                <xsl:variable name="val1">
                    <xsl:value-of select="attested[@name='All_attested']/@alone"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$val1 ne ''">
                        <xsl:value-of select="$val1"/>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>    
                </xsl:choose>
            </td>
            <td>
                <xsl:variable name="val1">
                    <xsl:value-of select="attested[@name='All_attested']/@total"/>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$val1 ne ''">
                        <xsl:value-of select="$val1"/>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>    
                </xsl:choose>
            </td>
        </tr>
    </xsl:template>

    <xsl:template match="category" mode="detail">
        <xsl:variable name="cat" select="@name"/>
        
        <h3>
        <xsl:choose>
            <xsl:when test="$cat eq 'logogram'">
                <xsl:text>Logographic value(s)</xsl:text>
            </xsl:when>
            <xsl:when test="$cat eq 'syllabic'">
                <xsl:text>Syllabic value(s)</xsl:text>
            </xsl:when>
            <xsl:when test="$cat eq 'determinative'">
                <xsl:text>Determinative(s)</xsl:text>
            </xsl:when>
            <xsl:when test="$cat eq 'phonetic'">
                <xsl:text>Phonetic complement(s)</xsl:text>
            </xsl:when>
            <xsl:when test="$cat eq 'punct'">
                <xsl:text>Punctuation marks</xsl:text>
            </xsl:when>
            <xsl:when test="$cat eq 'number'">
                <xsl:text>Numbers</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$cat"/>
            </xsl:otherwise>
        </xsl:choose>
        </h3>
        
        <xsl:choose>
            <xsl:when test="$cat eq 'syllabic'">
                <xsl:apply-templates select="abstract" mode="detail"/>
            </xsl:when>
            <xsl:when test="$cat eq 'punct'">
                <!-- TODO: fill in  -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select=".//value" mode="detail"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="abstract" mode="detail">
        <xsl:apply-templates select="value" mode="detail"/>
    </xsl:template>
    
    <xsl:template match="value" mode="detail">
        <!-- only if some values are preserved/damaged/excised -->
        <xsl:if test="(count(state[@name='preserved']) &gt; 0) or (count(state[@name='damaged']) &gt; 0) or (count(state[@name='excised']) &gt; 0)">
            <xsl:variable name="currentValue" select="@name"/>
            <p><strong><xsl:value-of select="$currentValue"/></strong></p>
            <table>
                <thead>
                    <td>Position</td>
                    <td>Wordtype</td>
                    <td>Guide word</td>
                    <td>Citation form</td>
                    <td>Written word</td>
                    <td>Attestations</td>
                </thead>
                <tbody>
                    <xsl:variable name="ini">
                        <xsl:value-of select="attested[@name='All_attested']/@initial"/>
                    </xsl:variable>
                    <xsl:if test="$ini ne ''">
                        <xsl:apply-templates select=".//pos[@name='initial']" mode="detail">
                            <xsl:with-param name="posit" select="'initial'" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:if>
                    
                    <xsl:variable name="med">
                        <xsl:value-of select="attested[@name='All_attested']/@medial"/>
                    </xsl:variable>
                    <xsl:if test="$med ne ''">
                        <xsl:apply-templates select=".//pos[@name='medial']" mode="detail">
                            <xsl:with-param name="posit" select="'medial'" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:if>
                    
                    <xsl:variable name="fin">
                        <xsl:value-of select="attested[@name='All_attested']/@final"/>
                    </xsl:variable>
                    <xsl:if test="$fin ne ''">
                        <xsl:apply-templates select=".//pos[@name='final']" mode="detail">
                            <xsl:with-param name="posit" select="'final'" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:if>
                    
                    <xsl:variable name="alo">
                        <xsl:value-of select="attested[@name='All_attested']/@alone"/>
                    </xsl:variable>
                    <xsl:if test="$alo ne ''">
                        <xsl:apply-templates select=".//pos[@name='alone']" mode="detail">
                            <xsl:with-param name="posit" select="'alone'" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:if>
                    
                </tbody>
            </table>    
        </xsl:if>
        
        
    </xsl:template>
    
    <xsl:template match="pos" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:variable name="preserved" select=".//state[@name='preserved']/@num"/>
        <xsl:variable name="damaged" select=".//state[@name='damaged']/@num"/>
        <xsl:variable name="excised" select=".//state[@name='excised']/@num"/>
        <xsl:if test="$preserved &gt; 0 or $damaged &gt; 0 or $excised &gt; 0">
            <xsl:apply-templates select="wordtype" mode="detail">
                <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            </xsl:apply-templates>
            <!-- if no wordtype then go to gw -->
            <xsl:apply-templates select="gw" mode="detail">
                <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
                <xsl:with-param name="wtype" select="'-'" tunnel="yes"/>
            </xsl:apply-templates>
            
            <!-- if no wordtype and no gw, go to cf -->
            <xsl:apply-templates select="cf" mode="detail">
                <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
                <xsl:with-param name="wtype" select="'-'" tunnel="yes"/>
                <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
            </xsl:apply-templates>
        
            <!-- if no wordtype, no gw and no cf, go to state -->
            <xsl:apply-templates select="state" mode="detail">
                <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
                <xsl:with-param name="wtype" select="'-'" tunnel="yes"/>
                <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
                <xsl:with-param name="cf" select="'-'" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="wordtype" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:variable name="wtype" select="@name"/>
        <xsl:apply-templates select="gw" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
        </xsl:apply-templates>
        
        <!-- if no gw, go to cf-->
        <xsl:apply-templates select="cf" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
        
        <!-- if no gw and no cf, go to state -->
        <xsl:apply-templates select="state" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
            <xsl:with-param name="cf" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="gw" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:variable name="gw" select="@name"/>
        <xsl:apply-templates select="cf" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
        </xsl:apply-templates>
        <!-- if no cf then go immediately to state, with cf = '-' -->
        <xsl:apply-templates select="state" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
            <xsl:with-param name="cf" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="cf" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:param name="gw" tunnel="yes"/>
        <xsl:variable name="cf" select="@name"/>
        <xsl:apply-templates select="state" mode="detail">
            <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
            <xsl:with-param name="cf" select="$cf" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="state" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:param name="gw" tunnel="yes"/>
        <xsl:param name="cf" tunnel="yes"/>
        <xsl:variable name="stateName" select="@name"/>
        <xsl:if test="$stateName eq 'preserved'"> <!-- or damaged or excised -->
            <xsl:apply-templates select="writtenWord" mode="detail">
                <xsl:with-param name="posit" select="$posit" tunnel="yes"/>
                <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
                <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
                <xsl:with-param name="cf" select="$cf" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <xsl:template match="writtenWord" mode="detail">
        <xsl:param name="posit" tunnel="yes"/>
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:param name="gw" tunnel="yes"/>
        <xsl:param name="cf" tunnel="yes"/>
        <xsl:variable name="written" select="@name"/>

        <tr>        
            <td><xsl:value-of select="$posit"/></td>
            <td><xsl:value-of select="$wtype"/></td>
            <td><xsl:value-of select="$gw"/></td>
            <td><xsl:value-of select="$cf"/></td>
            <td><xsl:value-of select="$written"/></td>
            <td>
                <xsl:apply-templates select="line" mode="detail"/>
            </td>
        </tr>
    </xsl:template>
    
    <xsl:template match="line" mode="detail">
        <xsl:value-of select="."/>
        <xsl:text>, </xsl:text>
    </xsl:template>
    
    <xsl:template match="splitWords"> 
        <!--<h1>Words written over one or more lines</h1>
        <table>
            <thead>
                <td>Wordtype</td>
                <td>Guide word</td>
                <td>Citation form</td>
                <td>Written word</td>
                <td>Attestations</td>
            </thead>
            <tbody>
                <xsl:apply-templates select=".//wordtype" mode="split"/>
            </tbody>
        </table>-->
    </xsl:template>
    
    <xsl:template match="wordtype" mode="split">
        <xsl:variable name="wtype" select="@name"/>
        <xsl:apply-templates select="gw" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="cf" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="writtenWord" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="'-'" tunnel="yes"/>
            <xsl:with-param name="cf" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="gw" mode="split">
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:variable name="gw" select="@name"/>
        <xsl:apply-templates select="cf" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="writtenWord" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
            <xsl:with-param name="cf" select="'-'" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="cf" mode="split">
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:param name="gw" tunnel="yes"/>
        <xsl:variable name="cf" select="@name"/>
        <xsl:apply-templates select="writtenWord" mode="split">
            <xsl:with-param name="wtype" select="$wtype" tunnel="yes"/>
            <xsl:with-param name="gw" select="$gw" tunnel="yes"/>
            <xsl:with-param name="cf" select="$cf" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="writtenWord" mode="split">
        <xsl:param name="wtype" tunnel="yes"/>
        <xsl:param name="gw" tunnel="yes"/>
        <xsl:param name="cf" tunnel="yes"/>
        <xsl:variable name="written" select="@name"/>
        <tr>
            <td><xsl:value-of select="$wtype"/></td>
            <td><xsl:value-of select="$gw"/></td>
            <td><xsl:value-of select="$cf"/></td>
            <td><xsl:value-of select="$written"/></td>
            <td>
                <xsl:apply-templates select="label" mode="split"/>
            </td>
        </tr>
    </xsl:template>
    
    <xsl:template match="label" mode="split">
        <xsl:value-of select="."/>
        <xsl:text>, </xsl:text>
    </xsl:template>
    
</xsl:stylesheet>
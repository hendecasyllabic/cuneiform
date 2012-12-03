<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    
    <!-- Statistical information about corpus: no of texts, words, signs etc.-->
    
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
                <title>Signs listed according to frequency</title>
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
               <table>
                    <thead>
                        <td>Sign</td>
                        <td>Reading</td>
                        <td>Times attested</td>
                        <td>Borger no.</td>
                    </thead>
                    <xsl:apply-templates select=".//value">
                        <xsl:sort select="attested[@name='All_attested']/@total" order="descending" data-type="number"/>
                        <xsl:sort select="ancestor::BorgerNo/@name" />
                    </xsl:apply-templates>
                </table>           
            </body>
        </html>
    </xsl:template>
    
    <!--<xsl:template match="/">
        <xsl:apply-templates select=".//value">
            <xsl:sort select="attested[@name='All_attested']/@total" order="descending" data-type="number"/>
        </xsl:apply-templates>
    </xsl:template>-->
    
    <xsl:template match="value">
        <tr>
            <td>
                <xsl:variable name="cun" select="ancestor::BorgerNo/@Cuneicode"/>
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
            </td>
            <td><xsl:value-of select="@name"/></td>
            <td><xsl:value-of select="attested[@name='All_attested']/@total"/></td>
            <td><xsl:value-of select="ancestor::BorgerNo/@name"/></td>
        </tr>
    </xsl:template>
    
    <xsl:template match="category">
        
    </xsl:template>
    
    
    
</xsl:stylesheet>
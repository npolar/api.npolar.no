<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <xsl:template match="/">
    <add>
          <xsl:apply-templates select="/xml/records/record"/>
    </add>
  </xsl:template>


  <xsl:template match="record">
     <doc>
        <field name="id"><xsl:value-of select="database"/>-<xsl:value-of select="rec-number"/></field>
        <field name="source">ru_polar_bear_publications</field>
        <xsl:apply-templates select="titles"/>
        <xsl:apply-templates select="keywords/keyword"/>
        <xsl:apply-templates select="dates/year"/>
        <xsl:apply-templates select="periodical"/>
        <xsl:apply-templates select="abstract"/>
        <xsl:apply-templates select="volume"/>
        <xsl:apply-templates select="pages"/>
        <xsl:apply-templates select="contributors/authors/author"/>
      </doc>
  </xsl:template>
  
  <xsl:template match="periodical">
        <field name="periodical"><xsl:value-of select="full-title"/></field>
  </xsl:template>
 
  <xsl:template match="abstract">
        <field name="abstract"><xsl:value-of select="."/></field>
  </xsl:template>

 
  <xsl:template match="titles">
        <field name="title"><xsl:value-of select="title"/></field>
        <field name="secondaryTitle"><xsl:value-of select="secondary-title"/></field>
  </xsl:template>
  
  <xsl:template match="author">
        <field name="author"><xsl:value-of select="normalize-space(.)"/></field>
  </xsl:template>


  <xsl:template match="keyword">
        <field name="keyword"><xsl:value-of select="normalize-space(.)"/></field>
  </xsl:template>


  <xsl:template match="year">
        <field name="year"><xsl:value-of select="normalize-space(.)"/></field>
  </xsl:template>

  <xsl:template match="pages">
        <field name="pages"><xsl:value-of select="."/></field>
  </xsl:template>
  <xsl:template match="volume">
        <field name="volume"><xsl:value-of select="style"/></field>
  </xsl:template>



</xsl:stylesheet>

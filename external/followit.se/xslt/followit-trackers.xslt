<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:f="http://tempuri.org/">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>
  <xsl:strip-space elements="*"/>
<!--
  Transform [Followit  XML] Tracking Deployment JSON
  
  Usage:
    xsltproc xslt/followit-trackers.xslt npolar.no/trackers.xml | ruby -e "require 'json'; puts JSON.parse(ARGF.read).to_json"
-->

<xsl:param name="comment" select="''"/>
<xsl:param name="schema" select="'http://api.npolar.no/schema/tracking-deployment-1'"/>
<xsl:param name="object" select="'Svalbard reindeer'"/>
<xsl:param name="species" select="'Rangifer tarandus platyrhynchus'"/>

<xsl:template match="/">  
[<xsl:for-each select="//f:GetResult/f:Tracker">

{ "provider": "followit.se",
  "platform": "<xsl:value-of select="f:TrackerId"/>",
  "platform_model": "<xsl:value-of select="f:ObjectType"/>",
  "platform_name": "<xsl:value-of select="f:Name"/>",
  "individual": null,
  "species": "<xsl:value-of select="$species"/>",
  "object": "<xsl:value-of select="$object"/>",
  "technology": "gps",
  "imei":  "<xsl:value-of select="f:IMEI"/>",
  "deployed": null,
  "registered": "<xsl:value-of select="f:RegistrationDate"/>Z",
  "links": [{"rel": "related", "href": "http://followit.se"}],
  "comment": "<xsl:value-of select="$comment"/>",
  "longitude": <xsl:value-of select="f:Lng"/>,
  "latitude": <xsl:value-of select="f:Lat"/>,
  "positioned": "<xsl:value-of select="f:EventDate"/>Z"
}<xsl:choose><xsl:when test="position() &lt; last()">,</xsl:when></xsl:choose>
</xsl:for-each>]
</xsl:template>
</xsl:stylesheet>
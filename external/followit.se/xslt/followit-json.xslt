<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
  xmlns:f="http://tempuri.org/">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>
  <xsl:strip-space elements="*"/>
<!--
  Transform [Followit GetUnitReportPosition XML](http://total.followit.se/DataAccess/TrackerService.asmx?op=GetUnitReportPositions) to Tracking JSON v1 (http://api.npolar.no/schema/tracking-1)
  
  Usage:
    xsltproc xslt/followit-json.xslt GetUnitReportPositions.xml | ruby -e "require 'json'; puts JSON.parse(ARGF.read).to_json"
  
  Example (abbr.) input:
    <UnitReportPosition>
      <TrafficType>1</TrafficType>
      <TrackerId>11531</TrackerId>
      <RegDate xsi:nil="true"/>
      <EventDate>2015-03-23T00:00:42</EventDate>
      <Latitude>78.95951</Latitude>
      <Longitude>11.61548</Longitude>
      <Power>3.28 V</Power>
      <Speed>0.00</Speed>
      <Course>0.00</Course>
      <Status xsi:nil="true"/>
      <MagneticDeviation xsi:nil="true"/>
      <DeltaDist xsi:nil="true"/>
      <TidFix>42</TidFix>
      <nSats>7</nSats>
      <nAlt>52</nAlt>
      <fHDOP>1.4</fHDOP>
      <nFOM xsi:nil="true"/>
      <nActivityX>0</nActivityX>
      <nActivityY>0</nActivityY>
      <nDCDC xsi:nil="true"/>
      <TrafficGPSExtendedId>8718232</TrafficGPSExtendedId>
      <Temperature>-2.00</Temperature>
      <ObjectLineTypeID>2</ObjectLineTypeID>
      <nInfo>3D</nInfo>
    </UnitReportPosition>
-->
<!--
Additional documentation from Followit:

  Angående <EventDate>, tiden är alltid angiven i GMT.
  Fälten Status, MagneticDeviation, DeltaDist och nFOM innehåller bara data om detta är programmerat via TPM, I annat fall är de nil.
  Fälten Speed och Course används inte av Tellus-enheter.
  
  nActivityX, nActivityY - Ett numeriskt värde som saknar enhet. Ju högre värde desto mer rörelse i resp led. Rent tekniskt mäts om det finns någon rörelse i X och Y led varje sekund under TTF.
  TidFix - Time To Fix, tid i sekunder det tar att få en GPS position.
  nSats - Antal satelliter som hittats / använts.
  nAlt - Höjd över havet i meter.
  ObjectLineTypeID - GEO-specifikt data, ej relevant.
  TrafficGPSExtendedId - GEO-specifikt data, ej relevant.
  TrafficType - GEO-specifikt data, ej relevant.
  nDCDC- ?
-->
<xsl:param name="filename" select="''"/>
<xsl:param name="schema" select="'http://api.npolar.no/schema/tracking-1'"/>
<xsl:param name="object" select="'Svalbard reindeer'"/>
<xsl:param name="species" select="'Rangifer tarandus platyrhynchus'"/>
<xsl:param name="voltage" select="substring-after(substring-before(f:Power, ' V'), ' ')"/>
  
<xsl:template match="/">[<xsl:for-each select="//f:GetUnitReportPositionsResult/f:UnitReportPosition">
{ "measured": "<xsl:value-of select="f:EventDate"/>Z",
  "latitude": <xsl:value-of select="f:Latitude"/>,
  "longitude": <xsl:value-of select="f:Longitude"/>,
  "altitude": <xsl:choose><xsl:when test="number(f:nAlt) = f:nAlt"><xsl:value-of select="f:nAlt"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,
  "platform": "<xsl:value-of select="f:TrackerId"/>",
  "temperature": <xsl:choose><xsl:when test="number(f:Temperature) = f:Temperature"><xsl:value-of select="f:Temperature"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,
  "battery_voltage": <xsl:choose><xsl:when test="number($voltage) = $voltage"><xsl:value-of select="$voltage"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,
  "schema": "<xsl:value-of select="$schema"/>",
  "species": "<xsl:value-of select="$species"/>",
  "object": "<xsl:value-of select="$object"/>",
  "provider": "followit.se",
  "technology": "gps",
  "activity_x": <xsl:choose><xsl:when test="number(f:nActivityX) = f:nActivityX"><xsl:value-of select="f:nActivityX"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,  
  "activity_y": <xsl:choose><xsl:when test="number(f:nActivityY) = f:nActivityY"><xsl:value-of select="f:nActivityY"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,  
  "hdop": <xsl:choose><xsl:when test="number(f:fHDOP) = f:fHDOP"><xsl:value-of select="f:fHDOP"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,  
  "comment": "<xsl:value-of select="f:nInfo"/>",
  "satellites": <xsl:choose><xsl:when test="number(f:nSats) = f:nSats"><xsl:value-of select="f:nSats"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>,
  "time_to_fix": <xsl:choose><xsl:when test="number(f:TidFix) = f:TidFix"><xsl:value-of select="f:TidFix"/></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>
}<xsl:choose><xsl:when test="position() &lt; last()">,</xsl:when></xsl:choose>
</xsl:for-each>]
</xsl:template>
</xsl:stylesheet>
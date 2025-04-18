<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-25 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:ltx="http://dlmf.nist.gov/LaTeXML"
  xmlns:b="https://vlmantova.github.io/bookml/functions"
  xmlns:exsl="http://exslt.org/common"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="exsl str">

  <xsl:import href="utils.xsl"/>

  <xsl:output
    method="text"
    encoding="utf-8" />

  <xsl:param name="BML_TARGET" />

  <xsl:template match="/">
    <xsl:if test="$BMLSTYLE='gitbook'">
      <xsl:value-of select="$BML_TARGET" /><xsl:text>: LATEXMLPOSTAUTOFLAGS=--navigationtoc=context&#x0A;</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="//ltx:resource | //ltx:graphics/@candidates" />
  </xsl:template>

  <xsl:template match="ltx:resource">
    <xsl:value-of select="$BML_TARGET" /><xsl:text>: </xsl:text><xsl:value-of select="@src" /><xsl:text>&#x0A;</xsl:text>
    <xsl:value-of select="@src" /><xsl:text>:&#x0A;</xsl:text>
  </xsl:template>

  <!-- convert PDF and EPS to SVG using dvisvgm (instead of letting LaTeXML rely on ImageMagick) -->
  <xsl:template match="ltx:graphics/@candidates">
    <xsl:variable name="candidates" select="str:split(str:replace(.,'\','/'),',')" />

    <!-- find page number, if specified -->
    <xsl:variable name="escaped-options" select="str:replace(../@options,'\,','-NOTCOMMA-')" />
    <xsl:variable name="page">
      <!-- TODO: select *last* occurrence of page option -->
      <xsl:variable name="page-option" select="str:split($escaped-options,',')/text()[starts-with(.,'page=')]" />
      <xsl:value-of select="substring-after($page-option,'page=')" />
    </xsl:variable>

    <!-- find if we have a scalable candidate (SVG, PDF, EPS) -->
    <xsl:variable name="scalable">
      <xsl:choose>
        <xsl:when test="$candidates//text()[contains(b:lower-case(.),'.svg') or contains(b:lower-case(.),'.pdf') or contains(b:lower-case(.),'.eps')]">
          <xsl:value-of select="$candidates//text()[contains(b:lower-case(.),'.svg') or contains(b:lower-case(.),'.pdf') or contains(b:lower-case(.),'.eps')]" />
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="ext" select="b:lower-case(substring($scalable,string-length($scalable)-2))" />

    <!-- if $scalable is not below the current folder, we remove the folder, as latexmlpost would do -->
    <xsl:variable name="scalable-without-parent">
      <xsl:choose>
        <!-- Win32: also check if path starts with drive letter -->
        <xsl:when test="substring($scalable,2,1)=':' or starts-with($scalable,'/') or starts-with($scalable,'../')">
          <xsl:value-of select="str:split($scalable,'/')[last()]//text()" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$scalable" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="converted">
      <xsl:choose>
        <!-- if the image is already an SVG, no need for conversion -->
        <xsl:when test="$ext = 'svg'"><xsl:value-of select="$scalable" /></xsl:when>
        <!-- otherwise, we ask make to create an SVG -->
        <xsl:otherwise>
          <xsl:text>bmlimages/svg/</xsl:text>
          <xsl:choose>
            <xsl:when test="$page != ''">
              <xsl:value-of select="$scalable-without-parent" />
              <xsl:text>/p</xsl:text>
              <xsl:value-of select="$page" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="substring($scalable-without-parent,1,string-length($scalable-without-parent)-4)" />
            </xsl:otherwise>
          </xsl:choose>
          <xsl:text>.svg</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="$scalable != ''">
        <xsl:value-of select="$BML_TARGET" />
        <xsl:text>: </xsl:text>
        <xsl:value-of select="$converted" />
        <xsl:text>&#x0A;</xsl:text>
        <xsl:choose>
          <xsl:when test="$ext = 'svg'">
            <!-- the file may have been produced externally, do not try to build it if there is no rule for it -->
            <xsl:value-of select="$converted" />
            <xsl:text>:&#x0A;</xsl:text>
          </xsl:when>
          <xsl:when test="$scalable-without-parent != $scalable or $page != ''">
            <!-- the make pattern rule will not catch this one, it must be produced by hand -->
            <xsl:value-of select="$converted" />
            <xsl:text>: </xsl:text>
            <xsl:value-of select="$scalable" />
            <xsl:text> | bmlimages/svg</xsl:text>
            <xsl:if test="$page != ''">
              <xsl:text>/</xsl:text>
              <xsl:value-of select="$scalable-without-parent" />
            </xsl:if>
            <!-- WARNING: must be kept in sync with bookml.mk -->
            <xsl:text>&#x0A;&#x09;@$(call bml.cmd,$(DVISVGM) $(DVISVGMFLAGS) --</xsl:text>
            <xsl:value-of select="$ext" />
            <xsl:if test="$page != ''">
              <xsl:text> --page=</xsl:text>
              <xsl:value-of select="$page" />
            </xsl:if>
            <xsl:text> "$&lt;" --output="$@")&#x0A;</xsl:text>
          </xsl:when>
          <!-- remaining case bmlimages/svg/... will be handled by the make pattern rules %.svg: -->
        </xsl:choose>
      </xsl:when>

      <!-- if none of SVG, PDF, EPS is present, do not guess LaTeXML's preference: rebuild when any candidate has changed -->
      <xsl:otherwise>
        <xsl:for-each select="$candidates">
          <xsl:value-of select="$BML_TARGET" />
          <xsl:text>: </xsl:text>
          <xsl:value-of select="string()" />
          <xsl:text>&#x0A;</xsl:text>
          <xsl:value-of select="string()" />
          <xsl:text>:&#x0A;</xsl:text>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>

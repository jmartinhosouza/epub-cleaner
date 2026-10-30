<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:opf="http://www.idpf.org/2007/opf"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    exclude-result-prefixes="opf dc">

    <xsl:param name="title"/>
    <xsl:param name="author"/>
    <xsl:param name="language"/>
    <xsl:param name="identifier"/>
    <xsl:param name="modified"/>
    <xsl:param name="css-href"/>
    <xsl:param name="cover-href"/>

    <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="opf:metadata">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>

            <dc:title>
                <xsl:value-of select="$title"/>
            </dc:title>

            <dc:creator>
                <xsl:value-of select="$author"/>
            </dc:creator>

            <dc:language>
                <xsl:value-of select="$language"/>
            </dc:language>

            <dc:identifier id="pub-id">
                <xsl:value-of select="$identifier"/>
            </dc:identifier>

            <xsl:if test="/*/@version = '3.0'">
                <opf:meta property="dcterms:modified">
                    <xsl:value-of select="$modified"/>
                </opf:meta>
            </xsl:if>

            <xsl:if test="not(/*/@version = '3.0')">
                <opf:meta name="cover" content="cover-image"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="opf:metadata/dc:title"/>
    <xsl:template match="opf:metadata/dc:creator"/>
    <xsl:template match="opf:metadata/dc:language"/>
    <xsl:template match="opf:metadata/dc:identifier"/>
    <xsl:template match="opf:metadata/opf:meta"/>

    <xsl:template match="opf:manifest/opf:item[
        starts-with(@media-type, 'image/')
        or @media-type = 'text/css'
    ]"/>

    <xsl:template match="opf:manifest">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>

            <opf:item
                id="stylesheet"
                href="{$css-href}"
                media-type="text/css"/>

            <opf:item
                id="cover-image"
                href="{$cover-href}"
                media-type="image/jpeg">
                <xsl:if test="/*/@version = '3.0'">
                    <xsl:attribute name="properties">cover-image</xsl:attribute>
                </xsl:if>
            </opf:item>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>

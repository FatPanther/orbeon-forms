<?xml version="1.0" encoding="UTF-8"?>
<!--
    Copyright (C) 2009 Orbeon, Inc.

    This program is free software; you can redistribute it and/or modify it under the terms of the
    GNU Lesser General Public License as published by the Free Software Foundation; either version
    2.1 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Lesser General Public License for more details.

    The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
-->
<xsl:transform xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xbl="http://www.w3.org/ns/xbl" xmlns:xxbl="http://orbeon.org/oxf/xml/xbl"
    xmlns:fr="http://orbeon.org/oxf/xml/form-runner"
    xmlns:oxf="http://www.orbeon.com/oxf/processors" xmlns:exf="http://www.exforms.org/exf/1-0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">

    <xsl:variable name="parameters">
        <!-- These optional attributes are used as parameters -->
        <parameter>appearance</parameter>
        <parameter>scrollable</parameter>
        <parameter>width</parameter>
        <parameter>height</parameter>
        <parameter>paginated</parameter>
        <parameter>rowsPerPage</parameter>
        <parameter>sortAndPaginationMode</parameter>
        <parameter>nbPages</parameter>
        <parameter>maxNbPagesToDisplay</parameter>
        <parameter>page</parameter>
        <parameter>innerTableWidth</parameter>
        <parameter>loading</parameter>
        <parameter>dynamic</parameter>
        <parameter>debug</parameter>
    </xsl:variable>


    <xsl:variable name="numberTypes">
        <type>xs:decimal</type>
        <type>xs:integer</type>
        <type>xs:nonPositiveInteger</type>
        <type>xs:negativeInteger</type>
        <type>xs:long</type>
        <type>xs:int</type>
        <type>xs:short</type>
        <type>xs:byte</type>
        <type>xs:nonNegativeInteger</type>
        <type>xs:unsignedLong</type>
        <type>xs:unsignedInt</type>
        <type>xs:unsignedShort</type>
        <type>xs:unsignedByte</type>
        <type>xs:positiveInteger</type>
    </xsl:variable>
    <xsl:variable name="numberTypesEnumeration">
        <xsl:for-each select="$numberTypes/*">
            <xsl:if test="position() >1">,</xsl:if>
            <xsl:text>resolve-QName('</xsl:text>
            <xsl:value-of select="."/>
            <xsl:text>', $fr-dt-datatable-instance)</xsl:text>
        </xsl:for-each>
    </xsl:variable>

    <!-- Perform pass 1 to 4 to support simplified syntaxes -->
    <xsl:variable name="pass1">
        <xsl:apply-templates select="/" mode="pass1"/>
    </xsl:variable>

    <xsl:variable name="pass2">
        <xsl:apply-templates select="$pass1" mode="pass2"/>
    </xsl:variable>

    <xsl:variable name="pass3">
        <xsl:apply-templates select="$pass2" mode="pass3"/>
    </xsl:variable>

    <xsl:variable name="pass4">
        <xsl:apply-templates select="$pass3" mode="pass4"/>
    </xsl:variable>

    <!-- Set some variables that will dictate the geometry of the widget -->
    <xsl:variable name="scrollH"
        select="$pass4/fr:datatable/@scrollable = ('horizontal', 'both') and $pass4/fr:datatable/@width"/>
    <xsl:variable name="scrollV"
        select="$pass4/fr:datatable/@scrollable = ('vertical', 'both') and $pass4/fr:datatable/@height"/>
    <xsl:variable name="scrollable" select="$scrollH or $scrollV"/>
    <xsl:variable name="height"
        select="if ($scrollV) then concat('height: ', $pass4/fr:datatable/@height, ';') else ''"/>
    <xsl:variable name="width"
        select="if ($pass4/fr:datatable/@width) then concat('width: ', $pass4/fr:datatable/@width, ';') else ''"/>
    <xsl:variable name="id">
        <xsl:choose>
            <xsl:when test="$pass4/fr:datatable/@id">
                <id xxbl:scope="outer">
                    <xsl:value-of select="$pass4/fr:datatable/@id"/>
                </id>
            </xsl:when>
            <xsl:otherwise>
                <id xxbl:scope="inner">
                    <xsl:value-of select="generate-id($pass4/fr:datatable)"/>
                </id>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="paginated" select="$pass4/fr:datatable/@paginated = 'true'"/>
    <xsl:variable name="rowsPerPage"
        select="if ($pass4/fr:datatable/@rowsPerPage castable as xs:integer) then $pass4/fr:datatable/@rowsPerPage cast as xs:integer else 10"/>
    <xsl:variable name="maxNbPagesToDisplay"
        select="if ($pass4/fr:datatable/@maxNbPagesToDisplay castable as xs:integer) then $pass4/fr:datatable/@maxNbPagesToDisplay cast as xs:integer else -1"/>
    <xsl:variable name="sortAndPaginationMode" select="$pass4/fr:datatable/@sortAndPaginationMode"/>
    <xsl:variable name="innerTableWidth"
        select="if ($pass4/fr:datatable/@innerTableWidth) then concat(&quot;'&quot;, $pass4/fr:datatable/@innerTableWidth, &quot;'&quot;) else 'null'"/>
    <xsl:variable name="hasLoadingFeature" select="count($pass4/fr:datatable/@loading) = 1"/>
    <xsl:variable name="debug" select="$pass4/fr:datatable/@debug = 'true'"/>

    <!-- And some more -->

    <xsl:variable name="repeatNodeset"
        select="$pass4/fr:datatable/xhtml:tbody/xforms:repeat/@nodeset"/>

    <xsl:template match="@*|node()" mode="#all" priority="-100">
        <!-- Default template == identity -->
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="/">

        <xsl:apply-templates select="$pass4/fr:datatable" mode="dynamic"/>

    </xsl:template>

    <xsl:template name="fr-goto-page">
        <xsl:param name="fr-new-page"/>
        <xsl:choose>
            <xsl:when test="$sortAndPaginationMode='external'">
                <xforms:dispatch ev:event="DOMActivate" name="fr-goto-page" target="fr.datatable">
                    <xxforms:context name="fr-new-page" select="{$fr-new-page}"/>
                </xforms:dispatch>
            </xsl:when>
            <xsl:otherwise>
                <xforms:setvalue ev:event="DOMActivate" model="datatable-model"
                    ref="instance('page')" value="{$fr-new-page}"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- 
    
    Pass 1 : create a body element if missing
    
    Note (common to pass 1, 2, 3, 4): replace xsl:copy-of by xsl:apply-templates if needed! 
    
    -->

    <xsl:template match="/fr:datatable" mode="pass1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="xhtml:colgroup|xhtml:thead|xhtml:tbody"/>
            <xsl:if test="not(xhtml:tbody)">
                <xhtml:tbody>
                    <xsl:copy-of select="*[not(self::tcolgroup|self::thead)]"/>
                </xhtml:tbody>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <!-- 
        
        Pass 2 : expand /fr:datatable/xhtml:tbody/xhtml:tr[@repeat-nodeset]
        
    -->

    <xsl:template match="/fr:datatable/xhtml:tbody/xhtml:tr[@repeat-nodeset]" mode="pass2">
        <xforms:repeat nodeset="{@repeat-nodeset}">
            <xsl:copy>
                <xsl:copy-of select="@*[name() != 'repeat-nodeset']|node()"/>
            </xsl:copy>
        </xforms:repeat>
    </xsl:template>

    <!-- 
        
        Pass 3 : expand /fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/td[@repeat-nodeset]
        and /fr:datatable/xhtml:thead/xhtml:tr/th[@repeat-nodeset]
        
        Note: do not merge with pass 2 unless you update these XPath expressions to work with 
        xhtml:tr[@repeat-nodeset]
        
    -->

    <xsl:template
        match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/td[@repeat-nodeset]|/fr:datatable/xhtml:thead/xhtml:tr/th[@repeat-nodeset]"
        mode="pass3">
        <xforms:repeat nodeset="{@repeat-nodeset}">
            <xsl:copy>
                <xsl:copy-of select="@*[name() != 'repeat-nodeset']|node()"/>
            </xsl:copy>
        </xforms:repeat>
    </xsl:template>

    <!-- 
        
        Pass 4 : create a header element if missing
        
    -->

    <xsl:template match="/fr:datatable" mode="pass4">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="xhtml:colgroup|xhtml:thead"/>
            <xsl:if test="not(xhtml:thead)">
                <xhtml:thead>
                    <xhtml:tr>
                        <xsl:apply-templates
                            select="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/*"
                            mode="pass4-header"/>
                    </xhtml:tr>
                </xhtml:thead>
            </xsl:if>
            <xsl:apply-templates select="xhtml:tbody" mode="pass4"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template
        match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xhtml:td/xforms:output[xforms:label][1]/xforms:label
        |/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat/xhtml:td/xforms:output[xforms:label][1]/xforms:label"
        mode="pass4"/>

    <!-- 
        
        Pass 4-header : populate the a header element if missing
        (called by pass4)
        
    -->

    <xsl:template match="*" mode="pass4-header"/>

    <xsl:template match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat"
        mode="pass4-header">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="pass4-header"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template
        match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xhtml:td|/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat/xhtml:td"
        mode="pass4-header">
        <xhtml:th>
            <xsl:apply-templates select="@*" mode="pass4-header"/>
            <xsl:apply-templates select="xforms:output[xforms:label][1]" mode="pass4-header"/>
        </xhtml:th>
    </xsl:template>

    <xsl:template
        match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xhtml:td/xforms:output[@ref]|/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat/xhtml:td/xforms:output[@ref]"
        mode="pass4-header">
        <xforms:group>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="xforms:label/*"/>
        </xforms:group>
    </xsl:template>

    <xsl:template
        match="/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xhtml:td/xforms:output|/fr:datatable/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat/xhtml:td/xforms:output"
        mode="pass4-header">
        <xsl:value-of select="xforms:label"/>
    </xsl:template>

    <!-- 
        ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        Below this point, the templates belong to the new implementation that supports dynamic columns
    
        ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    -->

    <xsl:template match="/fr:datatable" mode="dynamic">
        <!-- Matches the bound element -->

        <xsl:if test="not(xhtml:thead)">
            <xsl:message terminate="yes">Datatable components should include a thead
                element.</xsl:message>
        </xsl:if>
        <xsl:if test="not(xhtml:tbody)">
            <xsl:message terminate="yes">Datatable components should include a tbody
                element.</xsl:message>
        </xsl:if>

        <xsl:variable name="columns">
            <xsl:apply-templates select="xhtml:thead/xhtml:tr[1]/*" mode="dyn-columns"/>
        </xsl:variable>

        <xforms:group xbl:attr="model context ref bind" xxbl:scope="outer" id="{$id}-container">
            <xsl:copy-of select="namespace::*"/>

            <xforms:model id="datatable-model" xxbl:scope="inner">
                <xforms:instance id="datatable-instance">
                    <columns xmlns="" currentSortColumn="-1" default="true">
                        <xsl:for-each select="$columns/*">
                            <xsl:copy>
                                <xsl:attribute name="nbColumns"/>
                                <xsl:attribute name="index"/>
                                <xsl:attribute name="currentSortOrder"/>
                                <xsl:attribute name="nextSortOrder"/>
                                <xsl:attribute name="type"/>
                                <xsl:attribute name="pathToFirstNode"/>
                                <xsl:copy-of select="@*"/>
                            </xsl:copy>
                        </xsl:for-each>
                    </columns>
                </xforms:instance>
                <xforms:bind nodeset="column/@nbColumns" calculate="1"/>
                <xforms:bind nodeset="columnSet/@nbColumns" calculate="count(../column)"/>
                <xforms:bind nodeset="//@index" calculate="count(../preceding::column) + 1"/>
                <xforms:bind nodeset="//column/@currentSortOrder"
                    calculate="if (/*/@default='true' and ../@fr:sorted) then ../@fr:sorted else if (../@index = /*/@currentSortColumn) then . else 'none'"/>
                <xforms:bind nodeset="//column/@nextSortOrder"
                    calculate="if (../@currentSortOrder = 'ascending') then 'descending' else 'ascending'"/>
                <xxforms:variable name="repeatNodeset">
                    <xsl:value-of select="$repeatNodeset"/>
                </xxforms:variable>
                <xforms:bind nodeset="//column/@pathToFirstNode"
                    calculate="concat('xxforms:component-context()/(', $repeatNodeset, ')[1]/(', ../@sortKey, ')')"/>
                <xforms:bind nodeset="//column[@fr:sortType]/@type" calculate="../@fr:sortType"/>
                <!--<xforms:bind nodeset="//column[not(@fr:sortType)]/@type"
                    calculate="for $value in xxforms:evaluate(../@pathToFirstNode)
                        return if ($value instance of node())
                        then if (xxforms:type($value) = ({$numberTypesEnumeration}))
                            then 'number'
                            else 'text'
                        else if ($value instance of xs:decimal)
                            then 'number'
                            else 'text'"/>
-->

                <xsl:if test="$paginated">
                    <xforms:instance id="page">
                        <page xmlns="">1</page>
                    </xforms:instance>
                </xsl:if>

            </xforms:model>

            <xsl:choose>
                <xsl:when test="$paginated and not($sortAndPaginationMode='external')">
                    <xxforms:variable name="page" model="datatable-model" select="instance('page')"
                        xxbl:scope="inner"/>
                    <xxforms:variable name="nbRows" xxbl:scope="inner">
                        <xxforms:sequence select="count({$repeatNodeset})" xxbl:scope="outer"/>
                    </xxforms:variable>
                    <xxforms:variable name="nbPages"
                        select="ceiling($nbRows div {$rowsPerPage}) cast as xs:integer"
                        xxbl:scope="inner"/>
                </xsl:when>

                <xsl:when test="$paginated and $sortAndPaginationMode='external'">
                    <xxforms:variable name="page" xxbl:scope="inner">
                        <xxforms:sequence xbl:attr="select=page" xxbl:scope="outer"/>
                    </xxforms:variable>
                    <xxforms:variable name="nbPages" xxbl:scope="inner">
                        <xxforms:sequence xbl:attr="select=nbPages" xxbl:scope="outer"/>
                    </xxforms:variable>
                </xsl:when>

            </xsl:choose>


            <xsl:choose>
                <xsl:when test="$paginated and $maxNbPagesToDisplay &lt; 0">
                    <xxforms:variable name="pages"
                        select="for $p in 1 to $nbPages cast as xs:integer return xxforms:element('page', $p)"
                        xxbl:scope="inner"/>
                </xsl:when>
                <xsl:when test="$paginated">
                    <xxforms:variable name="maxNbPagesToDisplay"
                        select="{$maxNbPagesToDisplay} cast as xs:integer" xxbl:scope="inner"/>
                    <xxforms:variable name="radix"
                        select="floor(($maxNbPagesToDisplay - 2) div 2) cast as xs:integer"
                        xxbl:scope="inner"/>
                    <xxforms:variable name="minPage"
                        select="
                        (if ($page > $radix)
                        then if ($nbPages >= $page + $radix)
                        then ($page - $radix)
                        else max((1, $nbPages - $maxNbPagesToDisplay + 1))
                        else 1) cast as xs:integer"
                        xxbl:scope="inner"/>
                    <xxforms:variable name="pages"
                        select="for $p in 1 to $nbPages cast as xs:integer return xxforms:element('page', $p)"
                        xxbl:scope="inner"/>
                </xsl:when>
            </xsl:choose>

            <xsl:variable name="pagination">
                <!-- TODO: fix scopes -->
                <xsl:if test="$paginated">
                    <xhtml:div class="yui-dt-paginator yui-pg-container" style="">

                        <xforms:group appearance="xxforms:internal" xxbl:scope="inner">

                            <xforms:group ref=".[$page = 1]">
                                <xhtml:span class="yui-pg-first">&lt;&lt; first</xhtml:span>
                            </xforms:group>
                            <xforms:group ref=".[$page != 1]">
                                <xforms:trigger class="yui-pg-first" appearance="minimal">
                                    <xforms:label>&lt;&lt; first </xforms:label>
                                    <xsl:call-template name="fr-goto-page">
                                        <xsl:with-param name="fr-new-page">1</xsl:with-param>
                                    </xsl:call-template>
                                </xforms:trigger>
                            </xforms:group>

                            <xforms:group ref=".[$page = 1]">
                                <xhtml:span class="yui-pg-previous">&lt; prev</xhtml:span>
                            </xforms:group>
                            <xforms:group ref=".[$page != 1]">
                                <xforms:trigger class="yui-pg-previous" appearance="minimal">
                                    <xforms:label>&lt; prev</xforms:label>
                                    <xsl:call-template name="fr-goto-page">
                                        <xsl:with-param name="fr-new-page">$page -
                                            1</xsl:with-param>
                                    </xsl:call-template>
                                </xforms:trigger>
                            </xforms:group>

                            <xhtml:span class="yui-pg-pages">
                                <xforms:repeat nodeset="$pages">
                                    <xsl:choose>
                                        <xsl:when test="$maxNbPagesToDisplay &lt; 0">
                                            <xxforms:variable name="display">page</xxforms:variable>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xxforms:variable name="display"
                                                select="
                                            if ($page &lt; $maxNbPagesToDisplay -2)
                                            then if (. &lt;= $maxNbPagesToDisplay - 2 or . = $nbPages)
                                            then 'page'
                                            else if (. = $nbPages - 1)
                                            then 'ellipses'
                                            else 'none'
                                            else if ($page > $nbPages - $maxNbPagesToDisplay + 3)
                                            then if (. >= $nbPages - $maxNbPagesToDisplay + 3 or . = 1)
                                            then 'page'
                                            else if (. = 2)
                                            then 'ellipses'
                                            else 'none'
                                            else if (. = 1 or . = $nbPages or (. > $page - $radix and . &lt; $page + $radix))
                                            then 'page'
                                            else if (. = 2 or . = $nbPages -1)
                                            then 'ellipses'
                                            else 'none'
                                            "
                                            />
                                        </xsl:otherwise>
                                    </xsl:choose>
                                    <xforms:group ref=".[. = $page and $display = 'page']">
                                        <xforms:output class="yui-pg-page" value="$page">
                                            <!-- <xforms:hint>Current page (edit to move to another
                                            page)</xforms:hint>-->
                                        </xforms:output>
                                    </xforms:group>
                                    <xforms:group ref=".[. != $page and $display = 'page']">
                                        <xxforms:variable name="targetPage" select="."/>
                                        <xforms:trigger class="yui-pg-page" appearance="minimal">
                                            <xforms:label>
                                                <xforms:output value="."/>
                                            </xforms:label>
                                            <xsl:call-template name="fr-goto-page">
                                                <xsl:with-param name="fr-new-page"
                                                  >$targetPage</xsl:with-param>
                                            </xsl:call-template>
                                        </xforms:trigger>
                                    </xforms:group>
                                    <xforms:group ref=".[ $display = 'ellipses']">
                                        <xhtml:span class="yui-pg-page">...</xhtml:span>
                                    </xforms:group>
                                </xforms:repeat>
                            </xhtml:span>

                            <xforms:group ref=".[$page = $nbPages or $nbPages = 0]">
                                <xhtml:span class="yui-pg-next">next ></xhtml:span>
                            </xforms:group>
                            <xforms:group ref=".[$page != $nbPages and $nbPages != 0]">
                                <xforms:trigger class="yui-pg-next" appearance="minimal">
                                    <xforms:label>next ></xforms:label>
                                    <xsl:call-template name="fr-goto-page">
                                        <xsl:with-param name="fr-new-page">$page +
                                            1</xsl:with-param>
                                    </xsl:call-template>
                                </xforms:trigger>
                            </xforms:group>

                            <xforms:group ref=".[$page = $nbPages or $nbPages = 0]">
                                <xhtml:span class="yui-pg-last">last >></xhtml:span>
                            </xforms:group>
                            <xforms:group ref=".[$page != $nbPages and $nbPages != 0]">
                                <xforms:trigger class="yui-pg-last" appearance="minimal">
                                    <xforms:label>last >></xforms:label>
                                    <xsl:call-template name="fr-goto-page">
                                        <xsl:with-param name="fr-new-page">$nbPages</xsl:with-param>
                                    </xsl:call-template>
                                </xforms:trigger>
                            </xforms:group>

                        </xforms:group>
                    </xhtml:div>

                </xsl:if>
            </xsl:variable>

            <xxforms:variable name="currentSortOrder" model="datatable-model"
                select="instance('datatable-instance')/@currentSortOrder" xxbl:scope="inner"/>
            <xxforms:variable name="currentSortColumn" model="datatable-model"
                select="instance('datatable-instance')/@currentSortColumn" xxbl:scope="inner"/>

            <xsl:if test="$debug">
                <xhtml:div style="border:thin solid black" class="fr-dt-debug fr-dt-debug-{id}">
                    <xhtml:h3>Local instance:</xhtml:h3>
                    <xforms:group model="datatable-model" instance="datatable-instance"
                        xxbl:scope="inner">
                        <xhtml:div class="fr-dt-debug-columns" id="debug-columns">
                            <xhtml:p>
                                <xforms:output value="name()"/>
                            </xhtml:p>
                            <xhtml:ul>
                                <xforms:repeat nodeset="@*">
                                    <xhtml:li>
                                        <xforms:output ref=".">
                                            <xforms:label>
                                                <xforms:output value="concat(name(), ': ')"/>
                                            </xforms:label>
                                        </xforms:output>
                                    </xhtml:li>
                                </xforms:repeat>
                            </xhtml:ul>
                        </xhtml:div>
                        <xforms:repeat nodeset="*|//column">
                            <xhtml:div id="debug-column">
                                <xhtml:p>
                                    <xforms:output value="name()"/>
                                </xhtml:p>
                                <xhtml:ul>
                                    <xforms:repeat nodeset="@*">
                                        <xhtml:li>
                                            <xforms:output ref=".">
                                                <xforms:label>
                                                  <xforms:output value="concat(name(), ': ')"/>
                                                </xforms:label>
                                            </xforms:output>
                                        </xhtml:li>
                                    </xforms:repeat>
                                </xhtml:ul>
                            </xhtml:div>
                        </xforms:repeat>
                    </xforms:group>
                </xhtml:div>
            </xsl:if>

            <xsl:if test="$hasLoadingFeature">
                <xxforms:variable name="fr-dt-loading" xbl:attr="select=loading"/>
            </xsl:if>

            <xsl:copy-of select="$pagination"/>

            <xxforms:variable name="group-ref" xxbl:scope="inner">
                <xxforms:sequence
                    select=".{if ($hasLoadingFeature) then '[not($fr-dt-loading = true())]' else ''}"
                    xxbl:scope="outer"/>
            </xxforms:variable>

            <xxforms:script ev:event="xforms-enabled" ev:target="fr-dt-group" xxbl:scope="inner">
                YAHOO.log("Enabling datatable id <xsl:value-of select="$id"/>","info");
                ORBEON.widgets.datatable.init(this, <xsl:value-of select="$innerTableWidth"/>); </xxforms:script>

            <xforms:group ref="$group-ref" id="fr-dt-group" xxbl:scope="inner">

                <!--  <xforms:group appearance="xxforms:internal" xxbl:scope="outer"> would be better but doesn't work! -->
                <xforms:group xxbl:scope="outer">
                    <xhtml:table id="{$id}-table"
                        class="datatable datatable-{$id} yui-dt-table {if ($scrollV) then 'fr-scrollV' else ''}  {if ($scrollH) then 'fr-scrollH' else ''} "
                        style="{$height} {$width}">
                        <!-- Copy attributes that are not parameters! -->
                        <xsl:apply-templates select="@*[not(name() = ($parameters/*, 'id' ))]"
                            mode="dynamic"/>
                        <xhtml:thead id="{$id}-thead">
                            <xhtml:tr class="yui-dt-first yui-dt-last {@class}" id="{$id}-thead-tr">
                                <xsl:apply-templates select="$columns/*" mode="dynamic"/>
                            </xhtml:tr>
                        </xhtml:thead>
                        <xsl:apply-templates select="xhtml:tbody" mode="dynamic"/>
                    </xhtml:table>
                </xforms:group>

            </xforms:group>

            <xsl:if test="$hasLoadingFeature">
                <!-- The trick with the spans is working fine for simple case where we don't need to specify the height or width.
                    In other cases, the elements "gain layout" in IE world and the width of the div that contains the 
                    scrollbar takes all the page in IE 6 if not explicitely set...-->
                <xforms:group ref="xxforms:component-context()[$fr-dt-loading = true()]">
                    <xforms:action ev:event="xforms-enabled">
                        <xxforms:script> ORBEON.widgets.datatable.initLoadingIndicator(this,
                                <xsl:value-of select="$scrollV"/>, <xsl:value-of select="$scrollH"
                            />); </xxforms:script>
                    </xforms:action>
                    <xsl:variable name="tableContent">
                        <xhtml:thead>
                            <xhtml:tr class="yui-dt-first yui-dt-last">
                                <xsl:apply-templates select="$columns/*" mode="dyn-loadingIndicator"
                                />
                            </xhtml:tr>
                        </xhtml:thead>
                        <xhtml:tbody>
                            <xhtml:tr>
                                <xhtml:td colspan="{count($columns/*)}">
                                    <xhtml:div class="fr-datatable-is-loading"
                                        style="{if ($scrollable) then concat( $height, ' ', $width) else ''}"
                                    />
                                </xhtml:td>
                            </xhtml:tr>
                        </xhtml:tbody>
                    </xsl:variable>
                    <xsl:choose>
                        <xsl:when test="$scrollable">
                            <xhtml:div class="yui-dt yui-dt-scrollable"
                                style="{if ($scrollV) then $height else 'height: 95px;'} {$width}">
                                <xhtml:div
                                    style="overflow: auto; {if ($scrollV) then $height else 'height: 95px;'} {$width}"
                                    class="yui-dt-hd">
                                    <xhtml:table style=""
                                        class="datatable datatable-table-scrollV yui-dt-table fr-scrollV">
                                        <xsl:copy-of select="$tableContent"/>
                                    </xhtml:table>
                                </xhtml:div>
                            </xhtml:div>
                        </xsl:when>
                        <xsl:otherwise>
                            <xhtml:span class="yui-dt yui-dt-scrollable" style="display: table; ">
                                <xhtml:span class="yui-dt-hd"
                                    style="border: 1px solid rgb(127, 127, 127); display: table-cell;">
                                    <xhtml:table class="datatable  yui-dt-table"
                                        style="{$height} {$width}">
                                        <xsl:copy-of select="$tableContent"/>
                                    </xhtml:table>
                                </xhtml:span>
                            </xhtml:span>
                        </xsl:otherwise>
                    </xsl:choose>
                </xforms:group>
            </xsl:if>

            <xsl:copy-of select="$pagination"/>


        </xforms:group>
        <!-- End of template on the bound element -->
    </xsl:template>



    <xsl:template name="header-cell">

        <!-- XXForms variable "columnDesc" is the current column description when we enter here -->

        <!-- <xforms:output value="$columnDesc/@index"/>-->

        <xhtml:div class="yui-dt-liner">
            <xhtml:span class="yui-dt-label">
                <xsl:choose>
                    <xsl:when test="@fr:sortable = 'true'">
                        <xforms:trigger appearance="minimal">
                            <xforms:label>
                                <xsl:apply-templates select="node()" mode="dynamic"/>
                            </xforms:label>
                            <xforms:hint xxbl:scope="inner">Click to sort <xforms:output
                                    value="$columnDesc/@nextSortOrder"/></xforms:hint>
                            <xforms:action ev:event="DOMActivate">
                                <xforms:setvalue ref="$columnDesc/ancestor::columns/@default"
                                    xxbl:scope="inner">false</xforms:setvalue>
                                <xforms:setvalue ref="$columnDesc/@currentSortOrder"
                                    value="$columnDesc/@nextSortOrder" xxbl:scope="inner"/>
                                <xforms:setvalue ref="$currentSortColumn" value="$columnDesc/@index"
                                    xxbl:scope="inner"/>
                            </xforms:action>
                        </xforms:trigger>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="node()" mode="dynamic"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xhtml:span>
        </xhtml:div>

    </xsl:template>

    <xsl:template match="column|columnSet" priority="1" mode="dynamic">
        <xsl:apply-templates select="header" mode="dynamic"/>
    </xsl:template>

    <xsl:template match="header" mode="dynamic">
        <xsl:apply-templates select="*" mode="dynamic"/>
    </xsl:template>

    <xsl:template match="header/xhtml:th" mode="dynamic">
        <xxforms:variable name="index" select="{count(../../preceding-sibling::*) + 1}"
            xxbl:scope="inner"/>
        <xxforms:variable name="columnDesc" model="datatable-model"
            select="instance('datatable-instance')/*[position() = $index]" xxbl:scope="inner"/>
        <xxforms:variable name="fr-dt-columnDesc">
            <xxforms:sequence select="$columnDesc" xxbl:scope="inner"/>
        </xxforms:variable>
        <xhtml:th
            class="
            {if (@fr:sortable = 'true') then 'yui-dt-sortable' else ''} 
            {if (@fr:resizeable = 'true') then 'yui-dt-resizeable' else ''} 
            {{if ($fr-dt-columnDesc/@currentSortOrder = 'ascending') then 'yui-dt-asc'
            else if ($fr-dt-columnDesc/@currentSortOrder = 'descending') then 'yui-dt-desc' else '' }}
            
             {@class}
            ">
            <xsl:apply-templates select="@*[name() != 'class']" mode="dynamic"/>
            <xsl:call-template name="header-cell"/>

        </xhtml:th>
    </xsl:template>

    <xsl:template match="header/xforms:repeat/xhtml:th" mode="dynamic">
        <xxforms:variable name="position" xxbl:scope="inner">
            <xxforms:sequence select="position()" xxbl:scope="outer"/>
        </xxforms:variable>
        <xxforms:variable name="index" select="{count(../../../preceding-sibling::*) + 1}"
            xxbl:scope="inner"/>
        <xxforms:variable name="columnSet"
            select="instance('datatable-instance')/*[position() = $index]" xxbl:scope="inner"/>
        <xxforms:variable name="columnIndex" select="$columnSet/@index + $position - 1"
            xxbl:scope="inner"/>
        <xxforms:variable name="column" select="$columnSet/column[@index = $columnIndex]"
            xxbl:scope="inner"/>
        <xxforms:variable name="fr-dt-column">
            <xxforms:sequence select="$column" xxbl:scope="inner"/>
        </xxforms:variable>
        <xhtml:th
            class="
            {if (@fr:sortable = 'true') then 'yui-dt-sortable' else ''} 
            {if (@fr:resizeable = 'true') then 'yui-dt-resizeable' else ''} 
            {{if ($fr-dt-column/@currentSortOrder = 'ascending') then 'yui-dt-asc'
            else if ($fr-dt-column/@currentSortOrder = 'descending') then 'yui-dt-desc' else '' }}
            {@class}
            ">
            <xsl:apply-templates select="@*[name() != 'class']" mode="dynamic"/>
            <xforms:group ref=".">
                <xforms:action ev:event="xforms-enabled" xxbl:scope="inner">
                    <!--<xforms:delete nodeset="$columnSet/column[@position = $position]"/>-->
                    <xforms:insert context="$columnSet" nodeset="column"
                        origin="xxforms:element('column', (
                                xxforms:attribute('position', $position),
                                xxforms:attribute('nbColumns', 1),
                                xxforms:attribute('index', $columnIndex),
                                xxforms:attribute('sortKey', concat( '(',  $columnSet/@nodeset, ')[', $position , ']/', $columnSet/@sortKey)),
                                xxforms:attribute('currentSortOrder', ''),
                                xxforms:attribute('nextSortOrder', ''),
                                xxforms:attribute('type', ''),
                                xxforms:attribute('pathToFirstNode', ''),
                                $columnSet/@fr:sortable,
                                $columnSet/@fr:resizeable,
                                $columnSet/@fr:sortType
                                ))"
                        if="not($columnSet/column[@position = $position])
                           "
                    />
                </xforms:action>
            </xforms:group>

            <xxforms:variable name="columnDesc" select="$columnSet/column[@position = $position]"
                xxbl:scope="inner"/>

            <xsl:call-template name="header-cell"/>

        </xhtml:th>
    </xsl:template>

    <xsl:template match="/*/xhtml:tbody" mode="dynamic">
        <xhtml:tbody class="yui-dt-data {@class}" id="{$id}-tbody">
            <xsl:apply-templates select="@*[not(name() = ('class', 'id'))]|node()" mode="dynamic"/>
        </xhtml:tbody>
    </xsl:template>

    <xsl:template match="/*/xhtml:tbody/xforms:repeat" mode="dynamic">

        <xxforms:variable name="nodeset" xxbl:scope="outer" select="{$repeatNodeset}"/>

        <xsl:choose>

            <xsl:when test="$sortAndPaginationMode = 'external'">
                <xxforms:variable name="rewrittenNodeset" xxbl:scope="inner">
                    <xxforms:sequence xxbl:scope="outer" select="$nodeset"/>
                </xxforms:variable>
            </xsl:when>

            <xsl:otherwise>
                <xxforms:variable name="fr-dt-datatable-instance" xxbl:scope="outer">
                    <xxforms:sequence select="instance('datatable-instance')" xxbl:scope="inner"/>
                </xxforms:variable>
                <xxforms:variable name="currentSortColumnIndex"
                    select="instance('datatable-instance')/@currentSortColumn" xxbl:scope="inner"/>

                <xxforms:variable name="currentSortColumn" xxbl:scope="outer">
                    <xxforms:sequence
                        select="(instance('datatable-instance')//column)[@index=$currentSortColumnIndex]"
                        xxbl:scope="inner"/>
                </xxforms:variable>

                <xxforms:variable name="fr-dt-isDefault" xxbl:scope="outer">
                    <xxforms:sequence select="instance('datatable-instance')/@default = 'true'"
                        xxbl:scope="inner"/>
                </xxforms:variable>

                <xxforms:variable name="fr-dt-isSorted"
                    select="$fr-dt-isDefault or $currentSortColumn[@currentSortOrder = @fr:sorted]"
                    xxbl:scope="outer"/>

                <xxforms:variable name="currentSortColumnType" xxbl:scope="outer"
                    select="
            
            if ($currentSortColumn)
                then if ($currentSortColumn/@type != '')
                    then $currentSortColumn/@type
                    else for $value in xxforms:evaluate($currentSortColumn/@pathToFirstNode)
                        return if ($value instance of node())
                            then if (xxforms:type($value) = ({$numberTypesEnumeration}))
                                then 'number'
                                else 'text'
                            else if ($value instance of xs:decimal)
                                then 'number'
                                else 'text'
                else ''
            
            "/>


                <xsl:if test="$paginated">
                    <xxforms:variable name="page" xxbl:scope="outer">
                        <xxforms:sequence select="$page" xxbl:scope="inner"/>
                    </xxforms:variable>
                </xsl:if>
                <xxforms:variable name="rewrittenNodeset" xxbl:scope="inner">
                    <xxforms:sequence xxbl:scope="outer"
                        select="
                
                {if ($paginated) then '(' else ''}
                
                if (not($currentSortColumn) or $currentSortColumn/@currentSortOrder = 'none' or $fr-dt-isSorted) 
                    then $nodeset
                    else exf:sort($nodeset,  $currentSortColumn/@sortKey , $currentSortColumnType, $currentSortColumn/@currentSortOrder)
                
                {if ($paginated) 
                    then concat(
                        ')[position() >= ($page - 1) * '
                        , $rowsPerPage 
                        , ' + 1 and position() &lt;= $page *'
                        , $rowsPerPage
                        ,']') 
                    else ''}
                
                "
                    />
                </xxforms:variable>
            </xsl:otherwise>
        </xsl:choose>


        <xxforms:script ev:event="xxforms-nodeset-changed" ev:target="fr-datatable-repeat"
            xxbl:scope="inner"> ORBEON.widgets.datatable.update(this); </xxforms:script>

        <xforms:repeat id="fr-datatable-repeat" nodeset="$rewrittenNodeset" xxbl:scope="inner">
            <xsl:apply-templates select="@*[not(name()='nodeset')]|node()" mode="dynamic"/>
        </xforms:repeat>

    </xsl:template>

    <xsl:template match="/*/xhtml:tbody/xforms:repeat/xhtml:tr" mode="dynamic">
        <xhtml:tr
            class="
            {{if (position() = 1) then 'yui-dt-first' else '' }}
            {{if (position() = last()) then 'yui-dt-last' else '' }}
            {{if (position() mod 2 = 0) then 'yui-dt-odd' else 'yui-dt-even' }}
            {{if (xxforms:index() = position()) then 'yui-dt-selected' else ''}}
            {@class}"
            style="height: auto;" xxbl:scope="outer">
            <xsl:apply-templates select="@*[name() != 'class']|node()" mode="dynamic"/>
        </xhtml:tr>
    </xsl:template>

    <xsl:template match="/*/xhtml:tbody/xforms:repeat/xhtml:tr/xhtml:td" mode="dynamic">
        <xxforms:variable name="index" select="{count(preceding-sibling::*) + 1}"/>
        <xxforms:variable name="columnDesc" model="datatable-model"
            select="instance('datatable-instance')/*[position() = $index]"/>

        <xhtml:td
            class="
            {if (@fr:sortable = 'true') then 'yui-dt-sortable' else ''} 
            {{if ($columnDesc/@currentSortOrder = 'ascending') then 'yui-dt-asc'
            else if ($columnDesc/@currentSortOrder = 'descending') then 'yui-dt-desc' else '' }}
            {@class}            
            ">

            <xsl:apply-templates select="@*[name() != 'class']" mode="dynamic"/>
            <xhtml:div class="yui-dt-liner">
                <xsl:apply-templates select="node()" mode="dynamic"/>
            </xhtml:div>
        </xhtml:td>
    </xsl:template>

    <xsl:template match="/*/xhtml:tbody/xforms:repeat/xhtml:tr/xforms:repeat/xhtml:td"
        mode="dynamic">
        <xxforms:variable name="position" select="position()"/>
        <xxforms:variable name="index" select="{count(../preceding-sibling::*) + 1}"/>
        <xxforms:variable name="columnSet" model="datatable-model"
            select="instance('datatable-instance')/*[position() = $index]"/>
        <xxforms:variable name="columnIndex" model="datatable-model"
            select="$columnSet/@index + $position - 1"/>
        <xxforms:variable name="column" model="datatable-model"
            select="$columnSet/column[@index = $columnIndex]"/>
        <xhtml:td
            class="
            {if (@fr:sortable = 'true') then 'yui-dt-sortable' else ''} 
            {{if ($column/@currentSortOrder = 'ascending') then 'yui-dt-asc'
            else if ($column/@currentSortOrder = 'descending') then 'yui-dt-desc' else '' }}
            {@class}            
            ">

            <xsl:apply-templates select="@*[name() != 'class']" mode="dynamic"/>
            <xhtml:div class="yui-dt-liner">
                <xsl:apply-templates select="node()" mode="dynamic"/>
            </xhtml:div>
        </xhtml:td>
    </xsl:template>

    <xsl:template match="@fr:*" mode="dynamic"/>

    <!-- 
        
        sortKey mode builds a list of sort keys from a cell content 
        
        Note that we don't bother to take text nodes into account, assuming that
        they are constant and should not influence the sort order...
        
    -->

    <xsl:template match="*" mode="dyn-sortKey" priority="-0.25">
        <xsl:apply-templates select="*" mode="dyn-sortKey"/>
    </xsl:template>

    <xsl:template match="xforms:output" mode="dyn-sortKey">
        <xpath>
            <xsl:value-of select="@ref|@value"/>
        </xpath>
    </xsl:template>


    <!-- 

        Column mode is used to consolidate information about columns
        from theader and tbody

    -->

    <xsl:template match="/*/xhtml:thead/xhtml:tr/*" mode="dyn-columns">
        <xsl:message terminate="yes">Unxepected element (<xsl:value-of select="name()"/> found in a
            datatable header (expecting either xhtml:th or xforms:repeat).</xsl:message>
    </xsl:template>

    <xsl:template match="/*/xhtml:thead/xhtml:tr/xhtml:th" mode="dyn-columns" priority="1">
        <xsl:variable name="position" select="count(preceding-sibling::*) + 1"/>
        <xsl:variable name="body"
            select="/*/xhtml:tbody/xforms:repeat/xhtml:tr/*[position() = $position]"/>
        <xsl:if test="not($body/self::xhtml:td)">
            <xsl:message terminate="yes">Datatable: mismatch, element position <xsl:value-of
                    select="$position"/> is a <xsl:value-of select="name()"/> in the header and a
                    <xsl:value-of select="name($body)"/> in the body.</xsl:message>repeat </xsl:if>
        <xsl:variable name="sortKey">
            <xsl:apply-templates select="$body" mode="dyn-sortKey"/>
        </xsl:variable>
        <column sortKey="{$sortKey}" type="" xmlns="">
            <xsl:copy-of select="@*"/>
            <header>
                <xsl:copy-of select="."/>
            </header>
            <body>
                <xsl:copy-of select="$body"/>
            </body>
        </column>
    </xsl:template>

    <xsl:template match="/*/xhtml:thead/xhtml:tr/xforms:repeat" mode="dyn-columns" priority="1">
        <xsl:variable name="position" select="count(preceding-sibling::*) + 1"/>
        <xsl:variable name="body"
            select="/*/xhtml:tbody/xforms:repeat/xhtml:tr/*[position() = $position]"/>
        <xsl:if test="not($body/self::xforms:repeat)">
            <xsl:message terminate="yes">Datatable: mismatch, element position <xsl:value-of
                    select="$position"/> is a <xsl:value-of select="name()"/> in the header and a
                    <xsl:value-of select="name($body)"/> in the body.</xsl:message>
        </xsl:if>
        <xsl:variable name="sortKey">
            <xsl:apply-templates select="$body" mode="dyn-sortKey"/>
        </xsl:variable>
        <columnSet sortKey="{$sortKey}" xmlns="">
            <xsl:copy-of select="$body/@nodeset|xhtml:th/@*"/>
            <header>
                <xsl:copy-of select="."/>
            </header>
            <body>
                <xsl:copy-of select="$body"/>
            </body>
        </columnSet>
    </xsl:template>

    <xsl:template match="column" mode="dyn-loadingIndicator">
        <xsl:apply-templates select="header/xhtml:th" mode="dynamic"/>
    </xsl:template>

    <xsl:variable name="fakeColumn">
        <header xmlns="">
            <xhtml:th class="fr-datatable-columnset-loading-indicator"
                >&#160;...&#160;</xhtml:th>
        </header>
    </xsl:variable>

    <xsl:template match="columnSet" mode="dyn-loadingIndicator">
        <xsl:apply-templates select="$fakeColumn/header/xhtml:th"/>
    </xsl:template>



</xsl:transform>

<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:svg="http://www.w3.org/2000/svg"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:tangram="http://www.masereeuw.nl/tangram"
    xmlns:local="#local"
    exclude-result-prefixes="xs ixsl math map local"
    expand-text="yes"
    version="3.0">
    
    <!-- Pass an SVN colour to shapeStroke for the default colour of the shapes; if not supplied, black is used. -->
    <xsl:param name="shapeStroke" as="xs:string" required="no" select="'black'"/>
    <!-- Pass an SVN stroke value (colour, none) to shapeFill for the default colour of the shapes; if not supplied, none is  used. -->
    <xsl:param name="shapeFill" as="xs:string" required="no" select="'none'"/>
    <!--Pass a positive (non-zero) value to gridSize in order to show the grid with the given number of horizontal and vertical cells. -->
    <xsl:param name="gridSize" as="xs:string" required="false" select="'0'"/>
    <!-- If gridSize > 0, pass an SVG colour value to gridLineStroke in order to override the yellow default. -->
    <xsl:param name="gridLineStroke" as="xs:string" required="false" select="'yellow'"/>
    <!-- The default viewBox has twice the size of the longest side of a large triangle. Set viewBoxFactor to some number (e.g., 2) to enlarge it. -->
    <xsl:param name="viewBoxFactor" as="xs:string" required="false" select="'1.0'"/>
    <!-- The width of the tangram SVG image as a CSS width value: -->
    <xsl:param name="svgCSSWidth" select="'100%'"/>
    <!-- The height of the tangram SVG image as a CSS height value: -->
    <xsl:param name="svgCSSHeight" select="'100%'"/>
    
    <!-- initialShape defines the first Tangram shape that is generated. The values for initialShare are defined as keys
         of the $transforms-map variable. -->
    <xsl:param name="initialShape" as="xs:string" select="'blue-tangram'"/>
    <!-- initialColours defines the colours of the first tangram shape that is generated. It is the name of an XML file
         with colour definitions, such as in 'coloured-tangram.xml'. -->
    <xsl:param name="initialColours" as="xs:string" select="'black-tangram.xml'"/>
    
    <!-- moveIterations is the number of iterations it should take from one tangram figure to another. -->
    <xsl:param name="moveIterations" as="xs:string" select="'50'"/>
    <!-- wait-millis-between-moves is the number of milliseconds between each movement of tangram objects (triangle, square)... -->
    <xsl:param name="waitMillisBetweenMoves" as="xs:string" select="'50'"/>
    
    <!-- Keeps, as a Javascript object in ixsl:page(), the name of the current transform (tangram shape + color, such as a square, a cat or a bird). Used to compute
         the difference between runs of several shapes initiated by the user.
         
         Make sure to use a name that is not used internally on the xsl:page() javascript object (window.document?).
         
         If you have more than one tangram on a page, you will want to have a distinct value for each tangram. In that case,
         you must also have distinct <div>'s where the tangram should go. If you specifiy several keyForPreviousFangram values,
         you will also specify several idOfTangramDiv values.
         
         NOTE: Having multiple tangrams on one page has not yet been attempted. I have currently no idea about how to do it.
         If you are desperate, you may use iframes (you don't need to specify this parameter in that case). 
    -->
    <xsl:param name="keyForPreviousFangram" select="'tangramtransforms'"/>
    <!-- Specifies the id of the <div> where the tangram should go. If you have several tangrams, specifiy a distinct div for each of
         them. In such a case, you will also need to specify distinct values for parameter keyForPreviousFangram.
    -->
    <xsl:param name="idOfTangramDiv" select="'tangram-div'"/>
    
    <xsl:output indent="yes" method="xml" encoding="UTF-8"/>
    
    <xsl:variable name="gridSize-as-int" as="xs:integer" select="xs:integer($gridSize)"/>
    <xsl:variable name="viewBoxFactor-as-double" as="xs:double" select="xs:double($viewBoxFactor)"/>
    
    <xsl:variable name="SQRT2" as="xs:double" select="math:sqrt(2)"/>
    
    <!-- The size of the short sides of the small triangles is called singleShortSide. All other dimensions are derived from it.
         Its value is arbitrary, but don't make it to small in order to properly render strokes.
    -->
    <xsl:variable name="singleShortSide" as="xs:integer" select="100"/>
    <xsl:variable name="doubleShortSide" as="xs:integer" select="2 * $singleShortSide"/>
    <xsl:variable name="singleLongSide" as="xs:double" select="$singleShortSide * $SQRT2"/>
    <xsl:variable name="doubleLongSide" as="xs:double" select="$singleLongSide * 2"/>
    
    <xsl:variable name="small-triangle-center" as="xs:double" select="$singleShortSide div 4"/>
    <xsl:variable name="medium-triangle-center" as="xs:double" select="$singleLongSide div 4"/>
    <xsl:variable name="big-triangle-center" as="xs:double" select="$doubleShortSide div 4"/>
    <xsl:variable name="square-center" as="xs:double" select="$singleShortSide div 2"/>
    <xsl:variable name="parallelogram-center-x" as="xs:double" select="$singleShortSide"/>
    <xsl:variable name="parallelogram-center-y" as="xs:double" select="$singleShortSide div 2"/>
    
    <xsl:function name="tangram:get-initial-tangram" as="element(svg:svg)">
        <!-- TODO retrieve initial trangram from settings file -->
        <xsl:param name="settings" as="document-node()"/>
        
        <xsl:variable name="viewboxDimension" as="xs:double" select="$doubleLongSide * $viewBoxFactor-as-double"/>
        <xsl:variable name="tangram-svg">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {$viewboxDimension} {$viewboxDimension}" style="width: {$svgCSSWidth}; height: {$svgCSSHeight}">
                
                <xsl:variable name="viewboxShift" as="xs:double" select="($viewboxDimension div 2) - $singleLongSide"/>
                
                <xsl:if test="$gridSize-as-int gt 0">
                    <xsl:variable name="cellSize" select="$viewboxDimension div $gridSize-as-int"
                        as="xs:double"/>
                    <xsl:for-each select="0 to $gridSize-as-int">
                        <line stroke="{$gridLineStroke}" x1="0" y1="{. * $cellSize}" x2="{$viewboxDimension}" y2="{. * $cellSize}">
                            <xsl:if test="(. mod 5) eq 0"><xsl:attribute name="stroke-width" select="2"/></xsl:if>
                        </line>
                        <line stroke="{$gridLineStroke}" x1="{. * $cellSize}" y1="0" x2="{. * $cellSize}" y2="{$viewboxDimension}">
                            <xsl:if test="(. mod 5) eq 0"><xsl:attribute name="stroke-width" select="2"/></xsl:if>
                        </line>
                    </xsl:for-each>
                </xsl:if>
                
                <g transform="translate({$viewboxShift}, {$viewboxShift})">
                    <polygon points="0,0 {$doubleShortSide},0 0,{$doubleShortSide}"
                        id="big-triangle-1" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon points="0,0 {$doubleShortSide},0 0,{$doubleShortSide}"
                        id="big-triangle-2" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon points="0,0 {$singleLongSide},0 0,{$singleLongSide}"
                        id="medium-triangle" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon points="0,0 {$singleShortSide},0 0,{$singleShortSide}"
                        id="small-triangle-1" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon points="0,0 {$singleShortSide},0 0,{$singleShortSide}"
                        id="small-triangle-2" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon
                        points="0,0 0,{$singleShortSide} {$singleShortSide},{$singleShortSide}, {$singleShortSide},0"
                        id="square" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                    
                    <polygon
                        points="0,{$singleShortSide} {$singleShortSide},0 {$doubleShortSide},0 {$singleShortSide},{$singleShortSide}"
                        id="parallelogram" stroke="{$shapeStroke}" fill="{$shapeFill}">
                    </polygon>
                </g>                
            </svg>
        </xsl:variable>
        
        <xsl:apply-templates select="$tangram-svg" mode="colourify">
            <xsl:with-param name="settings" as="document-node()" tunnel="yes" select="$settings"/>
        </xsl:apply-templates>
    </xsl:function>
    
    <xsl:function name="tangram:get-fill-colour-for-id" as="xs:string?">
        <xsl:param name="settings" as="document-node()"/>
        <xsl:param name="id" as="xs:string"/>
        <xsl:variable name="colour" as="element(colour)?" select="$settings/tangramsettings/fill-colours/colour[@for-id eq $id]"/>
        <xsl:value-of select="if ($colour) then string($colour) else ()"/>
    </xsl:function>
    
    <xsl:function name="tangram:get-stroke-colour-for-id" as="xs:string?">
        <xsl:param name="settings" as="document-node()"/>
        <xsl:param name="id" as="xs:string"/>
        <xsl:variable name="colour" as="element(colour)?" select="$settings/tangramsettings/stroke-colours/colour[@for-id eq $id]"/>
        <xsl:value-of select="if ($colour) then string($colour) else ()"/>
    </xsl:function>
    
    <xsl:variable name="moveIterations-as-int" as="xs:integer" select="xs:integer($moveIterations)"/>
    <xsl:variable name="waitMillisBetweenMoves-as-int" as="xs:integer" select="xs:integer($waitMillisBetweenMoves)"/>
    
    <!-- TODO retrieve transforms from settings file (requires eliminition of variables and some extra multiplications to obtain correct scaling. -->    
    <xsl:variable name="zero-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="0" translate-y="0" rotate-r="0" rotate-x="0" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="0" translate-y="0" rotate-r="0" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="1" scale-y="1"/>
    </xsl:variable>
    
    <xsl:variable name="tangram-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="0" translate-y="{-$singleLongSide div 2}" rotate-r="-135" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{-$singleLongSide div 2} " translate-y="0" rotate-r="135" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * 1.21}" translate-y="{$singleShortSide * 1.21}" rotate-r="180" rotate-x="{$medium-triangle-center}" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{-$singleShortSide  * 0.45}" translate-y="{$singleShortSide * 1.31}" rotate-r="45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide * 0.60}" translate-y="{$singleShortSide * 0.25}" rotate-r="-45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="0" translate-y="{$singleShortSide * 0.71}" rotate-r="45" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="{$singleShortSide * 0.56}" translate-y="{-$singleShortSide * 0.35}" rotate-r="-45" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="1" scale-y="1"/>
    </xsl:variable>
    
    <xsl:variable name="sitting-cat-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="0" translate-y="{$doubleShortSide}" rotate-r="-90" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{$singleShortSide * 1.02}" translate-y="{$doubleShortSide * 2}" rotate-r="180" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * 0.65}" translate-y="{$doubleShortSide * 1.58}" rotate-r="225" rotate-x="{$medium-triangle-center}" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{-$singleShortSide div 5.3}" translate-y="{-$singleShortSide div 5}" rotate-r="135" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide * 0.5}" translate-y="{-$singleShortSide div 5}" rotate-r="-45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="{-$singleShortSide * 0.1}" translate-y="{$singleShortSide * 0.25}" rotate-r="45" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="{$doubleShortSide}" translate-y="{$singleShortSide * 4}" rotate-r="360" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="1" scale-y="1"/>
    </xsl:variable>
    
    <xsl:variable name="bird-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="0" translate-y="0" rotate-r="180"  rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{$singleShortSide * 1.2}" translate-y="{-$singleShortSide * 0.09}" rotate-r="135" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * 2.2}" translate-y="-{$singleShortSide * 0.5}" rotate-r="90" rotate-x="{$medium-triangle-center}" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{$singleShortSide * 3.4}" translate-y="{$singleShortSide * 0.9}" rotate-r="90" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide}" translate-y="{$singleShortSide * 1.68}" rotate-r="45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="{$singleShortSide * 2.9}" translate-y="{-$singleShortSide * 0.08}" rotate-r="0" rotate-x="0" rotate-y="0" scale-x="1" scale-y="1"/>
        <!-- Note: scale-x="-1": flip the parallellogram: -->
        <transform for-id="parallelogram" translate-x="{-$singleShortSide * 0.9}" translate-y="{$singleShortSide * 0.85}" rotate-r="45" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="-1" scale-y="1"/>
    </xsl:variable>
    
    <xsl:variable name="tux-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="{$singleLongSide}" translate-y="0" rotate-r="0" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{$singleShortSide * 1.61}" translate-y="{$singleShortSide * 1.52}" rotate-r="-45" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * 2.13}" translate-y="{$singleShortSide * 2.9}" rotate-r="45" rotate-x="0" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{$singleShortSide * 0.8}" translate-y="{$singleShortSide * -0.36}" rotate-r="-45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide * -0.26}" translate-y="{$singleShortSide * -0.72}" rotate-r="45" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="{$singleShortSide * 0.2}" translate-y="{$singleShortSide * -1.33}" rotate-r="-45" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="{$singleShortSide * -2.05}" translate-y="{$singleShortSide * 0.44}" rotate-r="135" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="-1" scale-y="1"/>
    </xsl:variable>

    <xsl:variable name="runner-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="0" translate-y="0" rotate-r="-135" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{$singleShortSide * 0.51}" translate-y="{$singleShortSide * 0.90}" rotate-r="45" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * -0.4}" translate-y="{$singleShortSide * 2.11}" rotate-r="0" rotate-x="0" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{$singleShortSide * -0.37}" translate-y="{$singleShortSide * 3.5}" rotate-r="180" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide * 3.2}" translate-y="{$singleShortSide * 2.6}" rotate-r="90" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="{$singleShortSide * -0.2}" translate-y="{$singleShortSide * -1.4}" rotate-r="30" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="{$singleShortSide * -3.2}" translate-y="{$singleShortSide * 2.1}" rotate-r="0" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="-1" scale-y="1"/>
    </xsl:variable>
    
    <xsl:variable name="arrow-transforms" as="element(transform)+">
        <transform for-id="big-triangle-1" translate-x="{$singleShortSide * 0.99}" translate-y="{$singleShortSide * 2}" rotate-r="45" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="big-triangle-2" translate-x="{$singleShortSide * 0.11}" translate-y="{$singleShortSide * 1.12}" rotate-r="135" rotate-x="{$big-triangle-center}" rotate-y="{$big-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="medium-triangle" translate-x="{$singleShortSide * 1.15}" translate-y="{$singleShortSide * 0.6}" rotate-r="-135" rotate-x="0" rotate-y="{$medium-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-1" translate-x="{$singleShortSide * 2.4}" translate-y="{$singleShortSide * 1.2}" rotate-r="90" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="small-triangle-2" translate-x="{$singleShortSide * 1.4}" translate-y="{$singleShortSide * 0.7}" rotate-r="180" rotate-x="{$small-triangle-center}" rotate-y="{$small-triangle-center}" scale-x="1" scale-y="1"/>
        <transform for-id="square" translate-x="{$singleShortSide * 1.9}" translate-y="{$singleShortSide * 0.2}" rotate-r="0" rotate-x="{$square-center}" rotate-y="{$square-center}" scale-x="1" scale-y="1"/>
        <transform for-id="parallelogram" translate-x="{$singleShortSide * 1.4}" translate-y="{$singleShortSide * 1.7}" rotate-r="90" rotate-x="{$parallelogram-center-x}" rotate-y="{$parallelogram-center-y}" scale-x="1" scale-y="1"/>
    </xsl:variable>
    
    <!-- The transforms-map provides a mapping between transform names and the defining variables.
         Note that this script enforces the convention that colour name files have the same names
         as the keys, with an extension '.xml'.
         Update this map when new transforms-variables become available; also update the basic-shape-map below.
    -->    
    <xsl:variable name="transforms-map" as="map(xs:string, element(transform)+)">
        <xsl:map>
            <xsl:map-entry key="'black-tangram'" select="$tangram-transforms"/>
            <xsl:map-entry key="'coloured-tangram'" select="$tangram-transforms"/>
            <xsl:map-entry key="'blue-tangram'" select="$tangram-transforms"/>
            <xsl:map-entry key="'transparant-tangram'" select="$tangram-transforms"/>
            <xsl:map-entry key="'sitting-cat-tangram'" select="$sitting-cat-transforms"/>
            <xsl:map-entry key="'bird-tangram'" select="$bird-transforms"/>
            <xsl:map-entry key="'tux-tangram'" select="$tux-transforms"/>
            <xsl:map-entry key="'runner-tangram'" select="$runner-transforms"/>
            <xsl:map-entry key="'arrow-tangram'" select="$arrow-transforms"/>
        </xsl:map>
    </xsl:variable>
    
    <!-- The basic-shap-map provides a mapping between transform names and the basic shapes
         (a shape may be used more than once with different colours).
         Update this map when new transforms-variables become available; also update the transforms-map above.
    -->
    <xsl:variable name="basic-shape-map" as="map(xs:string, xs:string)">
        <xsl:map>
            <xsl:map-entry key="'black-tangram'" select="'tangram'"/>
            <xsl:map-entry key="'coloured-tangram'" select="'tangram'"/>
            <xsl:map-entry key="'blue-tangram'" select="'tangram'"/>
            <xsl:map-entry key="'transparant-tangram'" select="'tangram'"/>
            <xsl:map-entry key="'sitting-cat-tangram'" select="'sitting-cat'"/>
            <xsl:map-entry key="'bird-tangram'" select="'bird'"/>
            <xsl:map-entry key="'tux-tangram'" select="'tux'"/>
            <xsl:map-entry key="'runner-tangram'" select="'runner'"/>
        </xsl:map>
    </xsl:variable>
    
    <!-- This template is used in the Saxon-JS environment in order to initialize the SVG image on the HTML page. -->
    <xsl:template name="initialize">
        <xsl:call-template name="on-tangram-start"/>
        <ixsl:set-property name="{$keyForPreviousFangram}" select="$initialShape" object="ixsl:page()"/>
        
        <xsl:call-template name="initial-tangram">
            <xsl:with-param name="initial-transforms" as="element(transform)+" select="$transforms-map($initialShape)"/>
            <xsl:with-param name="settings" select="$initialColours"/>
        </xsl:call-template>
    </xsl:template>
    
    <!-- This template initiates the drawing of a new tangram image. -->
    <xsl:template match="*:input[@type eq 'image' and @id]" mode="ixsl:onclick">
        <xsl:variable name="oldShape" as="xs:string" select="ixsl:get(ixsl:page(), $keyForPreviousFangram)"/>
        <xsl:variable name="newShape" as="xs:string" select="@id"/>
        <ixsl:set-property name="{$keyForPreviousFangram}" select="$newShape" object="ixsl:page()"/>
        
        <!-- Leave this xsl:message here, for some reason it triggers something that causes ixsl:schedule-action
             to have effect. Without it, the figure appears in one time on the page. -->
        <xsl:message select="'oldShape=' || $oldShape || ', newShape=' || $newShape"/>
        
        <xsl:variable name="oldTransforms" as="element(transform)+" select="$transforms-map($oldShape)"/>
        <xsl:variable name="newTransforms" as="element(transform)+" select="$transforms-map($newShape)"/>
        
        <xsl:choose>
            <xsl:when test="$basic-shape-map($oldShape) eq $basic-shape-map($newShape)">
                <!-- Same kind of figure, perhaps different colors. Make sure some movement is
                     visible by starting at the zero situation: -->
                <xsl:call-template name="next-tangram">
                    <xsl:with-param name="old-transforms" as="element(transform)+" select="$zero-transforms"/>
                    <xsl:with-param name="new-transforms" as="element(transform)+" select="$newTransforms"/>
                    <xsl:with-param name="settings" as="document-node()" select="doc($newShape || '.xml')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="next-tangram">
                    <xsl:with-param name="old-transforms" as="element(transform)+" select="$oldTransforms"/>
                    <xsl:with-param name="new-transforms" as="element(transform)+" select="$newTransforms"/>
                    <xsl:with-param name="settings" as="document-node()" select="doc($newShape || '.xml')"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Creates a map with keys corresponding to the svg object id's and values being a nested map
         that maps the svg object's attribute names to values needed to generate an svg transform attributte
         later on. -->
    <xsl:function name="local:create-transform-map" as="map(xs:string, map(xs:string, xs:double))">
        <xsl:param name="svgObjectsWithId" as="element()*"/>
        <xsl:param name="old-transforms" as="element(transform)+"/>
        <xsl:param name="new-transforms" as="element(transform)+"/>
        
        <xsl:map>
            <xsl:for-each select="$svgObjectsWithId">
                <xsl:variable name="svgObject" as="element()" select="."/>
                <xsl:map-entry key="string($svgObject/@id)" select="local:create-transform-entrymap($svgObject/@id, $old-transforms, $new-transforms)"/>    
            </xsl:for-each>
        </xsl:map>
    </xsl:function>
    
    <!-- Creates a map with keys equal to the svgObject's attributes (except id) and stores a new increment and original (.org) value
         for them. The origin serves as the basis for transforms, while the increment is added to it in every iteration
         that moves an svg object in the browser page. -->
    <xsl:function name="local:create-transform-entrymap" as="map(xs:string, xs:double)">
        <!-- Note that old-transforms will be the empty sequence when dealing with the first tangram figure. -->
        <xsl:param name="svgObjectId" as="xs:string"/>
        <xsl:param name="old-transforms" as="element(transform)+"/>
        <xsl:param name="new-transforms" as="element(transform)+"/>
        <xsl:variable name="old-transform" as="element(transform)" select="$old-transforms/self::transform[@for-id eq $svgObjectId]"/>
        <xsl:variable name="new-transform" as="element(transform)" select="$new-transforms/self::transform[@for-id eq $svgObjectId]"/>
        <xsl:map>
            <xsl:for-each select="$new-transform/@*[local-name() ne 'for-id']"> <!-- For some reason, "$new-transform/@* except @for-id" is not allowed here: there is no context item. -->
                <xsl:variable name="key" as="xs:string" select="local-name(.)"/>
                <xsl:variable name="old-value" as="xs:string" select="$old-transform/@*[local-name() eq $key]"/>
                <xsl:variable name="new-value" as="xs:string" select="$new-transform/@*[local-name() eq $key]"/>
                
                <xsl:variable name="org-key" as="xs:string" select="local-name(.) || '.org'"/>
                <xsl:variable name="key-value" as="xs:double" select="xs:double($new-value) - xs:double($old-value)"/>
                <xsl:map-entry key="$org-key" select="xs:double($old-value)"/>
                <xsl:map-entry key="$key" select="xs:double($key-value div $moveIterations-as-int)"/>
            </xsl:for-each>
        </xsl:map>
    </xsl:function>
    
    <xsl:template name="initial-tangram">
        <xsl:param name="initial-transforms" required="yes" as="element(transform)+"/>
        <xsl:param name="settings" required="yes" as="xs:string"/>
        
        <xsl:result-document href="{'#' || $idOfTangramDiv}" method="ixsl:replace-content">
            <xsl:copy-of select="tangram:get-initial-tangram(doc($settings))"/>
        </xsl:result-document>
        
        <xsl:variable name="svgObjectsWithId" as="element()*" select="ixsl:page()//svg:*[@id]"/>
        
        <!-- Note that we pass the empty sequence for parameter old-transforms: -->
        <xsl:variable name="transformmap" as="map(xs:string, map(xs:string, xs:double))" select="local:create-transform-map($svgObjectsWithId, $zero-transforms, $initial-transforms)"/>
        
        <xsl:for-each select="$svgObjectsWithId">
            <xsl:variable name="id" select="@id" as="attribute(id)?"/>
            <xsl:call-template name="do-moves">
                <xsl:with-param name="id" select="string($id)" as="xs:string"/>
                <xsl:with-param name="transformmap-for-id" select="$transformmap(string(@id))" as="map(xs:string, xs:double)"/>
                <xsl:with-param name="svgobject" as="element()" select="."/>
                <xsl:with-param name="iteration-count" as="xs:integer" select="1"/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="next-tangram">
        <xsl:param name="old-transforms" required="yes" as="element(transform)+"/>
        <xsl:param name="new-transforms" required="yes" as="element(transform)+"/>
        <xsl:param name="settings" required="yes" as="document-node()"/>
        
        <xsl:call-template name="on-tangram-start"/>
        
        <xsl:for-each select="ixsl:page()//*:div[@id eq 'tangram-div']//svg:*[@id]">
            <xsl:variable name="nth" as="xs:integer" select="count(preceding-sibling::*) + 1"/>
            <ixsl:schedule-action wait="xs:integer($waitMillisBetweenMoves-as-int * $nth * 7)">
                <!-- 7 is the number of tangram pieces -->
                <xsl:call-template name="change-color-for-id">
                    <xsl:with-param name="settings" select="$settings"/>
                    <xsl:with-param name="id" select="string(@id)"/>
                </xsl:call-template>
            </ixsl:schedule-action>
        </xsl:for-each>
        
        <xsl:variable name="svgObjectsWithId" as="element()*" select="ixsl:page()//svg:*[@id]"/>
        
        <xsl:variable name="transformmap" as="map(xs:string, map(xs:string, xs:double))" select="local:create-transform-map($svgObjectsWithId, $old-transforms, $new-transforms)"/>
        
        <xsl:for-each select="$svgObjectsWithId">
            <xsl:variable name="id" select="@id" as="attribute(id)?"/>
            <xsl:call-template name="do-moves">
                <xsl:with-param name="id" select="string($id)" as="xs:string"/>
                <xsl:with-param name="transformmap-for-id" select="$transformmap(string(@id))" as="map(xs:string, xs:double)"/>
                <xsl:with-param name="svgobject" as="element()" select="."/>
                <xsl:with-param name="iteration-count" as="xs:integer" select="1"/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="change-color-for-id">
        <xsl:param name="settings" required="yes" as="document-node()"/>
        <xsl:param name="id" required="yes" as="xs:string"/>
        <ixsl:set-attribute name="fill" select="tangram:get-fill-colour-for-id($settings, $id)"/>
        <ixsl:set-attribute name="stroke" select="tangram:get-stroke-colour-for-id($settings, $id)"/>
    </xsl:template>
    
    
    <xsl:template name="do-moves">
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="transformmap-for-id" as="map(xs:string, xs:double)"/>
        <xsl:param name="svgobject" as="element()" required="yes"/>
        <xsl:param name="iteration-count" as="xs:integer" required="yes"/>
        
        <xsl:variable name="translate-x" as="xs:double" select="$transformmap-for-id('translate-x.org') + ($iteration-count * $transformmap-for-id('translate-x'))"/>
        <xsl:variable name="translate-y" as="xs:double" select="$transformmap-for-id('translate-y.org') + ($iteration-count * $transformmap-for-id('translate-y'))"/>
        <xsl:variable name="rotate-r" as="xs:double" select="$transformmap-for-id('rotate-r.org') + ($iteration-count * $transformmap-for-id('rotate-r'))"/>
        <xsl:variable name="rotate-x" as="xs:double" select="$transformmap-for-id('rotate-x.org') + ($iteration-count * $transformmap-for-id('rotate-x'))"/>
        <xsl:variable name="rotate-y" as="xs:double" select="$transformmap-for-id('rotate-y.org') + ($iteration-count * $transformmap-for-id('rotate-y'))"/>
        <xsl:variable name="scale-x" as="xs:double" select="$transformmap-for-id('scale-x.org') + ($iteration-count * $transformmap-for-id('scale-x'))"/>
        <xsl:variable name="scale-y" as="xs:double" select="$transformmap-for-id('scale-y.org') + ($iteration-count * $transformmap-for-id('scale-y'))"/>
        
        <xsl:for-each select="$svgobject">
            <!-- This iterates only once, it merely sets the context - there is just one svgobject -->
            <xsl:variable name="transform" as="xs:string" select="
                'scale(' || $scale-x || ', ' || $scale-y || ') ' ||
                'translate(' || $translate-x || ', ' || $translate-y || ') ' ||
                'rotate(' || $rotate-r || ', ' || $rotate-x || ', ' || $rotate-y || ')'
                "/>
            <!--<xsl:message select="$id || ': ' || $transform"/>-->
            <ixsl:set-attribute name="transform" select="$transform"/>
        </xsl:for-each>
        
        <xsl:choose>
            <xsl:when test="$iteration-count lt $moveIterations-as-int">
                <ixsl:schedule-action wait="xs:integer($waitMillisBetweenMoves-as-int)">
                    <xsl:call-template name="do-moves">
                        <xsl:with-param name="id" select="$id" as="xs:string"/>
                        <xsl:with-param name="transformmap-for-id" select="$transformmap-for-id" as="map(xs:string, xs:double)"/>
                        <xsl:with-param name="svgobject" as="element()" select="."/>
                        <xsl:with-param name="iteration-count" as="xs:integer" select="$iteration-count + 1"/>
                    </xsl:call-template>
                </ixsl:schedule-action>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="on-tangram-completion"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    
    <xsl:template name="on-tangram-completion">
        <!-- Enable the tangram buttons (assumed to be buttons with an id attribute): -->
        <xsl:for-each select="ixsl:page()//*:input[@id]"><ixsl:remove-attribute name="disabled"/></xsl:for-each>
    </xsl:template>
    
    <xsl:template name="on-tangram-start">
        <!-- Disable the tangram buttons (assumed to be buttons with an id attribute): -->
        <xsl:for-each select="ixsl:page()//*:input[@id]"><ixsl:set-attribute name="disabled" select="'disabled'"/></xsl:for-each>
    </xsl:template>
    
    <xsl:template match="node() | @*" mode="colourify">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="colourify"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@fill[../@id]" mode="colourify">
        <xsl:param name="settings" as="document-node()" tunnel="yes"/>
        
        <xsl:variable name="id" select="../@id" as="attribute(id)?"/>
        <xsl:variable name="colour" as="xs:string?" select="tangram:get-fill-colour-for-id($settings, $id)"/>
        <xsl:attribute name="fill" select="if ($colour) then $colour else ."/>
    </xsl:template>
    
    <xsl:template match="@stroke[../@id]" mode="colourify">
        <xsl:param name="settings" as="document-node()" tunnel="yes"/>
        <xsl:variable name="id" select="../@id" as="attribute(id)?"/>
        <xsl:variable name="colour" as="xs:string?" select="tangram:get-stroke-colour-for-id($settings, $id)"/>
        <xsl:attribute name="stroke" select="if ($colour) then $colour else ."/>
    </xsl:template>
    
</xsl:stylesheet>

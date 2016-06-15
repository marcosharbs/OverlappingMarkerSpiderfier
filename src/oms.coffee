###* @preserve OverlappingMarkerSpiderfier
https://github.com/jawj/OverlappingMarkerSpiderfier
Copyright (c) 2011 - 2013 George MacKerron
Released under the MIT licence: http://opensource.org/licenses/mit-license
Note: The Google Maps API v3 must be included *before* this code
###

class @['OverlappingMarkerSpiderfier']
  p = @::  # this saves a lot of repetition of .prototype that isn't optimized away
  
  gm = google.maps
  ge = gm.event
  mt = gm.MapTypeId
  twoPi = Math.PI * 2
  
  p['keepSpiderfied']  = no          # yes -> don't unspiderfy when a marker is selected
  p['markersWontHide'] = no          # yes -> a promise you won't hide markers, so we needn't check
  p['markersWontMove'] = no          # yes -> a promise you won't move markers, so we needn't check

  p['spiderfiedShadowColor'] = 'white' # [valid color like 'black' or '#000', or falsey for no shadow] ->
                                       # Show a shadow underneath the spiderfied markers

  p['nudgeStackedMarkers'] = yes       # yes -> nudge up markers that are perfectly stacked
  p['minNudgeZoomLevel'] = 8           # The minimum zoom level at which to nudge markers
  p['nudgeRadius'] = 1                 # The distance of the nudged marker from its original position
  p['markerCountInBaseNudgeLevel'] = 9 # The number of markers in the closest ring to the original marker
  p['maxNudgeCount'] = 9               # Max number of markers that will be nudged from the center. A smaller count
                                       # means fewer nudged markers per stack, but also better nudge performance.
  p['nudgeBucketSize'] = 12            # The size of the buckets arranged in a grid to use
                                       # in determining which markers need to be nudged
                                       # (0 means nudging only occurs when icons are perfectly overlapped)

  p['nearbyDistance'] = 20           # spiderfy markers within this range of the one clicked, in px
  
  p['circleSpiralSwitchover'] = 9    # show spiral instead of circle from this marker count upwards
                                     # 0 -> always spiral; Infinity -> always circle
  p['circleFootSeparation'] = 23     # related to circumference of circle
  p['circleStartAngle'] = twoPi / 12
  p['spiralFootSeparation'] = 26     # related to size of spiral (experiment!)
  p['spiralLengthStart'] = 11        # ditto
  p['spiralLengthFactor'] = 4        # ditto
  
  p['spiderfiedZIndex'] = 1000       # ensure spiderfied markers are on top
  p['usualLegZIndex'] = 10           # for legs
  p['highlightedLegZIndex'] = 20     # ensure highlighted leg is always on top
  p['event'] = 'click'               # Event to use when we want to trigger spiderify
  p['minZoomLevel'] = no             # Minimum zoom level necessary to trigger spiderify
  p['lineToCenter'] = yes            # yes -> Point all the lines to the center of the circle or spiral
                                     # no -> Point the lines to the original positions of each marker
  
  p['legWeight'] = 1.5
  p['legColors'] =
    'usual': {}
    'highlighted': {}
  
  lcU = p['legColors']['usual']
  lcH = p['legColors']['highlighted']
  lcU[mt.HYBRID]  = lcU[mt.SATELLITE] = '#fff'
  lcH[mt.HYBRID]  = lcH[mt.SATELLITE] = '#f00'
  lcU[mt.TERRAIN] = lcU[mt.ROADMAP]   = '#444'
  lcH[mt.TERRAIN] = lcH[mt.ROADMAP]   = '#f00'
  
  # Note: it's OK that this constructor comes after the properties, because a function defined by a 
  # function declaration can be used before the function declaration itself
  constructor: (@map, opts = {}) ->
    (@[k] = v) for own k, v of opts
    @projHelper = new @constructor.ProjHelper(@map)
    @initMarkerArrays()
    @listeners = {}
    for e in ['click', 'zoom_changed', 'maptypeid_changed']
      ge.addListener(@map, e, => @['unspiderfy']())
    if @['nudgeStackedMarkers']
      ge.addListenerOnce @map, 'idle', =>
        ge.addListener(@map, 'zoom_changed', => @mapZoomChangeListener())
        @mapZoomChangeListener()

  p.initMarkerArrays = ->
    @markers = []
    @markerListenerRefs = []
    
  p['addMarker'] = (marker) ->
    return @ if marker['_oms']?
    marker['_oms'] = yes
    listenerRefs = [ge.addListener(marker, @['event'], (event) => @spiderListener(marker, event))]
    unless @['markersWontHide']
      listenerRefs.push(ge.addListener(marker, 'visible_changed', => @markerChangeListener(marker, no)))
    unless @['markersWontMove']
      listenerRefs.push(ge.addListener(marker, 'position_changed', => @markerChangeListener(marker, yes)))
    @markerListenerRefs.push(listenerRefs)
    @markers.push(marker)
    @requestNudge() if @isNudgingActive()
    @  # return self, for chaining

  p.nudgeTimeout = null
  p.requestNudge = ->
    clearTimeout(@nudgeTimeout) if @nudgeTimeout
    @nudgeTimeout = setTimeout(
      => @nudgeAllMarkers(),
      10
    )

  p.isNudgingActive = ->
    @['nudgeStackedMarkers'] and not (@['minNudgeZoomLevel'] and @map.getZoom() < @['minNudgeZoomLevel']) and not @spiderfied

  p.markerChangeListener = (marker, positionChanged) ->
    if marker['_omsData']? and marker['_omsData'].leg and (positionChanged or not marker.getVisible()) and not (@spiderfying? or @unspiderfying?)
      @['unspiderfy'](if positionChanged then marker else null)

  p.countsPerLevel = [1,1]
  p.levelsByCount = []

  p.getCountPerNudgeLevel = (level) ->
    return @countsPerLevel[level] if @countsPerLevel[level]?

    @countsPerLevel[level] = @getCountPerNudgeLevel(level - 1) + Math.pow(2, level - 2) * @['markerCountInBaseNudgeLevel']
    return @countsPerLevel[level]

  p.getNudgeLevel = (markerIndex) ->
    return @levelsByCount[markerIndex] if @levelsByCount[markerIndex]?

    level = 0
    while markerIndex >= @countsPerLevel[level]
      if level + 1 >= @countsPerLevel.length
        @getCountPerNudgeLevel(level + 1)
      level++
    @levelsByCount[markerIndex] = level - 1
    return @levelsByCount[markerIndex]

  p.nudgeAllMarkers = ->
    return if not @isNudgingActive()

    positions = {}
    changesX = []
    changesY = []
    bucketSize = 1 / ((1 + @['nudgeBucketSize']) * @['nudgeRadius'])
    getHash = (pos) => Math.floor(pos.x * bucketSize) + ',' + Math.floor(pos.y * bucketSize)
    for m in @markers
      needsNudge = no
      pos = @llToPt(m['_omsData']?.usualPosition ? m.position)
      originalPos = {x: pos.x, y: pos.y}
      posHash = getHash(pos)
      while positions[posHash]? and (not @['maxNudgeCount']? or positions[posHash] <= @['maxNudgeCount'])
        count = positions[posHash]
        positions[posHash] += 1

        if changesX[count]?
          changeX = changesX[count]
          changeY = changesY[count]
        else
          ringLevel = @getNudgeLevel(count)
          changesX[count] = changeX = Math.sin(twoPi * count / @['markerCountInBaseNudgeLevel'] / ringLevel) * 20 * @['nudgeRadius'] * ringLevel
          changesY[count] = changeY = Math.cos(twoPi * count / @['markerCountInBaseNudgeLevel'] / ringLevel) * 20 * @['nudgeRadius'] * ringLevel

        pos.x = originalPos.x + changeX
        pos.y = originalPos.y + changeY
        @nudged = yes
        needsNudge = yes
        posHash = getHash(pos);

      if needsNudge
        m['_omsData'] = m['_omsData'] ? {}
        m['_omsData'].usualPosition = m['_omsData']?.usualPosition ? m.position;
        m.setPosition(@ptToLl(pos))
      else if m['_omsData']? and not m['_omsData'].leg?
        m.setPosition(m['_omsData'].usualPosition)
        delete m['_omsData']

      if not (posHash of positions)
        positions[posHash] = 1

  p.resetNudgedMarkers = ->
    return if not @nudged
    for m in @markers
      if m['_omsData']? and not m['_omsData'].leg?
        m.setPosition(m['_omsData'].usualPosition)
        delete m['_omsData']
    delete @nudged


  p.mapZoomChangeListener = () ->
    if @['minNudgeZoomLevel'] and @map.getZoom() < @['minNudgeZoomLevel']
      return @resetNudgedMarkers()
    @requestNudge()

  p['getMarkers'] = -> @markers[0..]  # returns a copy, so no funny business

  p['removeMarker'] = (marker) ->
    @['unspiderfy']() if marker['_omsData']?  # otherwise it'll be stuck there forever!
    i = @arrIndexOf(@markers, marker)
    return @ if i < 0
    listenerRefs = @markerListenerRefs.splice(i, 1)[0]
    ge.removeListener(listenerRef) for listenerRef in listenerRefs
    delete marker['_oms']
    @markers.splice(i, 1)
    @requestNudge() if @isNudgingActive()
    @  # return self, for chaining
    
  p['clearMarkers'] = ->
    @['unspiderfy']()
    for marker, i in @markers
      listenerRefs = @markerListenerRefs[i]
      ge.removeListener(listenerRef) for listenerRef in listenerRefs
      delete marker['_oms']
    @initMarkerArrays()
    @  # return self, for chaining
        
  # available listeners: click(marker), spiderfy(markers), unspiderfy(markers)
  p['addListener'] = (event, func) ->
    (@listeners[event] ?= []).push(func)
    @  # return self, for chaining
    
  p['removeListener'] = (event, func) ->
    i = @arrIndexOf(@listeners[event], func)
    @listeners[event].splice(i, 1) unless i < 0
    @  # return self, for chaining
  
  p['clearListeners'] = (event) ->
    @listeners[event] = []
    @  # return self, for chaining
  
  p.trigger = (event, args...) ->
    func(args...) for func in (@listeners[event] ? [])
  
  p.generatePtsCircle = (count, centerPt) ->
    circumference = @['circleFootSeparation'] * (2 + count)
    legLength = circumference / twoPi  # = radius from circumference
    angleStep = twoPi / count
    for i in [0...count]
      angle = @['circleStartAngle'] + i * angleStep
      new gm.Point(centerPt.x + legLength * Math.cos(angle), 
                   centerPt.y + legLength * Math.sin(angle))
  
  p.generatePtsSpiral = (count, centerPt) ->
    legLength = @['spiralLengthStart']
    angle = 0
    for i in [0...count]
      angle += @['spiralFootSeparation'] / legLength + i * 0.0005
      pt = new gm.Point(centerPt.x + legLength * Math.cos(angle), 
                        centerPt.y + legLength * Math.sin(angle))
      legLength += twoPi * @['spiralLengthFactor'] / angle
      pt
  
  p.spiderListener = (marker, event) ->
    markerSpiderfied = marker['_omsData']? and marker['_omsData'].leg?
    unless markerSpiderfied and @['keepSpiderfied']
      if @['event'] is 'mouseover'
        window.clearTimeout(p.timeout)
        p.timeout = setTimeout(
          () => @['unspiderfy'](),
          3000
        )
      else
        @['unspiderfy']()
    if (
      markerSpiderfied or                                      # don't spiderfy an already-spiderfied marker
      @map.getStreetView().getVisible() or                     # don't spiderfy in Street View
      @map.getMapTypeId() is 'GoogleEarthAPI' or               # don't spiderfy in GE Plugin!
      @['minZoomLevel'] and @map.getZoom() < @['minZoomLevel'] # don't spiderfy below the minimum zoom level
    )
      @trigger('click', marker, event)
    else
      nearbyMarkerData = []
      nonNearbyMarkers = []
      nDist = @['nearbyDistance']
      pxSq = nDist * nDist
      markerPt = @llToPt(marker.position)
      for m in @markers
        continue unless m.map? and m.getVisible()  # at 2011-08-12, property m.visible is undefined in API v3.5
        mPt = @llToPt(m.position)
        if @ptDistanceSq(mPt, markerPt) < pxSq
          nearbyMarkerData.push(marker: m, markerPt: mPt)
        else
          nonNearbyMarkers.push(m)
      if nearbyMarkerData.length is 1 # If no other markers are nearby the clicked marker
        # Trigger the default marker click handler
        @trigger('click', marker, event)
      else
        @spiderfy(nearbyMarkerData, nonNearbyMarkers)
  
  p['markersNearMarker'] = (marker, firstOnly = no) ->
    unless @projHelper.getProjection()?
      throw "Must wait for 'idle' event on map before calling markersNearMarker"
    nDist = @['nearbyDistance']
    pxSq = nDist * nDist
    markerPt = @llToPt(marker.position)
    markers = []
    for m in @markers
      continue if m is marker or not m.map? or not m.getVisible()
      mPt = @llToPt(m['_omsData']?.usualPosition ? m.position)
      if @ptDistanceSq(mPt, markerPt) < pxSq
        markers.push(m)
        break if firstOnly
    markers
  
  p['markersNearAnyOtherMarker'] = ->  # *very* much quicker than calling markersNearMarker in a loop
    unless @projHelper.getProjection()?
      throw "Must wait for 'idle' event on map before calling markersNearAnyOtherMarker"
    nDist = @['nearbyDistance']
    pxSq = nDist * nDist
    mData = for m in @markers
      {pt: @llToPt(m['_omsData']?.usualPosition ? m.position), willSpiderfy: no}
    for m1, i1 in @markers
      continue unless m1.map? and m1.getVisible()
      m1Data = mData[i1]
      continue if m1Data.willSpiderfy
      for m2, i2 in @markers
        continue if i2 is i1
        continue unless m2.map? and m2.getVisible()
        m2Data = mData[i2]
        continue if i2 < i1 and not m2Data.willSpiderfy
        if @ptDistanceSq(m1Data.pt, m2Data.pt) < pxSq
          m1Data.willSpiderfy = m2Data.willSpiderfy = yes
          break
    m for m, i in @markers when mData[i].willSpiderfy
  
  p.makeHighlightListenerFuncs = (marker) ->
    highlight: =>
      marker['_omsData'].leg.setOptions
        strokeColor: @['legColors']['highlighted'][@map.mapTypeId]
        zIndex: @['highlightedLegZIndex']
      if marker['_omsData'].shadow?
        icon = marker['_omsData'].shadow.getIcon()
        icon.fillOpacity = 0.8
        marker['_omsData'].shadow.setOptions
          icon: icon

    unhighlight: =>
      marker['_omsData'].leg.setOptions
        strokeColor: @['legColors']['usual'][@map.mapTypeId]
        zIndex: @['usualLegZIndex']
      if marker['_omsData'].shadow?
        icon = marker['_omsData'].shadow.getIcon()
        icon.fillOpacity = 0.3
        marker['_omsData'].shadow.setOptions
          icon: icon

  p.spiderfy = (markerData, nonNearbyMarkers) ->
    @spiderfying = yes
    numFeet = markerData.length
    bodyPt = @ptAverage(md.markerPt for md in markerData)
    footPts = if numFeet >= @['circleSpiralSwitchover'] 
      @generatePtsSpiral(numFeet, bodyPt).reverse()  # match from outside in => less criss-crossing
    else
      @generatePtsCircle(numFeet, bodyPt)
    centerLl = @ptToLl(bodyPt)
    spiderfiedMarkers = for footPt in footPts
      footLl = @ptToLl(footPt)
      nearestMarkerDatum = @minExtract(markerData, (md) => @ptDistanceSq(md.markerPt, footPt))
      marker = nearestMarkerDatum.marker
      lineOrigin = if @['lineToCenter'] then centerLl else marker.position
      leg = new gm.Polyline
        map: @map
        path: [lineOrigin, footLl]
        strokeColor: @['legColors']['usual'][@map.mapTypeId]
        strokeWeight: @['legWeight']
        zIndex: @['usualLegZIndex']
      marker['_omsData'] = marker['_omsData'] ? {}
      marker['_omsData'].usualPosition = marker['_omsData']?.usualPosition ? marker.position
      marker['_omsData'].leg = leg

      if @['spiderfiedShadowColor']
        marker['_omsData'].shadow = new gm.Marker
          position: footLl
          map: @map
          clickable: false
          zIndex: -2
          icon:
            path: google.maps.SymbolPath.CIRCLE
            fillOpacity: 0.3
            fillColor: @['spiderfiedShadowColor']
            strokeWeight: 0
            scale: 20

      unless @['legColors']['highlighted'][@map.mapTypeId] is
             @['legColors']['usual'][@map.mapTypeId]
        highlightListenerFuncs = @makeHighlightListenerFuncs(marker)
        marker['_omsData'].hightlightListeners =
          highlight:   ge.addListener(marker, 'mouseover', highlightListenerFuncs.highlight)
          unhighlight: ge.addListener(marker, 'mouseout',  highlightListenerFuncs.unhighlight)
      marker.setPosition(footLl)
      marker.setZIndex(Math.round(@['spiderfiedZIndex'] + footPt.y))  # lower markers cover higher
      marker
    delete @spiderfying
    @spiderfied = yes
    @trigger('spiderfy', spiderfiedMarkers, nonNearbyMarkers)
  
  p['unspiderfy'] = (markerNotToMove = null) ->
    return @ unless @spiderfied? or @nudged?
    @unspiderfying = yes
    unspiderfiedMarkers = []
    nonNearbyMarkers = []
    for marker in @markers
      if marker['_omsData']? and marker['_omsData'].leg?
        marker['_omsData'].leg.setMap(null)
        marker['_omsData'].shadow?.setMap(null)
        marker.setPosition(marker['_omsData'].usualPosition) unless marker is markerNotToMove
        marker.setZIndex(null)
        listeners = marker['_omsData'].hightlightListeners
        if listeners?
          ge.removeListener(listeners.highlight)
          ge.removeListener(listeners.unhighlight)
        delete marker['_omsData']
        unspiderfiedMarkers.push(marker)
      else
        nonNearbyMarkers.push(marker)
    delete @unspiderfying
    delete @spiderfied
    @trigger('unspiderfy', unspiderfiedMarkers, nonNearbyMarkers)
    @requestNudge() if @nudged
    @  # return self, for chaining
  
  p.ptDistanceSq = (pt1, pt2) -> 
    dx = pt1.x - pt2.x
    dy = pt1.y - pt2.y
    dx * dx + dy * dy
  
  p.ptAverage = (pts) ->
    sumX = sumY = 0
    for pt in pts
      sumX += pt.x; sumY += pt.y
    numPts = pts.length
    new gm.Point(sumX / numPts, sumY / numPts)
  
  p.llToPt = (ll) -> @projHelper.getProjection().fromLatLngToDivPixel(ll)
  p.ptToLl = (pt) -> @projHelper.getProjection().fromDivPixelToLatLng(pt)
  
  p.minExtract = (set, func) ->  # destructive! returns minimum, and also removes it from the set
    for item, index in set
      val = func(item)
      if ! bestIndex? || val < bestVal
        bestVal = val
        bestIndex = index
    set.splice(bestIndex, 1)[0]
    
  p.arrIndexOf = (arr, obj) -> 
    return arr.indexOf(obj) if arr.indexOf?
    (return i if o is obj) for o, i in arr
    -1
  
  # the ProjHelper object is just used to get the map's projection
  @ProjHelper = (map) -> @setMap(map)
  @ProjHelper:: = new gm.OverlayView()
  @ProjHelper::['draw'] = ->  # dummy function

module.exports = @['OverlappingMarkerSpiderfier']

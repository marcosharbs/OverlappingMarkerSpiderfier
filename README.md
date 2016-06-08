Overlapping Marker Spiderfier for Google Maps API v3
====================================================

Customized fork of [jawj/OverlappingMarkerSpiderfier](https://github.com/jawj/OverlappingMarkerSpiderfier)

Demo
----

See the [demo map](http://fritz-c.github.com/OverlappingMarkerSpiderfier/examples/) (the data is random: reload the map to reposition the markers).

Installation
--------

Via npm:
```
npm install --save overlapping-marker-spiderfier
```

How to use
----------

See the [demo map source](https://github.com/fritz-c/OverlappingMarkerSpiderfier/blob/gh-pages/examples/index.html), or follow along here for a slightly simpler usage with commentary.

Create your map like normal:

```js
const map = new google.maps.Map(document.getElementById('map_canvas'), {
  center: {lat: 50, lng: 0},
  zoom: 6
});
```

Require `OverlappingMarkerSpiderfier` and create an instance:

```js
import OverlappingMarkerSpiderfier from 'overlapping-marker-spiderfier';
// ...
const options = { legWeight: 3 }; // Just an example of options - please set your own if necessary
const oms = new OverlappingMarkerSpiderfier(map, options);
```

Instead of adding click listeners to your markers directly via `google.maps.event.addListener`, add a global listener on the `OverlappingMarkerSpiderfier` instance instead. The listener will be passed the clicked marker as its first argument, and the Google Maps `event` object as its second.

```js
const iw = new google.maps.InfoWindow();
oms.addListener('click', function(marker, event) {
  iw.setContent(marker.desc);
  iw.open(map, marker);
});
```

You can also add listeners on the `spiderfy` and `unspiderfy` events, which will be passed an array of the markers affected. In this example, we observe only the `spiderfy` event, using it to close any open `InfoWindow`:

```js
oms.addListener('spiderfy', function(markers) {
  iw.close();
});
```

Finally, tell the `OverlappingMarkerSpiderfier` instance about each marker as you add it, using the `addMarker` method:

```js
for (let i = 0; i < markerPositions.length; i ++) {
  const marker = new google.maps.Marker({
    position: markerPositions[i],
    map: map
  });
  oms.addMarker(marker);  // <-- here
}
```

Docs
----

### Loading

The `google.maps` object must be available when this code runs -- i.e. put the Google Maps API &lt;script&gt; tag before this one.

### Construction

    new OverlappingMarkerSpiderfier(map, options)

Creates an instance associated with `map` (a `google.maps.Map`).

The `options` argument is an optional `Object` specifying any options you want changed from their defaults. 

## Options

Property                    | Type                    | Default   | Description
:---------------------------|:-----------------------:|:---------:|:------------
keepSpiderfied              | bool                    | `false`   | By default, the OverlappingMarkerSpiderfier works like Google Earth, in that when you click a spiderfied marker, the markers unspiderfy before any other action takes place.
minZoomLevel                | number or `false`       | `false`   | Minimum zoom level necessary to trigger spiderify
nearbyDistance              | number                  | `20`      | This is the pixel radius within which a marker is considered to be overlapping a clicked marker.
circleSpiralSwitchover      | number                  | `9`       | This is the lowest number of markers that will be fanned out into a spiral instead of a circle. Set this to `0` to always get spirals, or `Infinity` for all circles.
legWeight                   | number                  | `1.5`     | This determines the thickness of the lines joining spiderfied markers to their original locations.
circleFootSeparation        | number                  | `23`      | This is the pixel distance between each marker in a circle shape.
spiralFootSeparation        | number                  | `26`      | This is the pixel distance between each marker in a spiral shape.
nudgeStackedMarkers         | bool                    | `true`    | Nudge markers that are stacked right on top of each other, so markers aren't overlooked
minNudgeZoomLevel           | number                  | `8`       | The minimum zoom level at which to nudge markers
nudgeRadius                 | number                  | `1`       | The distance of the nudged marker from its original position
markerCountInBaseNudgeLevel | number                  | `9`       | The number of markers in the closest ring to the original marker
maxNudgeCount               | number or `false`       | `9`       | The maximum number of markers that will be nudged from the center. A smaller count means fewer nudged markers per stack, but also better nudge performance.
nudgeBucketSize             | number                  | `12`      | The size of the buckets arranged in a grid to use in determining which markers need to be nudged (0 means nudging only occurs when icons are perfectly overlapped)
lineToCenter                | bool                    | `true`    | When true, all lines point to the averaged center of the markers. When false, point the lines to the original positions of each marker.
spiderfiedShadowColor       | color string or `false` | `'white'` | Set the color of the shadow underneath the spiderfied markers, or to false to disable
markersWontMove             | bool                    | `false`   | See [Optimizations](#optimizations)
markersWontHide             | bool                    | `false`   | See [Optimizations](#optimizations)

### Instance methods: managing markers

Note: methods that have no obvious return value return the OverlappingMarkerSpiderfier instance they were called on, in case you want to chain method calls.

**addMarker(marker)**

Adds `marker` (a `google.maps.Marker`) to be tracked.

**removeMarker(marker)**

Removes `marker` from those being tracked. This *does not* remove the marker from the map (to remove a marker from the map you must call `setMap(null)` on it, as per usual).

**clearMarkers()**

Removes every `marker` from being tracked. Much quicker than calling `removeMarker` in a loop, since that has to search the markers array every time.

This *does not* remove the markers from the map (to remove the markers from the map you must call `setMap(null)` on each of them, as per usual).

**getMarkers()**

Returns an array of all the markers that are currently being tracked. This is a copy of the one used internally, so you can do what you like with it.

### Instance methods: managing listeners

**addListener(event, listenerFunc)**

Adds a listener to react to one of three events.

`event` may be `'click'`, `'spiderfy'` or `'unspiderfy'`.

For `'click'` events, `listenerFunc` receives one argument: the clicked marker object. You'll probably want to use this listener to do something like show a `google.maps.InfoWindow`.

For `'spiderfy'` or `'unspiderfy'` events, `listenerFunc` receives two arguments: first, an array of the markers that were spiderfied or unspiderfied; second, an array of the markers that were not. One use for these listeners is to make some distinction between spiderfied and non-spiderfied markers when some markers are spiderfied -- e.g. highlighting those that are spiderfied, or dimming out those that aren't.

**removeListener(event, listenerFunc)**

Removes the specified listener on the specified event.

**clearListeners(event)**

Removes all listeners on the specified event.

**unspiderfy()**

Returns any spiderfied markers to their original positions, and triggers any listeners you may have set for this event. Unless no markers are spiderfied, in which case it does nothing.

### Instance methods: advanced use only!

**markersNearMarker(marker, firstOnly)**

Returns an array of markers within `nearbyDistance` pixels of `marker` -- i.e. those that will be spiderfied when `marker` is clicked. If you pass `true` as the second argument, the search will stop when a single marker has been found. This is more efficient if all you want to know is whether there are any nearby markers.

*Don't* call this method in a loop over all your markers, since this can take a *very* long time.

The return value of this method may change any time the zoom level changes, and when any marker is added, moved, hidden or removed. Hence you'll very likely want call it (and take appropriate action) every time the map's `zoom_changed` event fires *and* any time you add, move, hide or remove a marker.

Note also that this method relies on the map's `Projection` object being available, and thus cannot be called until the map's first `idle` event fires.

**markersNearAnyOtherMarker()**

Returns an array of all markers that are near one or more other markers -- i.e. those will be spiderfied when clicked.

This method is several orders of magnitude faster than looping over all markers calling `markersNearMarker` (primarily because it only does the expensive business of converting lat/lons to pixel coordinates once per marker).

The return value of this method may change any time the zoom level changes, and when any marker is added, moved, hidden or removed. Hence you'll very likely want call it (and take appropriate action) every time the map's `zoom_changed` event fires *and* any time you add, move, hide or remove a marker.

Note also that this method relies on the map's `Projection` object being available, and thus cannot be called until the map's first `idle` event fires.

### Properties

You can set the following properties on an OverlappingMarkerSpiderfier instance:

**legColors.usual\[mapType\]** and **legColors.highlighted\[mapType\]**

These determine the usual and highlighted colours of the lines, where `mapType` is one of the `google.maps.MapTypeId` constants ([or a custom map type ID](https://github.com/jawj/OverlappingMarkerSpiderfier/issues/4)).

The defaults are as follows:


```js
const mti = google.maps.MapTypeId;
legColors.usual[mti.HYBRID] = legColors.usual[mti.SATELLITE] = '#fff';
legColors.usual[mti.TERRAIN] = legColors.usual[mti.ROADMAP] = '#444';
legColors.highlighted[mti.HYBRID] = legColors.highlighted[mti.SATELLITE] =
  legColors.highlighted[mti.TERRAIN] = legColors.highlighted[mti.ROADMAP] = '#f00';
```

You can also get and set any of the options noted in the constructor function documentation above as properties on an OverlappingMarkerSpiderfier instance. However, for some of these options (e.g. `markersWontMove`) modifications won't be applied retroactively.

### Optimizations
By default, change events for each added marker's `position` and `visibility` are observed (so that, if a spiderfied marker is moved or hidden, all spiderfied markers are unspiderfied, and the new position is respected where applicable).

However, if you know that you won't be moving and/or hiding any of the markers you add to this instance, you can save memory (a closure per marker in each case) by setting the options named `markersWontMove` and/or `markersWontHide` to `true`.

### Local dev
```sh
npm install
npm start # Starts a webpack dev server with livereload
```

License
-------

This software is released under the [MIT License](http://www.opensource.org/licenses/mit-license.php).

Finally, if you want to say thanks, the original author is on [Gittip](https://www.gittip.com/jawj).

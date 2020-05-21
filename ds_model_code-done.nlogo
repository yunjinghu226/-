globals [
  lower-edge
  upper-edge
  bus-frequency

  ped-waiting
  delay-record
  delay-record-dis
  delay-record-non
  collision-count
  colli-count-dis
  colli-count-non
]
patches-own [
  waiting-area?
  possible-pp
]
turtles-own[
  ;; personal traits
  desire-speed
  relaxation-t
  sense-radius
  body-radius
  mass
  comfort-radius
  ability
  ;; movement releated
  desire-v-x
  desire-v-y
  moment-speed-x
  moment-speed-y
  moment-speed
  d-wall
  total-force
  collision
  start-end
  delay
  start-tick
  for-bus?
  behavior
  destination
  preferred-p
]

to setup

  ca
  reset-ticks

  setup-world
  setup-bus-stop

  set delay-record []
  set delay-record-dis []
  set delay-record-non []
  set collision-count []
  set colli-count-dis []
  set colli-count-non []

end

to setup-world

  ;; setup the sidewalk with white patches
  set lower-edge (31 - sidewalk-width * 2) / 2
  set upper-edge lower-edge + sidewalk-width * 2
  ask patches with [pycor < upper-edge and pycor > lower-edge] [set pcolor white]
  ask patches with [pycor > upper-edge or pycor < lower-edge] [set pcolor grey]
  set bus-frequency 1

end

to setup-bus-stop

  ;; setup the bus stop based on type choice
  ;; then define the avoid area and waiting area based on bus stop type

  ;; bus flag
  if bus-stop-type = "bus flag" [
    ask patches with [pxcor >= 33 and pxcor <= 39 and (pycor < upper-edge and pycor > upper-edge - 4)] [set waiting-area? 1 set pcolor yellow]
    ask patches with [pycor = (upper-edge - 1.5) and pxcor = 34] [
      set pcolor red
      set waiting-area? 0
    ]
  ]

  ;; backing road
  if bus-stop-type = "backing road" [
    ask patches with [pycor < upper-edge - 1 and pycor >= upper-edge - 5.5 and pxcor < 37 and pxcor > 27] [set waiting-area? 1 set pcolor yellow]
    ask patches with [(pycor = (upper-edge - 1.5) and pxcor > 27 and pxcor < 35) or (pxcor = 28 or pxcor = 34 and (pycor = (upper-edge - 2.5) or pycor = (upper-edge - 3.5)))] [
      set pcolor red
      set waiting-area? 0
    ]
  ]

  ;; backing footway
  if bus-stop-type = "backing footway" [
    ask patches with [pycor < upper-edge and pycor >= upper-edge - 4.5 and pxcor < 37 and pxcor > 27] [set waiting-area? 1 set pcolor yellow]
    ask patches with [(pycor = (upper-edge - 4.5) and pxcor > 27 and pxcor < 35) or (pxcor = 28 or pxcor = 34 and (pycor = (upper-edge - 3.5) or pycor = (upper-edge - 2.5)))] [
      set pcolor red
      set waiting-area? 0
    ]
  ]

  ;; backing building
  if bus-stop-type = "backing building" [
    ask patches with [pycor > lower-edge and pycor <= lower-edge + 4.5 and pxcor < 37 and pxcor > 27] [set waiting-area? 1 set pcolor yellow]
    ask patches with [(pycor = (lower-edge + 0.5) and pxcor > 27 and pxcor < 35) or (pxcor = 28 or pxcor = 34 and (pycor = (lower-edge + 1.5) or pycor = (lower-edge + 2.5)))] [
      set pcolor red
      set waiting-area? 0
    ]
  ]

end

to set-ped
  ;; pedestrian initialization

  let a random-float 1
  if a <= disabled-proportion [set-visually-impaired]
  if a > disabled-proportion and a <= disabled-proportion * 2 [set-non-motorized]
  if a > disabled-proportion * 2 and a <= disabled-proportion * 3 [set-motorized]
  if a > disabled-proportion * 3 [set-non-disabled]

  set relaxation-t 0.5
  set moment-speed-y 0
  ifelse xcor = 0
  [set start-end 0 set heading 90 set moment-speed-x desire-speed set color (62 - 10 * moment-speed-x) / 3]
  [set start-end 60 set heading -90 set moment-speed-x 0 - desire-speed set color (274 - 10 * moment-speed-x) / 3]
  ifelse random-float 1 < 0.1 [set for-bus? 1] [set for-bus? 0]

  set collision []
  set start-tick ticks

end

to set-visually-impaired

  set ability "visually-impaired"
  set shape "circle"
  set size 0.75
  set sense-radius 0.4
  set body-radius 0.25
  set mass 65
  set comfort-radius random-normal-in-bounds 1.39 0.43 0.96 1.82
  set desire-speed random-normal-in-bounds 0.97 0.23 0.74 1.2

end

to set-non-motorized

  set ability "non-motorized"
  set shape "pentagon"
  set size 0.75
  set sense-radius 0.7
  set body-radius 0.4
  set mass 100
  set comfort-radius random-normal-in-bounds 1.68 0.31 1.37 1.99
  set desire-speed random-normal-in-bounds 0.68 0.17 0.51 0.85

end

to set-motorized

  set ability "motorized"
  set shape "square"
  set size 0.75
  set sense-radius 0.7
  set body-radius 0.4
  set mass 100
  set comfort-radius random-normal-in-bounds 1.73 0.37 1.36 2.1
  set desire-speed random-normal-in-bounds 0.78 0.21 0.57 0.99

end

to set-non-disabled

  set ability "non-disabled"
  set size 0.75
  set sense-radius 0.7
  set body-radius 0.25
  set mass 65
  set comfort-radius random-normal-in-bounds 1.52 0.4 1.12 1.92
  set desire-speed random-normal-in-bounds 1.12 0.16 0.96 1.28

end

to-report random-normal-in-bounds [m std l u]

  let a random-normal m std
  if a > u or a < l [report random-normal-in-bounds m std l u]
  report a

end

;; --------------------------------------------------------------------------

to go

  ; make movement
  sprawn-ped
  define-behavior
  calc-total-force
  move

  ; record measurements
  record-collision
  experience

  ; plot space-time
  plotter-LR
  plotter-RL

  ; update color and heading
  updates

  ; turtles finished trip die
  leave

  tick

end

;;-----------------------------------------------------------------------

to sprawn-ped

  let inflow pedestrian-flow / 3600 * 0.005 * 2
  if random-float 1 < inflow [
    set ped-waiting ped-waiting + 1
    if ped-waiting > 0 [
      crt 1 [
        set xcor one-of [0 60]
        set ycor (lower-edge + 1) + random-float (sidewalk-width * 2 - 2)
        set-ped
        if any? other turtles in-radius (comfort-radius * 2) [die]
      ]
        set ped-waiting ped-waiting - 1
    ]
  ]

end

to define-behavior

  ;; set the behavior mode for turtles based on their current position and final destination (for-bus?)
  ask turtles [
    ifelse for-bus? = 0 [
      let w min [pxcor] of patches with [pcolor = red]
      let ea max [pxcor] of patches with [pcolor = red]
      let n max [pycor] of patches with [pcolor = red]
      let s min [pycor] of patches with [pcolor = red]
      ifelse (start-end = 0 and xcor >= w - 4.5 and xcor < w - 0.5 and ycor <= n + 1 and ycor >= s - 1) or (start-end = 60 and xcor <= ea + 4.5 and xcor > ea + 0.5 and ycor <= n + 1 and ycor >= s - 1) [
        set behavior "bypassing"
      ] [set behavior "passing"]
    ] [
      ifelse [waiting-area?] of patch-here = 1 [
        assign-pp
        ifelse round xcor = first preferred-p and round ycor = last preferred-p [
          if behavior != "boarding" [set behavior "waiting"]
        ] [
          if behavior != "boarding" [set behavior "adjusting"]
        ]
      ] [
        if behavior != "boarding" [set behavior "approaching"]
      ]
    ]
  ]

  if remainder ticks bus-frequency * 12000 = 6000 [
    let waiting-peds turtles with [behavior = "waiting" or behavior = "adjusting"]
    let waiting-num count waiting-peds
    let boarding-num random waiting-num
    ask n-of boarding-num waiting-peds [set behavior "boarding"]
  ]

end

to assign-pp

  ;; assign a preperred position for for-bus pedestrians arriving the waiting area
  ifelse preferred-p = 0 [
    set possible-pp one-of patches with [pcolor = yellow and any? turtles-here = false]
    let pp-x [pxcor] of possible-pp
    let pp-y [pycor] of possible-pp
    set preferred-p list pp-x pp-y
  ] [
    set preferred-p preferred-p
  ]

end

;; create reporter for x and y components of three forces
;; 1. will force
to-report will-force

  ;; determine intermediate destination and calculate current desire velocity based on bahavior mode
  set-destination
  calc-desire-v

  ;; report a list of x and y components of the speed caused by will force
  let x-will (desire-v-x - moment-speed-x) * mass / relaxation-t
  let y-will (desire-v-y - moment-speed-y) * mass / relaxation-t
  report list x-will y-will

end

to set-destination

  ;; set the current destination point
  ask turtles with [behavior = "passing"] [
    ifelse start-end = 0 [set destination list 61 ycor] [set destination list -1 ycor]
  ]

  ask turtles with [behavior = "bypassing"] [
    ifelse bus-stop-type != "backing building" [
      let dest-y min [pycor] of patches with [pcolor = red] - 1
      let reference min-one-of patches with [pcolor = red] [distance myself]
      let dest-x [pxcor] of reference
      set destination list dest-x dest-y
    ] [
      let dest-y max [pycor] of patches with [pcolor = red] + 1
      let reference min-one-of patches with [pcolor = red] [distance myself]
      let dest-x [pxcor] of reference
      set destination list dest-x dest-y
    ]
  ]

  ask turtles with [behavior = "approaching"] [
    let possible-dest patches with [waiting-area? = 1]
    let dest-p min-one-of possible-dest [distance myself]
    let dest-x [pxcor] of dest-p
    let dest-y [pycor] of dest-p
    set destination list dest-x dest-y
  ]

  ask turtles with [behavior = "adjusting"] [
    set destination preferred-p
  ]

  ask turtles with [behavior = "waiting"] [
    set destination list xcor ycor
  ]

  ask turtles with [behavior = "boarding"] [
    ifelse bus-stop-type = "backing road" and xcor < 34 [
      set destination list 34 (upper-edge - 4.5)
    ] [
      set destination list 35 upper-edge
    ]
  ]

end

to calc-desire-v

  ;; calculate desired velocity (i.e. set desire-v-x and desire-v-y)
  ask turtles with [behavior = "waiting"] [set desire-v-x 0 set desire-v-y 0]

  ask turtles with [behavior = "adjusting"] [
    let wait-d 4 * desire-speed * 0.5 / mass
    let d-dest sqrt ((first destination - xcor) ^ 2 + (last destination - ycor) ^ 2)
    ifelse d-dest <= wait-d [
      set desire-v-x desire-speed * d-dest / wait-d * (first destination - xcor) / d-dest
      set desire-v-y desire-speed * d-dest / wait-d * (last destination - ycor) / d-dest
    ] [
      set desire-v-x desire-speed * (first destination - xcor) / d-dest
      set desire-v-y desire-speed * (last destination - ycor) / d-dest
    ]
  ]

  ask turtles with [behavior != "waiting" and behavior != "adjusting"] [
    let d-dest sqrt ((first destination - xcor) ^ 2 + (last destination - ycor) ^ 2)
    set desire-v-x desire-speed * (first destination - xcor) / d-dest
    set desire-v-y desire-speed * (last destination - ycor) / d-dest
  ]

end

;; 2. wall force

to-report wall-force [turtle-i]

  ;; check the distance from the two boudaries, report a list of x and y components of wall force
  ;; upper wall opens for boarding group
  let r [body-radius] of turtle-i
  let y [ycor] of turtle-i
  let d (min list abs (upper-edge - y) abs (lower-edge - y)) / 2
  ifelse y < 15.5 [set d-wall d] [set d-wall (0 - d)]

  ifelse d <= sense-radius [
    let x [xcor] of turtle-i
    ifelse [behavior] of turtle-i = "boarding" and x >= 33.5 and x <= 36.5 [report list 0 0] [
      if d >= r [
      let y-force 2000 * exp ((r - d) / 0.08) * d-wall / d
      report list 0 y-force
      ]
    if d < r [
      let y-force (2000 * exp ((r - d) / 0.08) + 24000 * (r - d)) * d-wall / d
      let x-force 0 - (r - d) * moment-speed-x
      report list x-force y-force
      ]
    ]
  ] [ report list 0 0 ]

end

;; 3. interaction force

to-report ped-force [turtle-i turtle-j]

  ;; report a list of x and y components of all the interactive forces caused by one other pedestrian in the sense radius

  let r-i [body-radius] of turtle-i
  let r-j [body-radius] of turtle-j
  let d-ij [distance turtle-j] of turtle-i
  let x-i [xcor] of turtle-i
  let y-i [ycor] of turtle-i
  let x-j [xcor] of turtle-j
  let y-j [ycor] of turtle-j
  let x-v-i [moment-speed-x] of turtle-i
  let y-v-i [moment-speed-y] of turtle-i
  let x-v-j [moment-speed-x] of turtle-j
  let y-v-j [moment-speed-y] of turtle-j

  let g r-i + r-j - d-ij / 2
  if g <= 0 [set g 0]
  let x-c (x-i - x-j) / d-ij
  let y-c (y-i - y-j) / d-ij

  let x-avoid (2000 * exp (g / 0.08) + 24000 * g) * x-c
  let y-avoid (2000 * exp (g / 0.08) + 24000 * g) * y-c
  let x-fric g * ((y-v-i - y-v-j) * x-c * y-c - (x-v-i - x-v-j) * (y-c ^ 2))
  let y-fric g * ((x-v-i - x-v-j) * x-c * y-c - (y-v-i - y-v-j) * (x-c ^ 2))

  report list (x-avoid + x-fric) (y-avoid + y-fric)

end

to-report ped-force-total [turtle-i]

  ;; report a list of total pedestrian forces from all interacting turtles on a turtle in both directions
  ;; way to add on interaction forces varied for different groups
  let inter-ped [other turtles in-cone (sense-radius * 2) 180] of turtle-i
  ifelse any? inter-ped [
    let p-x 0
    let p-y 0
    foreach [who] of inter-ped [x ->
      let ped-force-j ped-force turtle-i turtle x
      set p-x p-x + first ped-force-j
      set p-y p-y + last ped-force-j
    ]
    report list p-x p-y
  ] [report list 0 0]

end

to-report bus-stop-force [turtle-i]

  ;; calculate the avoidance force from the bus stop
  let inter-patches [patches with [pcolor = red] in-radius 1] of turtle-i
  ifelse any? inter-patches [
    let p-x 0
    let p-y 0
    ask inter-patches [
      let r-i [body-radius] of turtle-i
      let d-i distance turtle-i
      let x-i [xcor] of turtle-i
      let y-i [ycor] of turtle-i
      let x-v [moment-speed-x] of turtle-i
      let y-v [moment-speed-y] of turtle-i

      let g r-i + 0.25 - d-i / 2
      if g <= 0 [set g 0]
      let x-c (x-i - pxcor) / d-i
      let y-c (y-i - pycor) / d-i

      let x-avoid (2000 * exp (g / 0.08) + 24000 * g) * x-c
      let y-avoid (2000 * exp (g / 0.08) + 24000 * g) * y-c
      let x-fric g * (y-v * x-c * y-c - x-v * (y-c ^ 2))
      let y-fric g * (x-v * x-c * y-c - y-v * (x-c ^ 2))

      set p-x x-avoid + x-fric
      set p-y y-avoid + y-fric
    ]
    report list p-x p-y
  ] [report list 0 0]

end

to-report interaction-force [turtle-i]

  let i-x first ped-force-total turtle-i + first bus-stop-force turtle-i
  let i-y last ped-force-total turtle-i + last bus-stop-force turtle-i
  report list i-x i-y

end

;; calculate the total social force on each turtle
to calc-total-force

  ask turtles [
    let will will-force
    let wall wall-force self
    let inter interaction-force self
    let f-x first will + first wall + first inter
    let f-y last will + last wall + last inter
    set total-force list f-x f-y
  ]

end

;; --------------------------------------------------------------------------------------------

;; calculate the speed change and position change and move turtle to the new position
to-report dv [force v-start]
  ;; given the list of total force, and the list of speed change in both directions
  ;; report a list of speed change in x and y direction
  let d-x 0.005 / mass * first force
  let d-y 0.005 / mass * last force

  report list d-x d-y

end

to-report position-change [v-start v-change]
  ;; given the start speed and speed change in both directions
  ;; report a list of distance change in x and y direction
  let d-x (first v-start + 0.5 * first v-change) * 0.005 * 2
  let d-y (last v-start + 0.5 * last v-change) * 0.005 * 2
  report list d-x d-y

end

to move

  ;; make movement
  ask turtles [
    let v-start list moment-speed-x moment-speed-y
    let v-change dv total-force v-start
    set xcor xcor + first position-change v-start v-change
    set ycor ycor + last position-change v-start v-change
    set moment-speed-x moment-speed-x + first v-change
    set moment-speed-y moment-speed-y + last v-change
    ifelse moment-speed-x != 0 [
      set heading atan moment-speed-x moment-speed-y
    ] [
      if moment-speed-y > 0 [set heading 0]
      if moment-speed-y < 0 [set heading 180]
    ]
  ]

end

;;---------------------------------------------------------------------------------------------

to record-collision

  ;; record collision
  ask turtles [
    if behavior = "passing" or behavior = "bypassing" or behavior = "approaching" [
      let current-colli other turtles in-cone (comfort-radius * 2) 180
      if any? current-colli [
        foreach [who] of current-colli [ x ->
          if not member? x collision [set collision lput x collision]
        ]
      ]
    ]
  ]

end

to experience

  ;; record delay and collision incidents for turtles about to finish the trip
  let finish turtles with [abs (xcor - start-end) >= 60]
  if any? finish [
    ask finish [
      ;; record actual time used to go through the channel
      set delay (ticks - start-tick) * 0.005 - 30 / desire-speed
      set delay-record lput delay delay-record

      ;; record times the turtles get too close to others
      set collision-count lput length collision collision-count

      ;; record the delay time and collision count for disabled/non-disabled groups respectively
      ifelse ability != "non-disabled" [
        set delay-record-dis lput delay delay-record-dis
        set colli-count-dis lput length collision colli-count-dis
      ] [
        set delay-record-non lput delay delay-record-non
        set colli-count-non lput length collision colli-count-non
      ]
    ]
  ]

end

to-report total-colli

  ifelse empty? collision-count = false [report sum collision-count] [report 0]

end

to-report mean-colli-dis

  ifelse empty? colli-count-dis = false [report sum colli-count-dis / length colli-count-dis] [report 0]

end

to-report mean-colli-non

  ifelse empty? colli-count-non = false [report sum colli-count-non / length colli-count-non] [report 0]

end

to-report mean-delay

  ifelse empty? delay-record = false [
    report sum delay-record / length delay-record
  ] [report 0]

end

to-report mean-delay-dis

  ifelse empty? delay-record-dis = false [
    report sum delay-record-dis / length delay-record-dis
  ] [report 0]

end

to-report mean-delay-non

  ifelse empty? delay-record-non = false [
    report sum delay-record-non / length delay-record-non
  ] [report 0]

end

to updates

  ask turtles [
    set moment-speed sqrt (moment-speed-x ^ 2 + moment-speed-y ^ 2)
    ifelse heading > 0 and heading <= 180
    [set color (62 - 10 * moment-speed) / 3]
    [set color (302 - 10 * moment-speed) / 3]
  ]

end

to leave

  ;; remove pedestrians reaching the boundaries
  ask turtles with [ xcor < 0 or xcor > 60 or ycor >= upper-edge] [die]

end

;; plot space time diagram
to plotter-LR

  set-current-plot "Space-Time L to R"
  let passersby turtles with [(behavior = "passing" or behavior = "bypassing") and start-end = 0]
  if any? passersby
  [
    ask passersby
    [
      create-temporary-plot-pen word (who) ("")
      ifelse ability = "non-disabled" [set-plot-pen-color red] [set-plot-pen-color black]
      plotxy ticks xcor
    ]
  ]

end

to plotter-RL

  set-current-plot "Space-Time R to L"
  let passersby turtles with [(behavior = "passing" or behavior = "bypassing") and start-end = 60]
  if any? passersby
  [
    ask passersby
    [
      create-temporary-plot-pen word (who) ("")
      ifelse ability = "non-disabled" [set-plot-pen-color red] [set-plot-pen-color black]
      plotxy ticks (60 - xcor)
    ]
  ]

end


;; reporters used in BehaviorSpace
to-report speed-reporter

  ifelse empty? [moment-speed] of turtles = false [report mean [moment-speed] of turtles] [report 0]

end
@#$#@#$#@
GRAPHICS-WINDOW
13
12
631
331
-1
-1
10.0
1
10
1
1
1
0
0
0
1
0
60
0
30
0
0
1
ticks
30.0

BUTTON
860
14
923
47
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
861
56
924
89
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
14
340
321
558
Average Speed
NIL
m/s
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot speed-reporter"

SLIDER
643
66
841
99
pedestrian-flow
pedestrian-flow
100
2000
1800.0
100
1
pph
HORIZONTAL

CHOOSER
748
14
840
59
bus-stop-type
bus-stop-type
"bus flag" "backing road" "backing footway" "backing building"
3

MONITOR
838
286
1002
331
Average Delay Time
mean-delay
2
1
11

MONITOR
641
285
826
330
Total incidents of collision
total-colli
1
1
11

PLOT
641
341
947
558
Space-Time L to R
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

PLOT
955
341
1254
560
Space-Time R to L
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

PLOT
333
341
631
558
Ped Density
NIL
NIL
0.0
10.0
0.0
0.6
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles / sidewalk-width / 30"

CHOOSER
642
14
734
59
sidewalk-width
sidewalk-width
4 6 8
2

MONITOR
837
231
1001
276
Avg Delay Time of Disabled
mean-delay-dis
17
1
11

MONITOR
834
176
1001
221
Avg Delay Time of Non-Disabled
mean-delay-non
17
1
11

MONITOR
640
230
826
275
Avg Collision Count of Disabled
mean-colli-dis
17
1
11

MONITOR
640
177
826
222
Avg Collision Count of Non-Disabled
mean-colli-non
17
1
11

SLIDER
643
108
842
141
disabled-proportion
disabled-proportion
0
0.1
0.05
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="narrow-low-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="narrow-mid-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="narrow-high-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mid-mid-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mid-high-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="wide-high-speed-density" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 200 [ go ]</go>
    <timeLimit steps="180"/>
    <metric>speed-reporter</metric>
    <metric>count turtles / sidewalk-width / 30</metric>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="flow-on-x-4" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>repeat 36000 [ go ]</go>
    <timeLimit steps="1"/>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="pedestrian-flow" first="100" step="100" last="2000"/>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="flow-on-x-6" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36000"/>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="6"/>
    </enumeratedValueSet>
    <steppedValueSet variable="pedestrian-flow" first="100" step="100" last="1800"/>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="flow-on-x-8" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36000"/>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="8"/>
    </enumeratedValueSet>
    <steppedValueSet variable="pedestrian-flow" first="100" step="100" last="1800"/>
    <enumeratedValueSet variable="disabled-proportion">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="proportion" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36000"/>
    <metric>mean-delay</metric>
    <metric>mean-delay-dis</metric>
    <metric>mean-delay-non</metric>
    <metric>total-colli</metric>
    <metric>mean-colli-dis</metric>
    <metric>mean-colli-non</metric>
    <enumeratedValueSet variable="sidewalk-width">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pedestrian-flow">
      <value value="1000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="disabled-proportion" first="0.01" step="0.01" last="0.1"/>
    <enumeratedValueSet variable="bus-stop-type">
      <value value="&quot;bus flag&quot;"/>
      <value value="&quot;backing road&quot;"/>
      <value value="&quot;backing footway&quot;"/>
      <value value="&quot;backing building&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

# AIRBUS A320 SYSTEMS FILE
##########################

## LIVERY SELECT
################

print("Initializing livery select for " ~ getprop("sim/aero"));
aircraft.livery.init("Aircraft/A320-family/Models/Liveries/" ~ getprop("sim/aero"));

setlistener("sim/model/livery/texture", func
 {
 var base = getprop("sim/model/livery/texture");
 setprop("sim/model/livery/texture-path[0]", "../Models/" ~ base);
 setprop("sim/model/livery/texture-path[1]", "../../Models/" ~ base);
 }, 1, 1);

## LIGHTS
#########

# create all lights
var beacon_switch = props.globals.getNode("controls/switches/beacon", 2);
var beacon = aircraft.light.new("sim/model/lights/beacon", [0.015, 3], "controls/lighting/beacon");

var strobe_switch = props.globals.getNode("controls/switches/strobe", 2);
var strobe = aircraft.light.new("sim/model/lights/strobe", [0.025, 1.5], "controls/lighting/strobe");

## ENGINES
##########

# trigger engine failure when the "on-fire" property is set to true
var failEngine = func(engineNo)
 {
 if (props.globals.getNode("engines/engine[" ~ engineNo ~ "]/on-fire").getBoolValue())
  {
  props.globals.getNode("sim/failure-manager/engines/engine[" ~ engineNo ~ "]/serviceable").setBoolValue(0);
  }
 };
setlistener("engines/engine[0]/on-fire", func
 {
 failEngine(0);
 }, 0, 0);
setlistener("engines/engine[1]/on-fire", func
 {
 failEngine(1);
 }, 0, 0);

# startup/shutdown functions
var startup = func
 {
 setprop("controls/engines/engine[0]/cutoff", 1);
 setprop("controls/engines/engine[1]/cutoff", 1);
 setprop("controls/engines/engine[0]/starter", 1);
 setprop("controls/engines/engine[1]/starter", 1);
 setprop("controls/electric/avionics-switch", 1);
 setprop("controls/electric/battery-switch", 1);
 setprop("controls/lighting/instruments-norm", 0.8);

 settimer(func
  {
  setprop("controls/engines/engine[0]/cutoff", 0);
  setprop("controls/engines/engine[1]/cutoff", 0);
  }, 2);
 };
var shutdown = func
 {
 setprop("controls/engines/engine[0]/cutoff", 1);
 setprop("controls/engines/engine[1]/cutoff", 1);
 setprop("controls/electric/avionics-switch", 0);
 setprop("controls/electric/battery-switch", 0);
 setprop("controls/lighting/instruments-norm", 0);
 };

# listener to activate these functions accordingly
setlistener("sim/model/start-idling", func(idle)
 {
 var run = idle.getBoolValue();
 if (run)
  {
  startup();
  }
 else
  {
  shutdown();
  }
 }, 0, 0);

## GEAR
#######

# prevent retraction of the landing gear when any of the wheels are compressed
setlistener("controls/gear/gear-down", func
 {
 var down = props.globals.getNode("controls/gear/gear-down").getBoolValue();
 if (!down and (getprop("gear/gear[0]/wow") or getprop("gear/gear[1]/wow") or getprop("gear/gear[2]/wow")))
  {
  props.globals.getNode("controls/gear/gear-down").setBoolValue(1);
  }
 });

## INSTRUMENTS
##############

var instruments =
 {
 calcBugDeg: func(bug, limit)
  {
  var heading = getprop("orientation/heading-magnetic-deg");
  var bugDeg = 0;

  while (bug < 0)
   {
   bug += 360;
   }
  while (bug > 360)
   {
   bug -= 360;
   }
  if (bug < limit)
   {
   bug += 360;
   }
  if (heading < limit)
   {
   heading += 360;
   }
  # bug is adjusted normally
  if (math.abs(heading - bug) < limit)
   {
   bugDeg = heading - bug;
   }
  elsif (heading - bug < 0)
   {
   # bug is on the far right
   if (math.abs(heading - bug + 360 >= 180))
    {
    bugDeg = -limit;
    }
   # bug is on the far left
   elsif (math.abs(heading - bug + 360 < 180))
    {
    bugDeg = limit;
    }
   }
  else
   {
   # bug is on the far right
   if (math.abs(heading - bug >= 180))
    {
    bugDeg = -limit;
    }
   # bug is on the far left
   elsif (math.abs(heading - bug < 180))
    {
    bugDeg = limit;
    }
   }

  return bugDeg;
  },
 loop: func
  {
  instruments.setHSIBugsDeg();
  instruments.setSpeedBugs();
  instruments.setMPProps();
  instruments.calcEGTDegC();
  instruments.calcTotalFuel();

  settimer(instruments.loop, 0);
  },
 # set the rotation of the HSI bugs
 setHSIBugsDeg: func
  {
  setprop("sim/model/A320/heading-bug-pfd-deg", instruments.calcBugDeg(getprop("autopilot/settings/heading-bug-deg"), 80));
  setprop("sim/model/A320/heading-bug-deg", instruments.calcBugDeg(getprop("autopilot/settings/heading-bug-deg"), 37));
  setprop("sim/model/A320/nav1-bug-deg", instruments.calcBugDeg(getprop("instrumentation/nav[0]/heading-deg"), 37));
  setprop("sim/model/A320/nav2-bug-deg", instruments.calcBugDeg(getprop("instrumentation/nav[1]/heading-deg"), 37));
  if (getprop("autopilot/route-manager/route/num") > 0 and getprop("autopilot/route-manager/wp[0]/bearing-deg") != nil)
   {
   setprop("sim/model/A320/wp-bearing-deg", instruments.calcBugDeg(getprop("autopilot/route-manager/wp[0]/bearing-deg"), 45));
   }
  },
 setSpeedBugs: func
  {
  setprop("sim/model/A320/ias-bug-kt-norm", getprop("autopilot/settings/target-speed-kt") - getprop("velocities/airspeed-kt"));
  setprop("sim/model/A320/mach-bug-kt-norm", getprop("autopilot/settings/target-speed-mach") * 600 - getprop("velocities/uBody-fps") * 0.5924838);
  },
 setMPProps: func
  {
  var calcMPDistance = func(tree)
   {
   var x = getprop(tree ~ "position/global-x");
   var y = getprop(tree ~ "position/global-y");
   var z = getprop(tree ~ "position/global-z");
   var coords = geo.Coord.new().set_xyz(x, y, z);

   var distance = nil;
   call(func distance = geo.aircraft_position().distance_to(coords), nil, var err = []);
   if (size(err) or distance == nil)
    {
    return 0;
    }
   else
    {
    return distance;
    }
   };
  var calcMPBearing = func(tree)
   {
   var x = getprop(tree ~ "position/global-x");
   var y = getprop(tree ~ "position/global-y");
   var z = getprop(tree ~ "position/global-z");
   var coords = geo.Coord.new().set_xyz(x, y, z);

   return geo.aircraft_position().course_to(coords);
   };
  if (getprop("ai/models/multiplayer[0]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[0]", calcMPDistance("ai/models/multiplayer[0]/"));
   setprop("sim/model/A320/multiplayer-bearing[0]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[0]/"), 45));
   }
  if (getprop("ai/models/multiplayer[1]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[1]", calcMPDistance("ai/models/multiplayer[1]/"));
   setprop("sim/model/A320/multiplayer-bearing[1]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[1]/"), 45));
   }
  if (getprop("ai/models/multiplayer[2]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[2]", calcMPDistance("ai/models/multiplayer[2]/"));
   setprop("sim/model/A320/multiplayer-bearing[2]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[2]/"), 45));
   }
  if (getprop("ai/models/multiplayer[3]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[3]", calcMPDistance("ai/models/multiplayer[3]/"));
   setprop("sim/model/A320/multiplayer-bearing[3]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[3]/"), 45));
   }
  if (getprop("ai/models/multiplayer[4]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[4]", calcMPDistance("ai/models/multiplayer[4]/"));
   setprop("sim/model/A320/multiplayer-bearing[4]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[4]/"), 45));
   }
  if (getprop("ai/models/multiplayer[5]/valid"))
   {
   setprop("sim/model/A320/multiplayer-distance[5]", calcMPDistance("ai/models/multiplayer[5]/"));
   setprop("sim/model/A320/multiplayer-bearing[5]", instruments.calcBugDeg(calcMPBearing("ai/models/multiplayer[5]/"), 45));
   }
  },
 calcEGTDegC: func()
  {
  if (getprop("engines/engine[0]/egt-degf") != nil)
   {
   setprop("engines/engine[0]/egt-degc", (getprop("engines/engine[0]/egt-degf") - 32) * 1.8);
   }
  if (getprop("engines/engine[1]/egt-degf") != nil)
   {
   setprop("engines/engine[1]/egt-degc", (getprop("engines/engine[1]/egt-degf") - 32) * 1.8);
   }
  },
 calcTotalFuel: func()
  {
  if (getprop("consumables/fuel/tank[0]/level-lbs") != nil)
   {
   var tank1 = getprop("consumables/fuel/tank[0]/level-lbs");
   var tank2 = getprop("consumables/fuel/tank[1]/level-lbs");
   var tank3 = getprop("consumables/fuel/tank[2]/level-lbs");
   var tank4 = getprop("consumables/fuel/tank[3]/level-lbs");
   var tank5 = getprop("consumables/fuel/tank[4]/level-lbs");
   var tank6 = getprop("consumables/fuel/tank[5]/level-lbs");
   var tank7 = getprop("consumables/fuel/tank[6]/level-lbs");
   setprop("consumables/fuel/total-fuel-lbs", tank1 + tank2 + tank3 + tank4 + tank5 + tank6 + tank7);
   }
  }
 };
# start the loop 2 seconds after the FDM initializes
setlistener("sim/signals/fdm-initialized", func
 {
 settimer(instruments.loop, 2);
 });

## AUTOPILOT
############

# flight director pitch/roll computer
var flightDirectorLoop = func
 {
 var apPitch = getprop("autopilot/internal/target-pitch-deg");
 var acPitch = getprop("orientation/pitch-deg");
 if (apPitch and acPitch)
  {
  setprop("autopilot/internal/flight-director-pitch-deg", apPitch - acPitch);
  }

 var apRoll = getprop("autopilot/internal/target-roll-deg");
 var acRoll = getprop("orientation/roll-deg");
 if (apRoll and acRoll)
  {
  setprop("autopilot/internal/flight-director-roll-deg", apRoll - acRoll);
  }

 settimer(flightDirectorLoop, 0.05);
 };
# start the loop 2 seconds after the FDM initializes
setlistener("sim/signals/fdm-initialized", func
 {
 settimer(flightDirectorLoop, 2);
 });

# set the vertical speed setting if the altitude setting is higher/lower than the current altitude
var APVertSpeedSet = func
 {
 var altitude = getprop("instrumentation/altimeter/indicated-altitude-ft");
 var altitudeSetting = getprop("autopilot/settings/target-altitude-ft");
 var vertSpeedSetting = getprop("autopilot/settings/vertical-speed-fpm");

 if (altitude and altitudeSetting and vertSpeedSetting and math.abs(altitude - altitudeSetting) > 100)
  {
  if (altitude > altitudeSetting and vertSpeedSetting >= 0)
   {
   setprop("autopilot/settings/vertical-speed-fpm", -1000);
   }
  elsif (altitude < altitudeSetting and vertSpeedSetting <= 0)
   {
   setprop("autopilot/settings/vertical-speed-fpm", 1800);
   }
  }
 };
setlistener("autopilot/settings/target-altitude-ft", APVertSpeedSet, 1, 0);

## DOORS
########

# create all doors
# front doors
var doorl1 = aircraft.door.new("sim/model/door-positions/doorl1", 2);
var doorr1 = aircraft.door.new("sim/model/door-positions/doorr1", 2);

# rear doors
var doorl4 = aircraft.door.new("sim/model/door-positions/doorl4", 2);
var doorr4 = aircraft.door.new("sim/model/door-positions/doorr4", 2);

# cargo holds
var cargobulk = aircraft.door.new("sim/model/door-positions/cargobulk", 2.5);
var cargoaft = aircraft.door.new("sim/model/door-positions/cargoaft", 2.5);
var cargofwd = aircraft.door.new("sim/model/door-positions/cargofwd", 2.5);

# door opener/closer
var triggerDoor = func(door, doorName, doorDesc)
 {
 if (getprop("sim/model/door-positions/" ~ doorName ~ "/position-norm") > 0)
  {
  gui.popupTip("Closing " ~ doorDesc ~ " door");
  door.toggle();
  }
 else
  {
  if (getprop("velocities/groundspeed-kt") > 5)
   {
   gui.popupTip("You cannot open the doors while the aircraft is moving");
   }
  else
   {
   gui.popupTip("Opening " ~ doorDesc ~ " door");
   door.toggle();
   }
  }
 };

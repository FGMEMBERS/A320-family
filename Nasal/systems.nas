# AIRBUS A320 SYSTEMS FILE
##########################

# NOTE: This file contains a loop for running all update functions, so it should be loaded last

## SYSTEMS LOOP
###############

var systems =
 {
 stopUpdate: 0,
 init: func
  {
  print("A320 aircraft systems ... initialized");
  systems.stop();
  settimer(func
   {
   systems.stopUpdate = 0;
   systems.update();
   }, 0.5);
  },
 stop: func
  {
  systems.stopUpdate = 1;
  },
 update: func
  {
  apu1.update();
  engine1.update();
  engine2.update();
  instruments.update();
  update_electrical();

  # stop calling our systems code if the stop() function was called or the aircraft crashes
  if (!systems.stopUpdate and !props.globals.getNode("sim/crashed").getBoolValue())
   {
   settimer(systems.update, 0);
   }
  }
 };

# call init() 2 seconds after the FDM is ready
setlistener("sim/signals/fdm-initialized", func
 {
 settimer(systems.init, 2);
 }, 0, 0);
# call init() if the simulator resets
setlistener("sim/signals/reinit", func(reinit)
 {
 if (reinit.getBoolValue())
  {
  systems.init();
  }
 }, 0, 0);

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

# logo lights listener
setlistener("controls/lighting/nav-lights-switch", func
 {
 var nav_lights = props.globals.getNode("sim/model/lights/nav-lights");
 var logo_lights = props.globals.getNode("sim/model/lights/logo-lights");
 var setting = getprop("controls/lighting/nav-lights-switch");
 if (setting == 1)
  {
  nav_lights.setBoolValue(1);
  logo_lights.setBoolValue(0);
  }
 elsif (setting == 2)
  {
  nav_lights.setBoolValue(1);
  logo_lights.setBoolValue(1);
  }
 else
  {
  nav_lights.setBoolValue(0);
  logo_lights.setBoolValue(0);
  }
 });

## TIRE SMOKE/RAIN
##################

var tiresmoke_system = aircraft.tyresmoke_system.new(0, 1, 2);
aircraft.rain.init();

## SOUNDS
#########

# seatbelt/no smoking sign triggers
setlistener("controls/switches/seatbelt-sign", func
 {
 props.globals.getNode("sim/sound/seatbelt-sign").setBoolValue(1);

 settimer(func
  {
  props.globals.getNode("sim/sound/seatbelt-sign").setBoolValue(0);
  }, 2);
 });
setlistener("controls/switches/no-smoking-sign", func
 {
 props.globals.getNode("sim/sound/no-smoking-sign").setBoolValue(1);

 settimer(func
  {
  props.globals.getNode("sim/sound/no-smoking-sign").setBoolValue(0);
  }, 2);
 });


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
 update: func
  {
  instruments.setHSIBugsDeg();
  instruments.setSpeedBugs();
  instruments.setMPProps();
  instruments.calcEGTDegC();
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
  setprop("sim/model/A320/mach-bug-kt-norm", (getprop("autopilot/settings/target-speed-mach") - getprop("velocities/mach")) * 600);
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
  }
 };

## AUTOPILOT
############

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

# middle doors (A321 only)
var doorl2 = aircraft.door.new("sim/model/door-positions/doorl2", 2);
var doorr2 = aircraft.door.new("sim/model/door-positions/doorr2", 2);
var doorl3 = aircraft.door.new("sim/model/door-positions/doorl3", 2);
var doorr3 = aircraft.door.new("sim/model/door-positions/doorr3", 2);

# rear doors
var doorl4 = aircraft.door.new("sim/model/door-positions/doorl4", 2);
var doorr4 = aircraft.door.new("sim/model/door-positions/doorr4", 2);

# cargo holds
var cargobulk = aircraft.door.new("sim/model/door-positions/cargobulk", 2.5);
var cargoaft = aircraft.door.new("sim/model/door-positions/cargoaft", 2.5);
var cargofwd = aircraft.door.new("sim/model/door-positions/cargofwd", 2.5);

# seat armrests in the flight deck
var armrests = aircraft.door.new("sim/model/door-positions/armrests", 2);

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
 
 setlistener("/sim/signals/fdm-initialized", func {
  it2.ap_init();
  var autopilot = gui.Dialog.new("sim/gui/dialogs/autopilot/dialog", "Aircraft/A320-family/Systems/autopilot-dlg.xml");
});

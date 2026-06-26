#!/bin/bash

sleep 30

# Turn off the display (forces DPMS power-off)
export DISPLAY=:0
xset dpms force off

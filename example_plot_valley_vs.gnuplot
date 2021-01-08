#!/usr/bin/env gnuplot

# A short keyword shortcuts for uninitiated in Gnuplot:
#
# u - using, selects columns or expressions to plot with
# t - title, key
# lw - linewidth
# lt - linetype
# lc - linecolor
# w - with, used to change plotting style (other options are d - dots, p - points, pl - pointline, pt 5 - pointtype 5, l - lines, lp - linespoints, etc).
# step - use steps in x and y, not connected lines or points.
# *label - the thing below and on the left/right of the graph with numbers
# key - a legend in the box in the upper top corner.
# title ... noenhanced - disable processing of _ as subscript, i.e. like in H_20, rendering as H₂O.
# for - process multiple inputs (usually filenames)
# set yrange [*:*] - reset back to autoranging in y axis.
# system - execute external command
#
# This only covers about 0.2% of Gnuplot functionality tho, so check Gnuplot
# demos and docs, at http://www.gnuplot.info/

set terminal pngcairo size 1600,1200
set output "example_plot_valley_vs.png"

#set xlabel "Time [s]"

t = "Valley Extreme settings VRAM and RSS. zink-wip git-e28f3e5a92. zink on radv-aco vs radeonsi."
# set title t

set xrange [0:12000]

# Set fixed margins, especially l and r, so time aligns perfectly
# between multiple plots of multiplot.
set tmargin 1
set bmargin 1.5
set lmargin 9
set rmargin 26  # This is pretty big marging, but I don't want to overlay key over plot data.

# Line styles for ColorBrewer Set1
# For use with qualitative/categorical data
# Author: Anna Schneider
set style line 1 lt 1 lc rgb '#E41A1C' lw 2 # red
set style line 2 lt 1 lc rgb '#377EB8' lw 2 # blue
set style line 3 lt 1 lc rgb '#4DAF4A' lw 2 # green
set style line 4 lt 1 lc rgb '#984EA3' lw 2 # purple
set style line 5 lt 1 lc rgb '#FF7F00' lw 2 # orange
set style line 6 lt 1 lc rgb '#FFFF33' lw 2 # yellow
set style line 7 lt 1 lc rgb '#A65628' lw 2 # brown
set style line 8 lt 1 lc rgb '#F781BF' lw 2 # pink


set multiplot layout 3,1 title t # noenhanced

set grid x y

set xtics nomirror

#set key box width 2 height 3 opaque
set key box opaque
#set key at screen 0.99, graph 0.99
set key outside right top
set key Left reverse samplen 0.75


filenames = system("ls -1 /tmp/valley-mm-*.txt | grep radeon")
filename = "/tmp/valley-mm-zink.txt"

set yrange [0:]

suffix(x, filename) = (strstrt(filename, "zink") > 0 ? sprintf("%s zink", x) : sprintf("%s radeon", x));

set ylabel "MiB"
plot for [filename in filenames] filename u 3:5 w step t suffix("VRAM", filename) lw 2, \
     for [filename in filenames] filename u 3:8 w step t suffix("RSS valley_x64", filename) noenhanced lw 2, \
     for [filename in filenames] filename u 3:10 w step t suffix("RSS Xorg", filename) noenhanced lw 2

set yrange [0:105]
set ylabel "%"
set y2label "MHz"
set y2tics
plot filename u 3:4 w step t "GPU%" lw 2, \
     filename u 3:6 w step axes x1y2 t "SCLK" lw 2

set yrange [0:*]

set xlabel "Time [s]"

unset y2label
unset y2tics

set ylabel "%"
plot for [filename in filenames] filename u 3:7 w step t suffix("CPU% valley_x64", filename) noenhanced lw 1, \
     for [filename in filenames] filename u 3:9 w step t suffix("CPU% Xorg", filename) noenhanced lw 1

unset multiplot

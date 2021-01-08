#!/usr/bin/env gnuplot

set terminal pngcairo size 1024,768
set output "example_plot_valley.png"

#set xlabel "Time [s]"

t = "Valley Extreme settings VRAM and RSS. zink-wip git-e28f3e5a92. zink on radv-aco."
# set title t

# set xrange [0:2700]

set tmargin 1
set bmargin 1.5
set lmargin 9
set rmargin 22

# line styles for ColorBrewer Set1
# for use with qualitative/categorical data
# author: Anna Schneider
set style line 1 lt 1 lc rgb '#E41A1C' lw 2 # red
set style line 2 lt 1 lc rgb '#377EB8' lw 2 # blue
set style line 3 lt 1 lc rgb '#4DAF4A' lw 2 # green
set style line 4 lt 1 lc rgb '#984EA3' lw 2 # purple
set style line 5 lt 1 lc rgb '#FF7F00' lw 2 # orange
set style line 6 lt 1 lc rgb '#FFFF33' lw 2 # yellow
set style line 7 lt 1 lc rgb '#A65628' lw 2 # brown
set style line 8 lt 1 lc rgb '#F781BF' lw 2 # pink


set multiplot layout 3,1 title t # noehnanced

set grid x y

set xtics nomirror

#set key box width 2 height 3 opaque
set key box opaque
#set key at screen 0.99, graph 0.99
set key outside right top
set key Left reverse samplen 0.75


filenames = system("ls -1 /tmp/valley-mm*.txt")
filename = "/tmp/valley-mm-zink.txt"

set yrange [0:]

set ylabel "MiB"
plot filename u 3:5 w step t "VRAM" lw 2, \
     filename u 3:8 w step t "RSS valley_x64" noenhanced lw 2, \
     filename u 3:10 w step t "RSS Xorg" noenhanced lw 2

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
plot filename u 3:7 w step t "CPU% valley_x64" noenhanced lw 1, \
     filename u 3:9 w step t "CPU% Xorg" noenhanced lw 1

unset multiplot

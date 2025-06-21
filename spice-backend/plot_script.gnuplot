set terminal pngcairo size 800,600

set output 'plots/v_5.png'
set title "v 4,2"
set xlabel "Time (s)"
set ylabel "Voltage (V)"
set grid
plot "rc_data.txt" using 1:2 with lines title "V(out)"

set output 'plots/v_2.png'
set title "v 6"
set xlabel "Time (s)"
set ylabel "Voltage (V)"
set grid
plot "rc_data.txt" using 1:4 with lines title "V(out)"
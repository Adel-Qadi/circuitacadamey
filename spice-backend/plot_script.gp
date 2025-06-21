set terminal pngcairo size 800,600

set output 'plots/v_0.png'
set title "v 1,2"
set xlabel "Time (s)"
set ylabel "Voltage (V)"
set grid
plot "rc_data.txt" using 1:2 with lines title "V(out)"

set output 'plots/v_1.png'
set title "v 2"
set xlabel "Time (s)"
set ylabel "Voltage (V)"
set grid
plot "rc_data.txt" using 1:4 with lines title "V(out)"
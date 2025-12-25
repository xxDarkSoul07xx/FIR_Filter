import numpy as np
import matplotlib.pyplot as plt
from scipy import signal

# filter coefficients for a 4 tap lowpass
h = [0.25, 0.25, 0.25, 0.25]

# input signal for a square wave
x = [1, 1, 1, 1, -1, -1, -1, -1] * 4

y = []

# loop through each output sample
for n in range(len(x)):
    output_sample = 0.0

    # loop through each coefficient
    for k in range(len(h)):
        index = n - k

        if index >= 0:
            output_sample = output_sample + h[k] * x[index]

    y.append(output_sample)

# figure out the frequency response
w, h_freq = signal.freqz(h, worN=8000)


# plotting
plt.figure(figsize=(10, 6))
plt.plot(w/np.pi, 20 * np.log10(abs(h_freq)), 'b', linewidth=2)
plt.xlabel('Normalized Frequency (×π rad/sample)')
plt.ylabel('Magnitude (dB)')
plt.title('Frequency Response - Lowpass Filter')
plt.grid(True)
plt.xlim(0, 1)
plt.axhline(-3, color='r', linestyle='--', label='-3dB cutoff')
plt.legend()
plt.show()
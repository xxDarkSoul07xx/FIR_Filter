import numpy as np
import matplotlib.pyplot as plt

# x is the input samples, h is the coefficients
def fir_filter(x, h):
    y = []
    for n in range(len(x)):
        output_sample = 0.0
        for k in range(len(h)):
            index = n - k
            if index >= 0:
                output_sample += h[k] * x[index]
        y.append(output_sample)
    return y


def test_filter(h, name, x):
    print("=" * 70)
    print(f"{name}")
    print(f"Coefficients: {h}")
    print("=" * 70)
    
    y = fir_filter(x, h)
    
    for i in range(min(16, len(y))):
        print(f"Sample {i:2d}: {y[i]:7.4f}")
    print()
    
    return y


if __name__ == "__main__":
    # input for a square wave
    x = [1, 1, 1, 1, -1, -1, -1, -1] * 4
    
    # lowpass moving average
    h_lowpass = [0.25, 0.25, 0.25, 0.25]
    y_lowpass = test_filter(h_lowpass, "LOWPASS FILTER (Moving Average)", x)
    
    # highpass
    h_highpass = [0.25, -0.25, -0.25, 0.25]
    y_highpass = test_filter(h_highpass, "HIGHPASS FILTER", x)
    
    # plot
    plt.figure(figsize=(15, 5))
    
    # plot lowpass
    plt.subplot(1, 3, 1)
    plt.plot(x[:16], 'b.-', label='Input', linewidth=2, markersize=8)
    plt.plot(y_lowpass[:16], 'g.-', label='Output', linewidth=2, markersize=8)
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=11)
    plt.title('Lowpass: Smooth Edges', fontsize=13, fontweight='bold')
    plt.xlabel('Sample n')
    plt.ylabel('Amplitude')
    plt.ylim(-1.2, 1.2)
    
    # plot highpass
    plt.subplot(1, 3, 2)
    plt.plot(x[:16], 'b.-', label='Input', linewidth=2, markersize=8)
    plt.plot(y_highpass[:16], 'r.-', label='Output', linewidth=2, markersize=8)
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=11)
    plt.title('Highpass: Emphasize Edges', fontsize=13, fontweight='bold')
    plt.xlabel('Sample n')
    plt.ylabel('Amplitude')
    plt.ylim(-1.2, 1.2)
    
    # overlay them
    plt.subplot(1, 3, 3)
    plt.plot(x[:16], 'b-', label='Input', linewidth=2, alpha=0.5)
    plt.plot(y_lowpass[:16], 'g.-', label='Lowpass', linewidth=2, markersize=6)
    plt.plot(y_highpass[:16], 'r.-', label='Highpass', linewidth=2, markersize=6)
    plt.grid(True, alpha=0.3)
    plt.legend(fontsize=11)
    plt.title('Comparison', fontsize=13, fontweight='bold')
    plt.xlabel('Sample n')
    plt.ylabel('Amplitude')
    plt.ylim(-1.2, 1.2)
    
    plt.tight_layout()
    plt.savefig('fir_filter_comparison.png', dpi=150, bbox_inches='tight')
    print("Plot saved as 'fir_filter_comparison.png'")
    plt.show()